// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "./IERC20.sol";

interface IOffchainOracle {
    function getRateWithCustomConnectors(IERC20 srcToken, IERC20 dstToken, bool useWrappers, IERC20[] memory customConnectors, uint256 thresholdFilter) external view returns (uint256 weightedRate);

    function getManyRatesWithCustomConnectors(IERC20[] calldata srcTokens, IERC20 dstToken, bool useWrappers, IERC20[] calldata customConnectors, uint256 thresholdFilter) external view returns (uint256[] memory weightedRates);
}
