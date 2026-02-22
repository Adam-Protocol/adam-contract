use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;
use adam_pool::adam_pool::AdamPool;
use adam_common::interfaces::{IAdamPoolDispatcher, IAdamPoolDispatcherTrait};

fn OWNER() -> ContractAddress { starknet::contract_address_const::<'OWNER'>() }
fn SWAP() -> ContractAddress { starknet::contract_address_const::<'SWAP'>() }
fn ALICE() -> ContractAddress { starknet::contract_address_const::<'ALICE'>() }

fn deploy_pool() -> ContractAddress {
    let contract = declare("AdamPool").unwrap().contract_class();
    let mut calldata = array![];
    OWNER().serialize(ref calldata);
    let (addr, _) = contract.deploy(@calldata).unwrap();

    // Set swap contract
    let pool = IAdamPoolDispatcher { contract_address: addr };
    start_cheat_caller_address(addr, OWNER());
    pool.set_swap_contract(SWAP());
    stop_cheat_caller_address(addr);
    addr
}

#[test]
fn test_register_commitment() {
    let addr = deploy_pool();
    let pool = IAdamPoolDispatcher { contract_address: addr };
    let commitment: felt252 = 'commit_1';

    start_cheat_caller_address(addr, SWAP());
    pool.register_commitment(commitment, ALICE());
    stop_cheat_caller_address(addr);

    assert(pool.is_commitment_registered(commitment), 'commitment not registered');
}

#[test]
#[should_panic(expected: ('adam: commitment exists',))]
fn test_double_register_panics() {
    let addr = deploy_pool();
    let pool = IAdamPoolDispatcher { contract_address: addr };

    start_cheat_caller_address(addr, SWAP());
    pool.register_commitment('commit_dup', ALICE());
    pool.register_commitment('commit_dup', ALICE()); // should panic
}

#[test]
fn test_spend_nullifier() {
    let addr = deploy_pool();
    let pool = IAdamPoolDispatcher { contract_address: addr };
    let nullifier: felt252 = 'nullifier_1';

    start_cheat_caller_address(addr, SWAP());
    pool.spend_nullifier(nullifier);
    stop_cheat_caller_address(addr);

    assert(pool.is_nullifier_spent(nullifier), 'nullifier not spent');
}

#[test]
#[should_panic(expected: ('adam: nullifier spent',))]
fn test_double_spend_panics() {
    let addr = deploy_pool();
    let pool = IAdamPoolDispatcher { contract_address: addr };

    start_cheat_caller_address(addr, SWAP());
    pool.spend_nullifier('null_dup');
    pool.spend_nullifier('null_dup'); // should panic
}

#[test]
#[should_panic(expected: ('adam: unauthorized',))]
fn test_only_swap_can_register() {
    let addr = deploy_pool();
    let pool = IAdamPoolDispatcher { contract_address: addr };

    // ALICE is not the swap contract
    start_cheat_caller_address(addr, ALICE());
    pool.register_commitment('commit_x', ALICE());
}

#[test]
#[should_panic(expected: ('adam: unauthorized',))]
fn test_only_swap_can_spend() {
    let addr = deploy_pool();
    let pool = IAdamPoolDispatcher { contract_address: addr };

    start_cheat_caller_address(addr, ALICE());
    pool.spend_nullifier('null_x');
}
