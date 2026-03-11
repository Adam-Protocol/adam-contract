use adam_pool::interfaces::{IAdamPoolDispatcher, IAdamPoolDispatcherTrait};
use openzeppelin::access::accesscontrol::interface::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};
use openzeppelin::access::accesscontrol::DEFAULT_ADMIN_ROLE;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, spy_events, EventSpyAssertionsTrait,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::{ContractAddress, SyscallResultTrait};

fn alice() -> ContractAddress {
    starknet::contract_address_const::<'ALICE'>()
}

fn bob() -> ContractAddress {
    starknet::contract_address_const::<'BOB'>()
}

fn swap_contract() -> ContractAddress {
    starknet::contract_address_const::<'SWAP'>()
}

fn zero_address() -> ContractAddress {
    starknet::contract_address_const::<0>()
}

fn usdc_token() -> ContractAddress {
    starknet::contract_address_const::<'USDC'>()
}

fn deploy_adam_pool(owner: ContractAddress) -> ContractAddress {
    let pool_class = declare("AdamPool").expect('Failed to declare AdamPool').contract_class();
    let (contract_address, _) = pool_class.deploy(@array![owner.into()]).unwrap_syscall();
    contract_address
}

#[test]
fn test_constructor() {
    let pool_addr = deploy_adam_pool(owner());
    let access_control = IAccessControlDispatcher { contract_address: pool_addr };

    assert(access_control.has_role(DEFAULT_ADMIN_ROLE, owner()), 'owner not admin');
}

#[test]
fn test_set_swap_contract() {
    let pool_addr = deploy_adam_pool(owner());
    let pool = IAdamPoolDispatcher { contract_address: pool_addr };

    start_cheat_caller_address(pool_addr, owner());
    pool.set_swap_contract(swap_contract());
    stop_cheat_caller_address(pool_addr);
}

#[test]
#[should_panic(expected: ('adam: zero address',))]
fn test_set_swap_contract_zero_address() {
    let pool_addr = deploy_adam_pool(owner());
    let pool = IAdamPoolDispatcher { contract_address: pool_addr };

    start_cheat_caller_address(pool_addr, owner());
    pool.set_swap_contract(zero_address());
    stop_cheat_caller_address(pool_addr);
}

#[test]
#[should_panic]
fn test_set_swap_contract_unauthorized() {
    let pool_addr = deploy_adam_pool(owner());
    let pool = IAdamPoolDispatcher { contract_address: pool_addr };

    start_cheat_caller_address(pool_addr, alice());
    pool.set_swap_contract(swap_contract());
    stop_cheat_caller_address(pool_addr);
}

#[test]
fn test_register_commitment() {
    let pool_addr = deploy_adam_pool(owner());
    let pool = IAdamPoolDispatcher { contract_address: pool_addr };

    // Set swap contract
    start_cheat_caller_address(pool_addr, owner());
    pool.set_swap_contract(swap_contract());
    stop_cheat_caller_address(pool_addr);

    let commitment: felt252 = 0x123456;

    // Register commitment as swap contract
    start_cheat_caller_address(pool_addr, swap_contract());
    pool.register_commitment(commitment, usdc_token());
    stop_cheat_caller_address(pool_addr);

    assert(pool.is_commitment_registered(commitment), 'commitment not registered');
}

#[test]
#[should_panic(expected: ('adam: commitment exists',))]
fn test_register_commitment_duplicate() {
    let pool_addr = deploy_adam_pool(owner());
    let pool = IAdamPoolDispatcher { contract_address: pool_addr };

    start_cheat_caller_address(pool_addr, owner());
    pool.set_swap_contract(swap_contract());
    stop_cheat_caller_address(pool_addr);

    let commitment: felt252 = 0x123456;

    start_cheat_caller_address(pool_addr, swap_contract());
    pool.register_commitment(commitment, usdc_token());
    pool.register_commitment(commitment, usdc_token());
    stop_cheat_caller_address(pool_addr);
}

