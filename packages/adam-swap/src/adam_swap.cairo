/// AdamSwap — core exchange contract (upgradeable).
/// buy(), sell(), swap() — all emit privacy-safe events (no amounts on-chain).
#[starknet::contract]
pub mod AdamSwap {
    use openzeppelin::access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::security::pausable::PausableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::{ClassHash, ContractAddress, get_block_timestamp, get_caller_address};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use adam_common::errors::AdamErrors;
    use adam_common::events::{BuyExecuted, SellExecuted, SwapExecuted, RateUpdated};
    use adam_common::interfaces::{
        IAdamTokenDispatcher, IAdamTokenDispatcherTrait,
        IAdamPoolDispatcher, IAdamPoolDispatcherTrait,
    };

    pub const RATE_SETTER_ROLE: felt252 = selector!("RATE_SETTER_ROLE");
    pub const PAUSER_ROLE: felt252 = selector!("PAUSER_ROLE");
    pub const UPGRADER_ROLE: felt252 = selector!("UPGRADER_ROLE");
    pub const RATE_PRECISION: u256 = 1_000_000_000_000_000_000_u256; // 1e18
    pub const MAX_FEE_BPS: u16 = 1000; // 10%

    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    #[abi(embed_v0)]
    impl AccessControlMixinImpl = AccessControlComponent::AccessControlMixinImpl<ContractState>;

    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        usdc_address: ContractAddress,
        adusd_address: ContractAddress,
        adngn_address: ContractAddress,
        pool_address: ContractAddress,
        treasury: ContractAddress,
        fee_bps: u16,
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
        BuyExecuted: BuyExecuted,
        SellExecuted: SellExecuted,
        SwapExecuted: SwapExecuted,
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
        assert(owner.is_non_zero(), AdamErrors::ZERO_ADDRESS);
        assert(treasury.is_non_zero(), AdamErrors::ZERO_ADDRESS);
        assert(usdc_address.is_non_zero(), AdamErrors::ZERO_ADDRESS);
        assert(adusd_address.is_non_zero(), AdamErrors::ZERO_ADDRESS);
        assert(adngn_address.is_non_zero(), AdamErrors::ZERO_ADDRESS);
        assert(pool_address.is_non_zero(), AdamErrors::ZERO_ADDRESS);
        assert(fee_bps <= MAX_FEE_BPS, AdamErrors::INVALID_FEE);

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

