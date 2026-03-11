use adam_swap::adam_swap::RATE_PRECISION;
use adam_swap::interfaces::{
    IAdamPoolDispatcher, IAdamPoolDispatcherTrait, IAdamSwapDispatcher, IAdamSwapDispatcherTrait,
    IAdamTokenDispatcher, IAdamTokenDispatcherTrait
};
use openzeppelin::access::accesscontrol::interface::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::{ContractAddress, SyscallResultTrait};

fn owner() -> ContractAddress {
    0x4f574e4552.try_into().unwrap()
}

fn treasury() -> ContractAddress {
    0x5452454153555259.try_into().unwrap()
}

fn alice() -> ContractAddress {
    0x414c494345.try_into().unwrap()
}

fn usdc_contract() -> ContractAddress {
    0x55534443.try_into().unwrap() // Legacy usages
}

fn setup() -> (ContractAddress, ContractAddress, ContractAddress, ContractAddress, ContractAddress) {
    // 0. Deploy USDC (using AdamToken as a generic ERC20 for tests)
    let token_class = declare("AdamToken").expect('Failed to declare AdamToken').contract_class();
    let mut usdc_calldata = array![];
    let usdc_name: ByteArray = "USD Coin";
    let usdc_symbol: ByteArray = "USDC";
    usdc_name.serialize(ref usdc_calldata);
    usdc_symbol.serialize(ref usdc_calldata);
    owner().serialize(ref usdc_calldata);
    let (usdc_address, _) = token_class.deploy(@usdc_calldata).unwrap_syscall();

    // 1. Deploy AdamToken (ADUSD)
    let mut adusd_calldata = array![];
    let adusd_name: ByteArray = "Adam US Dollar";
    let adusd_symbol: ByteArray = "ADUSD";
    adusd_name.serialize(ref adusd_calldata);
    adusd_symbol.serialize(ref adusd_calldata);
    owner().serialize(ref adusd_calldata);
    let (adusd_address, _) = token_class.deploy(@adusd_calldata).unwrap_syscall();

    // 2. Deploy AdamToken (ADNGN)
    let mut adngn_calldata = array![];
    let adngn_name: ByteArray = "Adam Naira";
    let adngn_symbol: ByteArray = "ADNGN";
    adngn_name.serialize(ref adngn_calldata);
    adngn_symbol.serialize(ref adngn_calldata);
    owner().serialize(ref adngn_calldata);
    let (adngn_address, _) = token_class.deploy(@adngn_calldata).unwrap_syscall();

    // 3. Deploy AdamPool
    let pool_class = declare("AdamPool").expect('Failed to declare AdamPool').contract_class();
    let (pool_address, _) = pool_class.deploy(@array![owner().into()]).unwrap_syscall();

    // 4. Deploy AdamSwap
    let swap_class = declare("AdamSwap").expect('Failed to declare AdamSwap').contract_class();
    let mut swap_calldata = array![];
    owner().serialize(ref swap_calldata);
    treasury().serialize(ref swap_calldata);
    usdc_address.serialize(ref swap_calldata);
    adusd_address.serialize(ref swap_calldata);
    adngn_address.serialize(ref swap_calldata);
    pool_address.serialize(ref swap_calldata);
    0_u16.serialize(ref swap_calldata);
    let (swap_address, _) = swap_class.deploy(@swap_calldata).unwrap_syscall();

    // 5. Post-deploy setup
    start_cheat_caller_address(pool_address, owner());
    IAdamPoolDispatcher { contract_address: pool_address }.set_swap_contract(swap_address);
    stop_cheat_caller_address(pool_address);
    
    // Grant Swap contract minter/burner permissions on ADUSD and ADNGN
    let minter_role: felt252 = selector!("MINTER_ROLE");
    let burner_role: felt252 = selector!("BURNER_ROLE");
    start_cheat_caller_address(adusd_address, owner());
    IAccessControlDispatcher { contract_address: adusd_address }.grant_role(minter_role, swap_address);
    IAccessControlDispatcher { contract_address: adusd_address }.grant_role(burner_role, swap_address);
    stop_cheat_caller_address(adusd_address);
    start_cheat_caller_address(adngn_address, owner());
    IAccessControlDispatcher { contract_address: adngn_address }.grant_role(minter_role, swap_address);
    IAccessControlDispatcher { contract_address: adngn_address }.grant_role(burner_role, swap_address);
    stop_cheat_caller_address(adngn_address);

    (swap_address, adusd_address, adngn_address, pool_address, usdc_address)
}

