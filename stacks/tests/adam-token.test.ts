import { describe, expect, it } from 'vitest';
import { Cl } from '@stacks/transactions';

describe('Adam Token', () => {
  const accounts = () => simnet.getAccounts();
  const WALLET_1 = () => accounts().get('wallet_1')!;
  const WALLET_2 = () => accounts().get('wallet_2')!;
  const DEPLOYER = () => accounts().get('deployer')!;

  it('should initialize correctly', () => {
    const deployer = DEPLOYER();
    const { result } = simnet.callPublicFn(
      'adam-token-adusd',
      'initialize',
      [
        Cl.stringAscii('Adam USD'),
        Cl.stringAscii('ADUSD'),
        Cl.uint(6),
        Cl.principal(deployer),
      ],
      deployer
    );
    expect(result).toBeOk(Cl.bool(true));

    const name = simnet.callReadOnlyFn('adam-token-adusd', 'get-name', [], deployer);
    expect(name.result).toBeOk(Cl.stringAscii('Adam USD'));

    const symbol = simnet.callReadOnlyFn('adam-token-adusd', 'get-symbol', [], deployer);
    expect(symbol.result).toBeOk(Cl.stringAscii('ADUSD'));

    const decimals = simnet.callReadOnlyFn('adam-token-adusd', 'get-decimals', [], deployer);
    expect(decimals.result).toBeOk(Cl.uint(6));
  });

  it('should mint tokens successfully', () => {
    const deployer = DEPLOYER();
    const wallet1 = WALLET_1();
    simnet.callPublicFn('adam-token-adusd', 'initialize', [Cl.stringAscii('Adam USD'), Cl.stringAscii('ADUSD'), Cl.uint(6), Cl.principal(deployer)], deployer);
    const { result } = simnet.callPublicFn(
      'adam-token-adusd',
      'mint',
      [Cl.uint(1000000), Cl.principal(wallet1)],
      deployer
    );
    expect(result).toBeOk(Cl.bool(true));

    const balance = simnet.callReadOnlyFn('adam-token-adusd', 'get-balance', [Cl.principal(wallet1)], deployer);
    expect(balance.result).toBeOk(Cl.uint(1000000));

    const supply = simnet.callReadOnlyFn('adam-token-adusd', 'get-total-supply', [], deployer);
    expect(supply.result).toBeOk(Cl.uint(1000000));
  });

  it('should fail to mint zero amount', () => {
    const deployer = DEPLOYER();
    const wallet1 = WALLET_1();
    simnet.callPublicFn('adam-token-adusd', 'initialize', [Cl.stringAscii('Adam USD'), Cl.stringAscii('ADUSD'), Cl.uint(6), Cl.principal(deployer)], deployer);
    const { result } = simnet.callPublicFn(
      'adam-token-adusd',
      'mint',
      [Cl.uint(0), Cl.principal(wallet1)],
      deployer
    );
    expect(result).toBeErr(Cl.uint(103)); // ERR-ZERO-AMOUNT
  });

  it('should burn tokens successfully', () => {
    const deployer = DEPLOYER();
    const wallet1 = WALLET_1();
    simnet.callPublicFn('adam-token-adusd', 'initialize', [Cl.stringAscii('Adam USD'), Cl.stringAscii('ADUSD'), Cl.uint(6), Cl.principal(deployer)], deployer);
    // Grant burner role
    simnet.callPublicFn(
      'adam-token-adusd',
      'set-burner',
      [Cl.principal(deployer), Cl.bool(true)],
      deployer
    );
    
    // Mint some tokens first
    simnet.callPublicFn(
      'adam-token-adusd',
      'mint',
      [Cl.uint(2000), Cl.principal(wallet1)],
      deployer
    );

    const { result } = simnet.callPublicFn(
      'adam-token-adusd',
      'burn',
      [Cl.uint(1000), Cl.principal(wallet1)],
      deployer
    );
    expect(result).toBeOk(Cl.bool(true));

    const balance = simnet.callReadOnlyFn('adam-token-adusd', 'get-balance', [Cl.principal(wallet1)], deployer);
    expect(balance.result).toBeOk(Cl.uint(1000));
  });

  it('should set and check roles', () => {
    const deployer = DEPLOYER();
    const wallet2 = WALLET_2();
    simnet.callPublicFn('adam-token-adusd', 'initialize', [Cl.stringAscii('Adam USD'), Cl.stringAscii('ADUSD'), Cl.uint(6), Cl.principal(deployer)], deployer);
    const { result: minterResult } = simnet.callPublicFn(
      'adam-token-adusd',
      'set-minter',
      [Cl.principal(wallet2), Cl.bool(true)],
      deployer
    );
    expect(minterResult).toBeOk(Cl.bool(true));

    const isMinter = simnet.callReadOnlyFn('adam-token-adusd', 'is-minter', [Cl.principal(wallet2)], deployer);
    expect(isMinter.result).toBeBool(true);

    const { result: burnerResult } = simnet.callPublicFn(
      'adam-token-adusd',
      'set-burner',
      [Cl.principal(wallet2), Cl.bool(true)],
      deployer
    );
    expect(burnerResult).toBeOk(Cl.bool(true));

    const isBurner = simnet.callReadOnlyFn('adam-token-adusd', 'is-burner', [Cl.principal(wallet2)], deployer);
    expect(isBurner.result).toBeBool(true);
  });

  it('should respect pause state', () => {
    const deployer = DEPLOYER();
    const wallet1 = WALLET_1();
    simnet.callPublicFn('adam-token-adusd', 'initialize', [Cl.stringAscii('Adam USD'), Cl.stringAscii('ADUSD'), Cl.uint(6), Cl.principal(deployer)], deployer);
    simnet.callPublicFn('adam-token-adusd', 'pause', [], deployer);
    
    const isPaused = simnet.callReadOnlyFn('adam-token-adusd', 'is-paused', [], deployer);
    expect(isPaused.result).toBeOk(Cl.bool(true));

    const { result } = simnet.callPublicFn(
      'adam-token-adusd',
      'mint',
      [Cl.uint(1000), Cl.principal(wallet1)],
      deployer
    );
    expect(result).toBeErr(Cl.uint(105)); // ERR-PAUSED

    simnet.callPublicFn('adam-token-adusd', 'unpause', [], deployer);
    expect(simnet.callPublicFn(
      'adam-token-adusd',
      'mint',
      [Cl.uint(1000), Cl.principal(wallet1)],
      deployer
    ).result).toBeOk(Cl.bool(true));
  });
});
