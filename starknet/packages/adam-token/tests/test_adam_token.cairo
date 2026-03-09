use adam_token::adam_token::{BURNER_ROLE, MINTER_ROLE, PAUSER_ROLE};
use adam_token::interfaces::{IAdamTokenDispatcher, IAdamTokenDispatcherTrait};
use openzeppelin::access::accesscontrol::interface::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;

fn owner() -> ContractAddress {
    starknet::contract_address_const::<'OWNER'>()
}

fn alice() -> ContractAddress {
    starknet::contract_address_const::<'ALICE'>()
}

fn bob() -> ContractAddress {
    starknet::contract_address_const::<'BOB'>()
}

fn zero_address() -> ContractAddress {
    starknet::contract_address_const::<0>()
}

fn deploy_adam_token(
    name: ByteArray, symbol: ByteArray, owner: ContractAddress,
) -> ContractAddress {
    let token_class = declare("AdamToken").expect('Failed to declare AdamToken').contract_class();
    let mut calldata = array![];
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    owner.serialize(ref calldata);
    let (contract_address, _) = token_class.deploy(@calldata).unwrap();
    contract_address
}

#[test]
fn test_constructor() {
    let token_addr = deploy_adam_token("Adam USD", "ADUSD", owner());
    let token = IAdamTokenDispatcher { contract_address: token_addr };

    assert(token.name() == "Adam USD", 'wrong name');
    assert(token.symbol() == "ADUSD", 'wrong symbol');
    assert(token.decimals() == 18, 'wrong decimals');
    assert(token.total_supply() == 0, 'wrong supply');
}

#[test]
fn test_mint_success() {
    let token_addr = deploy_adam_token("Adam USD", "ADUSD", owner());
    let token = IAdamTokenDispatcher { contract_address: token_addr };

    start_cheat_caller_address(token_addr, owner());
    token.mint(alice(), 1000);
    stop_cheat_caller_address(token_addr);

    assert(token.balance_of(alice()) == 1000, 'wrong balance');
    assert(token.total_supply() == 1000, 'wrong supply');
}

#[test]
#[should_panic(expected: ('adam: zero amount',))]
fn test_mint_zero_amount() {
    let token_addr = deploy_adam_token("Adam USD", "ADUSD", owner());
    let token = IAdamTokenDispatcher { contract_address: token_addr };

    start_cheat_caller_address(token_addr, owner());
    token.mint(alice(), 0);
    stop_cheat_caller_address(token_addr);
}

#[test]
#[should_panic(expected: ('adam: zero address',))]
fn test_mint_zero_address() {
    let token_addr = deploy_adam_token("Adam USD", "ADUSD", owner());
    let token = IAdamTokenDispatcher { contract_address: token_addr };

    start_cheat_caller_address(token_addr, owner());
    token.mint(zero_address(), 1000);
    stop_cheat_caller_address(token_addr);
}

#[test]
#[should_panic]
fn test_mint_unauthorized() {
    let token_addr = deploy_adam_token("Adam USD", "ADUSD", owner());
    let token = IAdamTokenDispatcher { contract_address: token_addr };

    start_cheat_caller_address(token_addr, alice());
    token.mint(alice(), 1000);
    stop_cheat_caller_address(token_addr);
}

#[test]
fn test_burn_success() {
    let token_addr = deploy_adam_token("Adam USD", "ADUSD", owner());
    let token = IAdamTokenDispatcher { contract_address: token_addr };
    let access_control = IAccessControlDispatcher { contract_address: token_addr };

    // Mint tokens first
    start_cheat_caller_address(token_addr, owner());
    token.mint(alice(), 1000);
    access_control.grant_role(BURNER_ROLE, owner());
    token.burn(alice(), 500);
    stop_cheat_caller_address(token_addr);

    assert(token.balance_of(alice()) == 500, 'wrong balance');
    assert(token.total_supply() == 500, 'wrong supply');
}

