#!/bin/bash
# Base Sepolia Full Verification Script
# Using Etherscan API Key
# Chain: base-sepolia (84532)
# Compiler: 0.8.29

set -e

export BASESCAN_API_KEY="9JWIPJVEHU4FC5IFWKCM959S84TNE1A7S8"
DELAY=3

echo "=================================================="
echo "  YOLO PROTOCOL - BASE SEPOLIA VERIFICATION"
echo "  Total Contracts: 27"
echo "=================================================="
echo ""

# ========================================
# 1. CORE PROTOCOL (4 contracts)
# ========================================

echo "========================================"
echo "STEP 1/5: CORE PROTOCOL (4 contracts)"
echo "========================================"
echo ""

echo "🔍 [1/27] YoloHook Implementation..."
forge verify-contract 0x89fa4EBb912165db57B07c009E367dC6f0d93fFf \
  src/core/YoloHook.sol:YoloHook \
  --constructor-args $(cast abi-encode "constructor(address)" "0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408") \
  --chain base-sepolia --etherscan-api-key $BASESCAN_API_KEY \
  --compiler-version 0.8.29 --optimizer-runs 20 --via-ir --evm-version cancun \
  --watch || echo "⚠️  Already verified or failed"
sleep $DELAY

echo ""
echo "🔍 [2/27] PublicTransparentUpgradeableProxy..."
forge verify-contract 0x81B9808a8470236462A84457ebe047eE5874bFfF \
  src/proxy/PublicTransparentUpgradeableProxy.sol:PublicTransparentUpgradeableProxy \
  --constructor-args $(cast abi-encode "constructor(address,address,bytes)" "0x89fa4EBb912165db57B07c009E367dC6f0d93fFf" "0x000000030C764379b92bB9d0AB4B3455D5dc8e92" "0x") \
  --chain base-sepolia --etherscan-api-key $BASESCAN_API_KEY \
  --compiler-version 0.8.29 --optimizer-runs 20 --via-ir --evm-version cancun \
  --watch || echo "⚠️  Already verified or failed"
sleep $DELAY

echo ""
echo "🔍 [3/27] YoloOracle..."
forge verify-contract 0xF5e1F3C13150dCcD88F96791fd36D79c46F22088 \
  src/core/YoloOracle.sol:YoloOracle \
  --constructor-args 0x00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000000800000000000000000000000006d5cc7c72af979cb4d69404386a4f15f5488d0bb000000000000000000000000296ff1fb2c8dd9bfa7c87110fbe9ebf7fb481f2b0000000000000000000000000721160b5301e3c281d1428209d9a899257a1f03000000000000000000000000d1128a83531abfc9a96337d8b96d21fd39c7d864000000000000000000000000a348dfbfc45340da75d80892e2b8f1d34f4c4e35000000000000000000000000de2cfac1390d29491a50dc1bfba9bce70df13047000000000000000000000000044baf498b01ca6c54d0624030a8f738925289cfe00000000000000000000000038389462847c9961338118cb3e07e2336bfa3ac400000000000000000000000000000000000000000000000000000000000000080000000000000000000000007e59d5467be55d14507589b5641874b675f0fc0e0000000000000000000000009ffcf454b62cc4f9d4600cb338a90ea0c59e56c100000000000000000000000075932dc2fcb4e5d656aca97b11bdaa04162c09fc00000000000000000000000050f933804ba3140c0fb1d14cb3224af8c4b4e2df00000000000000000000000067bd0f6fd1466daed69f932ac51697ea65880805000000000000000000000000b74f4bc6801cca34c9a3df4a1d6c937a910ddec30000000000000000000000000301e85186651e5bed0c08bee604c12d8197514f0000000000000000000000000ebef942a9a0ac8575d7dd1c0072d14429705118 \
  --chain base-sepolia --etherscan-api-key $BASESCAN_API_KEY \
  --compiler-version 0.8.29 --optimizer-runs 20 --via-ir --evm-version cancun \
  --watch || echo "⚠️  Already verified or failed"
sleep $DELAY

