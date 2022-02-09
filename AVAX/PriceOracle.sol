pragma solidity ^0.8.5;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./libraries/Error.sol";


contract PriceOracle is Ownable {

    mapping (address => address) private tokenChainLinkAddress;
    mapping (address => AggregatorV3Interface) private tokenPrice;
    address[] private tokenAddresses;
    address[] private chainLinkAssetAddresses;
    int[] listOfAllTokenPrices;
    
    constructor(
        address[] memory _tokenAddresses,
        address[] memory _chainLinkAssetAddresses
    ) {
        tokenAddresses = _tokenAddresses;
        chainLinkAssetAddresses = _chainLinkAssetAddresses;
    } 

    function setTokenChainLinkAddress(address _newTokenAddress, address _newTokenChainLinkAddress) external onlyOwner returns(address) {
            tokenChainLinkAddress[_newTokenAddress] = _newTokenChainLinkAddress;
            return tokenChainLinkAddress[_newTokenAddress];
    }

    function getTokenChainLinkAddress(address _underlyingToken) external view returns (address) {
            return tokenChainLinkAddress[_underlyingToken];
    }

    function getTokenPrice(address _underlyingToken) external view returns (int) {
        (
            uint80 roundID, 
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = AggregatorV3Interface(_underlyingToken).latestRoundData();
        return price;
    }

    function setAllTokenChainLinkAddress(
        address[] memory _tokenAddresses,
        address[] memory _chainLinkAssetAddresses)
        external onlyOwner returns (address [] memory) {
            for(uint i=0; i<_tokenAddresses.length; i++) {
                tokenChainLinkAddress[_tokenAddresses[i]] = _chainLinkAssetAddresses[i];
            }
    }

    function getAllTokenPrices(address[] memory _tokenAddresses) 
        external returns (int[] memory) {
        int price;
        for (uint i=0; i<_tokenAddresses.length; i++) {
            price = this.getTokenPrice(_tokenAddresses[i]);
            listOfAllTokenPrices.push(price);
        }
        return listOfAllTokenPrices;
    }
}