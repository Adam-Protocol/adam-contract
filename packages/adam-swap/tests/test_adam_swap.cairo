use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address, start_cheat_block_timestamp,
};
use starknet::ContractAddress;
use adam_swap::adam_swap::{AdamSwap, RATE_PRECISION};
use adam_token::adam_token::{AdamToken, MINTER_ROLE, BURNER_ROLE};
use adam_pool::adam_pool::AdamPool;
use adam_common::interfaces::{
    IAdamSwapDispatcher, IAdamSwapDispatcherTrait, IAdamTokenDispatcher,
    IAdamTokenDispatcherTrait, IAdamPoolDispatcher, IAdamPoolDispatcherTrait,
};
use openzeppelin::access::accesscontrol::interface::{
    IAccessControlDispatcher, IAccessControlDispatcherTrait,
};

fn OWNER() -> ContractAddress { starknet::contract_address_const::<'OWNER'>() }
fn TREASURY() -> ContractAddress { starknet::contract_address_const::<'TREASURY'>() }
fn ALICE() -> ContractAddress { starknet::contract_address_const::<'ALICE'>() }
fn USDC() -> ContractAddress { starknet::contract_address_const::<'USDC'>() }

/// Deploy the full Adam Protocol stack and return dispatchers
fn deploy_system() -> (
    IAdamSwapDispatcher,
    IAdamTokenDispatcher, // ADUSD
    IAdamTokenDispatcher, // ADNGN
    IAdamPoolDispatcher,
    ContractAddress, // usdc_address (mock)
) {
    // Deploy ADUSD
    let adusd_contract = declare("AdamToken").unwrap().contract_class();
    let mut adusd_cd = array![];
    let name_adusd: ByteArray = "Adam USD";
    let sym_adusd: ByteArray = "ADUSD";
    name_adusd.serialize(ref adusd_cd);
    sym_adusd.serialize(ref adusd_cd);
    OWNER().serialize(ref adusd_cd);
    let (adusd_addr, _) = adusd_contract.deploy(@adusd_cd).unwrap();

    // Deploy ADNGN
    let adngn_contract = declare("AdamToken").unwrap().contract_class();
    let mut adngn_cd = array![];
    let name_adngn: ByteArray = "Adam NGN";
    let sym_adngn: ByteArray = "ADNGN";
    name_adngn.serialize(ref adngn_cd);
    sym_adngn.serialize(ref adngn_cd);
    OWNER().serialize(ref adngn_cd);
    let (adngn_addr, _) = adngn_contract.deploy(@adngn_cd).unwrap();

    // Deploy Pool
    let pool_contract = declare("AdamPool").unwrap().contract_class();
    let mut pool_cd = array![];
    OWNER().serialize(ref pool_cd);
    let (pool_addr, _) = pool_contract.deploy(@pool_cd).unwrap();

    // Deploy Swap
    let swap_contract = declare("AdamSwap").unwrap().contract_class();
    let mut swap_cd = array![];
    OWNER().serialize(ref swap_cd);
    TREASURY().serialize(ref swap_cd);
    USDC().serialize(ref swap_cd);
    adusd_addr.serialize(ref swap_cd);
    adngn_addr.serialize(ref swap_cd);
    pool_addr.serialize(ref swap_cd);
    30_u16.serialize(ref swap_cd); // 0.30% fee
    let (swap_addr, _) = swap_contract.deploy(@swap_cd).unwrap();

    // Setup roles
    let adusd_ac = IAccessControlDispatcher { contract_address: adusd_addr };
    let adngn_ac = IAccessControlDispatcher { contract_address: adngn_addr };
    let pool = IAdamPoolDispatcher { contract_address: pool_addr };

    start_cheat_caller_address(adusd_addr, OWNER());
    adusd_ac.grant_role(MINTER_ROLE, swap_addr);
    adusd_ac.grant_role(BURNER_ROLE, swap_addr);
    stop_cheat_caller_address(adusd_addr);

    start_cheat_caller_address(adngn_addr, OWNER());
    adngn_ac.grant_role(MINTER_ROLE, swap_addr);
    adngn_ac.grant_role(BURNER_ROLE, swap_addr);
    stop_cheat_caller_address(adngn_addr);

    start_cheat_caller_address(pool_addr, OWNER());
    pool.set_swap_contract(swap_addr);
    stop_cheat_caller_address(pool_addr);

    (
        IAdamSwapDispatcher { contract_address: swap_addr },
        IAdamTokenDispatcher { contract_address: adusd_addr },
        IAdamTokenDispatcher { contract_address: adngn_addr },
        pool,
        USDC(),
    )
}

#[test]
fn test_initial_usdc_adusd_rate_is_1_to_1() {
    let (swap, _, _, _, usdc_addr) = deploy_system();
    let adusd_addr = swap.get_adusd_address();
    let rate = swap.get_rate(usdc_addr, adusd_addr);
    assert(rate == RATE_PRECISION, 'rate should be 1e18');
}

#[test]
fn test_set_rate_by_rate_setter() {
    let (swap, adusd, adngn, _, _) = deploy_system();
    let swap_addr = swap.contract_address;
    let adusd_addr = adusd.contract_address;
    let adngn_addr = adngn.contract_address;

    // Owner has RATE_SETTER_ROLE by default
    start_cheat_caller_address(swap_addr, OWNER());
    let ngn_rate = 1600_u256 * RATE_PRECISION; // 1600 NGN per USD
    swap.set_rate(adusd_addr, adngn_addr, ngn_rate);
    stop_cheat_caller_address(swap_addr);

    assert(swap.get_rate(adusd_addr, adngn_addr) == ngn_rate, 'rate mismatch');
}

#[test]
#[should_panic(expected: ('Caller is missing role',))]
fn test_set_rate_unauthorized_panics() {
    let (swap, adusd, adngn, _, _) = deploy_system();
    // ALICE has no RATE_SETTER_ROLE
    start_cheat_caller_address(swap.contract_address, ALICE());
    swap.set_rate(adusd.contract_address, adngn.contract_address, RATE_PRECISION);
}

#[test]
fn test_get_fee_bps() {
    let (swap, _, _, _, _) = deploy_system();
    assert(swap.get_fee_bps() == 30, 'fee should be 30 bps');
}

#[test]
fn test_addresses_set_on_deploy() {
    let (swap, adusd, adngn, pool, usdc_addr) = deploy_system();
    assert(swap.get_usdc_address() == usdc_addr, 'usdc address wrong');
    assert(swap.get_adusd_address() == adusd.contract_address, 'adusd address wrong');
    assert(swap.get_adngn_address() == adngn.contract_address, 'adngn address wrong');
    assert(swap.get_pool_address() == pool.contract_address, 'pool address wrong');
}

#[test]
fn test_pool_address_correct() {
    let (swap, _, _, pool, _) = deploy_system();
    assert(swap.get_pool_address() == pool.contract_address, 'pool addr wrong');
}
