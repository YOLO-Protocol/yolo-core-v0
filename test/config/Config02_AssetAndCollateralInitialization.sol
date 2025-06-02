// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Config01_OraclesAndAssets} from "./Config01_OraclesAndAssets.sol";

contract Config02_AssetAndCollateralInitialization is Config01_OraclesAndAssets {
    struct YoloAssetConfiguration {
        uint256 maxMintableCap; // 0 == Pause
        uint256 maxFlashLoanableAmount;
    }

    struct YoloAssets {
        string name;
        string symbol;
        uint8 decimals;
        MockOracleConfig oracleConfig;
        YoloAssetConfiguration assetConfiguration;
    }

    struct CollateralAsset {
        string symbol;
        uint256 supplyCap;
    }

    YoloAssets[] internal yoloAssetsArray;
    CollateralAsset[] internal collateralAssetsArray;

    constructor() {
        yoloAssetsArray.push(
            YoloAssets(
                "Yolo JPY",
                "yJPY",
                18,
                MockOracleConfig("JPY / USD", 0.0069 * 1e8),
                YoloAssetConfiguration(10_000_000_000 * 1e18, 10_000_000_000 * 1e18)
            )
        );
        yoloAssetsArray.push(
            YoloAssets(
                "Yolo KRW",
                "yKRW",
                18,
                MockOracleConfig("KRW / USD", 71_000),
                YoloAssetConfiguration(100_000_000_000 * 1e18, 100_000_000_000 * 1e18)
            )
        );
        yoloAssetsArray.push(
            YoloAssets(
                "Yolo Gold",
                "yXAU",
                18,
                MockOracleConfig("XAU / USD", 3_201 * 1e8),
                YoloAssetConfiguration(1_000_000 * 1e18, 1_000_000 * 1e18)
            )
        );
        yoloAssetsArray.push(
            YoloAssets(
                "Yolo NVDIA",
                "yNVDA",
                18,
                MockOracleConfig("NVDIA / USD", 134 * 1e8),
                YoloAssetConfiguration(10_000 * 1e18, 10_000 * 1e18)
            )
        );

        collateralAssetsArray.push(CollateralAsset("WBTC", 10_000 * 1e18));
        collateralAssetsArray.push(CollateralAsset("PT-sUSDe-31JUL2025", 10_000_000 * 1e18));
    }
}
