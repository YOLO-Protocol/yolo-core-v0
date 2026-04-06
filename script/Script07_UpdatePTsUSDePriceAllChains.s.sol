// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/*---------- IMPORT FOUNDRY ----------*/
import "forge-std/Script.sol";

/*---------- IMPORT CONTRACTS ----------*/
import {MockPriceOracle} from "@yolo/contracts/mocks/MockPriceOracle.sol";

/**
 * @title   Script07_UpdatePTsUSDePriceAllChains
 * @author  0xyolodev.eth
 * @dev     Update PT-sUSDe-31JUL2025 oracle price across all 4 chains
 */
contract Script07_UpdatePTsUSDePriceAllChains is Script {
    // PT-sUSDe-31JUL2025 / USD Oracle address (same on all chains)
    address constant PT_SUSDE_ORACLE = 0xb74f4bc6801cca34C9a3dF4A1D6C937a910ddEc3;

    // New price: $0.9944 with 8 decimals
    int256 constant NEW_PRICE = 99440000;

    // Chain configurations
    struct ChainConfig {
        string name;
        string rpcEnvKey;
        uint256 chainId;
    }

    ChainConfig[] chains;

    function setUp() public {
        // Initialize chain configurations
        chains.push(ChainConfig("Base Sepolia", "BASE_SEPOLIA_RPC", 84532));
        chains.push(ChainConfig("Unichain Sepolia", "UNICHAIN_SEPOLIA_RPC", 1301));
        chains.push(ChainConfig("Avalanche Mainnet", "AVAX_MAINNET_RPC", 43114));
        chains.push(ChainConfig("Ink Mainnet", "INK_MAINNET_RPC", 57073));
    }

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        console.log("==========================================");
        console.log("  UPDATE PT-sUSDe-31JUL2025 ORACLE PRICE");
        console.log("==========================================");
        console.log("Deployer:", deployer);
        console.log("Oracle Address:", PT_SUSDE_ORACLE);
        console.log("New Price: $0.9944 (99440000 with 8 decimals)");
        console.log("==========================================");

        uint256 successCount = 0;
        uint256 failedCount = 0;

        // Update price on each chain
        for (uint256 i = 0; i < chains.length; i++) {
            ChainConfig memory chain = chains[i];

            console.log("");
            console.log("Updating on", chain.name, "...");

            try vm.envString(chain.rpcEnvKey) returns (string memory rpcUrl) {
                if (bytes(rpcUrl).length == 0) {
                    console.log("WARNING: Skipping - RPC URL not configured");
                    continue;
                }

                // Fork the chain
                uint256 forkId = vm.createFork(rpcUrl);
                vm.selectFork(forkId);

                // Verify we're on the correct chain
                if (block.chainid != chain.chainId) {
                    console.log("ERROR: Chain ID mismatch. Expected:", chain.chainId, "Got:", block.chainid);
                    failedCount++;
                    continue;
                }

                // Check if oracle exists
                uint256 codeSize;
                assembly {
                    codeSize := extcodesize(PT_SUSDE_ORACLE)
                }

                if (codeSize == 0) {
                    console.log("ERROR: Oracle not deployed on this chain");
                    failedCount++;
                    continue;
                }

                // Get current price
                MockPriceOracle oracle = MockPriceOracle(PT_SUSDE_ORACLE);
                (, int256 currentPrice,,,) = oracle.latestRoundData();
                console.log("Current Price:", currentPrice);

                // Update the price
                vm.startBroadcast(deployerKey);
                oracle.updateAnswer(NEW_PRICE);
                vm.stopBroadcast();

                // Verify the update
                (, int256 updatedPrice,,,) = oracle.latestRoundData();
                if (updatedPrice == NEW_PRICE) {
                    console.log("SUCCESS: Updated to:", updatedPrice);
                    successCount++;
                } else {
                    console.log("ERROR: Update failed. Price is still:", updatedPrice);
                    failedCount++;
                }
            } catch {
                console.log("WARNING: Skipping - RPC environment variable not found");
            }
        }

        console.log("");
        console.log("==========================================");
        console.log("            UPDATE SUMMARY");
        console.log("==========================================");
        console.log("Successful updates:", successCount);
        console.log("Failed updates:", failedCount);
        console.log("Skipped chains:", chains.length - successCount - failedCount);

        if (successCount == chains.length) {
            console.log("");
            console.log("All chains updated successfully!");
        } else if (successCount > 0) {
            console.log("");
            console.log("WARNING: Some chains were updated. Check logs above.");
        } else {
            console.log("");
            console.log("ERROR: No chains were updated. Check configuration.");
        }
    }
}
