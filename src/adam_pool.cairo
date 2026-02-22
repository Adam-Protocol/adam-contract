/// AdamPool — nullifier registry contract.
/// Tracks commitment registrations and nullifier spends to prevent double-spend.
/// Only AdamSwap can call register_commitment and spend_nullifier.
#[starknet::contract]
pub mod AdamPool {
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use adam_contract::errors::AdamErrors;
    use adam_contract::events::{CommitmentRegistered, NullifierSpent};

    #[storage]
    struct Storage {
        /// commitment_hash -> is_registered
        commitments: Map<felt252, bool>,
        /// nullifier_hash -> is_spent
        nullifiers: Map<felt252, bool>,
        /// The only address allowed to register commitments / spend nullifiers
        swap_contract: ContractAddress,
        owner: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        CommitmentRegistered: CommitmentRegistered,
        NullifierSpent: NullifierSpent,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        assert(owner.is_non_zero(), AdamErrors::ZERO_ADDRESS);
        self.owner.write(owner);
    }

    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        /// Register a new commitment — called by AdamSwap on every buy/swap
        #[external(v0)]
        fn register_commitment(
            ref self: ContractState, commitment: felt252, token: ContractAddress,
        ) {
            self._assert_only_swap();
            assert(!self.commitments.read(commitment), AdamErrors::COMMITMENT_EXISTS);
            self.commitments.write(commitment, true);
            self
                .emit(
                    CommitmentRegistered {
                        commitment, token, timestamp: get_block_timestamp(),
                    },
                );
        }

        /// Spend a nullifier — called by AdamSwap on sell
        #[external(v0)]
        fn spend_nullifier(ref self: ContractState, nullifier: felt252) {
            self._assert_only_swap();
            assert(!self.nullifiers.read(nullifier), AdamErrors::NULLIFIER_SPENT);
            self.nullifiers.write(nullifier, true);
            self.emit(NullifierSpent { nullifier, timestamp: get_block_timestamp() });
        }

        /// Set the authorised swap contract — owner only, called once after AdamSwap deploy
        #[external(v0)]
        fn set_swap_contract(ref self: ContractState, swap_contract: ContractAddress) {
            self._assert_only_owner();
            assert(swap_contract.is_non_zero(), AdamErrors::ZERO_ADDRESS);
            self.swap_contract.write(swap_contract);
        }

        /// View: check if commitment is registered
        #[external(v0)]
        fn is_commitment_registered(self: @ContractState, commitment: felt252) -> bool {
            self.commitments.read(commitment)
        }

        /// View: check if nullifier has been spent
        #[external(v0)]
        fn is_nullifier_spent(self: @ContractState, nullifier: felt252) -> bool {
            self.nullifiers.read(nullifier)
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _assert_only_owner(self: @ContractState) {
            assert(get_caller_address() == self.owner.read(), AdamErrors::UNAUTHORIZED);
        }

        fn _assert_only_swap(self: @ContractState) {
            assert(
                get_caller_address() == self.swap_contract.read(), AdamErrors::UNAUTHORIZED,
            );
        }
    }
}
