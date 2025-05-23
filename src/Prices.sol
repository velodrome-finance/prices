// SPDX-License-Identifier: LGPL-3.0

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
    uint256 public timeWindow;
    mapping(address => mapping(uint256 => uint256)) public historicalPrices;

    struct Entry {
        address token;
        uint256 timestamp;
    }

    /// @notice Emitted when a price for a token is fetched.
    /// @param token The address of the token.
    /// @param price The fetched price of the token.
    event Price(address indexed token, uint256 price);

    /// @notice Emitted when a new time window for pricing is set.
    /// @param timeWindow The new time window.
    event TimeWindowSet(uint256 timeWindow);
    
    constructor(address _owner, IOffchainOracle _oracle, uint256 _thresholdFilter, uint256 _timeWindow) {
        owners[_owner] = true;
        oracle = _oracle;
        thresholdFilter = _thresholdFilter;
        timeWindow = _timeWindow;
    }

    /// @notice Modifier that ensures the caller is an owner.
    modifier onlyOwner() {
        require(owners[msg.sender]);
        _;
    }

    /// @notice Modifier that ensures the caller is an owner or a keeper.
    modifier onlyOwnerOrKeeper() {
        require(owners[msg.sender] || keepers[msg.sender]);
        _;
    }

    /// @notice Adds an owner to the owners set.
    /// @dev Can only be called by an owner.
    /// @param _owner The address to be added.
    function addOwner(address _owner) public onlyOwner {
        owners[_owner] = true;
    }

    /// @notice Removes an owner from the owners set.
    /// @dev Can only be called by an owner.
    /// @param _owner The address to be added.
    function removeOwner(address _owner) public onlyOwner {
        require(msg.sender != _owner, "Owner cannot remove themself");
        owners[_owner] = false;
    }

    /// @notice Adds a keeper to the keepers set.
    /// @dev Can only be called by an owner.
    /// @param _keeper The address to be added.
    function addKeeper(address _keeper) public onlyOwner {
        keepers[_keeper] = true;
    }

    /// @notice Removes a keeper from the keepers set.
    /// @dev Can only be called by an owner.
    /// @param _keeper The address to be removed.
    function removeKeeper(address _keeper) public onlyOwner {
        keepers[_keeper] = false;
    }

    /// @notice Sets a new oracle.
    /// @dev Can only be called by an owner.
    /// @param _oracle The address of the new oracle.
    function setOracle(IOffchainOracle _oracle) public onlyOwner {
        oracle = _oracle;
    }

    /// @notice Adds a connector token for pricing.
    /// @dev Can only be called by an owner.
    /// @param _token The token to be added.
    function addConnector(address _token) public onlyOwner {
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
    function removeConnector(address _token) public onlyOwner {
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
    function setStableToken(address _stableToken) public onlyOwner {
        stableToken = _stableToken;
    }

    /// @notice Sets a new threshold filter for pricing.
    /// @dev Can only be called by an owner.
    /// @param _thresholdFilter The new threshold filter.
    function setThresholdFilter(uint256 _thresholdFilter) public onlyOwner {
        thresholdFilter = _thresholdFilter;
    }

    /// @notice Sets a new time window for posting prices.
    /// @dev Can only be called by an owner.
    /// @param _timeWindow The new time window.
    function setTimeWindow(uint256 _timeWindow) public onlyOwner {
        require(_timeWindow > 0, "Time window must be greater than 0");
        timeWindow = _timeWindow;
        emit TimeWindowSet(timeWindow);
    }

    /// @notice Fetches the price for a token.
    /// @param _token The token to fetch the price for.
    /// @return price The fetched price for the token.
    function fetchPrice(IERC20 _token) public view returns (uint256 price) {
        price = oracle.getRateWithCustomConnectors(_token, IERC20(stableToken), false, connectors, thresholdFilter);
    }

    /// @notice Fetches prices for a list of tokens.
    /// @param _tokens The tokens to fetch prices for.
    /// @return prices The fetched prices for the tokens.
    function fetchManyPrices(IERC20[] calldata _tokens) public view returns (uint256[] memory prices) {
        prices = oracle.getManyRatesWithCustomConnectors(_tokens, IERC20(stableToken), false, connectors, thresholdFilter);
    }

    /// @notice Records the price for a token.
    /// @dev Only callable by owners and keepers.
    /// @dev Emits a Price event and records it in storage.
    /// @param _token The token to store the price for.
    /// @param _price The price to store for the token.
    function storePrice(address _token, uint256 _price) public onlyOwnerOrKeeper {
        uint256 _timeWindow = timeWindow;
        uint256 timestamp = (block.timestamp / _timeWindow) * _timeWindow;
        storePrice(_token, _price, timestamp);
    }

    /// @notice Records the price for a token with a specific timestamp.
    /// @dev Only callable by owners and keepers.
    /// @dev Emits a Price event and records it in storage.
    /// @param _token The token to store the price for.
    /// @param _price The price to store for the token.
    /// @param _timestamp The timestamp to store the price at.
    /// @dev The timestamp should be a multiple of the time window.
    function storePrice(address _token, uint256 _price, uint256 _timestamp) public onlyOwnerOrKeeper {
        historicalPrices[_token][_timestamp] = _price;
        emit Price(_token, _price);
    }

    /// @notice Records prices for a list of tokens.
    /// @dev Only callable by owners and keepers.
    /// @dev Emits a Price event and records it in storage.
    /// @param _tokens The tokens to store prices for.
    /// @param _prices The prices to store for the tokens.
    function storeManyPrices(address[] calldata _tokens, uint256[] calldata _prices) public onlyOwnerOrKeeper {
        address token;
        uint256 price;
        uint256 _timeWindow = timeWindow;
        uint256 latestTimestamp = (block.timestamp / _timeWindow) * _timeWindow;
        for (uint i = 0; i < _tokens.length; i++) {
            token = _tokens[i];
            price = _prices[i];
            historicalPrices[token][latestTimestamp] = price;
            emit Price(token, price);
        }
    }

    /// @notice Returns most recent historical price for a token based on given timestamp.
    /// @param _token The token to return the price for.
    /// @param _timestamp The time to return the price at.
    function latest(address _token, uint256 _timestamp) public view returns (uint256) {
        return latest(_token, _timestamp, timeWindow);
    }

    /// @notice Returns most recent historical price for a token based on given timestamp and time window.
    /// @param _token The token to return the price for.
    /// @param _timestamp The time to return the price at.
    /// @param _timeWindow The time window to use for the timestamp.
    function latest(address _token, uint256 _timestamp, uint256 _timeWindow) public view returns (uint256) {
        return historicalPrices[_token][((_timestamp / _timeWindow) * _timeWindow)];
    }

    /// @notice Returns the most recent historical prices for multiple tokens based on given timestamps.
    /// @param entries Structs containing token addresses and timestamps to fetch the price for.
    /// @return prices The historial prices corresponding to the input entries.
    function latestMany(Entry[] calldata entries) public view returns (uint256[] memory) {
        uint256 _timeWindow = timeWindow;
        uint256[] memory prices = new uint256[](entries.length);
        for (uint256 i = 0; i < entries.length; i++) {
            address token = entries[i].token;
            uint256 timestamp = entries[i].timestamp;
            prices[i] = historicalPrices[token][((timestamp / _timeWindow) * _timeWindow)];
        }

        return prices;
    }
}