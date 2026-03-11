use adam_swap::adam_swap::{MAX_FEE_BPS, RATE_PRECISION};
use adam_swap::interfaces::{
    IAdamPoolDispatcher, IAdamPoolDispatcherTrait, IAdamSwapDispatcher, IAdamSwapDispatcherTrait,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::{ContractAddress, SyscallResultTrait};

fn owner() -> ContractAddress {
    starknet::contract_address_const::<'OWNER'>()
}

fn treasury() -> ContractAddress {
    starknet::contract_address_const::<'TREASURY'>()
}

fn alice() -> ContractAddress {
    starknet::contract_address_const::<'ALICE'>()
}

fn USDC() -> ContractAddress {
    starknet::contract_address_const::<'USDC'>()
}

fn setup() -> (ContractAddress, ContractAddress, ContractAddress, ContractAddress) {
    // 1. Deploy AdamToken (ADUSD)
    let token_class = declare("AdamToken").expect('Failed to declare AdamToken').contract_class();
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
    USDC().serialize(ref swap_calldata);
    adusd_address.serialize(ref swap_calldata);
    adngn_address.serialize(ref swap_calldata);
    pool_address.serialize(ref swap_calldata);
    0_u16.serialize(ref swap_calldata);
    let (swap_address, _) = swap_class.deploy(@swap_calldata).unwrap_syscall();

    // 5. Post-deploy setup
    start_cheat_caller_address(pool_address, owner());
    IAdamPoolDispatcher { contract_address: pool_address }.set_swap_contract(swap_address);
    stop_cheat_caller_address(pool_address);

    (swap_address, adusd_address, adngn_address, pool_address)
}

#[test]
fn test_constructor() {
    let (swap_addr, adusd_addr, adngn_addr, pool_addr) = setup();
    let swap = IAdamSwapDispatcher { contract_address: swap_addr };

    assert(swap.get_usdc_address() == USDC(), 'wrong usdc');
    assert(swap.get_adusd_address() == adusd_addr, 'wrong adusd');
    assert(swap.get_adngn_address() == adngn_addr, 'wrong adngn');
    assert(swap.get_pool_address() == pool_addr, 'wrong pool');
    assert(swap.get_fee_bps() == 0, 'wrong fee');
}

#[test]
fn test_get_rate() {
    let (swap_addr, adusd_addr, _, _) = setup();
    let swap = IAdamSwapDispatcher { contract_address: swap_addr };

    let rate: u256 = swap.get_rate(USDC(), adusd_addr);
    assert(rate == RATE_PRECISION, 'rate should be 1e18');
}

#[test]
fn test_set_rate() {
    let (swap_addr, adusd_addr, adngn_addr, _) = setup();
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
    let (swap_addr, adusd_addr, adngn_addr, _) = setup();
    let swap = IAdamSwapDispatcher { contract_address: swap_addr };

    start_cheat_caller_address(swap_addr, owner());
    swap.set_rate(adusd_addr, adngn_addr, 0);
    stop_cheat_caller_address(swap_addr);
}

#[test]
#[should_panic]
fn test_set_rate_unauthorized() {
    let (swap_addr, adusd_addr, adngn_addr, _) = setup();
    let swap = IAdamSwapDispatcher { contract_address: swap_addr };

    start_cheat_caller_address(swap_addr, alice());
    swap.set_rate(adusd_addr, adngn_addr, 1500_u256 * RATE_PRECISION);
    stop_cheat_caller_address(swap_addr);
}

#[test]
fn test_set_fee_bps() {
    let (swap_addr, _, _, _) = setup();
    let swap = IAdamSwapDispatcher { contract_address: swap_addr };

    start_cheat_caller_address(swap_addr, owner());
    swap.set_fee_bps(200); // 2%
    stop_cheat_caller_address(swap_addr);

    assert(swap.get_fee_bps() == 200, 'wrong fee');
}

#[test]
#[should_panic(expected: ('adam: fee > 10000 bps',))]
fn test_set_fee_bps_too_high() {
    let (swap_addr, _, _, _) = setup();
    let swap = IAdamSwapDispatcher { contract_address: swap_addr };

    start_cheat_caller_address(swap_addr, owner());
    swap.set_fee_bps(1001); // > 10%
    stop_cheat_caller_address(swap_addr);
}

#[test]
#[should_panic]
fn test_set_fee_bps_unauthorized() {
    let (swap_addr, _, _, _) = setup();
    let swap = IAdamSwapDispatcher { contract_address: swap_addr };

    start_cheat_caller_address(swap_addr, alice());
    swap.set_fee_bps(200);
    stop_cheat_caller_address(swap_addr);
}

#[test]
#[should_panic]
fn test_pause_unauthorized() {
    let (swap_addr, _, _, _) = setup();
    let swap = IAdamSwapDispatcher { contract_address: swap_addr };

    start_cheat_caller_address(swap_addr, alice());
    swap.pause();
    stop_cheat_caller_address(swap_addr);
}

#[test]
fn test_pause_and_unpause() {
    let (swap_addr, _, _, _) = setup();
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
    let (swap_addr, adusd_addr, adngn_addr, _) = setup();
    let swap = IAdamSwapDispatcher { contract_address: swap_addr };

    // Try to get a rate that was never set
    swap.get_rate(adusd_addr, adngn_addr);
}
