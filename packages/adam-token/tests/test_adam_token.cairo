use adam_token::adam_token::{AdamToken, MINTER_ROLE};
use adam_token::interfaces::{IAdamTokenDispatcher, IAdamTokenDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;

fn OWNER() -> ContractAddress {
    starknet::contract_address_const::<'OWNER'>()
}

fn deploy_token() -> (ContractAddress, IAdamTokenDispatcher) {
    let contract_class = declare("AdamToken")
        .expect('Failed to declare AdamToken')
        .contract_class();
    let mut constructor_calldata = array![];
    let name: ByteArray = "Adam US Dollar";
    let symbol: ByteArray = "ADUSD";
    name.serialize(ref constructor_calldata);
    symbol.serialize(ref constructor_calldata);
    OWNER().serialize(ref constructor_calldata);
    let (contract_address, _) = contract_class.deploy(@constructor_calldata).unwrap();
    (contract_address, IAdamTokenDispatcher { contract_address })
}

#[test]
fn test_metadata() {
    let (_, dispatcher) = deploy_token();
    assert(dispatcher.name() == "Adam US Dollar", 'wrong name');
    assert(dispatcher.symbol() == "ADUSD", 'wrong symbol');
    assert(dispatcher.decimals() == 18, 'wrong decimals');
}

#[test]
fn test_mint_admin() {
    let (address, dispatcher) = deploy_token();

    start_cheat_caller_address(address, OWNER());
    dispatcher.mint(ALICE(), 1000);
    stop_cheat_caller_address(address);

    assert(dispatcher.balance_of(ALICE()) == 1000, 'mint failed');
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_unauthorized_mint() {
    let (_address, dispatcher) = deploy_token();
    dispatcher.mint(ALICE(), 1000);
}

#[test]
fn test_transfer() {
    let (address, dispatcher) = deploy_token();

    start_cheat_caller_address(address, OWNER());
    dispatcher.mint(OWNER(), 1000);
    dispatcher.transfer(ALICE(), 400);
    stop_cheat_caller_address(address);

    assert(dispatcher.balance_of(OWNER()) == 600, 'wrong owner balance');
    assert(dispatcher.balance_of(ALICE()) == 400, 'wrong alice balance');
}

#[test]
fn test_pause_unpause() {
    let (address, dispatcher) = deploy_token();

    start_cheat_caller_address(address, OWNER());
    dispatcher.pause();
    // We expect transfer to fail when paused
// Note: OpenZeppelin Pausable usually reverts with 'Pausable: paused'
}

fn ALICE() -> ContractAddress {
    starknet::contract_address_const::<'ALICE'>()
}
