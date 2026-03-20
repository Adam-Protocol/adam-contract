import { describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';

describe('Integration Flow', () => {
  const accounts = () => simnet.getAccounts();
  const WALLET_1 = () => accounts().get('wallet_1')!;
  const TREASURY = () => accounts().get('wallet_2')!;
  const DEPLOYER = () => accounts().get('deployer')!;

  const usdcMock = `${DEPLOYER()}.usdcx-v3`;
  const getAdusd = () => `${DEPLOYER()}.adam-token-adusd-v3`;
  const getAdngn = () => `${DEPLOYER()}.adam-token-adngn-v3`;
  const getAdkes = () => `${DEPLOYER()}.adam-token-adkes-v3`;
  const getAdghs = () => `${DEPLOYER()}.adam-token-adghs-v3`;
  const getAdzar = () => `${DEPLOYER()}.adam-token-adzar-v3`;
  const getSwap = () => `${DEPLOYER()}.adam-swap-v3`;

  it('should setup the complete system', () => {
    const deployer = DEPLOYER();
    const treasury = TREASURY();
    const adusd = getAdusd();
    const adngn = getAdngn();
    const swap = getSwap();

    // 1. Initialize tokens
    simnet.callPublicFn('adam-token-adusd-v3', 'initialize', [Cl.stringAscii('Adam USD'), Cl.stringAscii('ADUSD'), Cl.uint(6), Cl.principal(deployer)], deployer);
    simnet.callPublicFn('adam-token-adngn-v3', 'initialize', [Cl.stringAscii('Adam NGN'), Cl.stringAscii('ADNGN'), Cl.uint(6), Cl.principal(deployer)], deployer);

    // 2. Initialize swap
    simnet.callPublicFn('adam-swap-v3', 'initialize', [
      Cl.principal(deployer),
      Cl.principal(treasury),
      Cl.principal(usdcMock),
      Cl.principal(adusd),
      Cl.principal(adngn),
      Cl.principal(getAdkes()),
      Cl.principal(getAdghs()),
      Cl.principal(getAdzar()),
      Cl.uint(50)
    ], deployer);

    // 3. Grant roles
    simnet.callPublicFn('adam-token-adusd-v3', 'set-minter', [Cl.principal(swap), Cl.bool(true)], deployer);
    simnet.callPublicFn('adam-token-adngn-v3', 'set-minter', [Cl.principal(swap), Cl.bool(true)], deployer);
    simnet.callPublicFn('adam-token-adusd-v3', 'set-burner', [Cl.principal(swap), Cl.bool(true)], deployer);
    simnet.callPublicFn('adam-token-adngn-v3', 'set-burner', [Cl.principal(swap), Cl.bool(true)], deployer);

    // 4. Set rates
    simnet.callPublicFn('adam-swap-v3', 'set-rate', [Cl.principal(usdcMock), Cl.principal(adusd), Cl.uint(10n ** 18n)], deployer);
    simnet.callPublicFn('adam-swap-v3', 'set-rate', [Cl.principal(usdcMock), Cl.principal(adngn), Cl.uint(1500n * 10n ** 6n)], deployer);
    simnet.callPublicFn('adam-swap-v3', 'set-rate', [Cl.principal(adusd), Cl.principal(adngn), Cl.uint(1500n * 10n ** 6n)], deployer);
    simnet.callPublicFn('adam-swap-v3', 'set-rate', [Cl.principal(adngn), Cl.principal(adusd), Cl.uint(10n ** 6n / 1500n)], deployer);

    // 5. Verify setup
    expect(simnet.callReadOnlyFn('adam-token-adusd-v3', 'is-minter', [Cl.principal(swap)], deployer).result).toBeBool(true);
    expect(simnet.callReadOnlyFn('adam-swap-v3', 'get-fee-bps', [], deployer).result).toBeOk(Cl.uint(50));
  });

  it('should execute buy flow successfully', () => {
    const wallet1 = WALLET_1();
    const adusd = getAdusd();
    const deployer = DEPLOYER();

    simnet.callPublicFn('adam-swap-v3', 'set-usdc-address', [Cl.principal(usdcMock)], deployer);
    simnet.callPublicFn('adam-swap-v3', 'set-adusd-address', [Cl.principal(adusd)], deployer);
    simnet.callPublicFn('adam-swap-v3', 'set-rate-setter', [Cl.principal(deployer), Cl.bool(true)], deployer);
    simnet.callPublicFn('adam-swap-v3', 'set-rate', [Cl.principal(usdcMock), Cl.principal(adusd), Cl.uint(1000000n)], deployer); // 1:1 rate
    simnet.callPublicFn('adam-token-adusd-v3', 'set-minter', [Cl.principal(getSwap()), Cl.bool(true)], deployer);

    // Mint USDC to wallet1 for testing
    simnet.callPublicFn('usdcx-v3', 'mint', [Cl.uint(10000000n), Cl.principal(wallet1)], deployer);

    const amountIn = 1000000n; // 1 USDC
    const { result } = simnet.callPublicFn(
      'adam-swap-v3',
      'buy',
      [Cl.uint(amountIn), Cl.principal(adusd)],
      wallet1
    );

    // Fee is 0.5%, so 1,000,000 * 0.995 = 995,000
    expect(result).toBeOk(Cl.uint(995000));

    const balance = simnet.callReadOnlyFn('adam-token-adusd-v3', 'get-balance', [Cl.principal(wallet1)], deployer);
    expect(balance.result).toBeOk(Cl.uint(995000));
  });

  it('should execute swap flow successfully', () => {
    const wallet1 = WALLET_1();
    const adusd = getAdusd();
    const adngn = getAdngn();
    const deployer = DEPLOYER();

    simnet.callPublicFn('adam-swap-v3', 'set-usdc-address', [Cl.principal(usdcMock)], deployer);
    simnet.callPublicFn('adam-swap-v3', 'set-adusd-address', [Cl.principal(adusd)], deployer);
    simnet.callPublicFn('adam-swap-v3', 'set-adngn-address', [Cl.principal(adngn)], deployer);
    simnet.callPublicFn('adam-swap-v3', 'set-rate-setter', [Cl.principal(deployer), Cl.bool(true)], deployer);
    simnet.callPublicFn('adam-swap-v3', 'set-rate', [Cl.principal(adusd), Cl.principal(adngn), Cl.uint(1500000000n)], deployer); // 1500 rate (1e6 precision)
    simnet.callPublicFn('adam-token-adusd-v3', 'set-minter', [Cl.principal(getSwap()), Cl.bool(true)], deployer);
    simnet.callPublicFn('adam-token-adngn-v3', 'set-minter', [Cl.principal(getSwap()), Cl.bool(true)], deployer);
    simnet.callPublicFn('adam-token-adusd-v3', 'set-burner', [Cl.principal(getSwap()), Cl.bool(true)], deployer);
    simnet.callPublicFn('adam-token-adusd-v3', 'set-minter', [Cl.principal(deployer), Cl.bool(true)], deployer);
    simnet.callPublicFn('adam-token-adusd-v3', 'mint', [Cl.uint(100000n), Cl.principal(wallet1)], deployer); // Fund wallet

    const amountIn = 100000n; // 0.1 ADUSD
    const { result } = simnet.callPublicFn(
      'adam-swap-v3',
      'swap',
      [
        Cl.principal(adusd),
        Cl.uint(amountIn),
        Cl.principal(adngn),
        Cl.uint(0) // min amount out
      ],
      wallet1
    );

    // Expected out: 100,000 * 1500 * 0.995 = 149,250,000
    expect(result).toBeOk(Cl.uint(149250000));

    const balanceNGN = simnet.callReadOnlyFn('adam-token-adngn-v3', 'get-balance', [Cl.principal(wallet1)], deployer);
    expect(balanceNGN.result).toBeOk(Cl.uint(149250000));

    const balanceUSD = simnet.callReadOnlyFn('adam-token-adusd-v3', 'get-balance', [Cl.principal(wallet1)], deployer);
    expect(balanceUSD.result).toBeOk(Cl.uint(0));
  });

  it('should execute sell flow successfully', () => {
    const wallet1 = WALLET_1();
    const adusd = getAdusd();
    const deployer = DEPLOYER();

    simnet.callPublicFn('adam-swap-v3', 'set-adusd-address', [Cl.principal(adusd)], deployer);
    simnet.callPublicFn('adam-token-adusd-v3', 'set-burner', [Cl.principal(getSwap()), Cl.bool(true)], deployer);
    simnet.callPublicFn('adam-token-adusd-v3', 'set-minter', [Cl.principal(deployer), Cl.bool(true)], deployer);
    simnet.callPublicFn('adam-token-adusd-v3', 'mint', [Cl.uint(50000n), Cl.principal(wallet1)], deployer); // Fund wallet

    const amount = 50000n;
    const { result } = simnet.callPublicFn(
      'adam-swap-v3',
      'sell',
      [Cl.principal(adusd), Cl.uint(amount)],
      wallet1
    );
    expect(result).toBeOk(Cl.bool(true));

    const balance = simnet.callReadOnlyFn('adam-token-adusd-v3', 'get-balance', [Cl.principal(wallet1)], deployer);
    expect(balance.result).toBeOk(Cl.uint(0));
  });
});
