use starknet::ContractAddress;

/// Interface for AdamToken used by AdamSwap (mint/burn + standard assertions).
#[starknet::interface]
pub trait IAdamToken<TState> {
    fn mint(ref self: TState, recipient: ContractAddress, amount: u256);
    fn burn(ref self: TState, from: ContractAddress, amount: u256);
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
}

/// Interface for AdamPool used by AdamSwap.
#[starknet::interface]
pub trait IAdamPool<TState> {
    fn register_commitment(ref self: TState, commitment: felt252, token: ContractAddress);
    fn spend_nullifier(ref self: TState, nullifier: felt252);
    fn is_commitment_registered(self: @TState, commitment: felt252) -> bool;
    fn is_nullifier_spent(self: @TState, nullifier: felt252) -> bool;
    fn set_swap_contract(ref self: TState, swap_contract: ContractAddress);
}

/// Full AdamSwap interface.
#[starknet::interface]
pub trait IAdamSwap<TState> {
    fn buy(
        ref self: TState,
        token_in: ContractAddress,
        amount_in: u256,
        token_out: ContractAddress,
        commitment: felt252,
    );
    fn sell(
        ref self: TState,
        token_in: ContractAddress,
        amount: u256,
        nullifier: felt252,
        commitment: felt252,
    );
    fn swap(
        ref self: TState,
        token_in: ContractAddress,
        amount_in: u256,
        token_out: ContractAddress,
        min_amount_out: u256,
        commitment: felt252,
    );
    fn set_rate(
        ref self: TState,
        token_from: ContractAddress,
        token_to: ContractAddress,
        rate: u256,
    );
    fn set_fee_bps(ref self: TState, fee_bps: u16);
    fn get_rate(self: @TState, token_from: ContractAddress, token_to: ContractAddress) -> u256;
    fn get_fee_bps(self: @TState) -> u16;
    fn get_usdc_address(self: @TState) -> ContractAddress;
    fn get_adusd_address(self: @TState) -> ContractAddress;
    fn get_adngn_address(self: @TState) -> ContractAddress;
    fn get_pool_address(self: @TState) -> ContractAddress;
    fn pause(ref self: TState);
    fn unpause(ref self: TState);
}
