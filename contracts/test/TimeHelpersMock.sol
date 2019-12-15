pragma solidity ^0.5.8;

import "../os/SafeMath.sol";
import "../os/TimeHelpers.sol";


contract TimeHelpersMock is TimeHelpers {
    using SafeMath for uint256;

    uint256 private mockedTimestamp;
    uint256 private mockedSetBlockNumber;
    uint256 private mockedAdvancedBlockNumber;

    /**
    * @dev Tells the mocked block number in uint256, or the real block number if it wasn't mocked
    */
    function getBlockNumberExt() external view returns (uint256) {
        return getBlockNumber();
    }

    /**
    * @dev Tells the mocked timestamp value in uint256, or the real timestamp if it wasn't mocked
    */
    function getTimestampExt() external view returns (uint256) {
        return getTimestamp();
    }

    /**
    * @dev Sets a mocked block number value, used only for testing purposes
    */
    function mockSetBlockNumber(uint256 _number) external {
        mockedSetBlockNumber = _number;
    }

    /**
    * @dev Advances the mocked block number value, used only for testing purposes
    */
    function mockAdvanceBlocks(uint256 _number) external {
        if (mockedSetBlockNumber != 0) {
            mockedAdvancedBlockNumber = mockedSetBlockNumber.add(_number);
            mockedSetBlockNumber = 0;
        }
        else if (mockedAdvancedBlockNumber != 0) mockedAdvancedBlockNumber = mockedAdvancedBlockNumber.add(_number);
        else mockedAdvancedBlockNumber = block.number.add(_number);
    }

    /**
    * @dev Sets a mocked timestamp value, used only for testing purposes
    */
    function mockSetTimestamp(uint256 _timestamp) external {
        mockedTimestamp = _timestamp;
    }

    /**
    * @dev Increases the mocked timestamp value, used only for testing purposes
    */
    function mockIncreaseTime(uint256 _seconds) external {
        if (mockedTimestamp != 0) mockedTimestamp = mockedTimestamp.add(_seconds);
        else mockedTimestamp = block.timestamp.add(_seconds);
    }

    /**
    * @dev Internal function to get the mocked block number if it was set, or current `block.number`
    */
    function getBlockNumber() internal view returns (uint256) {
        if (mockedSetBlockNumber != 0) return mockedSetBlockNumber;
        uint256 realBlockNumber = super.getBlockNumber();
        return (mockedAdvancedBlockNumber > realBlockNumber) ? mockedAdvancedBlockNumber : realBlockNumber;
    }

    /**
    * @dev Internal function to get the mocked timestamp if it was set, or current `block.timestamp`
    */
    function getTimestamp() internal view returns (uint256) {
        if (mockedTimestamp != 0) return mockedTimestamp;
        return super.getTimestamp();
    }
}
