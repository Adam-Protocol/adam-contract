use adam_pool::interfaces::{IAdamPoolDispatcher, IAdamPoolDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;

fn OWNER() -> ContractAddress {
    starknet::contract_address_const::<'OWNER'>()
}
fn SWAP() -> ContractAddress {
    starknet::contract_address_const::<'SWAP'>()
}

fn deploy_pool() -> (ContractAddress, IAdamPoolDispatcher) {
    let contract_class = declare("AdamPool").expect('Failed to declare AdamPool').contract_class();
    let mut constructor_calldata = array![];
    OWNER().serialize(ref constructor_calldata);
    let (contract_address, _) = contract_class.deploy(@constructor_calldata).unwrap();
    (contract_address, IAdamPoolDispatcher { contract_address })
}

#[test]
fn test_nullifier_lifecycle() {
    let (address, dispatcher) = deploy_pool();

    start_cheat_caller_address(address, OWNER());
    dispatcher.set_swap_contract(SWAP());
    stop_cheat_caller_address(address);

    let nullifier: felt252 = 0x456.into();

    assert(!dispatcher.is_nullifier_spent(nullifier), 'should not be spent yet');

    start_cheat_caller_address(address, SWAP());
    dispatcher.spend_nullifier(nullifier);
    stop_cheat_caller_address(address);

    assert(dispatcher.is_nullifier_spent(nullifier), 'should be spent');
}

#[test]
#[should_panic(expected: ('adam: nullifier spent',))]
fn test_cannot_spend_twice() {
    let (address, dispatcher) = deploy_pool();

    start_cheat_caller_address(address, OWNER());
    dispatcher.set_swap_contract(SWAP());
    stop_cheat_caller_address(address);

    let nullifier: felt252 = 0x456.into();

    start_cheat_caller_address(address, SWAP());
    dispatcher.spend_nullifier(nullifier);
    dispatcher.spend_nullifier(nullifier);
}

#[test]
#[should_panic(expected: ('adam: unauthorized',))]
fn test_spend_unauthorized() {
    let (address, dispatcher) = deploy_pool();
    let nullifier: felt252 = 0x456.into();
    dispatcher.spend_nullifier(nullifier);
}
