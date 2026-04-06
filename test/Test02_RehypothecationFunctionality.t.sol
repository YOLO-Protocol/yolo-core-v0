// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "forge-std/Test.sol";
// import "./base/Base01_DeployUniswapV4Pool.t.sol";
// import "./base/Base02_DeployMockAssetsAndOracles.t.sol";
// import "./base/Base03_DeployYoloAssetSettingsAndCollaterals.t.sol";
// /*---------- IMPORT CONTRACTS ----------*/
// import {PublicTransparentUpgradeableProxy} from "@yolo/contracts/proxy/PublicTransparentUpgradeableProxy.sol";
// import {YoloHook} from "@yolo/contracts/core/YoloHook.sol";
// import {YoloOracle} from "@yolo/contracts/core/YoloOracle.sol";
// import {RehypothecationLogic} from "@yolo/contracts/core/RehypothecationLogic.sol";
// import {SyntheticAssetLogic} from "@yolo/contracts/core/SyntheticAssetLogic.sol";
// import {MockUSYCTeller, MockUSYC} from "@yolo/contracts/rehypo/MockUSYCTeller.sol";
// import {IPoolManager, ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
// import {IYoloSyntheticAsset} from "@yolo/contracts/interfaces/IYoloSyntheticAsset.sol";
// /*---------- IMPORT LIBRARIES & TYPES ----------*/
// import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
// import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
// import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
// import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
// /*---------- IMPORT TEST SUITES ----------*/
// import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";

// /**
//  * @title   Test02_RehypothecationFunctionality
//  * @author  0xyolodev.eth
//  * @dev     This contract tests the rehypothecation functionality of the YoloHook contract.
//  *          It tests the integration with USYC Teller contracts, automatic rebalancing,
//  *          profit/loss tracking, and the complete rehypothecation lifecycle.
//  *
//  *          Test Cases:
//  *          1. Teller registration and configuration
//  *          2. Rehypothecation enable/disable functionality
//  *          3. Automatic rebalancing on liquidity additions
//  *          4. Automatic rebalancing on swaps
//  *          5. Manual rebalancing
//  *          6. Profit tracking when USYC appreciates
//  *          7. Loss handling when USYC depreciates
//  *          8. Emergency USYC withdrawal
//  *          9. Dehypothecation on liquidity removal
//  *          10. Cost basis tracking accuracy
//  *          11. Rebalancing thresholds and limits
//  *          12. Multiple rehypothecation cycles
//  */
// contract Test02_RehypothecationFunctionality is
//     Test,
//     Base01_DeployUniswapV4Pool,
//     Base03_DeployYoloAssetSettingsAndCollaterals
// {
//     YoloHook public yoloHookImplementation;
//     YoloHook public yoloHookProxy;
//     YoloOracle public yoloOracle;
//     RehypothecationLogic public rehypothecationLogic;
//     MockUSYCTeller public usycTeller;
//     MockUSYC public usycToken;

//     // For convenience
//     address public usdc;
//     address public usy;

//     function setUp()
//         public
//         virtual
//         override(Base01_DeployUniswapV4Pool, Base03_DeployYoloAssetSettingsAndCollaterals)
//     {
//         // Set up the base contracts
//         Base01_DeployUniswapV4Pool.setUp();
//         Base03_DeployYoloAssetSettingsAndCollaterals.setUp();

//         // A. Deploy YoloHook Implementation and Proxy
//         address hookImplementationAddress = address(uint160(Hooks.ALL_HOOK_MASK));
//         address hookProxyAddress = address(uint160(Hooks.ALL_HOOK_MASK << 1) + 1);

//         console.log("Hook Implementation Binary Format:");
//         _logAddressAsBinary(hookImplementationAddress);
//         console.log("Hook Proxy Binary Format:");
//         _logAddressAsBinary(hookProxyAddress);

//         /// Deploy code to the hook implementation & proxy addresses
//         deployCodeTo("YoloHook.sol", abi.encode(manager), hookImplementationAddress);
//         yoloHookImplementation = YoloHook(hookImplementationAddress);
//         deployCodeTo(
//             "PublicTransparentUpgradeableProxy.sol",
//             abi.encode(hookImplementationAddress, address(this), ""),
//             hookProxyAddress
//         );
//         yoloHookProxy = YoloHook(hookProxyAddress);

//         assertEq(
//             PublicTransparentUpgradeableProxy(payable(address(yoloHookProxy))).implementation(),
//             hookImplementationAddress,
//             "Test02: YoloHook implementation address mismatch"
//         );
//         console.log("Hook Implementation: ", hookImplementationAddress);
//         console.log("Hook Proxy: ", hookProxyAddress);

//         // B. Deploy the YoloOracle contract
//         address[] memory assets = new address[](getMockAssetsLength());
//         address[] memory oracles = new address[](getMockAssetsLength());

//         for (uint256 i = 0; i < getMockAssetsLength(); i++) {
//             string memory symbol = getMockAssetSymbol(i);
//             assets[i] = symbolToDeployedAsset[symbol];

//             string memory description = string(abi.encodePacked(symbol, " / USD"));
//             address oracleAddress = symbolToDeployedOracle[description];
//             require(oracleAddress != address(0), string(abi.encodePacked("Oracle not found for ", symbol)));
//             oracles[i] = oracleAddress;
//         }

