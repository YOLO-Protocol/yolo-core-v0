// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {MockPriceOracle} from "@yolo/contracts/mocks/MockPriceOracle.sol";

/**
 * @title   Script08_UpdateMockOraclePrices
 * @author  0xyolodev.eth
 * @dev     Quick script to update mock oracle prices on testnet
 */
contract Script08_UpdateMockOraclePrices is Script {
    // Oracle addresses from deployment-addresses.md
    address constant XAU_USD_ORACLE = 0x74D912FFb044a7AD279ba9CA82c01fE93dB5893c;
    address constant NVDA_USD_ORACLE = 0xFC01D56344395e6E796dB43495A28d2eE250e65E;
    address constant TSLA_USD_ORACLE = 0x34942f72E7e5529079b135EE03DDE76cB322b7D5;
    address constant JPY_USD_ORACLE = 0xE13dA0d002829D35834540e3BC2AF7519FB29352;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        console.log("==========================================");
        console.log("    UPDATING MOCK ORACLE PRICES");
        console.log("==========================================");

        vm.startBroadcast(deployerKey);

        // Update XAU/USD to $3540.5350 (normalized to 8 decimals: 354053500000)
        MockPriceOracle(XAU_USD_ORACLE).updateAnswer(354053500000);
        console.log("Updated XAU/USD to:", MockPriceOracle(XAU_USD_ORACLE).latestAnswer());

        // Update NVDA/USD to $170.0700 (normalized to 8 decimals: 17007000000)
        MockPriceOracle(NVDA_USD_ORACLE).updateAnswer(17007000000);
        console.log("Updated NVDA/USD to:", MockPriceOracle(NVDA_USD_ORACLE).latestAnswer());

        // Update TSLA/USD to $334.51 (normalized to 8 decimals: 33451000000)
        MockPriceOracle(TSLA_USD_ORACLE).updateAnswer(33451000000);
        console.log("Updated TSLA/USD to:", MockPriceOracle(TSLA_USD_ORACLE).latestAnswer());

        // Update JPY/USD to 0.00673785 (normalized to 8 decimals: 673785)
        MockPriceOracle(JPY_USD_ORACLE).updateAnswer(673785);
        console.log("Updated JPY/USD to:", MockPriceOracle(JPY_USD_ORACLE).latestAnswer());

        vm.stopBroadcast();

        console.log("==========================================");
        console.log("    PRICE UPDATES COMPLETED");
        console.log("==========================================");
    }
}
