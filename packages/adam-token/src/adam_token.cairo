use starknet::ContractAddress;

pub const MINTER_ROLE: felt252 = selector!("MINTER_ROLE");
pub const BURNER_ROLE: felt252 = selector!("BURNER_ROLE");
pub const PAUSER_ROLE: felt252 = selector!("PAUSER_ROLE");
pub const UPGRADER_ROLE: felt252 = selector!("UPGRADER_ROLE");

/// AdamToken — ERC-20 base deployed as ADUSD and ADNGN.
#[starknet::contract]
pub mod AdamToken {
    // OpenZeppelin imports for standard token functionality and security
    use core::num::traits::Zero;
    use openzeppelin::access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::security::pausable::PausableComponent;
    use openzeppelin::token::erc20::{DefaultConfig, ERC20Component};
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::{ClassHash, ContractAddress};
    use crate::errors::Errors;
    use super::{BURNER_ROLE, MINTER_ROLE, PAUSER_ROLE, UPGRADER_ROLE};

    // Components used for access control, state management, and upgrades
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl PausableImpl = PausableComponent::PausableImpl<ContractState>;
    #[abi(embed_v0)]
    impl AccessControlMixinImpl =
        AccessControlComponent::AccessControlMixinImpl<ContractState>;

    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        // Core ERC20 storage component
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        // Pausable state for emergency stops
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        // Access control management for roles
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        // Introspection implementation
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        // Upgradeable contract state
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
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
        ref self: ContractState, name: ByteArray, symbol: ByteArray, owner: ContractAddress,
    ) {
        assert(!owner.is_zero(), Errors::ZERO_ADDRESS);

        // Initialize ERC20 and AccessControl components
        self.erc20.initializer(name, symbol);
        self.accesscontrol.initializer();

        // Grant all initial roles to the owner
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, owner);
        self.accesscontrol._grant_role(MINTER_ROLE, owner);
        self.accesscontrol._grant_role(PAUSER_ROLE, owner);
        self.accesscontrol._grant_role(UPGRADER_ROLE, owner);
    }

    impl ERC20HooksImpl of ERC20Component::ERC20HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) {
            let contract_state = self.get_contract();
            contract_state.pausable.assert_not_paused();
        }
    }

    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self.accesscontrol.assert_only_role(MINTER_ROLE);
            assert(amount > 0, Errors::ZERO_AMOUNT);
            assert(!recipient.is_zero(), Errors::ZERO_ADDRESS);
            self.erc20.mint(recipient, amount);
        }

        #[external(v0)]
        fn burn(ref self: ContractState, from: ContractAddress, amount: u256) {
            self.accesscontrol.assert_only_role(BURNER_ROLE);
            assert(amount > 0, Errors::ZERO_AMOUNT);
            self.erc20.burn(from, amount);
        }

        /// Pauses all token transfers and actions.
        /// Requires PAUSER_ROLE.
        #[external(v0)]
        fn pause(ref self: ContractState) {
            self.accesscontrol.assert_only_role(PAUSER_ROLE);
            self.pausable.pause();
        }

        /// Unpauses token actions.
        /// Requires PAUSER_ROLE.
        #[external(v0)]
        fn unpause(ref self: ContractState) {
            self.accesscontrol.assert_only_role(PAUSER_ROLE);
            self.pausable.unpause();
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.accesscontrol.assert_only_role(UPGRADER_ROLE);
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
