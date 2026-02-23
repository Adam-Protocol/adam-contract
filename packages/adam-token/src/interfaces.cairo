use starknet::ContractAddress;

/// Interface for AdamToken (ERC-20 + mint/burn/pause)
#[starknet::interface]
pub trait IAdamToken<TState> {
    // ERC-20 standard
    fn name(self: @TState) -> ByteArray;
    fn symbol(self: @TState) -> ByteArray;
    fn decimals(self: @TState) -> u8;
    fn total_supply(self: @TState) -> u256;
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TState, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    ) -> bool;
    fn approve(ref self: TState, spender: ContractAddress, amount: u256) -> bool;

    // Adam custom
    fn mint(ref self: TState, recipient: ContractAddress, amount: u256);
    fn burn(ref self: TState, from: ContractAddress, amount: u256);
    fn pause(ref self: TState);
    fn unpause(ref self: TState);
}
