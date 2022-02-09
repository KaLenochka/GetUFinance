pragma solidity ^0.8.5;
pragma abicoder v2;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IMarket.sol";
import "./libraries/Error.sol";


contract Controller is Ownable {

    constructor() {}
        
    address private marketAddress;

    function setMarketAddress(address _marketAddress) external onlyOwner returns (address) {
        marketAddress = _marketAddress;
        return marketAddress;
    }

    function getMarketAddress () external view returns (address) {
        return marketAddress;
    }

    function createTokenMarket(
        address _underlyingToken, 
        address _gToken,
        address _debtgToken,
        address _reserves) external onlyOwner returns (address) {
            //IMarket.createMarket(_underlyingToken, _gToken, _debtgToken, _reserves);
            return marketAddress;
    } 

    function updateTokenMarket(
        address _underlyingToken, 
        address _gToken,
        address _debtgToken,
        address _reserves) external onlyOwner returns (address) {
            //IMarket.updateMarket(_underlyingToken, _gToken, _debtgToken, _reserves);
            return marketAddress;
    } 

    function deleteTokenMarket(address _underlyingToken) external onlyOwner returns (address) {
        //IMarket.deleteMarket(_underlyingToken);
        return address(0);
    } 
}