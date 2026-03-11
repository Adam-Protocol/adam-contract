pub const RATE_SETTER_ROLE: felt252 = selector!("RATE_SETTER_ROLE");
pub const PAUSER_ROLE: felt252 = selector!("PAUSER_ROLE");
pub const UPGRADER_ROLE: felt252 = selector!("UPGRADER_ROLE");
/// 1e18 — fixed-point precision for rates
pub const RATE_PRECISION: u256 = 1_000_000_000_000_000_000_u256;
pub const MAX_FEE_BPS: u16 = 1000; // 10%

/// AdamSwap — core exchange contract (upgradeable).
#[starknet::contract]
pub mod AdamSwap {
    use core::num::traits::Zero;
    use openzeppelin::access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::security::pausable::PausableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ClassHash, ContractAddress, get_block_timestamp, get_caller_address};
    use crate::errors::Errors;
    use crate::events::{BuyExecuted, RateUpdated, SellExecuted, SwapExecuted};
    use crate::interfaces::{
        IAdamPoolDispatcher, IAdamPoolDispatcherTrait, IAdamTokenDispatcher,
        IAdamTokenDispatcherTrait,
    };
    use super::{MAX_FEE_BPS, PAUSER_ROLE, RATE_PRECISION, RATE_SETTER_ROLE, UPGRADER_ROLE};

    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    #[abi(embed_v0)]
    impl AccessControlMixinImpl =
        AccessControlComponent::AccessControlMixinImpl<ContractState>;

    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        // External stablecoin address (e.g., USDC)
        usdc_address: ContractAddress,
        // Adam Protocol stablecoin addresses
        adusd_address: ContractAddress,
        adngn_address: ContractAddress,
        adkes_address: ContractAddress,
        adghs_address: ContractAddress,
        adzar_address: ContractAddress,
        // Repository for commitments and nullifiers
        pool_address: ContractAddress,
        // Address where protocol fees are sent
        treasury: ContractAddress,
        // Transaction fee in basis points (1/100th of a percent)
        fee_bps: u16,
        // Exchange rates between token pairs
        rates: Map<(ContractAddress, ContractAddress), u256>,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        // Fired when a user buys Adam stablecoins with USDC
        BuyExecuted: BuyExecuted,
        // Fired when a user sells Adam stablecoins back to USDC
        SellExecuted: SellExecuted,
        // Fired when a user swaps between different Adam stablecoins
        SwapExecuted: SwapExecuted,
        // Fired when an admin updates the exchange rate
        RateUpdated: RateUpdated,
        #[flat]
        PausableEvent: PausableComponent::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        treasury: ContractAddress,
        usdc_address: ContractAddress,
        adusd_address: ContractAddress,
        adngn_address: ContractAddress,
        pool_address: ContractAddress,
        fee_bps: u16,
    ) {
        assert(!owner.is_zero(), Errors::ZERO_ADDRESS);
        assert(!treasury.is_zero(), Errors::ZERO_ADDRESS);
        assert(!usdc_address.is_zero(), Errors::ZERO_ADDRESS);
        assert(!adusd_address.is_zero(), Errors::ZERO_ADDRESS);
        assert(!adngn_address.is_zero(), Errors::ZERO_ADDRESS);
        assert(!pool_address.is_zero(), Errors::ZERO_ADDRESS);
        assert(fee_bps <= MAX_FEE_BPS, Errors::INVALID_FEE);

        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, owner);
        self.accesscontrol._grant_role(RATE_SETTER_ROLE, owner);
        self.accesscontrol._grant_role(PAUSER_ROLE, owner);
        self.accesscontrol._grant_role(UPGRADER_ROLE, owner);

        self.usdc_address.write(usdc_address);
        self.adusd_address.write(adusd_address);
        self.adngn_address.write(adngn_address);
        self.pool_address.write(pool_address);
        self.treasury.write(treasury);
        self.fee_bps.write(fee_bps);

        // USDC <-> ADUSD starts at 1:1
        self.rates.write((usdc_address, adusd_address), RATE_PRECISION);
        self.rates.write((adusd_address, usdc_address), RATE_PRECISION);
    }

    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        /// Allows users to buy Adam stablecoins using USDC.
        /// Transfers USDC to treasury, mints Adam tokens, and registers commitment.
        #[external(v0)]
        fn buy(
            ref self: ContractState,
            token_in: ContractAddress,
            amount_in: u256,
            token_out: ContractAddress,
            commitment: felt252,
        ) {
            self.pausable.assert_not_paused();
            let caller = get_caller_address();
            assert(amount_in > 0, Errors::ZERO_AMOUNT);
            assert(token_in == self.usdc_address.read(), Errors::INVALID_TOKEN);
            assert(self._is_valid_adam_token(token_out), Errors::INVALID_TOKEN);

            // Transfer USDC to treasury
            IERC20Dispatcher { contract_address: token_in }
                .transfer_from(caller, self.treasury.read(), amount_in);

            // Mint equivalent tokens after fee
            let amount_out = self._apply_rate_and_fee(token_in, token_out, amount_in);
            IAdamTokenDispatcher { contract_address: token_out }.mint(caller, amount_out);

            // Register commitment on-chain (no amount included)
            IAdamPoolDispatcher { contract_address: self.pool_address.read() }
                .register_commitment(commitment, token_out);

            self.emit(BuyExecuted { commitment, token_out, timestamp: get_block_timestamp() });
        }

        /// Allows users to sell Adam stablecoins and spend a nullifier.
        /// Burns the input tokens and marks the nullifier as spent in the pool.
        #[external(v0)]
        fn sell(
            ref self: ContractState,
            token_in: ContractAddress,
            amount: u256,
            nullifier: felt252,
            commitment: felt252,
            proof: Span<felt252>,
            new_commitments: Span<felt252>,
        ) {
            self.pausable.assert_not_paused();
            let caller = get_caller_address();
            assert(amount > 0, Errors::ZERO_AMOUNT);
            assert(self._is_valid_adam_token(token_in), Errors::INVALID_TOKEN);

            let pool = IAdamPoolDispatcher { contract_address: self.pool_address.read() };
            assert(pool.is_commitment_registered(commitment), Errors::COMMITMENT_NOT_FOUND);
            assert(!pool.is_nullifier_spent(nullifier), Errors::NULLIFIER_SPENT);

            IAdamTokenDispatcher { contract_address: token_in }.burn(caller, amount);
            pool.spend_nullifier(nullifier, proof, new_commitments);

            self.emit(SellExecuted { nullifier, token_in, timestamp: get_block_timestamp() });
        }

        #[external(v0)]
        fn swap(
            ref self: ContractState,
            token_in: ContractAddress,
            amount_in: u256,
            token_out: ContractAddress,
            min_amount_out: u256,
            nullifier: felt252,
            proof: Span<felt252>,
            commitment: felt252,
        ) {
            self.pausable.assert_not_paused();
            let caller = get_caller_address();
            assert(amount_in > 0, Errors::ZERO_AMOUNT);
            assert(token_in != token_out, Errors::INVALID_TOKEN);
            assert(self._is_valid_adam_token(token_in), Errors::INVALID_TOKEN);
            assert(self._is_valid_adam_token(token_out), Errors::INVALID_TOKEN);

            let amount_out = self._apply_rate_and_fee(token_in, token_out, amount_in);
            assert(amount_out >= min_amount_out, Errors::SLIPPAGE_EXCEEDED);

            let pool = IAdamPoolDispatcher { contract_address: self.pool_address.read() };
            
            // In a private swap, we spend an existing note (nullifier) and create a new one (commitment)
            pool.spend_nullifier(nullifier, proof, array![commitment].span());

            IAdamTokenDispatcher { contract_address: token_in }.burn(caller, amount_in);
            IAdamTokenDispatcher { contract_address: token_out }.mint(caller, amount_out);

            self
                .emit(
                    SwapExecuted {
                        commitment, token_in, token_out, timestamp: get_block_timestamp(),
                    },
                );
        }

        #[external(v0)]
        fn set_rate(
            ref self: ContractState,
            token_from: ContractAddress,
            token_to: ContractAddress,
            rate: u256,
        ) {
            self.accesscontrol.assert_only_role(RATE_SETTER_ROLE);
            assert(rate > 0, Errors::ZERO_AMOUNT);
            self.rates.write((token_from, token_to), rate);
            self.emit(RateUpdated { token_from, token_to, rate, timestamp: get_block_timestamp() });
        }

        /// Sets the transaction fee in basis points.
        /// Requires DEFAULT_ADMIN_ROLE.
        #[external(v0)]
        fn set_fee_bps(ref self: ContractState, fee_bps: u16) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            assert(fee_bps <= MAX_FEE_BPS, Errors::INVALID_FEE);
            self.fee_bps.write(fee_bps);
        }

        /// Sets the USDC address.
        /// Requires DEFAULT_ADMIN_ROLE.
        #[external(v0)]
        fn set_usdc_address(ref self: ContractState, usdc_address: ContractAddress) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            assert(!usdc_address.is_zero(), Errors::ZERO_ADDRESS);
            self.usdc_address.write(usdc_address);
        }

        /// Pauses the swap contract.
        /// Requires PAUSER_ROLE.
        #[external(v0)]
        fn pause(ref self: ContractState) {
            self.accesscontrol.assert_only_role(PAUSER_ROLE);
            self.pausable.pause();
        }

        /// Unpauses the swap contract.
        /// Requires PAUSER_ROLE.
        #[external(v0)]
        fn unpause(ref self: ContractState) {
            self.accesscontrol.assert_only_role(PAUSER_ROLE);
            self.pausable.unpause();
        }

        /// Fetches the current exchange rate for a token pair.
        #[external(v0)]
        fn get_rate(
            self: @ContractState, token_from: ContractAddress, token_to: ContractAddress,
        ) -> u256 {
            let rate = self.rates.read((token_from, token_to));
            assert(rate > 0, Errors::RATE_NOT_SET);
            rate
        }

        #[external(v0)]
        fn get_fee_bps(self: @ContractState) -> u16 {
            self.fee_bps.read()
        }
        #[external(v0)]
        fn get_usdc_address(self: @ContractState) -> ContractAddress {
            self.usdc_address.read()
        }
        #[external(v0)]
        fn get_adusd_address(self: @ContractState) -> ContractAddress {
            self.adusd_address.read()
        }
        #[external(v0)]
        fn get_adngn_address(self: @ContractState) -> ContractAddress {
            self.adngn_address.read()
        }
        #[external(v0)]
        fn get_pool_address(self: @ContractState) -> ContractAddress {
            self.pool_address.read()
        }

        #[external(v0)]
        fn get_adkes_address(self: @ContractState) -> ContractAddress {
            self.adkes_address.read()
        }

        #[external(v0)]
        fn get_adghs_address(self: @ContractState) -> ContractAddress {
            self.adghs_address.read()
        }

        #[external(v0)]
        fn get_adzar_address(self: @ContractState) -> ContractAddress {
            self.adzar_address.read()
        }

        #[external(v0)]
        fn set_adkes_address(ref self: ContractState, adkes_address: ContractAddress) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            assert(!adkes_address.is_zero(), Errors::ZERO_ADDRESS);
            self.adkes_address.write(adkes_address);
        }

        #[external(v0)]
        fn set_adghs_address(ref self: ContractState, adghs_address: ContractAddress) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            assert(!adghs_address.is_zero(), Errors::ZERO_ADDRESS);
            self.adghs_address.write(adghs_address);
        }

        #[external(v0)]
        fn set_adzar_address(ref self: ContractState, adzar_address: ContractAddress) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            assert(!adzar_address.is_zero(), Errors::ZERO_ADDRESS);
            self.adzar_address.write(adzar_address);
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.accesscontrol.assert_only_role(UPGRADER_ROLE);
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _apply_rate_and_fee(
            self: @ContractState,
            token_from: ContractAddress,
            token_to: ContractAddress,
            amount_in: u256,
        ) -> u256 {
            let rate = self.rates.read((token_from, token_to));
            assert(rate > 0, Errors::RATE_NOT_SET);
            let gross_out = (amount_in * rate) / RATE_PRECISION;
            let fee_bps: u256 = self.fee_bps.read().into();
            gross_out - (gross_out * fee_bps) / 10000_u256
        }

        fn _is_valid_adam_token(self: @ContractState, token: ContractAddress) -> bool {
            token == self.adusd_address.read()
                || token == self.adngn_address.read()
                || token == self.adkes_address.read()
                || token == self.adghs_address.read()
                || token == self.adzar_address.read()
        }
    }
}
