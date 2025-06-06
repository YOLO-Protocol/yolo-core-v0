# YOLO Protocol V0

```___  _ ____  _     ____    ____  ____  ____  _____  ____  ____  ____  _    
\  \///  _ \/ \   /  _ \  /  __\/  __\/  _ \/__ __\/  _ \/   _\/  _ \/ \   
 \  / | / \|| |   | / \|  |  \/||  \/|| / \|  / \  | / \||  /  | / \|| |   
 / /  | \_/|| |_/\| \_/|  |  __/|    /| \_/|  | |  | \_/||  \__| \_/|| |_/\
/_/   \____/\____/\____/  \_/   \_/\_\\____/  \_/  \____/\____/\____/\____/
                                                                           
```

This repository contains the core smart contracts for Yolo Protocol V0.

## Project Introduction

Yolo Protocol V0 is an extension and continued development of our Hackhathon Project: 
[Hackathon Devfolio](https://devfolio.co/projects/yolo-protocol-univ-hook-b899):
[Hackathon Github](https://github.com/alvinyap510/hackathon-yolo-protocol-hook):

We are currently part of the [Uniswap V4 Hook Incubator - Cohort UHI5](https://atrium.academy/uniswap), where we are evolving the protocol beyond its MVP into a production-ready modular DeFi infrastructure.

## What is YOLO Protocol?

YOLO Protocol is a modular DeFi engine built on top of Uniswap V4, combining core features of multiple blue-chip protocols — all within a single Uniswap V4 Hook:

    - 🏦 MakerDAO/Abracadabra-like
      - An overcollateralized stablecoin YOLO USD (USY) backed by yield-bearing tokens(YBTs)
  
    - ⚖️ Synthetix-style
      - Synthetic assets (currencies, shares, commodities) minting & swapping within Uniswap itself, without the need of any prior liquidity

    - ⚙️ Gearbox-style
      - Execute permissionless leverage of up to 20x on YBT positions (PT-sUSDe vs USY) with low liquidation risk

Since YOLO Protocol has the ability to create synthetic assets on-chain, future iteration we plan to expand it into an <b>on-chain CFD-like experience trading platform</b> utilizing the aforementioned core features of YOLO Protocol's Hook. 
  > (<b>Think about an on-chain eToro / Plus500 / IG.com, where you can execute on-chain 20x leverage by collateralizing USY, and being liquidated promptly</b>)

## How to run

### 1. Make sure you have git, foundry and pnpm installed

### 2. Git clone this repo to your local directory
```
git clone git@github.com:YOLO-Protocol/yolo-core-v0.git
cd yolo-core-v0
```

### 3. Install dependencies
```
forge install
pnpm install
```

### 4. Run the tests
```
forge test
```

## Resources
- [Uniswap V4 Docs](https://docs.uniswap.org/contracts/v4/overview)