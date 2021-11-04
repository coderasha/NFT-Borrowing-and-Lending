// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

interface IAssetManager {
    function isAvailableLoanAsset(address _asset) external returns (bool);

    function isAvailableCollateralAsset(address _asset) external returns (bool);

    function requestETH(address _to, uint _amount) external;

    function requestToken(address _to, address _token, uint _amount) external;
}