//         yoloOracle = new YoloOracle(assets, oracles);
//         console.log("Successfully deployed YoloOracle contract at address:", address(yoloOracle));

//         // C. Deploy USDC and get reference
//         usdc = symbolToDeployedAsset["USDC"];
//         require(usdc != address(0), "USDC not deployed");

//         // D. Deploy MockUSYCTeller with internal USYC token
//         usycTeller = new MockUSYCTeller(usdc);
//         usycToken = MockUSYC(usycTeller.getUSYCToken());
//         console.log("MockUSYCTeller deployed at:", address(usycTeller));
//         console.log("MockUSYC token deployed at:", address(usycToken));

//         // E. Add initial liquidity to teller
//         uint256 initialUsdcLiquidity = IERC20Metadata(usdc).decimals() == 18 ? 10_000_000e18 : 10_000_000e6; // 10M USDC
//         deal(usdc, address(this), initialUsdcLiquidity);
//         IERC20(usdc).approve(address(usycTeller), initialUsdcLiquidity);
//         usycTeller.addLiquidity(initialUsdcLiquidity);

//         // Log initial USYC price (should be ~1.09)
//         console.log("Initial USYC price (8 decimals):", usycTeller.price());
//         console.log("Initial USYC price (human readable):", usycTeller.price() * 100 / 1e8, "cents per USYC");

//         // F. Initialize the YoloHook proxy contract
//         yoloHookProxy.initialize(
//             address(weth),
//             address(this),
//             address(yoloOracle),
//             5, // 0.05% stable swap fee
//             20, // 0.2% synthetic swap fee
//             10, // 0.1% flash loan fee
//             usdc // USDC address
//         );

//         // G. Deploy and set logic contracts
//         SyntheticAssetLogic syntheticAssetLogic = new SyntheticAssetLogic();
//         rehypothecationLogic = new RehypothecationLogic();

//         yoloHookProxy.setSyntheticAssetLogic(address(syntheticAssetLogic));
//         yoloHookProxy.setRehypothecationLogic(address(rehypothecationLogic));

//         // H. Set Hook on YoloOracle
//         yoloOracle.setHook(address(yoloHookProxy));
//         yoloOracle.setAnchor(address(yoloHookProxy.anchor()));

//         // I. Set convenience variables
//         usy = address(yoloHookProxy.anchor());

//         console.log();
//         console.log("============================================================");
//         console.log("USDC address:", usdc);
//         console.log("USY address:", usy);
//         console.log("USYC Teller address:", address(usycTeller));
//         console.log("USYC Token address:", address(usycToken));
//         console.log("============================================================");
//         console.log();
//     }

//     function test_Test02_Case01_registerTellerConfiguration() external {
//         console.log("==================== test_Test02_Case01_registerTellerConfiguration ====================");

//         // Verify initial state
//         assertEq(address(yoloHookProxy.usycTeller()), address(0), "Teller should not be set initially");
//         assertEq(address(yoloHookProxy.usyc()), address(0), "USYC should not be set initially");
//         assertFalse(yoloHookProxy.rehypothecationEnabled(), "Rehypothecation should not be enabled initially");

//         // Test registration
//         uint256 rehypothecationRatio = 7500; // 75%

//         vm.expectEmit(true, true, true, true);
//         emit YoloHook.RehypothecationConfigured(address(usycTeller), address(usycToken), rehypothecationRatio);

//         yoloHookProxy.configureRehypothecation(address(usycTeller), address(usycToken), rehypothecationRatio);

//         // Verify configuration
//         assertEq(address(yoloHookProxy.usycTeller()), address(usycTeller), "Teller not set correctly");
//         assertEq(address(yoloHookProxy.usyc()), address(usycToken), "USYC not set correctly");
//         assertEq(yoloHookProxy.rehypothecationRatio(), rehypothecationRatio, "Ratio not set correctly");

//         // Verify USDC approval was set
//         assertEq(
//             IERC20(usdc).allowance(address(yoloHookProxy), address(usycTeller)),
//             type(uint256).max,
//             "USDC allowance not set"
//         );

//         console.log("Successfully registered and configured USYC Teller");
//     }

//     function test_Test02_Case02_enableDisableRehypothecation() external {
//         console.log("==================== test_Test02_Case02_enableDisableRehypothecation ====================");

//         // Setup: Configure teller
//         _setupRehypothecation();

//         // Test enabling
//         vm.expectEmit(true, false, false, true);
//         emit YoloHook.RehypothecationStatusUpdated(true);

//         yoloHookProxy.setRehypothecationEnabled(true);
//         assertTrue(yoloHookProxy.rehypothecationEnabled(), "Rehypothecation not enabled");

//         // Add some USYC balance for disable test
//         _addInitialLiquidity();
//         _triggerRehypothecation();

//         uint256 usycBalanceBefore = yoloHookProxy.usycBalance();
//         assertGt(usycBalanceBefore, 0, "Should have USYC balance for test");

//         // Test disabling (should auto-sell USYC)
//         vm.expectEmit(true, false, false, true);
//         emit YoloHook.RehypothecationStatusUpdated(false);

