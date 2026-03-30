# MiniAMM — Uniswap V2 Style Automated Market Maker

A simplified implementation of Uniswap V2's core protocol built from scratch in Solidity, featuring a Factory pattern for multi-pair deployment.

## Overview

MiniAMM implements the core DeFi primitives of a Constant Product AMM:

- **Factory Contract** — Creates and tracks unlimited trading pairs via CREATE2
- **Pair Contract** — Handles swaps, liquidity, and LP token accounting per pair
- **Constant Product Formula** — `x * y = k` with 0.3% swap fee

## Architecture
```
MiniFactory.sol     — Deploys + registers new pairs (CREATE2)
MiniPair.sol        — Individual pool (addLiquidity, removeLiquidity, swap)
MockERC20.sol       — Minimal ERC20 for testing
```

## Key Features

**Factory Pattern**: Anyone can create a new trading pair. Each pair gets a deterministic address via CREATE2, enabling off-chain address calculation.

**Constant Product (x * y = k)**: Swap output calculated as:
```
amountOut = (reserveOut * amountIn * 997) / (reserveIn * 1000 + amountIn * 997)
```

**LP Token Mechanics**: First deposit uses `sqrt(amountA * amountB)`, subsequent deposits use proportional minting. 1000 wei MINIMUM_LIQUIDITY permanently locked.

**0.3% Swap Fee**: Stays in pool reserves, benefiting LPs over time.

## Getting Started
```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Clone and build
git clone https://github.com/YOUR_USERNAME/mini-amm.git
cd mini-amm
forge build

# Run tests
forge test -vvv
```

## Test Suite (14/14 Passing)

| Test | Verifies |
|------|----------|
| `test_Factory_CreatePair` | Factory deploys pair correctly |
| `test_Factory_BidirectionalLookup` | getPair[A][B] == getPair[B][A] |
| `test_Factory_RevertDuplicate` | Cannot create same pair twice |
| `test_Factory_RevertIdentical` | Cannot pair token with itself |
| `test_Factory_MultiplePairs` | Multiple unique pairs created |
| `test_Pair_CannotReinitialize` | Pair locked after initialization |
| `test_AddLiquidity_FirstDeposit` | sqrt formula + MINIMUM_LIQUIDITY |
| `test_Swap_AtoB` | Correct output with fee + price impact |
| `test_Swap_KOnlyIncreases` | K invariant preserved across swaps |
| `test_Swap_PriceImpact` | Larger swaps get worse price |
| `test_LP_EarnsFees` | LP earns from accumulated swap fees |
| `test_GetPrice` | Spot price calculation |
| `test_Revert_SwapZeroAmount` | Reverts on zero input |
| `test_Revert_SwapInvalidToken` | Reverts on invalid token |

## Security

- Reentrancy guard on all state-changing functions
- Return value checks on ERC20 transfers
- Checks-Effects-Interactions pattern
- MINIMUM_LIQUIDITY prevents first-depositor manipulation
- Factory-only initialization prevents unauthorized pair setup

## Roadmap

- [x] Core AMM (addLiquidity, removeLiquidity, swap)
- [x] Factory contract (multi-pair, CREATE2)
- [ ] Router contract (slippage protection, multi-hop swaps)
- [ ] Flash loan support
- [ ] TWAP oracle
- [ ] Sepolia deployment

## Built With

- Solidity 0.8.20
- Foundry (Forge)

## References

- [Uniswap V2 Core](https://github.com/Uniswap/v2-core)
- [Uniswap V2 Whitepaper](https://uniswap.org/whitepaper.pdf)

## Author

**Zakir Khan** — Blockchain Developer & Smart Contract Engineer