import { describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';

describe('Integration Flow', () => {
  const accounts = () => simnet.getAccounts();
  const WALLET_1 = () => accounts().get('wallet_1')!;
  const TREASURY = () => accounts().get('wallet_2')!;
  const DEPLOYER = () => accounts().get('deployer')!;

  const usdcMock = `${DEPLOYER()}.usdc-mock`;
  const getAdusd = () => `${DEPLOYER()}.adam-token-adusd`;
  const getAdngn = () => `${DEPLOYER()}.adam-token-adngn`;
  const getSwap = () => `${DEPLOYER()}.adam-swap`;

  it('should setup the complete system', () => {
    const deployer = DEPLOYER();
    const treasury = TREASURY();
    const adusd = getAdusd();
    const adngn = getAdngn();
    const swap = getSwap();

    // 1. Initialize tokens
    simnet.callPublicFn('adam-token-adusd', 'initialize', [Cl.stringAscii('Adam USD'), Cl.stringAscii('ADUSD'), Cl.uint(6), Cl.principal(deployer)], deployer);
    simnet.callPublicFn('adam-token-adngn', 'initialize', [Cl.stringAscii('Adam NGN'), Cl.stringAscii('ADNGN'), Cl.uint(6), Cl.principal(deployer)], deployer);

    // 2. Initialize swap
    simnet.callPublicFn('adam-swap', 'initialize', [
      Cl.principal(deployer),
      Cl.principal(usdcMock),
      Cl.principal(adusd),
      Cl.principal(adngn),
      Cl.uint(50)
    ], deployer);

    // 3. Grant roles
    simnet.callPublicFn('adam-token-adusd', 'set-minter', [Cl.principal(swap), Cl.bool(true)], deployer);
    simnet.callPublicFn('adam-token-adngn', 'set-minter', [Cl.principal(swap), Cl.bool(true)], deployer);
    simnet.callPublicFn('adam-token-adusd', 'set-burner', [Cl.principal(swap), Cl.bool(true)], deployer);
    simnet.callPublicFn('adam-token-adngn', 'set-burner', [Cl.principal(swap), Cl.bool(true)], deployer);

    // 4. Set rates
    simnet.callPublicFn('adam-swap', 'set-rate', [Cl.principal(usdcMock), Cl.principal(adusd), Cl.uint(10n**18n)], deployer);
    simnet.callPublicFn('adam-swap', 'set-rate', [Cl.principal(usdcMock), Cl.principal(adngn), Cl.uint(1500n * 10n**18n)], deployer);
    simnet.callPublicFn('adam-swap', 'set-rate', [Cl.principal(adusd), Cl.principal(adngn), Cl.uint(1500n * 10n**18n)], deployer);
    simnet.callPublicFn('adam-swap', 'set-rate', [Cl.principal(adngn), Cl.principal(adusd), Cl.uint(10n**18n / 1500n)], deployer);

    // 5. Verify setup
    expect(simnet.callReadOnlyFn('adam-token-adusd', 'is-minter', [Cl.principal(swap)], deployer).result).toBeBool(true);
    expect(simnet.callReadOnlyFn('adam-swap', 'get-fee-bps', [], deployer).result).toBeOk(Cl.uint(50));
  });

  it('should execute buy flow successfully', () => {
    const wallet1 = WALLET_1();
    const adusd = getAdusd();
    const deployer = DEPLOYER();

    simnet.callPublicFn('adam-swap', 'set-usdc-address', [Cl.principal(usdcMock)], deployer);
    simnet.callPublicFn('adam-swap', 'set-adusd-address', [Cl.principal(adusd)], deployer);
    simnet.callPublicFn('adam-swap', 'set-rate-setter', [Cl.principal(deployer), Cl.bool(true)], deployer);
    simnet.callPublicFn('adam-swap', 'set-rate', [Cl.principal(usdcMock), Cl.principal(adusd), Cl.uint(1000000000000000000n)], deployer); // 1:1 rate
    simnet.callPublicFn('adam-token-adusd', 'set-minter', [Cl.principal(getSwap()), Cl.bool(true)], deployer);

    const amountIn = 1000000n; // 1 USDC
    const { result } = simnet.callPublicFn(
      'adam-swap',
      'buy',
      [Cl.uint(amountIn), Cl.principal(adusd)],
      wallet1
    );
    
    // Fee is 0.5%, so 1,000,000 * 0.995 = 995,000
    expect(result).toBeOk(Cl.uint(995000));
    
    const balance = simnet.callReadOnlyFn('adam-token-adusd', 'get-balance', [Cl.principal(wallet1)], deployer);
    expect(balance.result).toBeOk(Cl.uint(995000));
  });

  it('should execute swap flow successfully', () => {
    const wallet1 = WALLET_1();
    const adusd = getAdusd();
    const adngn = getAdngn();
    const deployer = DEPLOYER();

    simnet.callPublicFn('adam-swap', 'set-usdc-address', [Cl.principal(usdcMock)], deployer);
    simnet.callPublicFn('adam-swap', 'set-adusd-address', [Cl.principal(adusd)], deployer);
    simnet.callPublicFn('adam-swap', 'set-adngn-address', [Cl.principal(adngn)], deployer);
    simnet.callPublicFn('adam-swap', 'set-rate-setter', [Cl.principal(deployer), Cl.bool(true)], deployer);
    simnet.callPublicFn('adam-swap', 'set-rate', [Cl.principal(adusd), Cl.principal(adngn), Cl.uint(1500000000000000000000n)], deployer); // 1500 rate
    simnet.callPublicFn('adam-token-adusd', 'set-minter', [Cl.principal(getSwap()), Cl.bool(true)], deployer);
    simnet.callPublicFn('adam-token-adngn', 'set-minter', [Cl.principal(getSwap()), Cl.bool(true)], deployer);
    simnet.callPublicFn('adam-token-adusd', 'set-burner', [Cl.principal(getSwap()), Cl.bool(true)], deployer);
    simnet.callPublicFn('adam-token-adusd', 'set-minter', [Cl.principal(deployer), Cl.bool(true)], deployer);
    simnet.callPublicFn('adam-token-adusd', 'mint', [Cl.uint(100000n), Cl.principal(wallet1)], deployer); // Fund wallet

    const amountIn = 100000n; // 0.1 ADUSD
    const { result } = simnet.callPublicFn(
      'adam-swap',
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

    const balanceNGN = simnet.callReadOnlyFn('adam-token-adngn', 'get-balance', [Cl.principal(wallet1)], deployer);
    expect(balanceNGN.result).toBeOk(Cl.uint(149250000));

    const balanceUSD = simnet.callReadOnlyFn('adam-token-adusd', 'get-balance', [Cl.principal(wallet1)], deployer);
    expect(balanceUSD.result).toBeOk(Cl.uint(0));
  });

  it('should execute sell flow successfully', () => {
    const wallet1 = WALLET_1();
    const adusd = getAdusd();
    const deployer = DEPLOYER();

    simnet.callPublicFn('adam-swap', 'set-adusd-address', [Cl.principal(adusd)], deployer);
    simnet.callPublicFn('adam-token-adusd', 'set-burner', [Cl.principal(getSwap()), Cl.bool(true)], deployer);
    simnet.callPublicFn('adam-token-adusd', 'set-minter', [Cl.principal(deployer), Cl.bool(true)], deployer);
    simnet.callPublicFn('adam-token-adusd', 'mint', [Cl.uint(50000n), Cl.principal(wallet1)], deployer); // Fund wallet

    const amount = 50000n;
    const { result } = simnet.callPublicFn(
      'adam-swap',
      'sell',
      [Cl.principal(adusd), Cl.uint(amount)],
      wallet1
    );
    expect(result).toBeOk(Cl.bool(true));

    const balance = simnet.callReadOnlyFn('adam-token-adusd', 'get-balance', [Cl.principal(wallet1)], deployer);
    expect(balance.result).toBeOk(Cl.uint(0));
  });
});