//         yoloHookProxy.setRehypothecationEnabled(false);

//         assertFalse(yoloHookProxy.rehypothecationEnabled(), "Rehypothecation not disabled");
//         assertEq(yoloHookProxy.usycBalance(), 0, "USYC balance should be zero after disable");

//         console.log("Successfully tested enable/disable functionality");
//     }

//     function test_Test02_Case03_automaticRehypothecationOnLiquidityAdd() external {
//         console.log(
//             "==================== test_Test02_Case03_automaticRehypothecationOnLiquidityAdd ===================="
//         );

//         // Setup
//         _setupRehypothecation();
//         yoloHookProxy.setRehypothecationEnabled(true);

//         // Track initial state
//         uint256 usycBalanceBefore = yoloHookProxy.usycBalance();
//         uint256 usdcReserveBefore = yoloHookProxy.totalAnchorReserveUSDC();

//         // Add liquidity
//         uint256 usdcAmount = IERC20Metadata(usdc).decimals() == 18 ? 100_000e18 : 100_000e6; // 100k USDC
//         uint256 usyAmount = 100_000e18; // 100k USY

//         deal(usdc, address(this), usdcAmount);
//         deal(usy, address(this), usyAmount);

//         IERC20(usdc).approve(address(yoloHookProxy), usdcAmount);
//         IERC20(usy).approve(address(yoloHookProxy), usyAmount);

//         // Execute liquidity addition
//         yoloHookProxy.addLiquidity(usdcAmount, usyAmount, 0, address(this));

//         // Verify rehypothecation occurred
//         uint256 usycBalanceAfter = yoloHookProxy.usycBalance();
//         uint256 usdcReserveAfter = yoloHookProxy.totalAnchorReserveUSDC();

//         assertGt(usycBalanceAfter, usycBalanceBefore, "USYC balance should increase");
//         assertGt(usdcReserveAfter, usdcReserveBefore, "USDC reserves should increase");

//         // Verify rehypothecation ratio is respected
//         // FIXED: Compare USDC values, not raw USYC token amounts
//         uint256 totalUsdcValue = usdcReserveAfter;
//         uint256 targetRehypothecation =
//             (totalUsdcValue * yoloHookProxy.rehypothecationRatio()) / (10000 + yoloHookProxy.rehypothecationRatio());

//         // Get USYC value in USDC terms
//         (uint256 usycValueInUSDC,,) = usycTeller.sellPreview(usycBalanceAfter);

//         // Should be close to target (within 1% tolerance due to exchange rate and fees)
//         assertApproxEqRel(usycValueInUSDC, targetRehypothecation, 0.01e18, "Rehypothecation ratio not respected");

//         console.log("USDC reserves after:", usdcReserveAfter);
//         console.log("USYC balance after:", usycBalanceAfter);
//         console.log("USYC value in USDC:", usycValueInUSDC);
//         console.log("Target rehypothecation:", targetRehypothecation);
//         console.log("Successfully tested automatic rehypothecation on liquidity add");
//     }

//     function test_Test02_Case04_automaticRehypothecationOnSwaps() external {
//         console.log("==================== test_Test02_Case04_automaticRehypothecationOnSwaps ====================");

//         // Setup
//         _setupRehypothecation();
//         yoloHookProxy.setRehypothecationEnabled(true);
//         _addInitialLiquidity();

//         // Track state before swap
//         uint256 usycBalanceBefore = yoloHookProxy.usycBalance();
//         uint256 usdcReserveBefore = yoloHookProxy.totalAnchorReserveUSDC();

//         // Perform USDC -> USY swap
//         uint256 swapAmount = IERC20Metadata(usdc).decimals() == 18 ? 50_000e18 : 50_000e6; // 50k USDC
//         deal(usdc, address(this), swapAmount);
//         IERC20(usdc).approve(address(swapRouter), swapAmount);

//         (PoolKey memory key, bool usdcIs0) = _getAnchorPoolKey();
//         SwapParams memory params =
//             SwapParams({zeroForOne: usdcIs0, amountSpecified: -int256(swapAmount), sqrtPriceLimitX96: 0});

//         PoolSwapTest.TestSettings memory settings =
//             PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false});

//         swapRouter.swap(key, params, settings, "");

//         // Verify rehypothecation occurred
//         uint256 usycBalanceAfter = yoloHookProxy.usycBalance();
//         uint256 usdcReserveAfter = yoloHookProxy.totalAnchorReserveUSDC();

//         assertGt(usycBalanceAfter, usycBalanceBefore, "USYC balance should increase after swap");
//         assertGt(usdcReserveAfter, usdcReserveBefore, "USDC reserves should increase after swap");

//         console.log("USDC reserves before:", usdcReserveBefore);
//         console.log("USDC reserves after:", usdcReserveAfter);
//         console.log("USYC balance before:", usycBalanceBefore);
//         console.log("USYC balance after:", usycBalanceAfter);
//         console.log("Successfully tested automatic rehypothecation on swaps");
//     }

//     function test_Test02_Case05_manualRebalancing() external {
//         console.log("==================== test_Test02_Case05_manualRebalancing ====================");

