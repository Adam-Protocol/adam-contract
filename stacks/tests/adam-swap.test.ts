import { describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';

describe('Adam Swap', () => {
  const accounts = () => simnet.getAccounts();
  const WALLET_1 = () => accounts().get('wallet_1')!;
  const TREASURY = () => accounts().get('wallet_2')!;
  const DEPLOYER = () => accounts().get('deployer')!;

  // Mock addresses for tests
  const usdcMock = `${DEPLOYER()}.usdc-mock`;
  const getAdusdMock = () => `${DEPLOYER()}.adam-token-adusd`;
  const getAdngnMock = () => `${DEPLOYER()}.adam-token-adngn`;

  it('should initialize correctly', () => {
    const deployer = DEPLOYER();
    const treasury = TREASURY();
    const adusdMock = getAdusdMock();
    const adngnMock = getAdngnMock();

    const { result } = simnet.callPublicFn(
      'adam-swap',
      'initialize',
      [
        Cl.principal(deployer),
        Cl.principal(usdcMock),
        Cl.principal(adusdMock),
        Cl.principal(adngnMock),
        Cl.uint(50),
      ],
      deployer
    );
    expect(result).toBeOk(Cl.bool(true));

    expect(simnet.callReadOnlyFn('adam-swap', 'get-fee-bps', [], deployer).result).toBeOk(Cl.uint(50));
    expect(simnet.callReadOnlyFn('adam-swap', 'get-usdc-address', [], deployer).result).toBeOk(Cl.some(Cl.principal(usdcMock)));
  });

  it('should set and get exchange rates', () => {
    const deployer = DEPLOYER();
    const adngnMock = getAdngnMock();
    const adusdMock = getAdusdMock();
    const currentRate = 1500n * 10n**18n;

    simnet.callPublicFn('adam-swap', 'set-rate-setter', [Cl.principal(deployer), Cl.bool(true)], deployer);
    // Set initial rate
    const { result } = simnet.callPublicFn(
      'adam-swap',
      'set-rate',
      [Cl.principal(usdcMock), Cl.principal(adngnMock), Cl.uint(currentRate)],
      deployer
    );
    expect(result).toBeOk(Cl.bool(true));

    const storedRate = simnet.callReadOnlyFn('adam-swap', 'get-rate', [Cl.principal(usdcMock), Cl.principal(adngnMock)], deployer);
    expect(storedRate.result).toBeOk(Cl.uint(currentRate));
  });

  it('should respect rate change limits', () => {
    const deployer = DEPLOYER();
    const adngnMock = getAdngnMock();
    const currentRate = 1500n * 10n**18n;
    
    simnet.callPublicFn('adam-swap', 'set-rate-setter', [Cl.principal(deployer), Cl.bool(true)], deployer);

    // Set initial rate first
    simnet.callPublicFn(
      'adam-swap',
      'set-rate',
      [Cl.principal(usdcMock), Cl.principal(adngnMock), Cl.uint(currentRate)],
      deployer
    );
    
    // Try to set it to 2000 (+33% change) -> should fail (limit is 20%)
    const highRate = 2000n * 10n**18n;
    const { result: failResult } = simnet.callPublicFn(
      'adam-swap',
      'set-rate',
      [Cl.principal(usdcMock), Cl.principal(adngnMock), Cl.uint(highRate)],
      deployer
    );
    expect(failResult).toBeErr(Cl.uint(309)); // ERR-RATE-LIMIT-EXCEEDED

    // Try to set it to 1700 (+13% change) -> should succeed
    const goodRate = 1700n * 10n**18n;
    const { result: successResult } = simnet.callPublicFn(
      'adam-swap',
      'set-rate',
      [Cl.principal(usdcMock), Cl.principal(adngnMock), Cl.uint(goodRate)],
      deployer
    );
    expect(successResult).toBeOk(Cl.bool(true));
  });

  it('should respect pause state', () => {
    const deployer = DEPLOYER();
    const adusdMock = getAdusdMock();
    const usdcMockAddress = usdcMock;
    simnet.callPublicFn('adam-swap', 'set-usdc-address', [Cl.principal(usdcMockAddress)], deployer);
    simnet.callPublicFn('adam-swap', 'set-adusd-address', [Cl.principal(adusdMock)], deployer);
    simnet.callPublicFn('adam-swap', 'set-adngn-address', [Cl.principal(getAdngnMock())], deployer);
    simnet.callPublicFn('adam-swap', 'set-rate-setter', [Cl.principal(deployer), Cl.bool(true)], deployer);
    simnet.callPublicFn('adam-swap', 'set-rate', [Cl.principal(adusdMock), Cl.principal(getAdngnMock()), Cl.uint(150000n)], deployer);
    
    simnet.callPublicFn('adam-swap', 'pause', [], deployer);
    expect(simnet.callReadOnlyFn('adam-swap', 'is-paused', [], deployer).result).toBeOk(Cl.bool(true));

    const { result } = simnet.callPublicFn(
      'adam-swap',
      'swap',
      [
        Cl.principal(adusdMock),
        Cl.uint(100),
        Cl.principal(getAdngnMock()),
        Cl.uint(0)
      ],
      deployer
    );
    expect(result).toBeErr(Cl.uint(308)); // ERR-PAUSED

    simnet.callPublicFn('adam-swap', 'unpause', [], deployer);
    expect(simnet.callReadOnlyFn('adam-swap', 'is-paused', [], deployer).result).toBeOk(Cl.bool(false));
  });
});