echo ""
echo "🔍 [4/27] SyntheticAssetLogic..."
forge verify-contract 0xACF21F6Ed3e52527b3eEef77df60B392E75F9AA7 \
  src/core/SyntheticAssetLogic.sol:SyntheticAssetLogic \
  --chain base-sepolia --etherscan-api-key $BASESCAN_API_KEY \
  --compiler-version 0.8.29 --optimizer-runs 20 --via-ir --evm-version cancun \
  --watch || echo "⚠️  Already verified or failed"
sleep $DELAY

# ========================================
# 2. MOCK TOKENS (7 contracts)
# ========================================

echo ""
echo "========================================"
echo "STEP 2/5: MOCK TOKENS (7 contracts)"
echo "========================================"
echo ""

echo "🔍 [5/27] MockERC20 - USDC..."
forge verify-contract 0x296Ff1fb2C8DD9BfA7C87110fbE9EBF7Fb481F2b \
  src/mocks/MockERC20.sol:MockERC20 \
  --constructor-args $(cast abi-encode "constructor(string,string,uint256)" "Mock USDC" "USDC" "100000000000000000000000000") \
  --chain base-sepolia --etherscan-api-key $BASESCAN_API_KEY \
  --compiler-version 0.8.29 --optimizer-runs 20 --via-ir --evm-version cancun || echo "⚠️  Already verified"
sleep $DELAY

echo ""
echo "🔍 [6/27] MockERC20 - WBTC..."
forge verify-contract 0xa348dFBFC45340dA75d80892e2b8F1D34F4C4E35 \
  src/mocks/MockERC20.sol:MockERC20 \
  --constructor-args $(cast abi-encode "constructor(string,string,uint256)" "Mock WBTC" "WBTC" "100000000000000000000000000") \
  --chain base-sepolia --etherscan-api-key $BASESCAN_API_KEY \
  --compiler-version 0.8.29 --optimizer-runs 20 --via-ir --evm-version cancun || echo "⚠️  Already verified"
sleep $DELAY

echo ""
echo "🔍 [7/27] MockERC20 - PT-sUSDe..."
forge verify-contract 0xde2CfAc1390D29491A50dC1bFbA9Bce70df13047 \
  src/mocks/MockERC20.sol:MockERC20 \
  --constructor-args $(cast abi-encode "constructor(string,string,uint256)" "Mock PT-sUSDe-31JUL2025" "PT-sUSDe-31JUL2025" "100000000000000000000000000") \
  --chain base-sepolia --etherscan-api-key $BASESCAN_API_KEY \
  --compiler-version 0.8.29 --optimizer-runs 20 --via-ir --evm-version cancun || echo "⚠️  Already verified"
sleep $DELAY

echo ""
echo "🔍 [8/27] MockERC20 - DAI..."
forge verify-contract 0x6d5Cc7C72Af979cb4d69404386A4F15f5488d0BB \
  src/mocks/MockERC20.sol:MockERC20 \
  --constructor-args $(cast abi-encode "constructor(string,string,uint256)" "Mock DAI" "DAI" "100000000000000000000000000") \
  --chain base-sepolia --etherscan-api-key $BASESCAN_API_KEY \
  --compiler-version 0.8.29 --optimizer-runs 20 --via-ir --evm-version cancun || echo "⚠️  Already verified"
sleep $DELAY

echo ""
echo "🔍 [9/27] MockERC20 - USDT..."
forge verify-contract 0x0721160b5301e3C281D1428209D9a899257a1f03 \
  src/mocks/MockERC20.sol:MockERC20 \
  --constructor-args $(cast abi-encode "constructor(string,string,uint256)" "Mock USDT" "USDT" "100000000000000000000000000") \
  --chain base-sepolia --etherscan-api-key $BASESCAN_API_KEY \
  --compiler-version 0.8.29 --optimizer-runs 20 --via-ir --evm-version cancun || echo "⚠️  Already verified"
sleep $DELAY