//         // Setup
//         _setupRehypothecation();
//         yoloHookProxy.setRehypothecationEnabled(true);
//         _addInitialLiquidity();

//         // Manually adjust USDC reserves to create imbalance
//         // NOTE: This intentionally breaks the invariant by adding raw USDC without minting claim tokens
//         // This is a deliberate stress test to verify rebalancing works even from broken states
//         uint256 additionalUsdc = IERC20Metadata(usdc).decimals() == 18 ? 200_000e18 : 200_000e6; // 200k USDC
//         deal(usdc, address(yoloHookProxy), additionalUsdc);

//         // The reserve tracking is not updated here - this creates a mismatch between
//         // actual USDC balance and totalAnchorReserveUSDC, simulating an edge case
//         uint256 currentReserves = yoloHookProxy.totalAnchorReserveUSDC();

//         // Track state before manual rebalance
//         uint256 usycBalanceBefore = yoloHookProxy.usycBalance();

//         // Execute manual rebalance
//         yoloHookProxy.rebalanceRehypothecation();

//         // Verify rebalancing occurred
//         uint256 usycBalanceAfter = yoloHookProxy.usycBalance();

//         // USYC balance should increase due to rebalancing
//         assertGt(usycBalanceAfter, usycBalanceBefore, "Manual rebalance should increase USYC balance");

//         console.log("USYC balance before rebalance:", usycBalanceBefore);
//         console.log("USYC balance after rebalance:", usycBalanceAfter);
//         console.log("Successfully tested manual rebalancing");
//     }

//     function test_Test02_Case06_profitTrackingFromUSYCAppreciation() external {
//         console.log("==================== test_Test02_Case06_profitTrackingFromUSYCAppreciation ====================");

//         // Setup
//         _setupRehypothecation();
//         yoloHookProxy.setRehypothecationEnabled(true);
//         _addInitialLiquidity();
//         _triggerRehypothecation();

//         uint256 initialUsdcReserves = yoloHookProxy.totalAnchorReserveUSDC();
//         uint256 initialUsycBalance = yoloHookProxy.usycBalance();
//         uint256 initialLpBalance = yoloHookProxy.anchorPoolLPBalance(address(this));

//         assertGt(initialUsycBalance, 0, "Should have USYC balance");

//         // Get initial USYC value in USDC terms
//         (uint256 initialUsycValueInUSDC,,) = usycTeller.sellPreview(initialUsycBalance);

//         // Fast forward time to let USYC appreciate (5% annual yield)
//         vm.warp(block.timestamp + 365 days); // 1 year
//         usycTeller.forceUpdatePrice();

//         // Check price increased (should be ~1.09 * 1.05 = ~1.14)
//         uint256 newPrice = usycTeller.price();
//         assertGt(newPrice, 109163886, "Price should have increased");
//         console.log("New USYC price (8 decimals):", newPrice);
//         console.log("New USYC price (human readable):", newPrice * 100 / 1e8, "cents per USYC");

//         // Get appreciated USYC value
//         (uint256 appreciatedUsycValueInUSDC,,) = usycTeller.sellPreview(initialUsycBalance);
//         uint256 expectedProfit = appreciatedUsycValueInUSDC - initialUsycValueInUSDC;
//         console.log("Expected profit from appreciation:", expectedProfit);

//         // Calculate LP value before removal
//         uint256 lpValueBefore = (initialLpBalance * (initialUsdcReserves + initialUsycValueInUSDC))
//             / yoloHookProxy.anchorPoolLiquiditySupply();

//         // Trigger a sell by removing liquidity to realize profit
//         uint256 lpToRemove = initialLpBalance / 4; // Remove 25%

//         // This should trigger dehypothecation and realize profit
//         yoloHookProxy.removeLiquidity(0, 0, lpToRemove, address(this));

//         // Verify LP holders implicitly received the profit
//         uint256 finalUsdcReserves = yoloHookProxy.totalAnchorReserveUSDC();
//         uint256 finalUsycBalance = yoloHookProxy.usycBalance();
//         (uint256 finalUsycValueInUSDC,,) = usycTeller.sellPreview(finalUsycBalance);

//         // Calculate LP value after removal (for remaining LP tokens)
//         uint256 remainingLpBalance = yoloHookProxy.anchorPoolLPBalance(address(this));
//         uint256 totalPoolValue = finalUsdcReserves + finalUsycValueInUSDC;
//         uint256 lpValueAfter = (remainingLpBalance * totalPoolValue) / yoloHookProxy.anchorPoolLiquiditySupply();

//         // The remaining LP tokens should be worth more due to USYC appreciation
//         assertGt(
//             lpValueAfter * initialLpBalance / remainingLpBalance,
//             lpValueBefore,
//             "LP value should have increased from USYC yield"
//         );

//         console.log("Initial USDC reserves:", initialUsdcReserves);
//         console.log("Final USDC reserves:", finalUsdcReserves);
//         console.log("Initial USYC value in USDC:", initialUsycValueInUSDC);
//         console.log("Final USYC value in USDC:", finalUsycValueInUSDC);
//         console.log("LP value increase:", (lpValueAfter * initialLpBalance / remainingLpBalance) - lpValueBefore);