        // USDC <-> ADUSD is always 1:1 at init
        self.rates.write((usdc_address, adusd_address), RATE_PRECISION);
        self.rates.write((adusd_address, usdc_address), RATE_PRECISION);
    }

    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        /// Buy ADUSD or ADNGN with USDC. Commitment computed client-side — amount never stored.
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
            assert(amount_in > 0, AdamErrors::ZERO_AMOUNT);
            assert(token_in == self.usdc_address.read(), AdamErrors::INVALID_TOKEN);
            assert(
                token_out == self.adusd_address.read() || token_out == self.adngn_address.read(),
                AdamErrors::INVALID_TOKEN,
            );

            IERC20Dispatcher { contract_address: token_in }
                .transfer_from(caller, self.treasury.read(), amount_in);

            let amount_out = self._apply_rate_and_fee(token_in, token_out, amount_in);
            IAdamTokenDispatcher { contract_address: token_out }.mint(caller, amount_out);

            IAdamPoolDispatcher { contract_address: self.pool_address.read() }
                .register_commitment(commitment, token_out);

            self.emit(BuyExecuted { commitment, token_out, timestamp: get_block_timestamp() });
        }

        /// Sell ADUSD/ADNGN — burns token, emits event so backend can trigger bank offramp.
        #[external(v0)]
        fn sell(
            ref self: ContractState,
            token_in: ContractAddress,
            amount: u256,
            nullifier: felt252,
            commitment: felt252,
        ) {
            self.pausable.assert_not_paused();
            let caller = get_caller_address();
            assert(amount > 0, AdamErrors::ZERO_AMOUNT);
            assert(
                token_in == self.adusd_address.read() || token_in == self.adngn_address.read(),
                AdamErrors::INVALID_TOKEN,
            );

            let pool = IAdamPoolDispatcher { contract_address: self.pool_address.read() };
            assert(pool.is_commitment_registered(commitment), AdamErrors::COMMITMENT_NOT_FOUND);
            assert(!pool.is_nullifier_spent(nullifier), AdamErrors::NULLIFIER_SPENT);

            IAdamTokenDispatcher { contract_address: token_in }.burn(caller, amount);
            pool.spend_nullifier(nullifier);

            self.emit(SellExecuted { nullifier, token_in, timestamp: get_block_timestamp() });
        }

        /// Swap ADUSD <-> ADNGN using the rate last pushed by the backend.
        #[external(v0)]
        fn swap(
            ref self: ContractState,
            token_in: ContractAddress,
            amount_in: u256,
            token_out: ContractAddress,
            min_amount_out: u256,
            commitment: felt252,
        ) {
            self.pausable.assert_not_paused();
            let caller = get_caller_address();
            assert(amount_in > 0, AdamErrors::ZERO_AMOUNT);
            assert(token_in != token_out, AdamErrors::INVALID_TOKEN);
            assert(
                (token_in == self.adusd_address.read() && token_out == self.adngn_address.read())
                    || (token_in == self.adngn_address.read()
                        && token_out == self.adusd_address.read()),
                AdamErrors::INVALID_TOKEN,
            );

            let amount_out = self._apply_rate_and_fee(token_in, token_out, amount_in);
            assert(amount_out >= min_amount_out, AdamErrors::SLIPPAGE_EXCEEDED);

            IAdamTokenDispatcher { contract_address: token_in }.burn(caller, amount_in);
            IAdamTokenDispatcher { contract_address: token_out }.mint(caller, amount_out);

            IAdamPoolDispatcher { contract_address: self.pool_address.read() }
                .register_commitment(commitment, token_out);

            self.emit(SwapExecuted { commitment, token_in, token_out, timestamp: get_block_timestamp() });
        }

        /// Push live USD/NGN rate — RATE_SETTER_ROLE only (backend service wallet).
        #[external(v0)]
        fn set_rate(
            ref self: ContractState,
            token_from: ContractAddress,
            token_to: ContractAddress,
            rate: u256,
        ) {
            self.accesscontrol.assert_only_role(RATE_SETTER_ROLE);
            assert(rate > 0, AdamErrors::ZERO_AMOUNT);
            self.rates.write((token_from, token_to), rate);
            self.emit(RateUpdated { token_from, token_to, rate, timestamp: get_block_timestamp() });
        }

        #[external(v0)]
        fn set_fee_bps(ref self: ContractState, fee_bps: u16) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            assert(fee_bps <= MAX_FEE_BPS, AdamErrors::INVALID_FEE);
            self.fee_bps.write(fee_bps);
        }

        #[external(v0)]
        fn pause(ref self: ContractState) {
            self.accesscontrol.assert_only_role(PAUSER_ROLE);
            self.pausable.pause();
        }

        #[external(v0)]
        fn unpause(ref self: ContractState) {
            self.accesscontrol.assert_only_role(PAUSER_ROLE);
            self.pausable.unpause();
        }

        #[external(v0)]
        fn get_rate(self: @ContractState, token_from: ContractAddress, token_to: ContractAddress) -> u256 {
            let rate = self.rates.read((token_from, token_to));
            assert(rate > 0, AdamErrors::RATE_NOT_SET);
            rate
        }

        #[external(v0)]
        fn get_fee_bps(self: @ContractState) -> u16 { self.fee_bps.read() }
        #[external(v0)]
        fn get_usdc_address(self: @ContractState) -> ContractAddress { self.usdc_address.read() }
        #[external(v0)]
        fn get_adusd_address(self: @ContractState) -> ContractAddress { self.adusd_address.read() }
        #[external(v0)]
        fn get_adngn_address(self: @ContractState) -> ContractAddress { self.adngn_address.read() }
        #[external(v0)]
        fn get_pool_address(self: @ContractState) -> ContractAddress { self.pool_address.read() }
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
            assert(rate > 0, AdamErrors::RATE_NOT_SET);
            let gross_out = (amount_in * rate) / RATE_PRECISION;
            let fee_bps: u256 = self.fee_bps.read().into();
            gross_out - (gross_out * fee_bps) / 10000_u256
        }
    }
}
