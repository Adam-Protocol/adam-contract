use starknet::ContractAddress;

/// Interface for the Garaga Verifier Contract (Ultra Honk)
#[starknet::interface]
pub trait IGaragaVerifier<TState> {
    fn verify_ultra_honk_proof(
        self: @TState,
        proof: Span<felt252>,
        public_inputs: Span<felt252>
    ) -> bool;
}

/// Interface for AdamPool used by AdamSwap.
#[starknet::interface]
pub trait IAdamPool<TState> {
    fn register_commitment(ref self: TState, commitment: felt252, token: ContractAddress);

    /// Spends a nullifier by providing a ZK proof of ownership and optionally registers new commitments (change).
    fn spend_nullifier(
        ref self: TState, nullifier: felt252, proof: Span<felt252>, new_commitments: Span<felt252>
    );
    
    fn is_commitment_registered(self: @TState, commitment: felt252) -> bool;
    fn is_nullifier_spent(self: @TState, nullifier: felt252) -> bool;
    
    fn set_swap_contract(ref self: TState, swap_contract: ContractAddress);
    fn set_verifier_contract(ref self: TState, verifier_contract: ContractAddress);
}