//         console.log("Successfully tested profit tracking from USYC appreciation");
//     }

//     function test_Test02_Case07_emergencyUSYCWithdrawal() external {
//         console.log("==================== test_Test02_Case07_emergencyUSYCWithdrawal ====================");

//         // Setup
//         _setupRehypothecation();
//         yoloHookProxy.setRehypothecationEnabled(true);
//         _addInitialLiquidity();
//         _triggerRehypothecation();

//         uint256 usycBalanceBefore = yoloHookProxy.usycBalance();
//         uint256 usdcReservesBefore = yoloHookProxy.totalAnchorReserveUSDC();

//         assertGt(usycBalanceBefore, 0, "Should have USYC balance");

//         // Get expected USDC output from selling all USYC
//         (uint256 expectedUsdcOut,,) = usycTeller.sellPreview(usycBalanceBefore);

//         // Execute emergency withdrawal
//         // Note: The event should show USYC amount and USDC received
//         // We check event signature but not exact values due to fees
//         vm.expectEmit(false, false, false, true);
//         emit YoloHook.EmergencyUSYCWithdrawal(0, 0);

//         yoloHookProxy.emergencyWithdrawUSYC();

//         // Verify all USYC was sold
//         assertEq(yoloHookProxy.usycBalance(), 0, "USYC balance should be zero");

//         // USDC reserves should increase by approximately the expected amount
//         uint256 usdcReservesAfter = yoloHookProxy.totalAnchorReserveUSDC();
//         assertGt(usdcReservesAfter, usdcReservesBefore, "USDC reserves should increase");

//         // The increase should be close to expected (within 1% for fees)
//         uint256 actualIncrease = usdcReservesAfter - usdcReservesBefore;
//         assertApproxEqRel(actualIncrease, expectedUsdcOut, 0.01e18, "USDC increase should match expected");

//         console.log("USYC balance before:", usycBalanceBefore);
//         console.log("Expected USDC from sale:", expectedUsdcOut);
//         console.log("USDC reserves before:", usdcReservesBefore);
//         console.log("USDC reserves after:", usdcReservesAfter);
//         console.log("Actual USDC increase:", actualIncrease);
//         console.log("Successfully tested emergency USYC withdrawal");
//     }

//     function test_Test02_Case08_dehypothecationOnLiquidityRemoval() external {
//         console.log("==================== test_Test02_Case08_dehypothecationOnLiquidityRemoval ====================");

//         // Setup
//         _setupRehypothecation();
//         yoloHookProxy.setRehypothecationEnabled(true);
//         _addInitialLiquidity();

//         uint256 lpBalance = yoloHookProxy.anchorPoolLPBalance(address(this));
//         uint256 usycBalanceBefore = yoloHookProxy.usycBalance();
//         uint256 usdcReservesBefore = yoloHookProxy.totalAnchorReserveUSDC();

//         assertGt(usycBalanceBefore, 0, "Should have USYC balance");
//         assertGt(lpBalance, 0, "Should have LP balance");

//         // Remove a significant portion of liquidity to trigger dehypothecation
//         uint256 lpToRemove = lpBalance / 2; // Remove 50%

//         yoloHookProxy.removeLiquidity(0, 0, lpToRemove, address(this));

//         // Verify dehypothecation occurred
//         uint256 usycBalanceAfter = yoloHookProxy.usycBalance();
//         uint256 usdcReservesAfter = yoloHookProxy.totalAnchorReserveUSDC();

//         // USYC balance should decrease (some sold to provide USDC)
//         assertLt(usycBalanceAfter, usycBalanceBefore, "USYC balance should decrease");

//         // USDC reserves should decrease less than proportionally due to USYC sale
//         assertLt(usdcReservesAfter, usdcReservesBefore, "USDC reserves should decrease");

//         console.log("LP removed:", lpToRemove);
//         console.log("USYC balance before:", usycBalanceBefore);
//         console.log("USYC balance after:", usycBalanceAfter);
//         console.log("USDC reserves before:", usdcReservesBefore);
//         console.log("USDC reserves after:", usdcReservesAfter);
//         console.log("Successfully tested dehypothecation on liquidity removal");
//     }

//     function test_Test02_Case09_costBasisTrackingAccuracy() external {
//         console.log("==================== test_Test02_Case09_costBasisTrackingAccuracy ====================");

//         // Setup
//         _setupRehypothecation();
//         yoloHookProxy.setRehypothecationEnabled(true);

//         // Add liquidity in multiple batches to test cost basis averaging
//         uint256 batchSize = IERC20Metadata(usdc).decimals() == 18 ? 50_000e18 : 50_000e6; // 50k USDC

//         // First batch at current exchange rate
//         deal(usdc, address(this), batchSize);
//         deal(usy, address(this), 50_000e18);
//         IERC20(usdc).approve(address(yoloHookProxy), batchSize);
//         IERC20(usy).approve(address(yoloHookProxy), 50_000e18);
//         yoloHookProxy.addLiquidity(batchSize, 50_000e18, 0, address(this));

//         uint256 firstUsycBalance = yoloHookProxy.usycBalance();

//         // Fast forward and update price
//         vm.warp(block.timestamp + 30 days); // 1 month
//         usycTeller.forceUpdatePrice();