echo ""
echo "🔍 [10/27] MockERC20 - USDe..."
forge verify-contract 0xD1128A83531aBFc9A96337d8B96d21fD39c7d864 \
  src/mocks/MockERC20.sol:MockERC20 \
  --constructor-args $(cast abi-encode "constructor(string,string,uint256)" "Mock USDe" "USDe" "100000000000000000000000000") \
  --chain base-sepolia --etherscan-api-key $BASESCAN_API_KEY \
  --compiler-version 0.8.29 --optimizer-runs 20 --via-ir --evm-version cancun || echo "⚠️  Already verified"
sleep $DELAY

echo ""
echo "🔍 [11/27] MockWETH..."
forge verify-contract 0x38389462847C9961338118cb3E07E2336bFA3AC4 \
  src/mocks/MockWETH.sol:MockWETH \
  --chain base-sepolia --etherscan-api-key $BASESCAN_API_KEY \
  --compiler-version 0.8.29 --optimizer-runs 20 --via-ir --evm-version cancun || echo "⚠️  Already verified"
sleep $DELAY

# ========================================
# 3. PRICE ORACLES (9 contracts)
# ========================================

echo ""
echo "========================================"
echo "STEP 3/5: PRICE ORACLES (9 contracts)"
echo "========================================"
echo ""

echo "🔍 [12/27] Oracle - USDC/USD..."
forge verify-contract 0x9Ffcf454b62cC4F9d4600CB338A90ea0C59E56c1 \
  src/mocks/MockPriceOracle.sol:MockPriceOracle \
  --constructor-args $(cast abi-encode "constructor(int256,string)" "100000000" "USDC / USD") \
  --chain base-sepolia --etherscan-api-key $BASESCAN_API_KEY \
  --compiler-version 0.8.29 --optimizer-runs 20 --via-ir --evm-version cancun || echo "⚠️  Already verified"
sleep $DELAY

echo ""
echo "🔍 [13/27] Oracle - WETH/USD..."
forge verify-contract 0x0eBEf942a9a0AC8575D7dD1c0072D14429705118 \
  src/mocks/MockPriceOracle.sol:MockPriceOracle \
  --constructor-args $(cast abi-encode "constructor(int256,string)" "350000000000" "WETH / USD") \
  --chain base-sepolia --etherscan-api-key $BASESCAN_API_KEY \
  --compiler-version 0.8.29 --optimizer-runs 20 --via-ir --evm-version cancun || echo "⚠️  Already verified"
sleep $DELAY

echo ""
echo "🔍 [14/27] Oracle - WBTC/USD..."
forge verify-contract 0x67BD0F6Fd1466DaED69F932Ac51697eA65880805 \
  src/mocks/MockPriceOracle.sol:MockPriceOracle \
  --constructor-args $(cast abi-encode "constructor(int256,string)" "9500000000000" "WBTC / USD") \
  --chain base-sepolia --etherscan-api-key $BASESCAN_API_KEY \
  --compiler-version 0.8.29 --optimizer-runs 20 --via-ir --evm-version cancun || echo "⚠️  Already verified"
sleep $DELAY

echo ""
echo "🔍 [15/27] Oracle - PT-sUSDe/USD..."
forge verify-contract 0xb74f4bc6801cca34C9a3dF4A1D6C937a910ddEc3 \
  src/mocks/MockPriceOracle.sol:MockPriceOracle \
  --constructor-args $(cast abi-encode "constructor(int256,string)" "112500000" "PT-sUSDe-31JUL2025 / USD") \
  --chain base-sepolia --etherscan-api-key $BASESCAN_API_KEY \
  --compiler-version 0.8.29 --optimizer-runs 20 --via-ir --evm-version cancun || echo "⚠️  Already verified"
sleep $DELAY

echo ""
echo "🔍 [16/27] Oracle - JPY/USD..."
forge verify-contract 0xE13dA0d002829D35834540e3BC2AF7519FB29352 \
  src/mocks/MockPriceOracle.sol:MockPriceOracle \
  --constructor-args $(cast abi-encode "constructor(int256,string)" "670000" "JPY / USD") \
  --chain base-sepolia --etherscan-api-key $BASESCAN_API_KEY \
  --compiler-version 0.8.29 --optimizer-runs 20 --via-ir --evm-version cancun || echo "⚠️  Already verified"
sleep $DELAY

