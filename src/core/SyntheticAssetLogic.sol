// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import "./YoloStorage.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IYoloSyntheticAsset} from "@yolo/contracts/interfaces/IYoloSyntheticAsset.sol";
import {IYoloOracle} from "@yolo/contracts/interfaces/IYoloOracle.sol";

/**
 * @title   SyntheticAssetLogic
 * @notice  Logic contract for synthetic asset operations (borrow, repay, withdraw, liquidate)
 * @dev     This contract is called via delegatecall from YoloHook, sharing its storage
 */
contract SyntheticAssetLogic is YoloStorage {
    using SafeERC20 for IERC20;

    /**
     * @notice  Allow users to deposit collateral and mint yolo assets
     * @param   _yoloAsset          The yolo asset to mint
     * @param   _borrowAmount       The amount of yolo asset to mint
     * @param   _collateral         The collateral asset to deposit
     * @param   _collateralAmount   The amount of collateral to deposit
     */
    function borrow(address _yoloAsset, uint256 _borrowAmount, address _collateral, uint256 _collateralAmount)
        external
    {
        // Early validation checks with immediate returns
        if (_borrowAmount == 0 || _collateralAmount == 0) revert YoloHook__InsufficientAmount();
        if (!isYoloAsset[_yoloAsset]) revert YoloHook__NotYoloAsset();
        if (!isWhiteListedCollateral[_collateral]) revert YoloHook__CollateralNotRecognized();

        CollateralToYoloAssetConfiguration storage pairConfig = pairConfigs[_collateral][_yoloAsset];
        if (pairConfig.collateral == address(0)) revert YoloHook__InvalidPair();

        // Early pause checks
        YoloAssetConfiguration storage assetConfig = yoloAssetConfigs[_yoloAsset];
        if (assetConfig.maxMintableCap <= 0) revert YoloHook__YoloAssetPaused();

        CollateralConfiguration storage colConfig = collateralConfigs[_collateral];
        if (colConfig.maxSupplyCap <= 0) revert YoloHook__CollateralPaused();

        // Transfer collateral first
        IERC20(_collateral).safeTransferFrom(msg.sender, address(this), _collateralAmount);

        // Handle position updates in a separate branch
        UserPosition storage position = positions[msg.sender][_collateral][_yoloAsset];
        if (position.borrower == address(0)) {
            _initializeNewPosition(position, msg.sender, _collateral, _yoloAsset, pairConfig.interestRate);
        } else {
            _updateExistingPosition(position, pairConfig.interestRate);
        }

        // Update amounts
        position.collateralSuppliedAmount += _collateralAmount;
        position.yoloAssetMinted += _borrowAmount;

        // Final checks
        if (!_isSolvent(position, _collateral, _yoloAsset, pairConfig.ltv)) revert YoloHook__NotSolvent();
        if (IYoloSyntheticAsset(_yoloAsset).totalSupply() + _borrowAmount > assetConfig.maxMintableCap) {
            revert YoloHook__ExceedsYoloAssetMintCap();
        }
        if (IERC20(_collateral).balanceOf(address(this)) > colConfig.maxSupplyCap) {
            revert YoloHook__ExceedsCollateralCap();
        }

        // Mint and emit
        IYoloSyntheticAsset(_yoloAsset).mint(msg.sender, _borrowAmount);
        emit Borrowed(msg.sender, _collateral, _collateralAmount, _yoloAsset, _borrowAmount);
    }

    /**
     * @notice  Allows users to repay their borrowed YoloAssets
     * @param   _collateral         The collateral asset address
     * @param   _yoloAsset          The yolo asset address being repaid
     * @param   _repayAmount        The amount to repay (0 for full repayment)
     * @param   _claimCollateral    Whether to withdraw collateral after full repayment
     */
    function repay(address _collateral, address _yoloAsset, uint256 _repayAmount, bool _claimCollateral) external {
        UserPosition storage position = positions[msg.sender][_collateral][_yoloAsset];
        if (position.borrower != msg.sender) revert YoloHook__InvalidPosition();

        _accrueInterest(position, position.storedInterestRate);

        uint256 totalDebt = position.yoloAssetMinted + position.accruedInterest;
        if (totalDebt == 0) revert YoloHook__NoDebt();

        uint256 actualRepayAmount = _repayAmount == 0 ? totalDebt : _repayAmount;
        if (actualRepayAmount > totalDebt) revert YoloHook__RepayExceedsDebt();

        // Handle repayment in separate function
        (uint256 interestPaid, uint256 principalPaid) = _processRepayment(position, _yoloAsset, actualRepayAmount);

        // Check if fully repaid (with dust handling)
        if (position.yoloAssetMinted <= 1 && position.accruedInterest <= 1) {
            _handleFullRepayment(position, _collateral, _yoloAsset, actualRepayAmount, _claimCollateral);
        } else {
            emit PositionPartiallyRepaid(
                msg.sender,
                _collateral,
                _yoloAsset,
                actualRepayAmount,
                interestPaid,
                principalPaid,
                position.yoloAssetMinted,
                position.accruedInterest
            );
        }
    }

    /**
     * @notice  Redeem up to `amount` of your collateral, provided your loan stays solvent
     * @param   _collateral    The collateral token address
     * @param   _yoloAsset     The YoloAsset token address
     * @param   _amount        How much collateral to withdraw
     */
    function withdraw(address _collateral, address _yoloAsset, uint256 _amount) external {
        UserPosition storage pos = positions[msg.sender][_collateral][_yoloAsset];
        if (pos.borrower != msg.sender) revert YoloHook__InvalidPosition();
        if (_amount == 0 || _amount > pos.collateralSuppliedAmount) revert YoloHook__InsufficientAmount();

        // Check if collateral is paused (optional, depends on your design intent)
        CollateralConfiguration storage colConfig = collateralConfigs[_collateral];
        if (colConfig.maxSupplyCap <= 0) revert YoloHook__CollateralPaused();

        // Accrue any outstanding interest before checking solvency
        _accrueInterest(pos, pos.storedInterestRate);

        // Calculate new collateral amount after withdrawal
        uint256 newCollateralAmount = pos.collateralSuppliedAmount - _amount;

        // If there's remaining debt, ensure the post-withdraw position stays solvent
        if (pos.yoloAssetMinted + pos.accruedInterest > 0) {
            // Temporarily reduce collateral for solvency check
            uint256 origCollateral = pos.collateralSuppliedAmount;
            pos.collateralSuppliedAmount = newCollateralAmount;

            // Check solvency using existing function
            CollateralToYoloAssetConfiguration storage pairConfig = pairConfigs[_collateral][_yoloAsset];
            bool isSolvent = _isSolvent(pos, _collateral, _yoloAsset, pairConfig.ltv);

            // Restore collateral amount
            pos.collateralSuppliedAmount = origCollateral;

            if (!isSolvent) revert YoloHook__NotSolvent();
        }

        // Update position state
        pos.collateralSuppliedAmount = newCollateralAmount;

        // Transfer collateral to user
        IERC20(_collateral).safeTransfer(msg.sender, _amount);

        // Clean up empty positions
        if (newCollateralAmount == 0 && pos.yoloAssetMinted == 0 && pos.accruedInterest == 0) {
            _removeUserPositionKey(msg.sender, _collateral, _yoloAsset);
            delete positions[msg.sender][_collateral][_yoloAsset];
        }

        emit Withdrawn(msg.sender, _collateral, _yoloAsset, _amount);
    }

    /**
     * @dev     Liquidate an under‐collateralized position
     * @param   _user        The borrower whose position is being liquidated
     * @param   _collateral  The collateral token address
     * @param   _yoloAsset   The YoloAsset token address
     * @param   _repayAmount How much of the borrower's debt to cover (0 == full debt)
     */
    function liquidate(address _user, address _collateral, address _yoloAsset, uint256 _repayAmount) external {
        // Early validation - all reverts first
        CollateralToYoloAssetConfiguration storage cfg = pairConfigs[_collateral][_yoloAsset];
        if (cfg.collateral == address(0)) revert YoloHook__InvalidPair();

        UserPosition storage pos = positions[_user][_collateral][_yoloAsset];
        if (pos.borrower == address(0)) revert YoloHook__InvalidPosition();

        // Accrue interest and check solvency
        _accrueInterest(pos, pos.storedInterestRate);
        if (_isSolvent(pos, _collateral, _yoloAsset, cfg.ltv)) revert YoloHook__Solvent();

        // Calculate repayment amount
        uint256 debt = pos.yoloAssetMinted + pos.accruedInterest;
        uint256 actualRepayAmount = _repayAmount == 0 ? debt : _repayAmount;
        if (actualRepayAmount > debt) revert YoloHook__RepayExceedsDebt();

        // Execute liquidation after all validation
        _executeLiquidation(pos, cfg, _collateral, _yoloAsset, actualRepayAmount, _user);
    }

    // ========================
    // INTERNAL HELPER FUNCTIONS
    // ========================

    function _initializeNewPosition(
        UserPosition storage position,
        address borrower,
        address collateral,
        address yoloAsset,
        uint256 interestRate
    ) private {
        position.borrower = borrower;
        position.collateral = collateral;
        position.yoloAsset = yoloAsset;
        position.lastUpdatedTimeStamp = block.timestamp;
        position.storedInterestRate = interestRate;

        UserPositionKey memory key = UserPositionKey({collateral: collateral, yoloAsset: yoloAsset});
        userPositionKeys[borrower].push(key);
    }

    function _updateExistingPosition(UserPosition storage position, uint256 newInterestRate) private {
        _accrueInterest(position, position.storedInterestRate);
        position.storedInterestRate = newInterestRate;
    }

    function _processRepayment(UserPosition storage position, address yoloAsset, uint256 repayAmount)
        private
        returns (uint256 interestPaid, uint256 principalPaid)
    {
        // Interest payment first
        if (position.accruedInterest > 0) {
            interestPaid = repayAmount < position.accruedInterest ? repayAmount : position.accruedInterest;
            position.accruedInterest -= interestPaid;

            IYoloSyntheticAsset(yoloAsset).burn(msg.sender, interestPaid);
            IYoloSyntheticAsset(yoloAsset).mint(treasury, interestPaid);
        }

        // Principal payment with remaining amount
        principalPaid = repayAmount - interestPaid;
        if (principalPaid > 0) {
            position.yoloAssetMinted -= principalPaid;
            IYoloSyntheticAsset(yoloAsset).burn(msg.sender, principalPaid);
        }
    }

    function _handleFullRepayment(
        UserPosition storage position,
        address collateral,
        address yoloAsset,
        uint256 repayAmount,
        bool claimCollateral
    ) private {
        position.yoloAssetMinted = 0;
        position.accruedInterest = 0;

        uint256 collateralToReturn = 0;
        if (claimCollateral && position.collateralSuppliedAmount > 0) {
            collateralToReturn = position.collateralSuppliedAmount;
            position.collateralSuppliedAmount = 0;

            IERC20(collateral).safeTransfer(msg.sender, collateralToReturn);
            _removeUserPositionKey(msg.sender, collateral, yoloAsset);
        }

        emit PositionFullyRepaid(msg.sender, collateral, yoloAsset, repayAmount, collateralToReturn);
    }

    function _executeLiquidation(
        UserPosition storage pos,
        CollateralToYoloAssetConfiguration storage cfg,
        address collateral,
        address yoloAsset,
        uint256 repayAmount,
        address user
    ) private {
        // Pull YoloAsset from liquidator and burn
        IERC20(yoloAsset).safeTransferFrom(msg.sender, address(this), repayAmount);
        IYoloSyntheticAsset(yoloAsset).burn(address(this), repayAmount);

        // Process debt reduction
        (uint256 interestPaid, uint256 principalPaid) = _reduceLiquidatedDebt(pos, repayAmount);

        // Calculate collateral seizure
        uint256 totalSeize = _calculateCollateralSeizure(collateral, yoloAsset, repayAmount, cfg.liquidationPenalty);

        if (totalSeize > pos.collateralSuppliedAmount) revert YoloHook__InvalidSeizeAmount();

        // Update position
        pos.collateralSuppliedAmount -= totalSeize;

        // Clean up if fully liquidated
        _cleanupLiquidatedPosition(pos, user, collateral, yoloAsset);

        // Transfer seized collateral to liquidator
        IERC20(collateral).safeTransfer(msg.sender, totalSeize);

        emit Liquidated(user, collateral, yoloAsset, repayAmount, totalSeize);
    }

    function _reduceLiquidatedDebt(UserPosition storage pos, uint256 repayAmount)
        private
        returns (uint256 interestPaid, uint256 principalPaid)
    {
        // Pay interest first
        interestPaid = repayAmount <= pos.accruedInterest ? repayAmount : pos.accruedInterest;
        pos.accruedInterest -= interestPaid;

        // Then principal
        principalPaid = repayAmount - interestPaid;
        pos.yoloAssetMinted -= principalPaid;
    }

    function _calculateCollateralSeizure(
        address collateral,
        address yoloAsset,
        uint256 repayAmount,
        uint256 liquidationPenalty
    ) private view returns (uint256 totalSeize) {
        // Get oracle prices
        uint256 priceColl = yoloOracle.getAssetPrice(collateral);
        uint256 priceYol = yoloOracle.getAssetPrice(yoloAsset);

        // Calculate value repaid
        uint256 usdValueRepaid = repayAmount * priceYol;

        // Calculate raw collateral amount (round up)
        uint256 rawCollateralSeize = (usdValueRepaid + priceColl - 1) / priceColl;

        // Add liquidation bonus
        uint256 bonus = (rawCollateralSeize * liquidationPenalty) / PRECISION_DIVISOR;
        totalSeize = rawCollateralSeize + bonus;
    }

    function _cleanupLiquidatedPosition(UserPosition storage pos, address user, address collateral, address yoloAsset)
        private
    {
        // Treat dust amounts as fully liquidated (≤1 wei)
        if (pos.yoloAssetMinted <= 1 && pos.accruedInterest <= 1) {
            pos.yoloAssetMinted = 0;
            pos.accruedInterest = 0;
        }

        // If position is fully cleared, delete it
        if (pos.yoloAssetMinted == 0 && pos.accruedInterest == 0 && pos.collateralSuppliedAmount == 0) {
            delete positions[user][collateral][yoloAsset];
            _removeUserPositionKey(user, collateral, yoloAsset);
        }
    }

    function _accrueInterest(UserPosition storage _pos, uint256 _rate) internal {
        if (_pos.yoloAssetMinted == 0) {
            _pos.lastUpdatedTimeStamp = block.timestamp;
            return;
        }
        uint256 dt = block.timestamp - _pos.lastUpdatedTimeStamp;
        // simple pro-rata APR: principal * rate * dt / (1yr * PRECISION_DIVISOR)
        _pos.accruedInterest += (_pos.yoloAssetMinted * _rate * dt) / (YEAR * PRECISION_DIVISOR);
        _pos.lastUpdatedTimeStamp = block.timestamp;
    }

    function _isSolvent(UserPosition storage _pos, address _collateral, address _yoloAsset, uint256 _ltv)
        internal
        view
        returns (bool)
    {
        uint256 collateralDecimals = IERC20Metadata(_collateral).decimals();
        uint256 yoloAssetDecimals = IERC20Metadata(_yoloAsset).decimals();

        uint256 colVal =
            yoloOracle.getAssetPrice(_collateral) * _pos.collateralSuppliedAmount / (10 ** collateralDecimals);
        uint256 debtVal = yoloOracle.getAssetPrice(_yoloAsset) * (_pos.yoloAssetMinted + _pos.accruedInterest)
            / (10 ** yoloAssetDecimals);

        return debtVal * PRECISION_DIVISOR <= colVal * _ltv;
    }

    function _removeUserPositionKey(address _user, address _collateral, address _yoloAsset) internal {
        UserPositionKey[] storage keys = userPositionKeys[_user];
        for (uint256 i = 0; i < keys.length;) {
            if (keys[i].collateral == _collateral && keys[i].yoloAsset == _yoloAsset) {
                // Swap with last element and pop
                keys[i] = keys[keys.length - 1];
                keys.pop();
                break;
            }
            unchecked {
                ++i;
            }
        }
    }
}
