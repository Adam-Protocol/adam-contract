use starknet::ContractAddress;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address};

use adam_pool::interfaces::{IAdamPoolDispatcher, IAdamPoolDispatcherTrait};
use adam_pool::adam_pool::AdamPool;

fn OWNER() -> ContractAddress { starknet::contract_address_const::<'OWNER'>() }
fn SWAP() -> ContractAddress { starknet::contract_address_const::<'SWAP'>() }
fn ALICE() -> ContractAddress { starknet::contract_address_const::<'ALICE'>() }

fn deploy_pool() -> (ContractAddress, IAdamPoolDispatcher) {
    let contract_class = declare("AdamPool").expect('Failed to declare AdamPool').contract_class();
    let mut constructor_calldata = array![];
    OWNER().serialize(ref constructor_calldata);
    let (contract_address, _) = contract_class.deploy(@constructor_calldata).unwrap();
    (contract_address, IAdamPoolDispatcher { contract_address })
}

#[test]
fn test_registration() {
    let (address, dispatcher) = deploy_pool();
    
    start_cheat_caller_address(address, OWNER());
    dispatcher.set_swap_contract(SWAP());
    stop_cheat_caller_address(address);
    
    let commitment: felt252 = 0x123.into();
    let token: ContractAddress = ALICE();
    
    start_cheat_caller_address(address, SWAP());
    dispatcher.register_commitment(commitment, token);
    
    assert(dispatcher.is_commitment_registered(commitment), 'commitment should be registered');
}

#[test]
#[should_panic(expected: ('UNAUTHORIZED', ))]
fn test_register_unauthorized() {
    let (address, dispatcher) = deploy_pool();
    let commitment: felt252 = 0x123.into();
    let token: ContractAddress = ALICE();
    dispatcher.register_commitment(commitment, token);
}
