use starknet::ContractAddress;

/// Privacy-safe events for AdamToken — amounts are intentionally included here
/// since the token standard requires them. Swap-level privacy is at AdamSwap.
#[derive(Drop, starknet::Event)]
pub struct TokenMinted {
    #[key]
    pub recipient: ContractAddress,
    pub amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct TokenBurned {
    #[key]
    pub from: ContractAddress,
    pub amount: u256,
}
