
// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../market/MarketStoreUtils.sol";

/**
 * @title MarketStoreUtilsTest
 * @dev Contract to help test the MarketStoreUtils library
 */
contract MarketStoreUtilsTest {
    function getEmptyMarket() external pure returns (Market.Props memory) {
        Market.Props memory market;
        return market;
    }

    function setMarket(DataStore dataStore, address key, bytes32 salt, Market.Props memory market) external {
        MarketStoreUtils.set(dataStore, key, salt, market);
    }

    function removeMarket(DataStore dataStore, address key) external {
        MarketStoreUtils.remove(dataStore, key);
    }

    function removeMarketSaltHash(
        DataStore dataStore,
        string memory label,
        address indexToken,
        address longToken,
        address shortToken,
        bytes32 marketType
    ) public {
        bytes32 salt = keccak256(abi.encode(
            label,
            indexToken,
            longToken,
            shortToken,
            marketType
        ));
        dataStore.removeAddress(MarketStoreUtils.getMarketSaltHash(salt));
    }

    function getMarketSaltHash(
        DataStore dataStore,
        string memory label,
        address indexToken,
        address longToken,
        address shortToken,
        bytes32 marketType
    ) public view returns (address) {
        bytes32 salt = keccak256(abi.encode(
            label,
            indexToken,
            longToken,
            shortToken,
            marketType
        ));
        return address(dataStore.getAddress(MarketStoreUtils.getMarketSaltHash(salt)));
    }
}
