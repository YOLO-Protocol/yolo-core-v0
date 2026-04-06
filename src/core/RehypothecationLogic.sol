// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import "./YoloStorage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ITeller} from "@yolo/contracts/interfaces/ITeller.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {CurrencySettler} from "@uniswap/v4-core/test/utils/CurrencySettler.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

interface IBaseHookView {
    function poolManager() external view returns (IPoolManager);
}

/**
 * @title   RehypothecationLogic
 * @notice  Logic contract for rehypothecation operations
 * @dev     This contract is called via delegatecall from YoloHook, sharing its storage
 */
contract RehypothecationLogic is YoloStorage {
    using CurrencyLibrary for Currency;
    using CurrencySettler for Currency;

    struct CallbackData {
        uint8 action;
        bytes data;
    }

    /**
     * @dev Convert claim-tokens to real ERC-20 USDC
     * @param amount Amount of USDC to pull as real tokens
     * @param inUnlockContext True if already in unlock context (e.g., called from hooks)
     */
    function _pullRealUSDC(uint256 amount, bool inUnlockContext) internal {
        if (amount == 0) return;

        // NEW: Use local real USDC first to avoid double-settle
        uint256 localBalance = IERC20(usdc).balanceOf(address(this));
        if (localBalance >= amount) return;

        uint256 needed = amount - localBalance;
        Currency cUSDC = Currency.wrap(usdc);
        IPoolManager pm = IBaseHookView(address(this)).poolManager();

        if (inUnlockContext) {
            // We're already in an unlock context, perform operations directly
            cUSDC.settle(pm, address(this), needed, true);
            cUSDC.take(pm, address(this), needed, false);
        } else {
            // Not in unlock context, need to unlock first
            pm.unlock(abi.encode(CallbackData(3, abi.encode(needed))));
        }
    }

    // function _pullRealUSDC(uint256 amount) internal {
    //     if (amount == 0) return;
    //     Currency cUSDC = Currency.wrap(usdc);

    //     IPoolManager pm = IBaseHookView(address(this)).poolManager();

    //     // burn claim-tokens we hold
    //     cUSDC.settle(pm, address(this), amount, true);
    //     // pull real ERC-20
    //     cUSDC.take(pm, address(this), amount, false);
    // }

    /**
     * @dev Deposit real ERC-20 USDC back to PM, receiving claim-tokens
     * @param amount Amount of real USDC to convert back to claim-tokens
     * @param inUnlockContext True if already in unlock context (e.g., called from hooks)
     */
    function _pushRealUSDC(uint256 amount, bool inUnlockContext) internal {
        if (amount == 0) return;

        // NEW: Use local real USDC first to avoid double-settle
        uint256 localBalance = IERC20(usdc).balanceOf(address(this));
        if (localBalance == 0) return;

        uint256 toPush = amount > localBalance ? localBalance : amount;
        Currency cUSDC = Currency.wrap(usdc);
        IPoolManager pm = IBaseHookView(address(this)).poolManager();

        if (inUnlockContext) {
            // We're already in an unlock context, perform operations directly
            cUSDC.settle(pm, address(this), toPush, false);
        } else {
            // Not in unlock context, need to unlock first
            pm.unlock(abi.encode(CallbackData(4, abi.encode(toPush))));
        }
    }

    // function _pushRealUSDC(uint256 amount) internal {
    //     if (amount == 0) return;
    //     Currency cUSDC = Currency.wrap(usdc);

    //     IPoolManager pm = IBaseHookView(address(this)).poolManager();

    //     // give PM the real ERC-20, minting claim-tokens to us
    //     cUSDC.settle(pm, address(this), amount, false);
    // }

    /**
     * @notice  Internal function to buy USYC with context awareness
     * @param   _usdcAmount      Amount of USDC to spend
     * @param   inUnlockContext  True if already in unlock context
     * @return  usycOut          Amount of USYC received
     */
    function _buyUSYC(uint256 _usdcAmount, bool inUnlockContext) internal returns (uint256 usycOut) {
        // Convert claim-tokens to real USDC for the Teller FIRST
        _pullRealUSDC(_usdcAmount, inUnlockContext);

        // Only update reserve after successful pull
        totalAnchorReserveUSDC -= _usdcAmount;

        // Buy USYC with real USDC
        usycOut = usycTeller.buy(_usdcAmount);

        // Update cost basis with weighted average
        usycCostBasisUSDC += _usdcAmount;
        usycQuantity += usycOut;
        usycBalance = usycQuantity; // Keep usycBalance in sync

        emit RehypothecationExecuted(true, _usdcAmount, usycOut);
        return usycOut;
    }

    /**
     * @notice  Function to buy USYC and track cost basis
     * @param   _usdcAmount  Amount of USDC to spend
     * @return  usycOut      Amount of USYC received
     */
    function buyUSYC(uint256 _usdcAmount) public returns (uint256 usycOut) {
        return _buyUSYC(_usdcAmount, false);
    }

    /**
     * @notice  Internal function to sell USYC with context awareness
     * @param   _usycAmount      Amount of USYC to sell
     * @param   inUnlockContext  True if already in unlock context
     * @return  usdcOut          Amount of USDC received
     */
    function _sellUSYC(uint256 _usycAmount, bool inUnlockContext) internal returns (uint256 usdcOut) {
        require(_usycAmount <= usycQuantity, "Insufficient USYC");

        // Calculate proportional cost basis being closed
        uint256 costPortion = (usycCostBasisUSDC * _usycAmount) / usycQuantity;

        // Execute the sale (receives real USDC)
        usdcOut = usycTeller.sell(_usycAmount);

        // Update tracking
        usycCostBasisUSDC -= costPortion;
        usycQuantity -= _usycAmount;
        usycBalance = usycQuantity;

        // Emit P/L only for accounting transparency
        if (usdcOut > costPortion) {
            emit RehypothecationGain(usdcOut - costPortion);
        } else if (usdcOut < costPortion) {
            emit RehypothecationLoss(costPortion - usdcOut);
        }

        // Clear cost basis if fully unwound
        if (usycQuantity == 0) {
            usycCostBasisUSDC = 0;
        }

        emit RehypothecationExecuted(false, _usycAmount, usdcOut);

        // FIXED: Update reserve BEFORE push to maintain consistency
        totalAnchorReserveUSDC += usdcOut;

        // Convert real USDC back to claim-tokens for consistent accounting
        _pushRealUSDC(usdcOut, inUnlockContext);

        return usdcOut;
    }

    /**
     * @notice  Function to sell USYC and realize P&L
     * @param   _usycAmount  Amount of USYC to sell
     * @return  usdcOut      Amount of USDC received
     */
    function sellUSYC(uint256 _usycAmount) public returns (uint256 usdcOut) {
        return _sellUSYC(_usycAmount, false);
    }

    /**
     * @notice  Bring the USYC position back toward the target ratio.
     * @param   _usdcAmount  Ignored — kept only so NatSpec matches the signature.
     */
    function handleRehypothecation(uint256 _usdcAmount) external {
        // silence the unused-variable warning
        _usdcAmount;

        if (!rehypothecationEnabled || rehypothecationRatio == 0) return;

        uint256 R = totalAnchorReserveUSDC; // live USDC reserve
        uint256 C = usycBalance == 0 ? 0 : _previewUSDC(usycBalance);

        uint256 r = rehypothecationRatio; // basis-points (e.g. 7500 = 75 %)
        uint256 P = PRECISION_DIVISOR;

        // x = (r·R − P·C)/(P + r)
        uint256 numerator = (r * R) > (P * C) ? (r * R) - (P * C) : 0;

        if (numerator == 0) return; // already on or above target

        uint256 denom = P + r;
        uint256 usdcToBuy = numerator / denom;

        // Cap by book reserves (which represents our claim tokens)
        if (usdcToBuy > totalAnchorReserveUSDC) usdcToBuy = totalAnchorReserveUSDC;

        if (usdcToBuy > 0) _buyUSYC(usdcToBuy, true);
    }

    // function handleRehypothecation(uint256 _usdcAmount) external {
    //     if (!rehypothecationEnabled || rehypothecationRatio == 0) return;

    //     // Calculate target USDC value to rehypothecate
    //     uint256 targetUSDCValue = (totalAnchorReserveUSDC * rehypothecationRatio) / PRECISION_DIVISOR;

    //     // Get current USYC value in USDC terms
    //     uint256 currentUSYCValueInUSDC = 0;
    //     if (usycBalance > 0) {
    //         // Preview how much USDC we'd get if we sold all our USYC
    //         (uint256 usdcOut,,) = usycTeller.sellPreview(usycBalance);
    //         currentUSYCValueInUSDC = usdcOut;
    //     }

    //     if (targetUSDCValue > currentUSYCValueInUSDC) {
    //         // Need to buy more USYC
    //         uint256 usdcToBuy = targetUSDCValue - currentUSYCValueInUSDC;

    //         // Check available USDC (use totalAnchorReserveUSDC as proxy for available funds)
    //         // Note: This is a simplification - in practice you may want more sophisticated tracking
    //         uint256 availableUSDC = totalAnchorReserveUSDC;
    //         if (usdcToBuy > availableUSDC) {
    //             usdcToBuy = availableUSDC;
    //         }

    //         if (usdcToBuy > 0) {
    //             // Preview the buy to see how much USYC we'll get
    //             (uint256 usycOut,,) = usycTeller.buyPreview(usdcToBuy);

    //             if (usycOut > 0) {
    //                 // Execute the buy
    //                 buyUSYC(usdcToBuy);
    //             }
    //         }
    //     }
    //     // Note: We don't sell excess USYC here, only in rebalance function
    // }

    /**
     * @notice  Handle de-hypothecation when USDC is needed
     * @param   _usdcNeeded  Amount of USDC needed
     */
    function handleDehypothecation(uint256 _usdcNeeded) external {
        if (usycBalance == 0) return;

        // Check current USDC balance (use totalAnchorReserveUSDC as proxy)
        uint256 currentUSDC = totalAnchorReserveUSDC;

        if (currentUSDC < _usdcNeeded) {
            uint256 shortfall = _usdcNeeded - currentUSDC;

            // We need to figure out how much USYC to sell to get the shortfall
            uint256 usycToSell = usycBalance; // Start with all our balance

            // Binary search or use preview to find right amount
            // For simplicity, try to sell enough to cover shortfall with buffer
            if (usycBalance > 0) {
                (uint256 maxUsdcOut,,) = usycTeller.sellPreview(usycBalance);

                if (maxUsdcOut >= shortfall) {
                    // We have enough USYC to cover the shortfall
                    // Estimate how much USYC we need to sell (with 1% buffer for fees)
                    usycToSell = (usycBalance * ((shortfall * 101) / 100)) / maxUsdcOut;

                    if (usycToSell > usycBalance) {
                        usycToSell = usycBalance;
                    }
                }

                // Execute the sale
                sellUSYC(usycToSell);

                // Check if we still need more USDC
                currentUSDC = totalAnchorReserveUSDC;
                if (currentUSDC < _usdcNeeded && usycQuantity > 0) {
                    // Sell all remaining USYC
                    sellUSYC(usycQuantity);
                }
            }
        }
    }

    /**
     * @notice  Internal rebalance logic that assumes we're in correct unlock context
     */
    function _rebalanceRehypothecation(bool inUnlockContext) internal {
        if (!rehypothecationEnabled) revert YoloHook__RehypothecationDisabled();

        uint256 R = totalAnchorReserveUSDC;
        uint256 C = (usycBalance == 0) ? 0 : _previewUSDC(usycBalance); // USDC-value of current USYC

        uint256 r = rehypothecationRatio;
        uint256 denom = PRECISION_DIVISOR + r;

        // ideal C*  = r·R / (1 + r)
        uint256 idealC = (R * r) / denom;

        if (C < idealC) {
            uint256 buyUSDC = idealC - C;

            // Cap by book reserves
            if (buyUSDC > totalAnchorReserveUSDC) buyUSDC = totalAnchorReserveUSDC;

            if (buyUSDC > 0) {
                // buyUSYC already handles the pull and reserve update
                uint256 got = _buyUSYC(buyUSDC, inUnlockContext);
                emit RehypothecationRebalanced(true, buyUSDC, got);
            }
        } else if (C > idealC) {
            uint256 sellUSDCeq = C - idealC;
            uint256 usycToSell = (usycBalance * sellUSDCeq) / C;
            if (usycToSell > 0) {
                uint256 got = _sellUSYC(usycToSell, inUnlockContext);
                emit RehypothecationRebalanced(false, usycToSell, got);
            }
        }
    }

    /**
     * @notice  Manually rebalance rehypothecation to target ratio
     */
    function rebalanceRehypothecation() external {
        // When called externally, we need to wrap in an unlock
        IPoolManager pm = IBaseHookView(address(this)).poolManager();
        pm.unlock(abi.encode(CallbackData(5, abi.encode(0))));
    }

    // function rebalanceRehypothecation() external {
    //     if (!rehypothecationEnabled) revert YoloHook__RehypothecationDisabled();

    //     // Calculate target USDC value to rehypothecate
    //     uint256 targetUSDCValue = (totalAnchorReserveUSDC * rehypothecationRatio) / PRECISION_DIVISOR;

    //     // Get current USYC value in USDC terms
    //     uint256 currentUSYCValueInUSDC = 0;
    //     if (usycBalance > 0) {
    //         (uint256 usdcOut,,) = usycTeller.sellPreview(usycBalance);
    //         currentUSYCValueInUSDC = usdcOut;
    //     }

    //     if (targetUSDCValue > currentUSYCValueInUSDC) {
    //         // Buy USYC
    //         uint256 usdcToBuy = targetUSDCValue - currentUSYCValueInUSDC;

    //         // Check available USDC (use totalAnchorReserveUSDC as proxy)
    //         uint256 availableUSDC = totalAnchorReserveUSDC;
    //         if (usdcToBuy > availableUSDC) {
    //             usdcToBuy = availableUSDC;
    //         }

    //         if (usdcToBuy > 0) {
    //             // Pull real USDC, buy USYC, and update storage
    //             _pullRealUSDC(usdcToBuy);
    //             uint256 usycReceived = usycTeller.buy(usdcToBuy);

    //             // Update storage directly since we're already in the logic contract
    //             usycCostBasisUSDC += usdcToBuy;
    //             usycQuantity += usycReceived;
    //             usycBalance = usycQuantity;

    //             emit RehypothecationRebalanced(true, usdcToBuy, usycReceived);
    //         }
    //     } else if (targetUSDCValue < currentUSYCValueInUSDC) {
    //         // Sell USYC
    //         uint256 excessUSDCValue = currentUSYCValueInUSDC - targetUSDCValue;

    //         // Estimate how much USYC to sell
    //         uint256 usycToSell = (usycBalance * excessUSDCValue) / currentUSYCValueInUSDC;

    //         if (usycToSell > 0 && usycToSell <= usycBalance) {
    //             // Execute the sale
    //             uint256 usdcReceived = sellUSYC(usycToSell);
    //             emit RehypothecationRebalanced(false, usycToSell, usdcReceived);
    //         }
    //     }
    // }

    /**
     * @notice  Internal emergency withdrawal logic
     */
    function _emergencyWithdrawUSYC(bool inUnlockContext)
        internal
        returns (uint256 usdcReceived, uint256 withdrawnAmount)
    {
        if (usycBalance == 0) return (0, 0);

        withdrawnAmount = usycBalance;
        usdcReceived = _sellUSYC(usycBalance, inUnlockContext);

        // Ensure everything is cleared
        usycBalance = 0;
        usycQuantity = 0;
        usycCostBasisUSDC = 0;

        emit EmergencyUSYCWithdrawal(withdrawnAmount, usdcReceived);
        return (usdcReceived, withdrawnAmount);
    }

    /**
     * @notice  Emergency withdrawal of all USYC
     */
    function emergencyWithdrawUSYC() external returns (uint256 usdcReceived, uint256 withdrawnAmount) {
        // When called externally, we need to wrap in an unlock
        IPoolManager pm = IBaseHookView(address(this)).poolManager();
        bytes memory result = pm.unlock(abi.encode(CallbackData(6, abi.encode(0))));
        return abi.decode(result, (uint256, uint256));
    }

    /// @dev helper – preview how much USDC we’d get for `usycAmt` USYC
    function _previewUSDC(uint256 usycAmt) internal view returns (uint256 usdcOut) {
        (usdcOut,,) = usycTeller.sellPreview(usycAmt);
    }
}