#[test]
fn test_constructor() {
    let (swap_addr, adusd_addr, adngn_addr, pool_addr, usdc_addr) = setup();
    let swap = IAdamSwapDispatcher { contract_address: swap_addr };

    assert(swap.get_usdc_address() == usdc_addr, 'wrong usdc');
    assert(swap.get_adusd_address() == adusd_addr, 'wrong adusd');
    assert(swap.get_adngn_address() == adngn_addr, 'wrong adngn');
    assert(swap.get_pool_address() == pool_addr, 'wrong pool');
    assert(swap.get_fee_bps() == 0, 'wrong fee');
}

#[test]
fn test_get_rate() {
    let (swap_addr, adusd_addr, _, _, usdc_addr) = setup();
    let swap = IAdamSwapDispatcher { contract_address: swap_addr };

    let rate: u256 = swap.get_rate(usdc_addr, adusd_addr);
    assert(rate == RATE_PRECISION, 'rate should be 1e18');
}

#[test]
fn test_set_rate() {
    let (swap_addr, adusd_addr, adngn_addr, _, _) = setup();
    let swap = IAdamSwapDispatcher { contract_address: swap_addr };

    start_cheat_caller_address(swap_addr, owner());
    let ngn_rate: u256 = 1600_u256 * RATE_PRECISION;
    swap.set_rate(adusd_addr, adngn_addr, ngn_rate);
    stop_cheat_caller_address(swap_addr);

    let fetched_rate: u256 = swap.get_rate(adusd_addr, adngn_addr);
    assert(fetched_rate == ngn_rate, 'wrong rate fetched');
}

#[test]
#[should_panic(expected: ('adam: zero amount',))]
fn test_set_rate_zero() {
    let (swap_addr, adusd_addr, adngn_addr, _, _) = setup();
    let swap = IAdamSwapDispatcher { contract_address: swap_addr };

    start_cheat_caller_address(swap_addr, owner());
    swap.set_rate(adusd_addr, adngn_addr, 0);
    stop_cheat_caller_address(swap_addr);
}

#[test]
#[should_panic]
fn test_set_rate_unauthorized() {
    let (swap_addr, adusd_addr, adngn_addr, _, _) = setup();
    let swap = IAdamSwapDispatcher { contract_address: swap_addr };

    start_cheat_caller_address(swap_addr, alice());
    swap.set_rate(adusd_addr, adngn_addr, 1500_u256 * RATE_PRECISION);
    stop_cheat_caller_address(swap_addr);
}

#[test]
fn test_set_fee_bps() {
    let (swap_addr, _, _, _, _) = setup();
    let swap = IAdamSwapDispatcher { contract_address: swap_addr };

    start_cheat_caller_address(swap_addr, owner());
    swap.set_fee_bps(200); // 2%
    stop_cheat_caller_address(swap_addr);

    assert(swap.get_fee_bps() == 200, 'wrong fee');
}

#[test]
#[should_panic(expected: ('adam: fee > 10000 bps',))]
fn test_set_fee_bps_too_high() {
    let (swap_addr, _, _, _, _) = setup();
    let swap = IAdamSwapDispatcher { contract_address: swap_addr };

    start_cheat_caller_address(swap_addr, owner());
    swap.set_fee_bps(1001); // > 10%
    stop_cheat_caller_address(swap_addr);
}

#[test]
#[should_panic]
fn test_set_fee_bps_unauthorized() {
    let (swap_addr, _, _, _, _) = setup();
    let swap = IAdamSwapDispatcher { contract_address: swap_addr };

    start_cheat_caller_address(swap_addr, alice());
    swap.set_fee_bps(200);
    stop_cheat_caller_address(swap_addr);
}

#[test]
#[should_panic]
fn test_pause_unauthorized() {
    let (swap_addr, _, _, _, _) = setup();
    let swap = IAdamSwapDispatcher { contract_address: swap_addr };

    start_cheat_caller_address(swap_addr, alice());
    swap.pause();
    stop_cheat_caller_address(swap_addr);
}

#[test]
fn test_pause_and_unpause() {
    let (swap_addr, _, _, _, _) = setup();
    let swap = IAdamSwapDispatcher { contract_address: swap_addr };

    // Pause the contract
    start_cheat_caller_address(swap_addr, owner());
    swap.pause();
    stop_cheat_caller_address(swap_addr);

    // Unpause
    start_cheat_caller_address(swap_addr, owner());
    swap.unpause();
    stop_cheat_caller_address(swap_addr);
}

#[test]
#[should_panic(expected: ('adam: rate not set',))]
fn test_get_rate_not_set() {
    let (swap_addr, adusd_addr, adngn_addr, _, _) = setup();
    let swap = IAdamSwapDispatcher { contract_address: swap_addr };

    // Try to get a rate that was never set
    swap.get_rate(adusd_addr, adngn_addr);
}

use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

