// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IAssetManager.sol";
import "./libraries/TribeOneHelper.sol";

contract AssetManager is Ownable, ReentrancyGuard, IAssetManager {
    event AddAvailableLoanAsset(address _sender, address _asset);
    event RemoveAvailableLoanAsset(address _sender, address _asset);
    event AddAvailableCollateralAsset(address _sender, address _asset);
    event RemoveAvailableCollateralAsset(address _sender, address _asset);
    event SetConsumer(address _setter, address _consumer);
    event TransferAsset(address indexed _requester, address _to, address _token, uint256 _amount);
    event WithdrawAsset(address indexed _to, address _token, uint256 _amount);

    mapping(address => bool) private availableLoanAsset;
    mapping(address => bool) private availableCollateralAsset;
    address private _consumer;

    constructor() {
        // Adding Native coins
        availableCollateralAsset[address(0)] = true;
        availableLoanAsset[address(0)] = true;
    }

    receive() external payable {}

    modifier onlyConsumer {
        require(msg.sender == _consumer, "Not consumer");
        _;
    }

    function consumer() external view returns (address) {
        return _consumer;
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

    function setConsumer(address _consumer_) external onlyOwner {
        require(_consumer_ != _consumer, "Already set as consumer");
        require(_consumer_ != address(0), "ZERO_ADDRESS");
        _consumer = _consumer_;

        emit SetConsumer(msg.sender, _consumer_);
    }

    function requestETH(address _to, uint _amount) external override onlyConsumer {
        require(address(this).balance >= _amount, "Asset Manager: Insufficient balance");
        TribeOneHelper.safeTransferETH(_to, _amount);
        emit TransferAsset(msg.sender, _to, address(0), _amount);
    }

    function requestToken(address _to, address _token, uint _amount) external override onlyConsumer {
        require(IERC20(_token).balanceOf(address(this)) >= _amount, "Asset Manager: Insufficient balance");
        TribeOneHelper.safeTransferFrom(_token, address(this), _to, _amount);
        emit TransferAsset(msg.sender, _to, _token, _amount);
    }

    function withdrawAsset(address _to, address _token, uint _amount) external onlyOwner {
        require(_to != address(0), "ZERO Address");
        if (_token == address(0)) {
            _amount = address(this).balance;
            TribeOneHelper.safeTransferETH(msg.sender, _amount);
        } else {
            TribeOneHelper.safeTransfer(_token, msg.sender, _amount);
        }

        WithdrawAsset(_to, _token, _amount);
    }
}
