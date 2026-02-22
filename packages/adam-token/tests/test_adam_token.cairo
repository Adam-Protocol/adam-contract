use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;
use adam_token::adam_token::{AdamToken, MINTER_ROLE, BURNER_ROLE};
use adam_common::interfaces::{IAdamTokenDispatcher, IAdamTokenDispatcherTrait};
use openzeppelin::access::accesscontrol::interface::{IAccessControlDispatcher, IAccessControlDispatcherTrait};

fn OWNER() -> ContractAddress { starknet::contract_address_const::<'OWNER'>() }
fn MINTER() -> ContractAddress { starknet::contract_address_const::<'MINTER'>() }
fn ALICE() -> ContractAddress { starknet::contract_address_const::<'ALICE'>() }

fn deploy_token(name: ByteArray, symbol: ByteArray) -> ContractAddress {
    let contract = declare("AdamToken").unwrap().contract_class();
    let mut calldata = array![];
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    OWNER().serialize(ref calldata);
    let (addr, _) = contract.deploy(@calldata).unwrap();
    addr
}

#[test]
fn test_token_name_and_symbol() {
    let addr = deploy_token("Adam USD", "ADUSD");
    let token = IAdamTokenDispatcher { contract_address: addr };
    assert(token.name() == "Adam USD", 'wrong name');
    assert(token.symbol() == "ADUSD", 'wrong symbol');
    assert(token.decimals() == 18, 'wrong decimals');
}

#[test]
fn test_mint_requires_minter_role() {
    let addr = deploy_token("Adam USD", "ADUSD");

    // Grant MINTER_ROLE to MINTER
    let ac = IAccessControlDispatcher { contract_address: addr };
    start_cheat_caller_address(addr, OWNER());
    ac.grant_role(MINTER_ROLE, MINTER());
    stop_cheat_caller_address(addr);

    // Mint as MINTER
    let token = IAdamTokenDispatcher { contract_address: addr };
    start_cheat_caller_address(addr, MINTER());
    token.mint(ALICE(), 1000_u256);
    stop_cheat_caller_address(addr);

    assert(token.balance_of(ALICE()) == 1000_u256, 'wrong balance');
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_mint_without_role_panics() {
    let addr = deploy_token("Adam USD", "ADUSD");
    let token = IAdamTokenDispatcher { contract_address: addr };
    // ALICE has no MINTER_ROLE — should panic
    start_cheat_caller_address(addr, ALICE());
    token.mint(ALICE(), 100_u256);
}

#[test]
fn test_burn_requires_burner_role() {
    let addr = deploy_token("Adam USD", "ADUSD");
    let ac = IAccessControlDispatcher { contract_address: addr };
    let token = IAdamTokenDispatcher { contract_address: addr };

    // Grant roles
    start_cheat_caller_address(addr, OWNER());
    ac.grant_role(MINTER_ROLE, MINTER());
    ac.grant_role(BURNER_ROLE, MINTER());
    stop_cheat_caller_address(addr);

    // Mint first
    start_cheat_caller_address(addr, MINTER());
    token.mint(ALICE(), 500_u256);
    // Burn
    token.burn(ALICE(), 200_u256);
    stop_cheat_caller_address(addr);

    assert(token.balance_of(ALICE()) == 300_u256, 'wrong balance after burn');
}

#[test]
fn test_transfer() {
    let addr = deploy_token("Adam NGN", "ADNGN");
    let ac = IAccessControlDispatcher { contract_address: addr };
    let token = IAdamTokenDispatcher { contract_address: addr };

    start_cheat_caller_address(addr, OWNER());
    ac.grant_role(MINTER_ROLE, OWNER());
    token.mint(ALICE(), 1000_u256);
    stop_cheat_caller_address(addr);

    let BOB: ContractAddress = starknet::contract_address_const::<'BOB'>();
    start_cheat_caller_address(addr, ALICE());
    token.transfer(BOB, 400_u256);
    stop_cheat_caller_address(addr);

    assert(token.balance_of(ALICE()) == 600_u256, 'alice balance wrong');
    assert(token.balance_of(BOB) == 400_u256, 'bob balance wrong');
}

#[test]
fn test_pause_blocks_transfers() {
    let addr = deploy_token("Adam USD", "ADUSD");
    let ac = IAccessControlDispatcher { contract_address: addr };
    let token = IAdamTokenDispatcher { contract_address: addr };

    start_cheat_caller_address(addr, OWNER());
    ac.grant_role(MINTER_ROLE, OWNER());
    token.mint(ALICE(), 1000_u256);
    token.pause();
    stop_cheat_caller_address(addr);

    // Transfer should panic while paused
    let result = std::panic::catch_unwind(|| {
        start_cheat_caller_address(addr, ALICE());
        token.transfer(OWNER(), 100_u256);
    });
    assert(result.is_err(), 'should have panicked');
}
