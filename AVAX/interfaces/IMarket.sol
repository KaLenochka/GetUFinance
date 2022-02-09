pragma solidity ^0.8.5;
pragma abicoder v2;

import "../libraries/DataTypes.sol";

interface IMarket {

    function deposit(
        address _underlyingToken, 
        address _user, 
        uint256 _amount) external returns (uint256);
    
    function withdraw(
        address _underlyingToken,
        address _user, 
        uint256 _amount) external returns (uint256);

    function getMarketData(address _underlyingToken) 
        external 
        returns (DataTypes.market_s memory);

    function repay(
        address _underlyingToken, 
        address _user, 
        uint256 _amount) external returns (uint256);

    function borrow(
        address _underlyingToken, 
        address _user, 
        uint256 _amount) external returns (uint256);
}