// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IAssetManager.sol";

contract AssetManager is Ownable, ReentrancyGuard, IAssetManager {
    event AddAvailableLoanAsset(address _sender, address _asset);
    event RemoveAvailableLoanAsset(address _sender, address _asset);
    event AddAvailableCollateralAsset(address _sender, address _asset);
    event RemoveAvailableCollateralAsset(address _sender, address _asset);

    mapping(address => bool) private availableLoanAsset;
    mapping(address => bool) private availableCollateralAsset;

    constructor() {
        // Adding Native coins
        availableCollateralAsset[address(0)] = true;
        availableLoanAsset[address(0)] = true;
    }

    function addAvailableLoanAsset(address _asset) external onlyOwner nonReentrant {
        require(!availableLoanAsset[_asset], "Already available");
        availableLoanAsset[_asset] = true;
        emit AddAvailableLoanAsset(msg.sender, _asset);
    }

    function removeAvailableLoanAsset(address _asset) external onlyOwner nonReentrant {
        require(availableLoanAsset[_asset], "Already removed");
        availableLoanAsset[_asset] = false;
        emit RemoveAvailableLoanAsset(msg.sender, _asset);
    }

    function addAvailableCollateralAsset(address _asset) external onlyOwner nonReentrant {
        require(!availableCollateralAsset[_asset], "Already available");
        availableCollateralAsset[_asset] = true;
        emit AddAvailableCollateralAsset(msg.sender, _asset);
    }

    function removeAvailableCollateralAsset(address _asset) external onlyOwner nonReentrant {
        require(availableCollateralAsset[_asset], "Already removed");
        availableCollateralAsset[_asset] = false;
        emit RemoveAvailableCollateralAsset(msg.sender, _asset);
    }

    function isAvailableLoanAsset(address _asset) external view override returns (bool) {
        return availableLoanAsset[_asset];
    }

    function isAvailableCollateralAsset(address _asset) external view override returns (bool) {
        return availableCollateralAsset[_asset];
    }
}
