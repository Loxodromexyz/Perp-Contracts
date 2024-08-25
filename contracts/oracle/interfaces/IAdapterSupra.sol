// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// @title IAdapterSupra.sol
// @dev Interface for a oracle adapter
interface IAdapterSupra {
    function latestPrices(uint64 _pairIndex, uint8 decimals) external view returns (uint256, uint256, uint256, uint256);
}