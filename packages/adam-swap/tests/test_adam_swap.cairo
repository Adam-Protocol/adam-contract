use adam_swap::adam_swap::RATE_PRECISION;
use adam_swap::interfaces::{
    IAdamPoolDispatcher, IAdamPoolDispatcherTrait, IAdamSwapDispatcher, IAdamSwapDispatcherTrait,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::{ContractAddress, SyscallResultTrait};

fn OWNER() -> ContractAddress {
    starknet::contract_address_const::<'OWNER'>()
}
fn TREASURY() -> ContractAddress {
    starknet::contract_address_const::<'TREASURY'>()
}
fn ALICE() -> ContractAddress {
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
    OWNER().serialize(ref adusd_calldata);
    let (adusd_address, _) = token_class.deploy(@adusd_calldata).unwrap_syscall();

    // 2. Deploy AdamToken (ADNGN)
    let mut adngn_calldata = array![];
    let adngn_name: ByteArray = "Adam Naira";
    let adngn_symbol: ByteArray = "ADNGN";
    adngn_name.serialize(ref adngn_calldata);
    adngn_symbol.serialize(ref adngn_calldata);
    OWNER().serialize(ref adngn_calldata);
    let (adngn_address, _) = token_class.deploy(@adngn_calldata).unwrap_syscall();

    // 3. Deploy AdamPool
    let pool_class = declare("AdamPool").expect('Failed to declare AdamPool').contract_class();
    let (pool_address, _) = pool_class.deploy(@array![OWNER().into()]).unwrap_syscall();

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
    let (swap_address, _) = swap_class.deploy(@swap_calldata).unwrap_syscall();

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

#[test]
fn test_buy_usdc_to_adusd() {
    let (_swap_addr, _adusd_addr, _, _pool_addr) = setup();
    // let _swap = IAdamSwapDispatcher { contract_address: _swap_addr };
}