echo ""
echo "🔍 [17/27] Oracle - KRW/USD..."
forge verify-contract 0x0eb3AbEEE28ee22371F044569c6a0801fF50225e \
  src/mocks/MockPriceOracle.sol:MockPriceOracle \
  --constructor-args $(cast abi-encode "constructor(int256,string)" "70000" "KRW / USD") \
  --chain base-sepolia --etherscan-api-key $BASESCAN_API_KEY \
  --compiler-version 0.8.29 --optimizer-runs 20 --via-ir --evm-version cancun || echo "⚠️  Already verified"
sleep $DELAY

echo ""
echo "🔍 [18/27] Oracle - XAU/USD..."
forge verify-contract 0x74D912FFb044a7AD279ba9CA82c01fE93dB5893c \
  src/mocks/MockPriceOracle.sol:MockPriceOracle \
  --constructor-args $(cast abi-encode "constructor(int256,string)" "285000000000" "XAU / USD") \
  --chain base-sepolia --etherscan-api-key $BASESCAN_API_KEY \
  --compiler-version 0.8.29 --optimizer-runs 20 --via-ir --evm-version cancun || echo "⚠️  Already verified"
sleep $DELAY

echo ""
echo "🔍 [19/27] Oracle - NVDA/USD..."
forge verify-contract 0xFC01D56344395e6E796dB43495A28d2eE250e65E \
  src/mocks/MockPriceOracle.sol:MockPriceOracle \
  --constructor-args $(cast abi-encode "constructor(int256,string)" "13000000000" "NVDA / USD") \
  --chain base-sepolia --etherscan-api-key $BASESCAN_API_KEY \
  --compiler-version 0.8.29 --optimizer-runs 20 --via-ir --evm-version cancun || echo "⚠️  Already verified"
sleep $DELAY

echo ""
echo "🔍 [20/27] Oracle - TSLA/USD..."
forge verify-contract 0x34942f72E7e5529079b135EE03DDE76cB322b7D5 \
  src/mocks/MockPriceOracle.sol:MockPriceOracle \
  --constructor-args $(cast abi-encode "constructor(int256,string)" "26500000000" "TSLA / USD") \
  --chain base-sepolia --etherscan-api-key $BASESCAN_API_KEY \
  --compiler-version 0.8.29 --optimizer-runs 20 --via-ir --evm-version cancun || echo "⚠️  Already verified"
sleep $DELAY

# ========================================
# 4. CCIP BRIDGE (1 contract)
# ========================================

echo ""
echo "========================================"
echo "STEP 4/5: CCIP BRIDGE (1 contract)"
echo "========================================"
echo ""

echo "🔍 [21/27] YoloCCIPBridge..."
forge verify-contract 0x0aCfee9DdE44B42b8E28d857a99723Ff2803954F \
  src/cross-chain/YoloCCIPBridge.sol:YoloCCIPBridge \
  --constructor-args $(cast abi-encode "constructor(address,address,uint64)" "0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93" "0x81B9808a8470236462A84457ebe047eE5874bFfF" "10344971235874465080") \
  --chain base-sepolia --etherscan-api-key $BASESCAN_API_KEY \
  --compiler-version 0.8.29 --optimizer-runs 20 --via-ir --evm-version cancun || echo "⚠️  Already verified"
sleep $DELAY

# ========================================
# 5. SYNTHETIC ASSETS (6 contracts)
# ========================================

echo ""
echo "========================================"
echo "STEP 5/5: SYNTHETIC ASSETS (6 contracts)"
echo "========================================"
echo ""

echo "🔍 [22/27] USY..."
forge verify-contract 0x5FF62705aA2F6dEAe0F8f3a771298440124A9988 \
  src/tokenization/YoloSyntheticAsset.sol:YoloSyntheticAsset \
  --constructor-args $(cast abi-encode "constructor(string,string,uint8,address)" "YOLO USD" "USY" "18" "0x81B9808a8470236462A84457ebe047eE5874bFfF") \
  --chain base-sepolia --etherscan-api-key $BASESCAN_API_KEY \
  --compiler-version 0.8.29 --optimizer-runs 20 --via-ir --evm-version cancun || echo "⚠️  Already verified"
