// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Timelock is Ownable {
    uint256 private _TIMELOCK = 48 hours;
    uint256 private lockedTime;

    modifier notLocked() {
        require(lockedTime != 0 && lockedTime < block.timestamp, "Time locked");
        _;
    }

    function unlock() public onlyOwner {
        lockedTime = block.timestamp + _TIMELOCK;
    }

    function lock() public onlyOwner {
        lockedTime = 0;
    }
}