#[test]
#[should_panic(expected: ('adam: zero amount',))]
fn test_burn_zero_amount() {
    let token_addr = deploy_adam_token("Adam USD", "ADUSD", owner());
    let token = IAdamTokenDispatcher { contract_address: token_addr };
    let access_control = IAccessControlDispatcher { contract_address: token_addr };

    start_cheat_caller_address(token_addr, owner());
    token.mint(alice(), 1000);
    access_control.grant_role(BURNER_ROLE, owner());
    token.burn(alice(), 0);
    stop_cheat_caller_address(token_addr);
}

#[test]
#[should_panic]
fn test_burn_unauthorized() {
    let token_addr = deploy_adam_token("Adam USD", "ADUSD", owner());
    let token = IAdamTokenDispatcher { contract_address: token_addr };

    start_cheat_caller_address(token_addr, owner());
    token.mint(alice(), 1000);
    stop_cheat_caller_address(token_addr);

    start_cheat_caller_address(token_addr, alice());
    token.burn(alice(), 500);
    stop_cheat_caller_address(token_addr);
}

#[test]
fn test_transfer_success() {
    let token_addr = deploy_adam_token("Adam USD", "ADUSD", owner());
    let token = IAdamTokenDispatcher { contract_address: token_addr };

    start_cheat_caller_address(token_addr, owner());
    token.mint(alice(), 1000);
    stop_cheat_caller_address(token_addr);

    start_cheat_caller_address(token_addr, alice());
    token.transfer(bob(), 300);
    stop_cheat_caller_address(token_addr);

    assert(token.balance_of(alice()) == 700, 'wrong alice balance');
    assert(token.balance_of(bob()) == 300, 'wrong bob balance');
}

#[test]
fn test_approve_and_transfer_from() {
    let token_addr = deploy_adam_token("Adam USD", "ADUSD", owner());
    let token = IAdamTokenDispatcher { contract_address: token_addr };

    start_cheat_caller_address(token_addr, owner());
    token.mint(alice(), 1000);
    stop_cheat_caller_address(token_addr);

    start_cheat_caller_address(token_addr, alice());
    token.approve(bob(), 500);
    stop_cheat_caller_address(token_addr);

    assert(token.allowance(alice(), bob()) == 500, 'wrong allowance');

    start_cheat_caller_address(token_addr, bob());
    token.transfer_from(alice(), bob(), 300);
    stop_cheat_caller_address(token_addr);

    assert(token.balance_of(alice()) == 700, 'wrong alice balance');
    assert(token.balance_of(bob()) == 300, 'wrong bob balance');
    assert(token.allowance(alice(), bob()) == 200, 'wrong allowance after');
}

#[test]
#[should_panic]
fn test_pause_unauthorized() {
    let token_addr = deploy_adam_token("Adam USD", "ADUSD", owner());
    let token = IAdamTokenDispatcher { contract_address: token_addr };

    start_cheat_caller_address(token_addr, alice());
    token.pause();
    stop_cheat_caller_address(token_addr);
}

#[test]
fn test_grant_minter_role() {
    let token_addr = deploy_adam_token("Adam USD", "ADUSD", owner());
    let token = IAdamTokenDispatcher { contract_address: token_addr };
    let access_control = IAccessControlDispatcher { contract_address: token_addr };

    start_cheat_caller_address(token_addr, owner());
    access_control.grant_role(MINTER_ROLE, alice());
    stop_cheat_caller_address(token_addr);

    assert(access_control.has_role(MINTER_ROLE, alice()), 'role not granted');

    // Alice can now mint
    start_cheat_caller_address(token_addr, alice());
    token.mint(bob(), 500);
    stop_cheat_caller_address(token_addr);

    assert(token.balance_of(bob()) == 500, 'mint failed');
}

#[test]
fn test_revoke_minter_role() {
    let token_addr = deploy_adam_token("Adam USD", "ADUSD", owner());
    let access_control = IAccessControlDispatcher { contract_address: token_addr };

    start_cheat_caller_address(token_addr, owner());
    access_control.grant_role(MINTER_ROLE, alice());
    access_control.revoke_role(MINTER_ROLE, alice());
    stop_cheat_caller_address(token_addr);

    assert(!access_control.has_role(MINTER_ROLE, alice()), 'role not revoked');
}
