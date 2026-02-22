/// AdamPool — nullifier registry (upgradeable).
/// Authorised swap contract is the only caller for register_commitment / spend_nullifier.
#[starknet::contract]
pub mod AdamPool {
    use openzeppelin::access::accesscontrol::{AccessControlComponent, DEFAULT_ADMIN_ROLE};
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::{ClassHash, ContractAddress, get_block_timestamp, get_caller_address};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use adam_common::errors::AdamErrors;
    use adam_common::events::{CommitmentRegistered, NullifierSpent};

    pub const UPGRADER_ROLE: felt252 = selector!("UPGRADER_ROLE");

    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl AccessControlMixinImpl = AccessControlComponent::AccessControlMixinImpl<ContractState>;

    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        commitments: Map<felt252, bool>,
        nullifiers: Map<felt252, bool>,
        swap_contract: ContractAddress,
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
        CommitmentRegistered: CommitmentRegistered,
        NullifierSpent: NullifierSpent,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        assert(owner.is_non_zero(), AdamErrors::ZERO_ADDRESS);
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(DEFAULT_ADMIN_ROLE, owner);
        self.accesscontrol._grant_role(UPGRADER_ROLE, owner);
    }

    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn register_commitment(ref self: ContractState, commitment: felt252, token: ContractAddress) {
            self._assert_only_swap();
            assert(!self.commitments.read(commitment), AdamErrors::COMMITMENT_EXISTS);
            self.commitments.write(commitment, true);
            self.emit(CommitmentRegistered { commitment, token, timestamp: get_block_timestamp() });
        }

        #[external(v0)]
        fn spend_nullifier(ref self: ContractState, nullifier: felt252) {
            self._assert_only_swap();
            assert(!self.nullifiers.read(nullifier), AdamErrors::NULLIFIER_SPENT);
            self.nullifiers.write(nullifier, true);
            self.emit(NullifierSpent { nullifier, timestamp: get_block_timestamp() });
        }

        #[external(v0)]
        fn set_swap_contract(ref self: ContractState, swap_contract: ContractAddress) {
            self.accesscontrol.assert_only_role(DEFAULT_ADMIN_ROLE);
            assert(swap_contract.is_non_zero(), AdamErrors::ZERO_ADDRESS);
            self.swap_contract.write(swap_contract);
        }

        #[external(v0)]
        fn is_commitment_registered(self: @ContractState, commitment: felt252) -> bool {
            self.commitments.read(commitment)
        }

        #[external(v0)]
        fn is_nullifier_spent(self: @ContractState, nullifier: felt252) -> bool {
            self.nullifiers.read(nullifier)
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
        fn _assert_only_swap(self: @ContractState) {
            assert(get_caller_address() == self.swap_contract.read(), AdamErrors::UNAUTHORIZED);
        }
    }
}
