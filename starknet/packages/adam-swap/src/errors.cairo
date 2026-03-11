/// Error constants for AdamSwap
pub mod Errors {
    pub const ZERO_ADDRESS: felt252 = 'adam: zero address';
    pub const ZERO_AMOUNT: felt252 = 'adam: zero amount';
    pub const INVALID_TOKEN: felt252 = 'adam: invalid token';
    pub const INVALID_FEE: felt252 = 'adam: fee > 10000 bps';
    pub const SLIPPAGE_EXCEEDED: felt252 = 'adam: slippage exceeded';
    pub const RATE_NOT_SET: felt252 = 'adam: rate not set';
    pub const COMMITMENT_NOT_FOUND: felt252 = 'adam: commitment not found';
    pub const NULLIFIER_SPENT: felt252 = 'adam: nullifier spent';
}
