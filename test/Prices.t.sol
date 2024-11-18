// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Prices.sol";

contract PricesTest is Test {
    Prices public prices;
    address public owner = vm.envAddress("OWNER_ADDRESS");
    address public oracle = vm.envAddress("ORACLE_ADDRESS");
    uint256 public thresholdFilter = vm.envUint("THRESHOLD_FILTER");
    address public stableToken = vm.envAddress("STABLE_TOKEN_ADDRESS");

    function setUp() public {
        prices = new Prices(owner, oracle, thresholdFiilter);
        prices.setStableToken(stableToken);
    }

    function testStableToken() public {
        assertEq(prices.stableToken(), stableToken);
    }

    function testOracle() public {
        assertEq(prices.oracle(), oracle);
    }
}