#[test]
fn test_buy() {
    let (swap_addr, adusd_addr, _, pool_addr, usdc_addr) = setup();
    let swap = IAdamSwapDispatcher { contract_address: swap_addr };
    let usdc = IERC20Dispatcher { contract_address: usdc_addr };
    let adusd = IERC20Dispatcher { contract_address: adusd_addr };
    let pool = IAdamPoolDispatcher { contract_address: pool_addr };

    let amount_in: u256 = 100 * RATE_PRECISION;
    let commitment: felt252 = 0x999;

    // Mint USDC to Alice
    start_cheat_caller_address(usdc_addr, owner());
    // In our mock USDC (AdamToken), owner has minter role
    IAdamTokenDispatcher { contract_address: usdc_addr }.mint(alice(), amount_in);
    stop_cheat_caller_address(usdc_addr);

    start_cheat_caller_address(usdc_addr, alice());
    usdc.approve(swap_addr, amount_in);
    stop_cheat_caller_address(usdc_addr);

    start_cheat_caller_address(swap_addr, alice());
    swap.buy(usdc_addr, amount_in, adusd_addr, commitment);
    stop_cheat_caller_address(swap_addr);

    // Verify treasury got the USDC
    assert(usdc.balance_of(treasury()) == amount_in, 'treasury balance wrong');
    // Verify Alice got ADUSD 
    assert(adusd.balance_of(alice()) == amount_in, 'alice balance wrong');
    // Verify pool registered commitment
    assert(pool.is_commitment_registered(commitment), 'commitment not registered');
}

#[test]
fn test_sell() {
    let (swap_addr, adusd_addr, _, pool_addr, usdc_addr) = setup();
    let swap = IAdamSwapDispatcher { contract_address: swap_addr };
    let adusd = IERC20Dispatcher { contract_address: adusd_addr };
    let pool = IAdamPoolDispatcher { contract_address: pool_addr };

    let amount: u256 = 50 * RATE_PRECISION;
    let nullifier: felt252 = 0x888;
    let commitment: felt252 = 0x999;
    let mut new_commitments = array![0x111, 0x222];

    // Mint ADUSD to Alice so she can sell
    start_cheat_caller_address(adusd_addr, owner());
    IAdamTokenDispatcher { contract_address: adusd_addr }.mint(alice(), amount);
    stop_cheat_caller_address(adusd_addr);

    // Register original commitment
    start_cheat_caller_address(pool_addr, swap_addr);
    pool.register_commitment(commitment, adusd_addr);
    stop_cheat_caller_address(pool_addr);

    start_cheat_caller_address(swap_addr, alice());
    swap.sell(adusd_addr, amount, nullifier, commitment, array![].span(), new_commitments.span());
    stop_cheat_caller_address(swap_addr);

    // Verify ADUSD was burned
    assert(adusd.balance_of(alice()) == 0, 'burn failed');

    // Verify nullifier spent & change output registered
    assert(pool.is_nullifier_spent(nullifier), 'nullifier not spent');
    assert(pool.is_commitment_registered(0x111), 'change note 1 missing');
    assert(pool.is_commitment_registered(0x222), 'change note 2 missing');
}

#[test]
fn test_swap() {
    let (swap_addr, adusd_addr, adngn_addr, pool_addr, usdc_addr) = setup();
    let swap = IAdamSwapDispatcher { contract_address: swap_addr };
    let adusd = IERC20Dispatcher { contract_address: adusd_addr };
    let adngn = IERC20Dispatcher { contract_address: adngn_addr };
    let pool = IAdamPoolDispatcher { contract_address: pool_addr };

    let amount_in: u256 = 10 * RATE_PRECISION;
    let ngn_rate: u256 = 1600_u256 * RATE_PRECISION;
    let expected_out: u256 = amount_in * 1600_u256;
    
    let nullifier: felt252 = 0x888;
    let new_commitment: felt252 = 0x777;

    start_cheat_caller_address(swap_addr, owner());
    swap.set_rate(adusd_addr, adngn_addr, ngn_rate);
    stop_cheat_caller_address(swap_addr);

    start_cheat_caller_address(adusd_addr, owner());
    IAdamTokenDispatcher { contract_address: adusd_addr }.mint(alice(), amount_in);
    stop_cheat_caller_address(adusd_addr);

    start_cheat_caller_address(swap_addr, alice());
    swap.swap(
        token_in: adusd_addr,
        amount_in: amount_in,
        token_out: adngn_addr,
        min_amount_out: expected_out,
        nullifier: nullifier,
        proof: array![].span(),
        commitment: new_commitment
    );
    stop_cheat_caller_address(swap_addr);

    assert(adusd.balance_of(alice()) == 0, 'burn failed');
    assert(adngn.balance_of(alice()) == expected_out, 'mint failed');
    assert(pool.is_nullifier_spent(nullifier), 'nullifier not spent');
    assert(pool.is_commitment_registered(new_commitment), 'new commitment missing');
}