#[test]
#[should_panic(expected: ('adam: unauthorized',))]
fn test_register_commitment_unauthorized() {
    let pool_addr = deploy_adam_pool(owner());
    let pool = IAdamPoolDispatcher { contract_address: pool_addr };

    start_cheat_caller_address(pool_addr, owner());
    pool.set_swap_contract(swap_contract());
    stop_cheat_caller_address(pool_addr);

    let commitment: felt252 = 0x123456;

    start_cheat_caller_address(pool_addr, alice());
    pool.register_commitment(commitment, usdc_token());
    stop_cheat_caller_address(pool_addr);
}

#[test]
fn test_spend_nullifier() {
    let pool_addr = deploy_adam_pool(owner());
    let pool = IAdamPoolDispatcher { contract_address: pool_addr };

    start_cheat_caller_address(pool_addr, owner());
    pool.set_swap_contract(swap_contract());
    stop_cheat_caller_address(pool_addr);

    let nullifier: felt252 = 0x789abc;

    start_cheat_caller_address(pool_addr, swap_contract());
    pool.spend_nullifier(nullifier, array![].span(), array![].span());
    stop_cheat_caller_address(pool_addr);

    assert(pool.is_nullifier_spent(nullifier), 'nullifier not spent');
}

#[test]
#[should_panic(expected: ('adam: nullifier spent',))]
fn test_spend_nullifier_duplicate() {
    let pool_addr = deploy_adam_pool(owner());
    let pool = IAdamPoolDispatcher { contract_address: pool_addr };

    start_cheat_caller_address(pool_addr, owner());
    pool.set_swap_contract(swap_contract());
    stop_cheat_caller_address(pool_addr);

    let nullifier: felt252 = 0x789abc;

    start_cheat_caller_address(pool_addr, swap_contract());
    pool.spend_nullifier(nullifier, array![].span(), array![].span());
    pool.spend_nullifier(nullifier, array![].span(), array![].span());
    stop_cheat_caller_address(pool_addr);
}

#[test]
#[should_panic(expected: ('adam: unauthorized',))]
fn test_spend_nullifier_unauthorized() {
    let pool_addr = deploy_adam_pool(owner());
    let pool = IAdamPoolDispatcher { contract_address: pool_addr };

    start_cheat_caller_address(pool_addr, owner());
    pool.set_swap_contract(swap_contract());
    stop_cheat_caller_address(pool_addr);

    let nullifier: felt252 = 0x789abc;

    start_cheat_caller_address(pool_addr, alice());
    pool.spend_nullifier(nullifier, array![].span(), array![].span());
    stop_cheat_caller_address(pool_addr);
}

#[test]
fn test_is_commitment_registered_false() {
    let pool_addr = deploy_adam_pool(owner());
    let pool = IAdamPoolDispatcher { contract_address: pool_addr };

    let commitment: felt252 = 0x999999;
    assert(!pool.is_commitment_registered(commitment), 'should not be registered');
}

#[test]
fn test_is_nullifier_spent_false() {
    let pool_addr = deploy_adam_pool(owner());
    let pool = IAdamPoolDispatcher { contract_address: pool_addr };

    let nullifier: felt252 = 0x888888;
    assert(!pool.is_nullifier_spent(nullifier), 'should not be spent');
}

#[test]
fn test_multiple_commitments() {
    let pool_addr = deploy_adam_pool(owner());
    let pool = IAdamPoolDispatcher { contract_address: pool_addr };

    start_cheat_caller_address(pool_addr, owner());
    pool.set_swap_contract(swap_contract());
    stop_cheat_caller_address(pool_addr);

    let commitment1: felt252 = 0x111;
    let commitment2: felt252 = 0x222;
    let commitment3: felt252 = 0x333;

    start_cheat_caller_address(pool_addr, swap_contract());
    pool.register_commitment(commitment1, usdc_token());
    pool.register_commitment(commitment2, usdc_token());
    pool.register_commitment(commitment3, usdc_token());
    stop_cheat_caller_address(pool_addr);

    assert(pool.is_commitment_registered(commitment1), 'c1 not registered');
    assert(pool.is_commitment_registered(commitment2), 'c2 not registered');
    assert(pool.is_commitment_registered(commitment3), 'c3 not registered');
}

