use starknet::ContractAddress;
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address, start_cheat_block_timestamp,
};

use adam_swap::adam_swap::{AdamSwap, RATE_PRECISION, RATE_SETTER_ROLE};
use adam_token::adam_token::AdamToken;
use adam_pool::adam_pool::AdamPool;

use adam_swap::interfaces::{
    IAdamSwapDispatcher, IAdamSwapDispatcherTrait,
    IAdamTokenDispatcher, IAdamTokenDispatcherTrait,
    IAdamPoolDispatcher, IAdamPoolDispatcherTrait,
};

fn OWNER() -> ContractAddress { starknet::contract_address_const::<'OWNER'>() }
fn TREASURY() -> ContractAddress { starknet::contract_address_const::<'TREASURY'>() }
fn ALICE() -> ContractAddress { starknet::contract_address_const::<'ALICE'>() }
fn USDC() -> ContractAddress { starknet::contract_address_const::<'USDC'>() }

fn setup() -> (ContractAddress, ContractAddress, ContractAddress, ContractAddress) {
    // 1. Deploy AdamToken (ADUSD)
    let token_class = declare("AdamToken").expect('Failed to declare AdamToken').contract_class();
    let mut adusd_calldata = array![];
    "Adam US Dollar".serialize(ref adusd_calldata);
    "ADUSD".serialize(ref adusd_calldata);
    OWNER().serialize(ref adusd_calldata);
    let (adusd_address, _) = token_class.deploy(@adusd_calldata).unwrap();

    // 2. Deploy AdamToken (ADNGN)
    let mut adngn_calldata = array![];
    "Adam Naira".serialize(ref adngn_calldata);
    "ADNGN".serialize(ref adngn_calldata);
    OWNER().serialize(ref adngn_calldata);
    let (adngn_address, _) = token_class.deploy(@adngn_calldata).unwrap();

    // 3. Deploy AdamPool
    let pool_class = declare("AdamPool").expect('Failed to declare AdamPool').contract_class();
    let (pool_address, _) = pool_class.deploy(@array![OWNER().into()]).unwrap();

    // 4. Deploy AdamSwap
    let swap_class = declare("AdamSwap").expect('Failed to declare AdamSwap').contract_class();
    let mut swap_calldata = array![];
    OWNER().serialize(ref swap_calldata);
    TREASURY().serialize(ref swap_calldata);
    USDC().serialize(ref swap_calldata);
    adusd_address.serialize(ref swap_calldata);
    adngn_address.serialize(ref swap_calldata);
    pool_address.serialize(ref swap_calldata);
    0_u16.serialize(ref swap_calldata);
    let (swap_address, _) = swap_class.deploy(@swap_calldata).unwrap();

    // 5. Post-deploy setup
    start_cheat_caller_address(pool_address, OWNER());
    IAdamPoolDispatcher { contract_address: pool_address }.set_swap_contract(swap_address);
    stop_cheat_caller_address(pool_address);

    (swap_address, adusd_address, adngn_address, pool_address)
}

#[test]
fn test_get_rate() {
    let (swap_addr, adusd_addr, _, _) = setup();
    let swap = IAdamSwapDispatcher { contract_address: swap_addr };
    
    let rate: u256 = swap.get_rate(USDC(), adusd_addr);
    let expected_rate: u256 = RATE_PRECISION;
    assert(rate == expected_rate, 'rate should be 1e18');
}

#[test]
fn test_set_rate() {
    let (swap_addr, adusd_addr, adngn_addr, _) = setup();
    let swap = IAdamSwapDispatcher { contract_address: swap_addr };
    
    start_cheat_caller_address(swap_addr, OWNER());
    let ngn_rate: u256 = 1600_u256 * RATE_PRECISION;
    swap.set_rate(adusd_addr, adngn_addr, ngn_rate);
    
    let fetched_rate: u256 = swap.get_rate(adusd_addr, adngn_addr);
    assert(fetched_rate == ngn_rate, 'wrong rate fetched');
}
