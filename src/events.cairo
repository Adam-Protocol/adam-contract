use starknet::ContractAddress;

// ── AdamToken events ────────────────────────────────────────────────
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

// ── AdamSwap events (privacy-preserving — no amounts on buy/sell/swap) ──
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

// ── AdamPool events ────────────────────────────────────────────────
#[derive(Drop, starknet::Event)]
pub struct CommitmentRegistered {
    #[key]
    pub commitment: felt252,
    pub token: ContractAddress,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct NullifierSpent {
    #[key]
    pub nullifier: felt252,
    pub timestamp: u64,
}
