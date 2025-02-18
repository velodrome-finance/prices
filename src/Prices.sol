// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "./interfaces/IOffchainOracle.sol";
import "./interfaces/IERC20.sol";

/// @title Prices
/// @notice A wrapper contract for OffchainOracle.
/// @notice It emits events for fetched prices and stores the price history.
contract Prices {
    mapping(address => bool) public owners;
    mapping(address => bool) public keepers;
    IOffchainOracle public oracle;
    IERC20[] public connectors;
    address public stableToken;
    uint256 public thresholdFilter;
    mapping(address => mapping(uint256 => uint256)) public historicalPrices;

    /// @notice Emitted when a price for a token is fetched.
    /// @param token The address of the token.
    /// @param price The fetched price of the token.
    event Price(address indexed token, uint256 price);
    
    constructor(address _owner, IOffchainOracle _oracle, uint256 _thresholdFilter) {
        owners[_owner] = true;
        oracle = _oracle;
        thresholdFilter = _thresholdFilter;
    }

    /// @notice Adds an owner to the owners set.
    /// @dev Can only be called by an owner.
    /// @param _owner The address to be added.
    function addOwner(address _owner) public {
        _onlyOwner();
        owners[_owner] = true;
    }

    /// @notice Removes an owner from the owners set.
    /// @dev Can only be called by an owner.
    /// @param _owner The address to be added.
    function removeOwner(address _owner) public {
        _onlyOwner();
        require(msg.sender != _owner, "Owner cannot remove themself");
        owners[_owner] = false;
    }

    /// @notice Adds a keeper to the keepers set.
    /// @dev Can only be called by an owner.
    /// @param _keeper The address to be added.
    function addKeeper(address _keeper) public {
        _onlyOwner();
        keepers[_keeper] = true;
    }

    /// @notice Removes a keeper from the keepers set.
    /// @dev Can only be called by an owner.
    /// @param _keeper The address to be removed.
    function removeKeeper(address _keeper) public {
        _onlyOwner();
        keepers[_keeper] = false;
    }

    /// @notice Sets a new oracle.
    /// @dev Can only be called by an owner.
    /// @param _oracle The address of the new oracle.
    function setOracle(IOffchainOracle _oracle) public {
        _onlyOwner();
        oracle = _oracle;
    }

    /// @notice Adds a connector token for pricing.
    /// @dev Can only be called by an owner.
    /// @param _token The token to be added.
    function addConnector(address _token) public {
        _onlyOwner();
        bool isConnector = false;
        for (uint i = 0; i < connectors.length; i++) {
            if (address(connectors[i]) == _token) {
                isConnector = true;
                break;
            }
        }

        if (!isConnector) {
            connectors.push(IERC20(_token));
        }
    }

    /// @notice Removes a connector token.
    /// @dev Can only be called by an owner.
    /// @param _token The token to be removed.
    function removeConnector(address _token) public {
        _onlyOwner();
        for (uint i = 0; i < connectors.length; i++) {
            if (address(connectors[i]) == _token) {
                connectors[i] = connectors[connectors.length - 1];
                connectors.pop();
                break;
            }
        }
    }

    /// @notice Sets a new stable token to price against.
    /// @dev Can only be called by an owner.
    /// @param _stableToken The address of the new stable token.
    function setStableToken(address _stableToken) public {
        _onlyOwner();
        stableToken = _stableToken;
    }

    /// @notice Sets a new threshold filter for pricing.
    /// @dev Can only be called by an owner.
    /// @param _thresholdFilter The new threshold filter.
    function setThresholdFilter(uint256 _thresholdFilter) public {
        _onlyOwner();
        thresholdFilter = _thresholdFilter;
    }

    /// @notice Fetches prices for a list of tokens.
    /// @dev Only callable by owners and keepers.
    /// @param _tokens The tokens to fetch prices for.
    /// @return The fetched prices for the tokens.
    function fetchPrices(IERC20[] calldata _tokens) public view returns (uint256[] memory prices) {
        _onlyOwnerOrKeeper();
        prices = oracle.getManyRatesWithCustomConnectors(_tokens, IERC20(stableToken), false, connectors, thresholdFilter);
    }

    /// @notice Records prices for a list of tokens.
    /// @dev Only callable by owners and keepers.
    /// @dev Emits a Price event and records it in storage.
    /// @param _tokens The tokens to store prices for.
    /// @param _prices The prices to store for the tokens.
    function storePrices(IERC20[] calldata _tokens, uint256[] calldata _prices) public {
        _onlyOwnerOrKeeper();
        address token;
        uint256 price;
        uint256 hourTimestamp = (block.timestamp / 1 hours) * 1 hours;
        for (uint i = 0; i < _tokens.length; i++) {
            token = address(_tokens[i]);
            price = _prices[i];
            historicalPrices[token][hourTimestamp] = price;
            emit Price(token, price);
        }
    }

    /// @notice Returns most recent historical price for a token based on given timestamp.
    /// @param _token The token to return the price for.
    /// @param _timestamp The time to return the price at.
    function latest(address _token, uint256 _timestamp) public view returns (uint256) {
        return historicalPrices[_token][((_timestamp / 1 hours) * 1 hours)];
    }

    /// @notice Enforces that the caller is an owner.
    function _onlyOwner() internal view {
        require(owners[msg.sender]);
    }

    /// @notice Enforces that the caller is an owner or a keeper.
    function _onlyOwnerOrKeeper() internal view {
        require(owners[msg.sender] || keepers[msg.sender]);
    }
}
