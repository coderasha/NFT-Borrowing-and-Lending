// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ITribeOne.sol";
import "./libraries/Timelock.sol";

contract AgentProxy is Ownable, Timelock {
    event AddedAgent(address _setter, address _agent);
    event RemovedAgent(address _setter, address _agent);

    mapping(address => bool) private agentList;

    constructor() {}

    modifier onlyAgent() {
        require(agentList[msg.sender], "TribeOne: Forbidden");
        _;
    }

    function addAgent(address _agent) external onlyOwner notLocked {
        require(!agentList[_agent], "Already agent");
        agentList[_agent] = true;
        lock();
        emit AddedAgent(msg.sender, _agent);
    }

    function removeAgent(address _agent) external onlyOwner {
        require(agentList[_agent], "Already removed");
        agentList[_agent] = false;

        emit RemovedAgent(msg.sender, _agent);
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