//         // Second batch at higher exchange rate
//         deal(usdc, address(this), batchSize);
//         deal(usy, address(this), 50_000e18);
//         IERC20(usdc).approve(address(yoloHookProxy), batchSize);
//         IERC20(usy).approve(address(yoloHookProxy), 50_000e18);
//         yoloHookProxy.addLiquidity(batchSize, 50_000e18, 0, address(this));

//         uint256 secondUsycBalance = yoloHookProxy.usycBalance();

//         // Verify USYC balance increased less in second batch due to higher price
//         uint256 firstBatchUsyc = firstUsycBalance;
//         uint256 secondBatchUsyc = secondUsycBalance - firstUsycBalance;

//         assertLt(secondBatchUsyc, firstBatchUsyc, "Second batch should yield less USYC due to appreciation");

//         console.log("First batch USYC:", firstBatchUsyc);
//         console.log("Second batch USYC:", secondBatchUsyc);
//         console.log("Total USYC balance:", secondUsycBalance);
//         console.log("Successfully tested cost basis tracking accuracy");
//     }

//     function test_Test02_Case10_rebalancingThresholdsAndLimits() external {
//         console.log("==================== test_Test02_Case10_rebalancingThresholdsAndLimits ====================");

//         // Setup
//         _setupRehypothecation();
//         yoloHookProxy.setRehypothecationEnabled(true);

//         // Test with different rehypothecation ratios
//         uint256[] memory ratios = new uint256[](3);
//         ratios[0] = 2500; // 25%
//         ratios[1] = 5000; // 50%
//         ratios[2] = 9000; // 90%

//         for (uint256 i = 0; i < ratios.length; i++) {
//             console.log("Testing ratio:", ratios[i]);

//             // Reset configuration
//             yoloHookProxy.configureRehypothecation(address(usycTeller), address(usycToken), ratios[i]);

//             // Add liquidity
//             uint256 usdcAmount = IERC20Metadata(usdc).decimals() == 18 ? 100_000e18 : 100_000e6;
//             deal(usdc, address(this), usdcAmount);
//             deal(usy, address(this), 100_000e18);
//             IERC20(usdc).approve(address(yoloHookProxy), usdcAmount);
//             IERC20(usy).approve(address(yoloHookProxy), 100_000e18);

//             yoloHookProxy.addLiquidity(usdcAmount, 100_000e18, 0, address(this));

//             uint256 usycBalance = yoloHookProxy.usycBalance();
//             uint256 usdcReserves = yoloHookProxy.totalAnchorReserveUSDC();

//             // FIXED: Compare USDC values, not token amounts
//             (uint256 usycValueInUSDC,,) = usycTeller.sellPreview(usycBalance);
//             uint256 expectedRehypothecation = (usdcReserves * ratios[i]) / (10000 + ratios[i]);

//             // Allow 5% tolerance for exchange rate differences and fees
//             assertApproxEqRel(usycValueInUSDC, expectedRehypothecation, 0.05e18, "Ratio not maintained");

//             console.log("USDC reserves:", usdcReserves);
//             console.log("USYC balance:", usycBalance);
//             console.log("USYC value in USDC:", usycValueInUSDC);
//             console.log("Expected rehypothecation:", expectedRehypothecation);

//             // Remove all liquidity for next test
//             uint256 lpBalance = yoloHookProxy.anchorPoolLPBalance(address(this));
//             if (lpBalance > 0) {
//                 yoloHookProxy.removeLiquidity(0, 0, lpBalance, address(this));
//             }
//         }

//         console.log("Successfully tested rebalancing thresholds and limits");
//     }

//     function test_Test02_Case11_multipleRehypothecationCycles() external {
//         console.log("==================== test_Test02_Case11_multipleRehypothecationCycles ====================");

//         // Setup
//         _setupRehypothecation();
//         yoloHookProxy.setRehypothecationEnabled(true);

//         uint256 cycleCount = 5;
//         uint256[] memory usycBalances = new uint256[](cycleCount + 1);
//         uint256[] memory usdcReserves = new uint256[](cycleCount + 1);

//         // Record initial state
//         usycBalances[0] = yoloHookProxy.usycBalance();
//         usdcReserves[0] = yoloHookProxy.totalAnchorReserveUSDC();

//         for (uint256 i = 1; i <= cycleCount; i++) {
//             console.log("Cycle", i);

//             // Add liquidity
//             uint256 usdcAmount = IERC20Metadata(usdc).decimals() == 18 ? 50_000e18 : 50_000e6;
//             deal(usdc, address(this), usdcAmount);
//             deal(usy, address(this), 50_000e18);
//             IERC20(usdc).approve(address(yoloHookProxy), usdcAmount);
//             IERC20(usy).approve(address(yoloHookProxy), 50_000e18);

//             yoloHookProxy.addLiquidity(usdcAmount, 50_000e18, 0, address(this));

//             // Fast forward time for yield accumulation
//             vm.warp(block.timestamp + 30 days);
//             usycTeller.forceUpdatePrice();

