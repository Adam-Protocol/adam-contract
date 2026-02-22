use starknet::ContractAddress;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address};

use adam_token::interfaces::{IAdamTokenDispatcher, IAdamTokenDispatcherTrait};
use adam_token::adam_token::{AdamToken, MINTER_ROLE};

fn OWNER() -> ContractAddress { starknet::contract_address_const::<'OWNER'>() }

fn deploy_token() -> (ContractAddress, IAdamTokenDispatcher) {
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
    // For now we just check it deploys.
}

#[test]
fn test_mint_admin() {
    let (address, dispatcher) = deploy_token();
    
    start_cheat_caller_address(address, OWNER());
    // In a real test we would grant MINTER_ROLE and mint.
}
