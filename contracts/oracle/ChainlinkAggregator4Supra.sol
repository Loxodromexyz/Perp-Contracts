// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";
import "./Owned.sol";
import "./interfaces/IAdapterSupra.sol";

contract ChainlinkAggregator4Supra is Owned, AggregatorV2V3Interface {
    uint256 public constant maxRoundId = 0xFFFFFFFF;

    uint32 latestAggregatorRoundId;
    address adapterAddress;
    uint64 pairIdx;

    // Transmission records the median answer from the transmit transaction at
    // time timestamp
    struct Transmission {
        int192 answer; // 192 bits ought to be enough for anyone
        uint64 timestamp;
    }
    mapping(uint32 /* aggregator round ID */ => Transmission)
    internal s_transmissions;

    mapping (address => bool) public isKeeper;

    constructor(uint8 _decimals, string memory _description, address _adapter, uint64 _pairIdx) {
        decimals = _decimals;
        s_description = _description;
        latestAggregatorRoundId = 0;
        adapterAddress = _adapter;
        pairIdx = _pairIdx;
    }

    function setKeeper(address _keeper, bool _isKeeper) external onlyOwner {
        isKeeper[_keeper] = _isKeeper;
    }

    function setLatestAnswer(int192[] memory answers) external {
        require(isKeeper[msg.sender], "update answer: forbidden");

        // s_answer = answer;
        latestAggregatorRoundId++;
        // Check the report contents, and record the result
        for (uint i = 0; i < answers.length - 1; i++) {
            bool inOrder = answers[i] <= answers[i + 1];
            require(inOrder, "answers not sorted");
        }

        int192 median = answers[answers.length / 2];
        s_transmissions[latestAggregatorRoundId] = Transmission(
            median,
            uint64(block.timestamp)
        );
        emit NewRound(latestAggregatorRoundId, address(0x0), block.timestamp);
        emit AnswerUpdated(median, latestAggregatorRoundId, block.timestamp);
    }

    /**
     * @notice median from the most recent report
     */
    function latestAnswer() external view returns (int256) {
        return s_transmissions[latestAggregatorRoundId].answer;
    }

    function latestAnswerOracle() external view returns (int256) {
        if (adapterAddress != address(0)) {
            (,,,uint256 price) = IAdapterSupra(adapterAddress).latestPrices(pairIdx, decimals);
            return int256(price);
        }
        return s_transmissions[latestAggregatorRoundId].answer;
    }

    /**
     * @notice timestamp of block in which last report was transmitted
     */
    function latestTimestamp() external view returns (uint256) {
        return s_transmissions[latestAggregatorRoundId].timestamp;
    }

    function latestTimestampOracle() external view returns (uint256) {
        if (adapterAddress != address(0)) {
            (,,uint256 timestamp,) = IAdapterSupra(adapterAddress).latestPrices(pairIdx, decimals);
            return timestamp;
        }
        return s_transmissions[latestAggregatorRoundId].timestamp;
    }

    function latestAnswerTimestampOracle() external view returns (int256, uint256) {
        if (adapterAddress != address(0)) {
            (,,uint256 timestamp, uint256 price) = IAdapterSupra(adapterAddress).latestPrices(pairIdx, decimals);
            return (int256(price), timestamp);
        }
        return (s_transmissions[latestAggregatorRoundId].answer, s_transmissions[latestAggregatorRoundId].timestamp);
    }

    /**
     * @notice Aggregator round (NOT OCR round) in which last report was transmitted
     */
    function latestRound() external view returns (uint256) {
        return latestAggregatorRoundId;
    }

    function latestRoundOracle() external view returns (uint256) {
        if (adapterAddress != address(0)) {
            (uint256 round,,,) = IAdapterSupra(adapterAddress).latestPrices(pairIdx, decimals);
            return round;
        }
        return latestAggregatorRoundId;
    }

    /**
     * @notice median of report from given aggregator round (NOT OCR round)
     * @param _roundId the aggregator round of the target report
     */
    function getAnswer(uint256 _roundId) external view returns (int256) {
        if (_roundId > maxRoundId) {
            return 0;
        }
        return s_transmissions[uint32(_roundId)].answer;
    }

    /**
     * @notice timestamp of block in which report from given aggregator round was transmitted
     * @param _roundId aggregator round (NOT OCR round) of target report
     */
    function getTimestamp(uint256 _roundId) external view returns (uint256) {
        if (_roundId > maxRoundId) {
            return 0;
        }
        return s_transmissions[uint32(_roundId)].timestamp;
    }

    /*
     * v3 Aggregator interface
     */

    string private constant V3_NO_DATA_ERROR = "No data present";

    /**
     * @return answers are stored in fixed-point format, with this many digits of precision
     */
    uint8 public immutable decimals;

    /**
     * @notice aggregator contract version
     */
    uint256 public constant version = 4;

    string internal s_description;

    /**
     * @notice human-readable description of observable this contract is reporting on
     */
    function description()
    external
    view
    virtual
    override
    returns (string memory)
    {
        return s_description;
    }

    /**
     * @notice details for the given aggregator round
     * @param _roundId target aggregator round (NOT OCR round). Must fit in uint32
     * @return roundId _roundId
     * @return answer median of report from given _roundId
     * @return startedAt timestamp of block in which report from given _roundId was transmitted
     * @return updatedAt timestamp of block in which report from given _roundId was transmitted
     * @return answeredInRound _roundId
     */
    function getRoundData(
        uint80 _roundId
    )
    external
    view
    returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    )
    {
        require(_roundId <= maxRoundId, V3_NO_DATA_ERROR);
        Transmission memory transmission = s_transmissions[uint32(_roundId)];
        return (
            _roundId,
            transmission.answer,
            transmission.timestamp,
            transmission.timestamp,
            _roundId
        );
    }

    /**
     * @notice aggregator details for the most recently transmitted report
     * @return roundId aggregator round of latest report (NOT OCR round)
     * @return answer median of latest report
     * @return startedAt timestamp of block containing latest report
     * @return updatedAt timestamp of block containing latest report
     * @return answeredInRound aggregator round of latest report
     */
    function latestRoundData()
    external
    view
    returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    )
    {
        roundId = latestAggregatorRoundId;

        // Skipped for compatability with existing FluxAggregator in which latestRoundData never reverts.
        // require(roundId != 0, V3_NO_DATA_ERROR);

        Transmission memory transmission = s_transmissions[uint32(roundId)];
        return (
            roundId,
            transmission.answer,
            transmission.timestamp,
            transmission.timestamp,
            roundId
        );
    }
}