sleep $DELAY

echo ""
echo "🔍 [23/27] yJPY..."
forge verify-contract 0x67Bb3cc52448866CD7743efF45823f30d344b1D6 \
  src/tokenization/YoloSyntheticAsset.sol:YoloSyntheticAsset \
  --constructor-args $(cast abi-encode "constructor(string,string,uint8,address)" "Yolo Japanese Yen" "yJPY" "18" "0x81B9808a8470236462A84457ebe047eE5874bFfF") \
  --chain base-sepolia --etherscan-api-key $BASESCAN_API_KEY \
  --compiler-version 0.8.29 --optimizer-runs 20 --via-ir --evm-version cancun || echo "⚠️  Already verified"
sleep $DELAY

echo ""
echo "🔍 [24/27] yKRW..."
forge verify-contract 0x0dbe9B2A4A428d514e6D45817Ec05E5738b89530 \
  src/tokenization/YoloSyntheticAsset.sol:YoloSyntheticAsset \
  --constructor-args $(cast abi-encode "constructor(string,string,uint8,address)" "Yolo Korean Won" "yKRW" "18" "0x81B9808a8470236462A84457ebe047eE5874bFfF") \
  --chain base-sepolia --etherscan-api-key $BASESCAN_API_KEY \
  --compiler-version 0.8.29 --optimizer-runs 20 --via-ir --evm-version cancun || echo "⚠️  Already verified"
sleep $DELAY

echo ""
echo "🔍 [25/27] yXAU..."
forge verify-contract 0x1091392b50De97065c829d749cad8B6e2f129dc3 \
  src/tokenization/YoloSyntheticAsset.sol:YoloSyntheticAsset \
  --constructor-args $(cast abi-encode "constructor(string,string,uint8,address)" "Yolo Gold" "yXAU" "18" "0x81B9808a8470236462A84457ebe047eE5874bFfF") \
  --chain base-sepolia --etherscan-api-key $BASESCAN_API_KEY \
  --compiler-version 0.8.29 --optimizer-runs 20 --via-ir --evm-version cancun || echo "⚠️  Already verified"
sleep $DELAY

echo ""
echo "🔍 [26/27] yNVDA..."
forge verify-contract 0xaf1034de923559E1AF90B67ac9c4f84A4EcEff1a \
  src/tokenization/YoloSyntheticAsset.sol:YoloSyntheticAsset \
  --constructor-args $(cast abi-encode "constructor(string,string,uint8,address)" "Yolo NVIDIA" "yNVDA" "18" "0x81B9808a8470236462A84457ebe047eE5874bFfF") \
  --chain base-sepolia --etherscan-api-key $BASESCAN_API_KEY \
  --compiler-version 0.8.29 --optimizer-runs 20 --via-ir --evm-version cancun || echo "⚠️  Already verified"
sleep $DELAY

echo ""
echo "🔍 [27/27] yTSLA..."
forge verify-contract 0xd74688447440407e926A98e9311Bde7190a7B437 \
  src/tokenization/YoloSyntheticAsset.sol:YoloSyntheticAsset \
  --constructor-args $(cast abi-encode "constructor(string,string,uint8,address)" "Yolo Tesla" "yTSLA" "18" "0x81B9808a8470236462A84457ebe047eE5874bFfF") \
  --chain base-sepolia --etherscan-api-key $BASESCAN_API_KEY \
  --compiler-version 0.8.29 --optimizer-runs 20 --via-ir --evm-version cancun || echo "⚠️  Already verified"

echo ""
echo "=================================================="
echo "  ✅ VERIFICATION COMPLETE!"
echo "=================================================="
echo ""
echo "📊 Total: 27 contracts"
echo "  • 4 Core Protocol Contracts"
echo "  • 7 Mock Token Contracts"
echo "  • 9 Mock Oracle Contracts"
echo "  • 1 CCIP Bridge Contract"
echo "  • 6 Synthetic Asset Contracts"
echo ""
echo "🔗 View on Basescan:"
echo "  https://sepolia.basescan.org/address/0x81B9808a8470236462A84457ebe047eE5874bFfF"
echo ""
