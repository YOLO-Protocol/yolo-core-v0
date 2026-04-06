# Base Sepolia Contract Verification Guide

## 📋 Quick Start

### Option 1: Run Full Verification Script
```bash
./verify-base-sepolia.sh
```

### Option 2: Verify Synthetic Assets Only
```bash
./verify-synthetic-assets.sh
```

### Option 3: Individual Commands (see below)

---

## 🔧 Configuration

| Parameter | Value |
|-----------|-------|
| **Chain ID** | `84532` (Base Sepolia) |
| **Compiler Version** | `0.8.29` |
| **Optimizer Runs** | `20` |
| **Via IR** | `true` |
| **EVM Version** | `cancun` |
| **API Key** | `P56935QPV9KIWXSB7D91N37769ZE4155F5` |

---

## 📝 Individual Verification Commands

### 1. Core Protocol Contracts

#### YoloHook Implementation
```bash
forge verify-contract \
  0x89fa4EBb912165db57B07c009E367dC6f0d93fFf \
  src/core/YoloHook.sol:YoloHook \
  --constructor-args $(cast abi-encode "constructor(address)" "0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408") \
  --chain-id 84532 \
  --compiler-version 0.8.29 \
  --optimizer-runs 20 \
  --via-ir \
  --evm-version cancun \
  --etherscan-api-key P56935QPV9KIWXSB7D91N37769ZE4155F5 \
  --watch
```

#### PublicTransparentUpgradeableProxy (YoloHook Proxy)
```bash
forge verify-contract \
  0x81B9808a8470236462A84457ebe047eE5874bFfF \
  src/contracts/proxy/PublicTransparentUpgradeableProxy.sol:PublicTransparentUpgradeableProxy \
  --constructor-args $(cast abi-encode "constructor(address,address,bytes)" "0x89fa4EBb912165db57B07c009E367dC6f0d93fFf" "0x000000030C764379b92bB9d0AB4B3455D5dc8e92" "0x") \
  --chain-id 84532 \
  --compiler-version 0.8.29 \
  --optimizer-runs 20 \
  --via-ir \
  --evm-version cancun \
  --etherscan-api-key P56935QPV9KIWXSB7D91N37769ZE4155F5 \
  --watch
```

#### SyntheticAssetLogic
```bash
forge verify-contract \
  0xACF21F6Ed3e52527b3eEef77df60B392E75F9AA7 \
  src/core/SyntheticAssetLogic.sol:SyntheticAssetLogic \
  --chain-id 84532 \
  --compiler-version 0.8.29 \
  --optimizer-runs 20 \
  --via-ir \
  --evm-version cancun \
  --etherscan-api-key P56935QPV9KIWXSB7D91N37769ZE4155F5 \
  --watch
```

---

### 2. Mock Tokens

#### USDC
```bash
forge verify-contract \
  0x296Ff1fb2C8DD9BfA7C87110fbE9EBF7Fb481F2b \
  src/mocks/MockERC20.sol:MockERC20 \
  --constructor-args $(cast abi-encode "constructor(string,string,uint256)" "Mock USDC" "USDC" "100000000000000000000000000") \
  --chain-id 84532 \
  --compiler-version 0.8.29 \
  --optimizer-runs 20 \
  --via-ir \
  --evm-version cancun \
  --etherscan-api-key P56935QPV9KIWXSB7D91N37769ZE4155F5 \
  --watch
```

#### WBTC
```bash
forge verify-contract \
  0xa348dFBFC45340dA75d80892e2b8F1D34F4C4E35 \
  src/mocks/MockERC20.sol:MockERC20 \
  --constructor-args $(cast abi-encode "constructor(string,string,uint256)" "Mock WBTC" "WBTC" "100000000000000000000000000") \
  --chain-id 84532 \
  --compiler-version 0.8.29 \
  --optimizer-runs 20 \
  --via-ir \
  --evm-version cancun \
  --etherscan-api-key P56935QPV9KIWXSB7D91N37769ZE4155F5 \
  --watch
```

#### MockWETH
```bash
forge verify-contract \
  0x38389462847C9961338118cb3E07E2336bFA3AC4 \
  src/mocks/MockWETH.sol:MockWETH \
  --chain-id 84532 \
  --compiler-version 0.8.29 \
  --optimizer-runs 20 \
  --via-ir \
  --evm-version cancun \
  --etherscan-api-key P56935QPV9KIWXSB7D91N37769ZE4155F5 \
  --watch
```

---

### 3. Synthetic Assets

#### USY (YOLO USD)
```bash
forge verify-contract \
  0x5FF62705aA2F6dEAe0F8f3a771298440124A9988 \
  src/core/YoloSyntheticAsset.sol:YoloSyntheticAsset \
  --constructor-args $(cast abi-encode "constructor(string,string,uint8,address)" "YOLO USD" "USY" "18" "0x81B9808a8470236462A84457ebe047eE5874bFfF") \
  --chain-id 84532 \
  --compiler-version 0.8.29 \
  --optimizer-runs 20 \
  --via-ir \
  --evm-version cancun \
  --etherscan-api-key P56935QPV9KIWXSB7D91N37769ZE4155F5 \
  --watch
```

#### yJPY (Japanese Yen)
```bash
forge verify-contract \
  0x67Bb3cc52448866CD7743efF45823f30d344b1D6 \
  src/core/YoloSyntheticAsset.sol:YoloSyntheticAsset \
  --constructor-args $(cast abi-encode "constructor(string,string,uint8,address)" "Yolo Japanese Yen" "yJPY" "18" "0x81B9808a8470236462A84457ebe047eE5874bFfF") \
  --chain-id 84532 \
  --compiler-version 0.8.29 \
  --optimizer-runs 20 \
  --via-ir \
  --evm-version cancun \
  --etherscan-api-key P56935QPV9KIWXSB7D91N37769ZE4155F5 \
  --watch
```

