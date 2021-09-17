// SPDX-License-Identifier: MIT
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract DragonResource is ERC1155 {
    /**
     * @param _uri_ string such like "https://game.example/api/item/{id}.json"
     */
    constructor(string memory _uri_) ERC1155(_uri_) {
        _mint(msg.sender, 1, 10**18, "");
        _mint(msg.sender, 2, 10**18, "");
    }
}
