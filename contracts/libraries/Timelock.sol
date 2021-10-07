// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Timelock is Ownable {
    uint private _TIMELOCK = 48 hours;
    uint private lockedTime;

    modifier notLocked() {
        require(lockedTime != 0 && lockedTime < block.timestamp, "Time locked");
        _;
    }
    
    function unlock() public {
        lockedTime = block.timestamp + _TIMELOCK;
    }
    
    function lock() public {
        lockedTime = 0;
    }
}