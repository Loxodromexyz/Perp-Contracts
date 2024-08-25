// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "./interfaces/IAdapterSupra.sol";
import "./interfaces/ISupraSValueFeed.sol";

contract AdapterSupra is IAdapterSupra {
    ISupraSValueFeed immutable sValueFeed;

    constructor(address _contractAddress) {
        sValueFeed = ISupraSValueFeed(_contractAddress);
    }

    function latestPrices(uint64 _pairIndex, uint8 decimals) external view returns (uint256 round, uint256 decimal, uint256 timestamp, uint256 price) {
        (bytes32 val, ) = sValueFeed.getSvalue(_pairIndex);
        uint256[4] memory decode = unpack(val);
        round = decode[0] / 1000;
        decimal = decimals;
        timestamp = decode[2] / 1000;
        price = priceDecimals(decode[3], decode[1], decimals);
    }

    function unpack(bytes32 data) internal pure returns(uint256[4] memory) {
        uint256[4] memory info;

        info[0] = bytesToUint256(abi.encodePacked(data >> 192));       // round
        info[1] = bytesToUint256(abi.encodePacked(data << 64 >> 248)); // decimal
        info[2] = bytesToUint256(abi.encodePacked(data << 72 >> 192)); // timestamp
        info[3] = bytesToUint256(abi.encodePacked(data << 136 >> 160)); // price

        return info;
    }

    function bytesToUint256(bytes memory _bs) internal pure returns (uint256 value) {
        require(_bs.length == 32, "bytes length is not 32.");
        assembly {
            value := mload(add(_bs, 0x20))
        }
    }

    function priceDecimals(uint256 price, uint256 srcDecimals, uint8 decimals) private pure returns (uint256) {
        if (decimals > srcDecimals) {
            price = price * (10 ** (decimals-uint8(srcDecimals)));
        } else if (decimals < srcDecimals) {
            price = price / (10 ** (uint8(srcDecimals)-decimals));
        }
        return uint256(price);
    }

}