#### yXAU (Gold)
```bash
forge verify-contract \
  0x1091392b50De97065c829d749cad8B6e2f129dc3 \
  src/core/YoloSyntheticAsset.sol:YoloSyntheticAsset \
  --constructor-args $(cast abi-encode "constructor(string,string,uint8,address)" "Yolo Gold" "yXAU" "18" "0x81B9808a8470236462A84457ebe047eE5874bFfF") \
  --chain-id 84532 \
  --compiler-version 0.8.29 \
  --optimizer-runs 20 \
  --via-ir \
  --evm-version cancun \
  --etherscan-api-key P56935QPV9KIWXSB7D91N37769ZE4155F5 \
  --watch
```

---

### 4. Price Oracles

#### USDC/USD Oracle
```bash
forge verify-contract \
  0x9Ffcf454b62cC4F9d4600CB338A90ea0C59E56c1 \
  src/mocks/MockPriceOracle.sol:MockPriceOracle \
  --constructor-args $(cast abi-encode "constructor(int256,string)" "100000000" "USDC / USD") \
  --chain-id 84532 \
  --compiler-version 0.8.29 \
  --optimizer-runs 20 \
  --via-ir \
  --evm-version cancun \
  --etherscan-api-key P56935QPV9KIWXSB7D91N37769ZE4155F5 \
  --watch
```

#### WETH/USD Oracle
```bash
forge verify-contract \
  0x0eBEf942a9a0AC8575D7dD1c0072D14429705118 \
  src/mocks/MockPriceOracle.sol:MockPriceOracle \
  --constructor-args $(cast abi-encode "constructor(int256,string)" "350000000000" "WETH / USD") \
  --chain-id 84532 \
  --compiler-version 0.8.29 \
  --optimizer-runs 20 \
  --via-ir \
  --evm-version cancun \
  --etherscan-api-key P56935QPV9KIWXSB7D91N37769ZE4155F5 \
  --watch
```

---

### 5. Cross-Chain Bridge

#### YoloCCIPBridge
```bash
forge verify-contract \
  0x0aCfee9DdE44B42b8E28d857a99723Ff2803954F \
  src/cross-chain/YoloCCIPBridge.sol:YoloCCIPBridge \
  --constructor-args $(cast abi-encode "constructor(address,address,uint64)" "0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93" "0x81B9808a8470236462A84457ebe047eE5874bFfF" "10344971235874465080") \
  --chain-id 84532 \
  --compiler-version 0.8.29 \
  --optimizer-runs 20 \
  --via-ir \
  --evm-version cancun \
  --etherscan-api-key P56935QPV9KIWXSB7D91N37769ZE4155F5 \
  --watch
```

---

## 🐛 Troubleshooting

### Issue: "Contract source code already verified"
**Solution:** Contract is already verified! Check Basescan to confirm.

### Issue: "Compiler version mismatch"
**Solution:** Ensure you're using compiler version `0.8.29` exactly.

### Issue: "Constructor arguments mismatch"
**Solution:** Double-check the constructor arguments match your deployment. You can verify with:
```bash
cast call <contract_address> --rpc-url https://sepolia.base.org
```

### Issue: "Rate limit exceeded"
**Solution:** Basescan API has rate limits. Add delays between verifications or use `--watch` flag.

### Issue: "Compilation error"
**Solution:** Ensure your local code matches the deployed bytecode:
```bash
forge build --force
```

---

## 📊 Verification Checklist

- [ ] YoloHook Implementation (0x89fa4E...)
- [ ] YoloHook Proxy (0x81B980...)
- [ ] YoloOracle (0xF5e1F3...)
- [ ] SyntheticAssetLogic (0xACF21F...)
- [ ] MockERC20 Tokens (7 contracts)
- [ ] MockWETH (0x383894...)
- [ ] MockPriceOracles (9 contracts)
- [ ] YoloCCIPBridge (0x0aCfee...)
- [ ] USY (0x5FF627...)
- [ ] Synthetic Assets (yJPY, yKRW, yXAU, yNVDA, yTSLA)

---

## 🔗 Useful Links

- **Base Sepolia Explorer:** https://sepolia.basescan.org
- **YoloHook Proxy:** https://sepolia.basescan.org/address/0x81B9808a8470236462A84457ebe047eE5874bFfF
- **Foundry Verification Docs:** https://book.getfoundry.sh/reference/forge/forge-verify-contract

---

## 💡 Tips

1. **Use `--watch` flag** to monitor verification status in real-time
2. **Verify core contracts first** (Hook, Oracle, Logic) before mocks
3. **Check gas settings** match your deployment (optimizer runs, via-ir)
4. **Save verification status** to track which contracts are done
5. **Use parallel verification** by running multiple terminals with different contracts

---

## 📝 Notes

- All synthetic assets (USY, yJPY, yKRW, yXAU, yNVDA, yTSLA) use the same `YoloSyntheticAsset` contract with different constructor arguments
- Mock contracts use simpler compiler settings (may vary)
- YoloOracle has complex array constructor args - use pre-encoded hex if needed
- Proxy contract verification may require implementation contract to be verified first

---

Generated: 2025-10-18
Chain: Base Sepolia (84532)
Compiler: 0.8.29
