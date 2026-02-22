/// Shared error constants for all Adam Protocol contracts
pub mod AdamErrors {
    pub const UNAUTHORIZED: felt252 = 'adam: unauthorized';
    pub const ZERO_AMOUNT: felt252 = 'adam: zero amount';
    pub const ZERO_ADDRESS: felt252 = 'adam: zero address';
    pub const COMMITMENT_EXISTS: felt252 = 'adam: commitment exists';
    pub const COMMITMENT_NOT_FOUND: felt252 = 'adam: commitment not found';
    pub const NULLIFIER_SPENT: felt252 = 'adam: nullifier spent';
    pub const INVALID_TOKEN: felt252 = 'adam: invalid token';
    pub const SLIPPAGE_EXCEEDED: felt252 = 'adam: slippage exceeded';
    pub const RATE_NOT_SET: felt252 = 'adam: rate not set';
    pub const PAUSED: felt252 = 'adam: paused';
    pub const INSUFFICIENT_BALANCE: felt252 = 'adam: insufficient balance';
    pub const INVALID_FEE: felt252 = 'adam: fee > 10000 bps';
}
