use starknet::ContractAddress;

/// Interface for AdamPool used by AdamSwap.
#[starknet::interface]
pub trait IAdamPool<TState> {
    fn register_commitment(ref self: TState, commitment: felt252, token: ContractAddress);
    fn spend_nullifier(ref self: TState, nullifier: felt252);
    fn is_commitment_registered(self: @TState, commitment: felt252) -> bool;
    fn is_nullifier_spent(self: @TState, nullifier: felt252) -> bool;
    fn set_swap_contract(ref self: TState, swap_contract: ContractAddress);
}
