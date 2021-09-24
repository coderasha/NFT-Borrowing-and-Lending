// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ITribeOne.sol";
import "hardhat/console.sol";

contract AgentProxy is Ownable {
    mapping(address => bool) private AGENT_LIST;

    constructor() {}

    modifier onlyAgent() {
        require(AGENT_LIST[msg.sender], "TribeOne: Forbidden");
        _;
    }

    function addAgent(address _agent) external onlyOwner {
        AGENT_LIST[_agent] = true;
    }

    function removeAgent(address _agent) external onlyOwner {
        AGENT_LIST[_agent] = false;
    }

    // We can use low level function, too
    function approveLoan(
        address _tribeOne,
        uint256 _loanId,
        uint256 _amount
    ) external onlyAgent {
        ITribeOne(_tribeOne).approveLoan(_loanId, _amount, msg.sender);
    }

    function relayNFT(
        address _tribeOne,
        uint256 _loanId,
        bool _accepted
    ) external payable onlyAgent {
        ITribeOne(_tribeOne).relayNFT{value: msg.value}(_loanId, msg.sender, _accepted);
    }
}
