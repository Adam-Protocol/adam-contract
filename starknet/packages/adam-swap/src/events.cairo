use starknet::ContractAddress;

/// Privacy-safe events for AdamSwap — no amounts emitted on-chain.
/// Amounts stay client-side inside commitment hashes.

#[derive(Drop, starknet::Event)]
pub struct BuyExecuted {
    #[key]
    pub commitment: felt252,
    pub token_out: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct SellExecuted {
    #[key]
    pub nullifier: felt252,
    pub token_in: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct SwapExecuted {
    #[key]
    pub commitment: felt252,
    pub token_in: ContractAddress,
    pub token_out: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct RateUpdated {
    pub token_from: ContractAddress,
    pub token_to: ContractAddress,
    pub rate: u256,
    pub timestamp: u64,
}