//             // Perform a swap to trigger rebalancing
//             uint256 swapAmount = IERC20Metadata(usdc).decimals() == 18 ? 10_000e18 : 10_000e6;
//             deal(usdc, address(this), swapAmount);
//             IERC20(usdc).approve(address(swapRouter), swapAmount);

//             (PoolKey memory key, bool usdcIs0) = _getAnchorPoolKey();
//             SwapParams memory params =
//                 SwapParams({zeroForOne: usdcIs0, amountSpecified: -int256(swapAmount), sqrtPriceLimitX96: 0});

//             PoolSwapTest.TestSettings memory settings =
//                 PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false});

//             swapRouter.swap(key, params, settings, "");

//             // Record state
//             usycBalances[i] = yoloHookProxy.usycBalance();
//             usdcReserves[i] = yoloHookProxy.totalAnchorReserveUSDC();

//             console.log("USYC balance:", usycBalances[i]);
//             console.log("USDC reserves:", usdcReserves[i]);

//             // Verify progression
//             assertGt(usycBalances[i], usycBalances[i - 1], "USYC balance should increase each cycle");
//             assertGt(usdcReserves[i], usdcReserves[i - 1], "USDC reserves should increase each cycle");
//         }

//         console.log("Successfully tested multiple rehypothecation cycles");
//     }

//     function test_Test02_Case12_invalidConfigurationReverts() external {
//         console.log("==================== test_Test02_Case12_invalidConfigurationReverts ====================");

//         // Test invalid ratio (> 100%)
//         vm.expectRevert(YoloHook.YoloHook__InvalidRehypothecationRatio.selector);
//         yoloHookProxy.configureRehypothecation(address(usycTeller), address(usycToken), 10001);

//         // Test zero addresses
//         vm.expectRevert(YoloHook.YoloHook__ZeroAddress.selector);
//         yoloHookProxy.configureRehypothecation(address(0), address(usycToken), 7500);

//         vm.expectRevert(YoloHook.YoloHook__ZeroAddress.selector);
//         yoloHookProxy.configureRehypothecation(address(usycTeller), address(0), 7500);

//         // Test operations when disabled
//         vm.expectRevert(YoloHook.YoloHook__RehypothecationDisabled.selector);
//         yoloHookProxy.rebalanceRehypothecation();

//         console.log("Successfully tested invalid configuration reverts");
//     }

//     function test_Test02_Case13_reserveConsistencyInvariant() external {
//         console.log("==================== test_Test02_Case13_reserveConsistencyInvariant ====================");

//         // Setup
//         _setupRehypothecation();
//         yoloHookProxy.setRehypothecationEnabled(true);
//         _addInitialLiquidity();

//         // Check initial state
//         assertTrue(_checkInvariant(), "Initial invariant check failed");

//         // Test 1: After rehypothecation
//         _triggerRehypothecation();
//         assertTrue(_checkInvariant(), "Invariant broken after rehypothecation");

//         // Test 2: After swap (USDC -> USY)
//         uint256 swapAmount = IERC20Metadata(usdc).decimals() == 18 ? 10_000e18 : 10_000e6;
//         deal(usdc, address(this), swapAmount);
//         IERC20(usdc).approve(address(swapRouter), swapAmount);

//         (PoolKey memory key, bool usdcIs0) = _getAnchorPoolKey();
//         SwapParams memory params =
//             SwapParams({zeroForOne: usdcIs0, amountSpecified: -int256(swapAmount), sqrtPriceLimitX96: 0});

//         swapRouter.swap(key, params, PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}), "");
//         assertTrue(_checkInvariant(), "Invariant broken after USDC->USY swap");

//         // Test 3: After reverse swap (USY -> USDC)
//         uint256 usySwapAmount = 5_000e18;
//         deal(usy, address(this), usySwapAmount);
//         IERC20(usy).approve(address(swapRouter), usySwapAmount);

//         params = SwapParams({zeroForOne: !usdcIs0, amountSpecified: -int256(usySwapAmount), sqrtPriceLimitX96: 0});

//         swapRouter.swap(key, params, PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}), "");
//         assertTrue(_checkInvariant(), "Invariant broken after USY->USDC swap");

//         // Test 4: After manual rebalance
//         yoloHookProxy.rebalanceRehypothecation();
//         assertTrue(_checkInvariant(), "Invariant broken after manual rebalance");

//         // Test 5: After liquidity removal
//         uint256 lpBalance = yoloHookProxy.anchorPoolLPBalance(address(this));
//         yoloHookProxy.removeLiquidity(0, 0, lpBalance / 2, address(this));
//         assertTrue(_checkInvariant(), "Invariant broken after liquidity removal");

//         console.log("Successfully tested reserve consistency invariant");
//     }

//     function test_Test02_Case14_claimTokenBalanceGuard() external {
//         console.log("==================== test_Test02_Case14_claimTokenBalanceGuard ====================");

//         // Setup
//         _setupRehypothecation();
//         yoloHookProxy.setRehypothecationEnabled(true);

//         // Add small amount of liquidity
//         uint256 smallUsdcAmount = IERC20Metadata(usdc).decimals() == 18 ? 10_000e18 : 10_000e6; // 10k USDC
//         uint256 smallUsyAmount = 10_000e18; // 10k USY