#[test]
fn test_multiple_nullifiers() {
    let pool_addr = deploy_adam_pool(owner());
    let pool = IAdamPoolDispatcher { contract_address: pool_addr };

    start_cheat_caller_address(pool_addr, owner());
    pool.set_swap_contract(swap_contract());
    stop_cheat_caller_address(pool_addr);

    let nullifier1: felt252 = 0x111;
    let nullifier2: felt252 = 0x222;
    let nullifier3: felt252 = 0x333;

    start_cheat_caller_address(pool_addr, swap_contract());
    pool.spend_nullifier(nullifier1, array![].span(), array![].span());
    pool.spend_nullifier(nullifier2, array![].span(), array![].span());
    pool.spend_nullifier(nullifier3, array![].span(), array![].span());
    stop_cheat_caller_address(pool_addr);

    assert(pool.is_nullifier_spent(nullifier1), 'n1 not spent');
    assert(pool.is_nullifier_spent(nullifier2), 'n2 not spent');
    assert(pool.is_nullifier_spent(nullifier3), 'n3 not spent');
}

#[starknet::contract]
pub mod MockGaragaVerifier {
    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl IGaragaVerifierImpl of adam_pool::interfaces::IGaragaVerifier<ContractState> {
        fn verify_ultra_honk_proof(
            self: @ContractState,
            proof: Span<felt252>,
            public_inputs: Span<felt252>
        ) -> bool {
            // Mock logic: return true if the first element of proof is 1.
            if proof.len() > 0 && *proof.at(0) == 1 {
                return true;
            }
            return false;
        }
    }
}

fn deploy_mock_verifier() -> ContractAddress {
    let verifier_class = declare("MockGaragaVerifier").expect('Failed to declare Garaga').contract_class();
    let (contract_address, _) = verifier_class.deploy(@array![]).unwrap_syscall();
    contract_address
}

#[test]
fn test_spend_nullifier_with_verifier_valid() {
    let pool_addr = deploy_adam_pool(owner());
    let pool = IAdamPoolDispatcher { contract_address: pool_addr };

    let verifier_addr = deploy_mock_verifier();

    start_cheat_caller_address(pool_addr, owner());
    pool.set_swap_contract(swap_contract());
    pool.set_verifier_contract(verifier_addr);
    stop_cheat_caller_address(pool_addr);

    let nullifier: felt252 = 0xabcdef;
    let new_commitment1: felt252 = 0x1111;
    let new_commitment2: felt252 = 0x2222;

    start_cheat_caller_address(pool_addr, swap_contract());
    // Valid proof for our mock starts with a 1
    let proof = array![1, 2, 3];
    let new_commitments = array![new_commitment1, new_commitment2];
    pool.spend_nullifier(nullifier, proof.span(), new_commitments.span());
    stop_cheat_caller_address(pool_addr);

    assert(pool.is_nullifier_spent(nullifier), 'nullifier not spent via mock');
    assert(pool.is_commitment_registered(new_commitment1), 'new commitment 1 not reg');
    assert(pool.is_commitment_registered(new_commitment2), 'new commitment 2 not reg');
}

#[test]
#[should_panic(expected: ('adam: unauthorized',))]
fn test_spend_nullifier_with_verifier_invalid() {
    let pool_addr = deploy_adam_pool(owner());
    let pool = IAdamPoolDispatcher { contract_address: pool_addr };

    let verifier_addr = deploy_mock_verifier();

    start_cheat_caller_address(pool_addr, owner());
    pool.set_swap_contract(swap_contract());
    pool.set_verifier_contract(verifier_addr);
    stop_cheat_caller_address(pool_addr);

    let nullifier: felt252 = 0xabcdef;
    let new_commitment1: felt252 = 0x1111;

    start_cheat_caller_address(pool_addr, swap_contract());
    // Invalid proof for our mock starts with 0
    let proof = array![0, 2, 3];
    let new_commitments = array![new_commitment1];
    pool.spend_nullifier(nullifier, proof.span(), new_commitments.span());
    stop_cheat_caller_address(pool_addr);
}
