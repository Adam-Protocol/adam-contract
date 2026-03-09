use starknet::ContractAddress;

/// Events emitted by AdamPool — commitment and nullifier only, no amounts.
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