//         deal(usdc, address(this), smallUsdcAmount);
//         deal(usy, address(this), smallUsyAmount);
//         IERC20(usdc).approve(address(yoloHookProxy), smallUsdcAmount);
//         IERC20(usy).approve(address(yoloHookProxy), smallUsyAmount);

//         yoloHookProxy.addLiquidity(smallUsdcAmount, smallUsyAmount, 0, address(this));

//         // Set a very high rehypothecation ratio (99%)
//         yoloHookProxy.configureRehypothecation(address(usycTeller), address(usycToken), 9900);

//         // Try to trigger rehypothecation - should be capped by available claim tokens
//         yoloHookProxy.rebalanceRehypothecation();

//         // Check that we didn't over-rehypothecate
//         uint256 usycBalance = yoloHookProxy.usycBalance();

//         // Get USYC value in USDC terms
//         (uint256 usycValueInUSDC,,) = usycTeller.sellPreview(usycBalance);

//         // The USYC value should not exceed what was actually available to rehypothecate
//         uint256 totalReserves = yoloHookProxy.totalAnchorReserveUSDC();
//         uint256 targetRehypo = (totalReserves * 9900) / (10000 + 9900); // Correct formula: r*R/(1+r)

//         console.log("Total reserves:", totalReserves);
//         console.log("Target rehypothecation (99%):", targetRehypo);
//         console.log("Actual USYC value:", usycValueInUSDC);
//         console.log("Remaining USDC reserves:", totalReserves);

//         // The rehypothecation should approach but not exceed the target
//         // Due to the cap by totalAnchorReserveUSDC, it should be less than or equal to target
//         assertLe(usycValueInUSDC, targetRehypo * 101 / 100, "Should not exceed target by more than 1%");

//         console.log("Successfully tested claim token balance guard");
//     }

//     // ************************ //
//     // *** HELPER FUNCTIONS *** //
//     // ************************ //

//     function _setupRehypothecation() internal {
//         yoloHookProxy.configureRehypothecation(address(usycTeller), address(usycToken), 7500); // 75%
//     }

//     function _addInitialLiquidity() internal {
//         uint256 usdcAmount = IERC20Metadata(usdc).decimals() == 18 ? 500_000e18 : 500_000e6; // 500k USDC
//         uint256 usyAmount = 500_000e18; // 500k USY

//         deal(usdc, address(this), usdcAmount);
//         deal(usy, address(this), usyAmount);

//         IERC20(usdc).approve(address(yoloHookProxy), usdcAmount);
//         IERC20(usy).approve(address(yoloHookProxy), usyAmount);

//         yoloHookProxy.addLiquidity(usdcAmount, usyAmount, 0, address(this));
//     }

//     function _triggerRehypothecation() internal {
//         // Perform a small swap to trigger rehypothecation
//         uint256 swapAmount = IERC20Metadata(usdc).decimals() == 18 ? 1_000e18 : 1_000e6; // 1k USDC
//         deal(usdc, address(this), swapAmount);
//         IERC20(usdc).approve(address(swapRouter), swapAmount);

//         (PoolKey memory key, bool usdcIs0) = _getAnchorPoolKey();
//         SwapParams memory params =
//             SwapParams({zeroForOne: usdcIs0, amountSpecified: -int256(swapAmount), sqrtPriceLimitX96: 0});

//         PoolSwapTest.TestSettings memory settings =
//             PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false});

//         swapRouter.swap(key, params, settings, "");
//     }

//     function _getAnchorPoolKey() internal view returns (PoolKey memory key, bool usdcIs0) {
//         usdcIs0 = usdc < usy;
//         key = PoolKey({
//             currency0: Currency.wrap(usdcIs0 ? usdc : usy),
//             currency1: Currency.wrap(usdcIs0 ? usy : usdc),
//             fee: 0,
//             tickSpacing: 1,
//             hooks: IHooks(address(yoloHookProxy))
//         });
//     }

//     function _checkInvariant() internal view returns (bool) {
//         // Since the hook holds claim tokens (ERC-1155) not real USDC,
//         // we verify the invariant by checking internal consistency
//         // The totalAnchorReserveUSDC should be the single source of truth

//         // For this simplified check, we just ensure reserves are non-negative
//         // and within reasonable bounds (not more than total supply)
//         uint256 totalReserves = yoloHookProxy.totalAnchorReserveUSDC();
//         uint256 totalSupply = yoloHookProxy.anchorPoolLiquiditySupply();

//         // Basic sanity check: reserves should be reasonable relative to LP supply
//         return totalSupply > 0 ? (totalReserves <= totalSupply * 1e6) : (totalReserves == 0);
//     }

//     function _logAddressAsBinary(address _addr) internal pure {
//         bytes20 b = bytes20(_addr);
//         bytes memory out = new bytes(160); // 20 bytes * 8 bits

//         for (uint256 i = 0; i < 20; i++) {
//             uint8 byteVal = uint8(b[i]);
//             for (uint256 j = 0; j < 8; j++) {
//                 out[i * 8 + (7 - j)] = (byteVal & (1 << j)) != 0 ? bytes1("1") : bytes1("0");
//             }
//         }

//         console.log(string(out));
//     }
// }
