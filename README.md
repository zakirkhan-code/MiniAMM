# MiniAMM — Uniswap V2 Style Decentralized Exchange

A complete implementation of Uniswap V2's core protocol built from scratch in Solidity, featuring Factory, Pair, and Router contracts.

## Overview

MiniAMM implements the complete DEX stack:

- **Factory** — Creates and tracks unlimited trading pairs via CREATE2
- **Pair** — Handles swaps, liquidity, and LP tokens per pool
- **Router** — User-facing safety layer with slippage protection, deadlines, and multi-hop swaps

## Architecture
```
MiniFactory.sol     — Deploys + registers pairs (CREATE2 deterministic)
MiniPair.sol        — Individual AMM pool (x * y = k, 0.3% fee)
MiniRouter.sol      — Safety layer (slippage, deadline, multi-hop)
MockERC20.sol       — Minimal ERC20 for testing
```

## Key Features

### Factory Pattern
Anyone can create a new trading pair. Deterministic addresses via CREATE2.

### Constant Product AMM
```
amountOut = (reserveOut * amountIn * 997) / (reserveIn * 1000 + amountIn * 997)
```

### Router Safety
- **Slippage protection**: Set minimum output amount
- **Deadline**: Transaction expires if not mined in time
- **Multi-hop**: Route through multiple pairs (ETH → USDC → DAI)
- **Preview**: Check expected output before swapping

### LP Mechanics
- First deposit: `sqrt(amountA * amountB) - MINIMUM_LIQUIDITY`
- 0.3% swap fee accumulates in reserves, benefiting LPs

## Quick Start
```bash
curl -L https://foundry.paradigm.xyz | bash && foundryup
git clone https://github.com/zakirkhan-code/mini-amm.git
cd mini-amm
forge build
forge test -vvv
```

## Test Suite

### Factory Tests (6)
| Test | Verifies |
|------|----------|
| `test_Factory_CreatePair` | Deploys pair correctly |
| `test_Factory_BidirectionalLookup` | getPair works both ways |
| `test_Factory_RevertDuplicate` | No duplicate pairs |
| `test_Factory_RevertIdentical` | No self-pairing |
| `test_Factory_MultiplePairs` | Multiple unique pairs |
| `test_Pair_CannotReinitialize` | Pair locked after init |

### Pair Tests (8)
| Test | Verifies |
|------|----------|
| `test_AddLiquidity_FirstDeposit` | sqrt + MINIMUM_LIQUIDITY |
| `test_Swap_AtoB` | Correct output with fee |
| `test_Swap_KOnlyIncreases` | K invariant preserved |
| `test_Swap_PriceImpact` | Larger swaps = worse price |
| `test_LP_EarnsFees` | LPs earn from swap fees |
| `test_GetPrice` | Spot price calculation |
| `test_Revert_SwapZeroAmount` | Revert on zero |
| `test_Revert_SwapInvalidToken` | Revert on invalid token |

### Router Tests (10)
| Test | Verifies |
|------|----------|
| `test_SwapExact_Basic` | Single swap through router |
| `test_SwapExact_SlippageReverts` | Slippage protection works |
| `test_SwapExact_DeadlineReverts` | Deadline protection works |
| `test_SwapExact_NoPairReverts` | Revert on missing pair |
| `test_MultiHop_TwoHops` | ETH → USDC → DAI works |
| `test_MultiHop_SlippageReverts` | Multi-hop slippage check |
| `test_MultiHop_VsDirect` | Direct beats multi-hop |
| `test_GetAmountOut_Preview` | Preview matches actual |
| `test_GetAmountsOut_MultiHop` | Multi-hop preview works |
| `test_GetAmountsOut_InvalidPath` | Invalid path reverts |

## Deployed on Sepolia Testnet

| Contract | Address |
|----------|---------|
| Factory | `0x6e7455DD574065cBC329A080ab10a4A2cdDF3871` |
| Router | `0x48E134c431ef850cAE51F10800c1F7884c971256` |
| WETH | `0x767a1c012548dCAD946Df72125A2E8b7797A2CC9` |
| USDC | `0x33bF0eBf6b05eA74514eC9482Fa816f0e1999b08` |
| DAI | `0x6dFA61F2b1e735D43A81eEDECafdd4Acd3c6817c` |
| WETH/USDC Pair | `0x8C3B2934beA68981bB1945b62a72D35e81505B6E` |
| USDC/DAI Pair | `0xf10FAe761378eb96bD750285881CFC7413186e4A` |
| WETH/DAI Pair | `0xe5bd0FEbB8008dF77b7cFdd603577aC70551F5A6` |

Network: Sepolia (Chain ID: 11155111)

## Security

- Reentrancy guard on all state-changing functions
- Checked ERC20 transfers
- Checks-Effects-Interactions pattern
- MINIMUM_LIQUIDITY prevents manipulation
- Factory-only pair initialization
- Slippage + deadline protection via Router

## Roadmap

- [x] Core AMM (addLiquidity, removeLiquidity, swap)
- [x] Factory contract (multi-pair, CREATE2)
- [x] Router contract (slippage, deadline, multi-hop)
- [ ] Flash loan support
- [ ] TWAP oracle
- [x] Sepolia testnet deployment

## Built With

- Solidity 0.8.20
- Foundry (Forge)

## References

- [Uniswap V2 Core](https://github.com/Uniswap/v2-core)
- [Uniswap V2 Periphery](https://github.com/Uniswap/v2-periphery)
- [Uniswap V2 Whitepaper](https://uniswap.org/whitepaper.pdf)

## Author

**Zakir Khan** — Blockchain Developer & Smart Contract Engineer