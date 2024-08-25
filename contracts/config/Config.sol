// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../data/DataStore.sol";
import "../data/Keys.sol";
import "../role/RoleModule.sol";
import "../event/EventEmitter.sol";
import "../utils/BasicMulticall.sol";
import "../utils/Precision.sol";
import "../utils/Cast.sol";
import "../market/MarketUtils.sol";

// @title Config
contract Config is ReentrancyGuard, RoleModule, BasicMulticall {
    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.IntItems;
    using EventUtils for EventUtils.BoolItems;
    using EventUtils for EventUtils.Bytes32Items;
    using EventUtils for EventUtils.BytesItems;
    using EventUtils for EventUtils.StringItems;

    uint256 public constant MAX_FEE_FACTOR = 5 * Precision.FLOAT_PRECISION / 100; // 5%

    DataStore public immutable dataStore;
    EventEmitter public immutable eventEmitter;

    // @dev the base keys that can be set
    mapping (bytes32 => bool) public allowedBaseKeys;
    // @dev the limited base keys that can be set
    mapping (bytes32 => bool) public allowedLimitedBaseKeys;

    constructor(
        RoleStore _roleStore,
        DataStore _dataStore,
        EventEmitter _eventEmitter
    ) RoleModule(_roleStore) {
        dataStore = _dataStore;
        eventEmitter = _eventEmitter;

        _initAllowedBaseKeys();
        _initAllowedLimitedBaseKeys();
    }

    modifier onlyKeeper() {
        if (
            !roleStore.hasRole(msg.sender, Role.LIMITED_CONFIG_KEEPER) &&
            !roleStore.hasRole(msg.sender, Role.CONFIG_KEEPER)
        ) {
            revert Errors.Unauthorized(msg.sender, "LIMITED / CONFIG KEEPER");
        }

        _;
    }

    function setClaimableCollateralFactorForTime(
        address market,
        address token,
        uint256 timeKey,
        uint256 factor
    ) external onlyConfigKeeper nonReentrant {
        if (factor > Precision.FLOAT_PRECISION) { revert Errors.InvalidClaimableFactor(factor); }

        bytes32 key = Keys.claimableCollateralFactorKey(market, token, timeKey);
        dataStore.setUint(key, factor);

        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "market", market);
        eventData.addressItems.setItem(1, "token", token);

        eventData.uintItems.initItems(2);
        eventData.uintItems.setItem(0, "timeKey", timeKey);
        eventData.uintItems.setItem(1, "factor", factor);

        eventEmitter.emitEventLog2(
            "SetClaimableCollateralFactorForTime",
            Cast.toBytes32(market),
            Cast.toBytes32(token),
            eventData
        );
    }

    function setClaimableCollateralFactorForAccount(
        address market,
        address token,
        uint256 timeKey,
        address account,
        uint256 factor
    ) external onlyConfigKeeper nonReentrant {
        if (factor > Precision.FLOAT_PRECISION) { revert Errors.InvalidClaimableFactor(factor); }

        bytes32 key = Keys.claimableCollateralFactorKey(market, token, timeKey, account);
        dataStore.setUint(key, factor);

        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(3);
        eventData.addressItems.setItem(0, "market", market);
        eventData.addressItems.setItem(1, "token", token);
        eventData.addressItems.setItem(2, "account", account);

        eventData.uintItems.initItems(2);
        eventData.uintItems.setItem(0, "timeKey", timeKey);
        eventData.uintItems.setItem(1, "factor", factor);

        eventEmitter.emitEventLog2(
            "SetClaimableCollateralFactorForAccount",
            Cast.toBytes32(market),
            Cast.toBytes32(token),
            eventData
        );
    }

    function setPositionImpactDistributionRate(
        address market,
        uint256 minPositionImpactPoolAmount,
        uint256 positionImpactPoolDistributionRate
    ) external onlyConfigKeeper nonReentrant {
        MarketUtils.distributePositionImpactPool(dataStore, eventEmitter, market);

        dataStore.setUint(Keys.minPositionImpactPoolAmountKey(market), minPositionImpactPoolAmount);
        dataStore.setUint(Keys.positionImpactPoolDistributionRateKey(market), positionImpactPoolDistributionRate);

        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "market", market);

        eventData.uintItems.initItems(2);
        eventData.uintItems.setItem(0, "minPositionImpactPoolAmount", minPositionImpactPoolAmount);
        eventData.uintItems.setItem(1, "positionImpactPoolDistributionRate", positionImpactPoolDistributionRate);

        eventEmitter.emitEventLog1(
            "SetPositionImpactPoolDistributionRate",
            Cast.toBytes32(market),
            eventData
        );
    }

    // @dev set a bool value
    // @param baseKey the base key of the value to set
    // @param data the additional data to be combined with the base key
    // @param value the bool value
    function setBool(bytes32 baseKey, bytes memory data, bool value) external onlyKeeper nonReentrant {
        _validateKey(baseKey);

        bytes32 fullKey = _getFullKey(baseKey, data);

        dataStore.setBool(fullKey, value);

        EventUtils.EventLogData memory eventData;

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "baseKey", baseKey);

        eventData.bytesItems.initItems(1);
        eventData.bytesItems.setItem(0, "data", data);

        eventData.boolItems.initItems(1);
        eventData.boolItems.setItem(0, "value", value);

        eventEmitter.emitEventLog1(
            "SetBool",
            baseKey,
            eventData
        );
    }

    // @dev set an address value
    // @param baseKey the base key of the value to set
    // @param data the additional data to be combined with the base key
    // @param value the address value
    function setAddress(bytes32 baseKey, bytes memory data, address value) external onlyKeeper nonReentrant {
        _validateKey(baseKey);

        bytes32 fullKey = _getFullKey(baseKey, data);

        dataStore.setAddress(fullKey, value);

        EventUtils.EventLogData memory eventData;

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "baseKey", baseKey);

        eventData.bytesItems.initItems(1);
        eventData.bytesItems.setItem(0, "data", data);

        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "value", value);

        eventEmitter.emitEventLog1(
            "SetAddress",
            baseKey,
            eventData
        );
    }

    // @dev set a bytes32 value
    // @param baseKey the base key of the value to set
    // @param data the additional data to be combined with the base key
    // @param value the bytes32 value
    function setBytes32(bytes32 baseKey, bytes memory data, bytes32 value) external onlyKeeper nonReentrant {
        _validateKey(baseKey);

        bytes32 fullKey = _getFullKey(baseKey, data);

        dataStore.setBytes32(fullKey, value);

        EventUtils.EventLogData memory eventData;

        eventData.bytes32Items.initItems(2);
        eventData.bytes32Items.setItem(0, "baseKey", baseKey);
        eventData.bytes32Items.setItem(1, "value", value);

        eventData.bytesItems.initItems(1);
        eventData.bytesItems.setItem(0, "data", data);

        eventEmitter.emitEventLog1(
            "SetBytes32",
            baseKey,
            eventData
        );
    }

    // @dev set a uint256 value
    // @param basekey the base key of the value to set
    // @param data the additional data to be combined with the base key
    // @param value the uint256 value
    function setUint(bytes32 baseKey, bytes memory data, uint256 value) external onlyKeeper nonReentrant {
        _validateKey(baseKey);

        bytes32 fullKey = _getFullKey(baseKey, data);

        _validateRange(baseKey, value);

        dataStore.setUint(fullKey, value);

        EventUtils.EventLogData memory eventData;

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "baseKey", baseKey);

        eventData.bytesItems.initItems(1);
        eventData.bytesItems.setItem(0, "data", data);

        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "value", value);

        eventEmitter.emitEventLog1(
            "SetUint",
            baseKey,
            eventData
        );
    }

    // @dev set an int256 value
    // @param basekey the base key of the value to set
    // @param data the additional data to be combined with the base key
    // @param value the int256 value
    function setInt(bytes32 baseKey, bytes memory data, int256 value) external onlyKeeper nonReentrant {
        _validateKey(baseKey);

        bytes32 fullKey = _getFullKey(baseKey, data);

        dataStore.setInt(fullKey, value);

        EventUtils.EventLogData memory eventData;

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "baseKey", baseKey);

        eventData.bytesItems.initItems(1);
        eventData.bytesItems.setItem(0, "data", data);

        eventData.intItems.initItems(1);
        eventData.intItems.setItem(0, "value", value);

        eventEmitter.emitEventLog1(
            "SetInt",
            baseKey,
            eventData
        );
    }

    function _getFullKey(bytes32 baseKey, bytes memory data) internal pure returns (bytes32) {
        if (data.length == 0) {
            return baseKey;
        }

        return keccak256(bytes.concat(baseKey, data));
    }

    // @dev initialize the allowed base keys
    function _initAllowedBaseKeys() internal {
        allowedBaseKeys[Keys.HOLDING_ADDRESS] = true;

        allowedBaseKeys[Keys.MIN_HANDLE_EXECUTION_ERROR_GAS] = true;
        allowedBaseKeys[Keys.MIN_HANDLE_EXECUTION_ERROR_GAS_TO_FORWARD] = true;
        allowedBaseKeys[Keys.MIN_ADDITIONAL_GAS_FOR_EXECUTION] = true;

        allowedBaseKeys[Keys.IS_MARKET_DISABLED] = true;

        allowedBaseKeys[Keys.MAX_SWAP_PATH_LENGTH] = true;
        allowedBaseKeys[Keys.MAX_CALLBACK_GAS_LIMIT] = true;

        allowedBaseKeys[Keys.MIN_POSITION_SIZE_USD] = true;
        allowedBaseKeys[Keys.MAX_POSITION_IMPACT_FACTOR_FOR_LIQUIDATIONS] = true;

        allowedBaseKeys[Keys.MAX_POOL_AMOUNT] = true;
        allowedBaseKeys[Keys.MAX_POOL_AMOUNT_FOR_DEPOSIT] = true;
        allowedBaseKeys[Keys.MAX_OPEN_INTEREST] = true;

        allowedBaseKeys[Keys.MIN_MARKET_TOKENS_FOR_FIRST_DEPOSIT] = true;

        allowedBaseKeys[Keys.CREATE_DEPOSIT_FEATURE_DISABLED] = true;
        allowedBaseKeys[Keys.CANCEL_DEPOSIT_FEATURE_DISABLED] = true;
        allowedBaseKeys[Keys.EXECUTE_DEPOSIT_FEATURE_DISABLED] = true;

        allowedBaseKeys[Keys.CREATE_WITHDRAWAL_FEATURE_DISABLED] = true;
        allowedBaseKeys[Keys.CANCEL_WITHDRAWAL_FEATURE_DISABLED] = true;
        allowedBaseKeys[Keys.EXECUTE_WITHDRAWAL_FEATURE_DISABLED] = true;

        allowedBaseKeys[Keys.CREATE_ORDER_FEATURE_DISABLED] = true;
        allowedBaseKeys[Keys.EXECUTE_ORDER_FEATURE_DISABLED] = true;
        allowedBaseKeys[Keys.EXECUTE_ADL_FEATURE_DISABLED] = true;
        allowedBaseKeys[Keys.UPDATE_ORDER_FEATURE_DISABLED] = true;
        allowedBaseKeys[Keys.CANCEL_ORDER_FEATURE_DISABLED] = true;

        allowedBaseKeys[Keys.CLAIM_FUNDING_FEES_FEATURE_DISABLED] = true;
        allowedBaseKeys[Keys.CLAIM_COLLATERAL_FEATURE_DISABLED] = true;
        allowedBaseKeys[Keys.CLAIM_AFFILIATE_REWARDS_FEATURE_DISABLED] = true;
        allowedBaseKeys[Keys.CLAIM_UI_FEES_FEATURE_DISABLED] = true;

        allowedBaseKeys[Keys.SUBACCOUNT_FEATURE_DISABLED] = true;

        allowedBaseKeys[Keys.MIN_ORACLE_BLOCK_CONFIRMATIONS] = true;
        allowedBaseKeys[Keys.MAX_ORACLE_PRICE_AGE] = true;
        allowedBaseKeys[Keys.MAX_ORACLE_REF_PRICE_DEVIATION_FACTOR] = true;
        allowedBaseKeys[Keys.POSITION_FEE_RECEIVER_FACTOR] = true;
        allowedBaseKeys[Keys.SWAP_FEE_RECEIVER_FACTOR] = true;
        allowedBaseKeys[Keys.BORROWING_FEE_RECEIVER_FACTOR] = true;

        allowedBaseKeys[Keys.ESTIMATED_GAS_FEE_BASE_AMOUNT] = true;
        allowedBaseKeys[Keys.ESTIMATED_GAS_FEE_MULTIPLIER_FACTOR] = true;

        allowedBaseKeys[Keys.EXECUTION_GAS_FEE_BASE_AMOUNT] = true;
        allowedBaseKeys[Keys.EXECUTION_GAS_FEE_MULTIPLIER_FACTOR] = true;

        allowedBaseKeys[Keys.DEPOSIT_GAS_LIMIT] = true;
        // use Keys.withdrawalGasLimitKey() here because it is double hashed
        allowedBaseKeys[Keys.withdrawalGasLimitKey()] = true;
        allowedBaseKeys[Keys.SINGLE_SWAP_GAS_LIMIT] = true;
        allowedBaseKeys[Keys.INCREASE_ORDER_GAS_LIMIT] = true;
        allowedBaseKeys[Keys.DECREASE_ORDER_GAS_LIMIT] = true;
        allowedBaseKeys[Keys.SWAP_ORDER_GAS_LIMIT] = true;
        allowedBaseKeys[Keys.TOKEN_TRANSFER_GAS_LIMIT] = true;
        allowedBaseKeys[Keys.NATIVE_TOKEN_TRANSFER_GAS_LIMIT] = true;

        allowedBaseKeys[Keys.REQUEST_EXPIRATION_BLOCK_AGE] = true;
        allowedBaseKeys[Keys.MIN_COLLATERAL_FACTOR] = true;
        allowedBaseKeys[Keys.MIN_COLLATERAL_FACTOR_FOR_OPEN_INTEREST_MULTIPLIER] = true;
        allowedBaseKeys[Keys.MIN_COLLATERAL_USD] = true;

        allowedBaseKeys[Keys.VIRTUAL_TOKEN_ID] = true;
        allowedBaseKeys[Keys.VIRTUAL_MARKET_ID] = true;
        allowedBaseKeys[Keys.VIRTUAL_INVENTORY_FOR_SWAPS] = true;
        allowedBaseKeys[Keys.VIRTUAL_INVENTORY_FOR_POSITIONS] = true;

        allowedBaseKeys[Keys.POSITION_IMPACT_FACTOR] = true;
        allowedBaseKeys[Keys.POSITION_IMPACT_EXPONENT_FACTOR] = true;
        allowedBaseKeys[Keys.MAX_POSITION_IMPACT_FACTOR] = true;
        allowedBaseKeys[Keys.POSITION_FEE_FACTOR] = true;

        allowedBaseKeys[Keys.SWAP_IMPACT_FACTOR] = true;
        allowedBaseKeys[Keys.SWAP_IMPACT_EXPONENT_FACTOR] = true;
        allowedBaseKeys[Keys.SWAP_FEE_FACTOR] = true;

        allowedBaseKeys[Keys.MAX_UI_FEE_FACTOR] = true;

        allowedBaseKeys[Keys.ORACLE_TYPE] = true;

        allowedBaseKeys[Keys.RESERVE_FACTOR] = true;
        allowedBaseKeys[Keys.OPEN_INTEREST_RESERVE_FACTOR] = true;

        allowedBaseKeys[Keys.MAX_PNL_FACTOR] = true;
        allowedBaseKeys[Keys.MIN_PNL_FACTOR_AFTER_ADL] = true;

        allowedBaseKeys[Keys.FUNDING_FACTOR] = true;
        allowedBaseKeys[Keys.FUNDING_EXPONENT_FACTOR] = true;
        allowedBaseKeys[Keys.FUNDING_INCREASE_FACTOR_PER_SECOND] = true;
        allowedBaseKeys[Keys.FUNDING_DECREASE_FACTOR_PER_SECOND] = true;
        allowedBaseKeys[Keys.MIN_FUNDING_FACTOR_PER_SECOND] = true;
        allowedBaseKeys[Keys.MAX_FUNDING_FACTOR_PER_SECOND] = true;
        allowedBaseKeys[Keys.THRESHOLD_FOR_STABLE_FUNDING] = true;
        allowedBaseKeys[Keys.THRESHOLD_FOR_DECREASE_FUNDING] = true;

        allowedBaseKeys[Keys.BORROWING_FACTOR] = true;
        allowedBaseKeys[Keys.BORROWING_EXPONENT_FACTOR] = true;
        allowedBaseKeys[Keys.SKIP_BORROWING_FEE_FOR_SMALLER_SIDE] = true;

        allowedBaseKeys[Keys.PRICE_FEED_HEARTBEAT_DURATION] = true;
    }

    function _initAllowedLimitedBaseKeys() internal {
        allowedLimitedBaseKeys[Keys.ESTIMATED_GAS_FEE_BASE_AMOUNT] = true;
        allowedLimitedBaseKeys[Keys.EXECUTION_GAS_FEE_BASE_AMOUNT] = true;

        allowedLimitedBaseKeys[Keys.MAX_POOL_AMOUNT] = true;
        allowedLimitedBaseKeys[Keys.MAX_POOL_AMOUNT_FOR_DEPOSIT] = true;
        allowedLimitedBaseKeys[Keys.MAX_OPEN_INTEREST] = true;
    }

    // @dev validate that the baseKey is allowed to be used
    // @param baseKey the base key to validate
    function _validateKey(bytes32 baseKey) internal view {
        if (roleStore.hasRole(msg.sender, Role.CONFIG_KEEPER)) {
            if (!allowedBaseKeys[baseKey]) {
                revert Errors.InvalidBaseKey(baseKey);
            }

            return;
        }

        if (roleStore.hasRole(msg.sender, Role.LIMITED_CONFIG_KEEPER)) {
            if (!allowedLimitedBaseKeys[baseKey]) {
                revert Errors.InvalidBaseKey(baseKey);
            }

            return;
        }

        revert Errors.InvalidBaseKey(baseKey);
    }

    // @dev validate that the value is within the allowed range
    // @param baseKey the base key for the value
    // @param value the value to be set
    function _validateRange(bytes32 baseKey, uint256 value) internal pure {
        if (
            baseKey == Keys.FUNDING_FACTOR ||
            baseKey == Keys.BORROWING_FACTOR
        ) {
            // revert if value > 1%
            if (value > 1 * Precision.FLOAT_PRECISION / 100) {
                revert Errors.InvalidFeeFactor(baseKey, value);
            }
        }

        if (
            baseKey == Keys.SWAP_FEE_FACTOR ||
            baseKey == Keys.POSITION_FEE_FACTOR ||
            baseKey == Keys.MAX_UI_FEE_FACTOR
        ) {
            // revert if value > 5%
            if (value > 5 * Precision.FLOAT_PRECISION / 100) {
                revert Errors.InvalidFeeFactor(baseKey, value);
            }
        }

        if (
            baseKey == Keys.POSITION_FEE_RECEIVER_FACTOR ||
            baseKey == Keys.SWAP_FEE_RECEIVER_FACTOR ||
            baseKey == Keys.BORROWING_FEE_RECEIVER_FACTOR ||
            baseKey == Keys.MIN_COLLATERAL_FACTOR ||
            baseKey == Keys.MAX_PNL_FACTOR ||
            baseKey == Keys.MIN_PNL_FACTOR_AFTER_ADL
        ) {
            // revert if value > 100%
            if (value > Precision.FLOAT_PRECISION) {
                revert Errors.InvalidFeeFactor(baseKey, value);
            }
        }
    }
}
