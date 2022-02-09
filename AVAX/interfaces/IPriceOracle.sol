pragma solidity ^0.8.5;
pragma abicoder v2;

interface IPriceOracle {

    function setTokenChainLinkAddress(address _newTokenAddress, address _newTokenChainLinkAddress) external returns(address);

    function getTokenChainLinkAddress(address _underlyingToken) external returns (address);

    function getTokenPrice(address _underlyingToken) external returns (int);

    function setAllTokenChainLinkAddress(
        address[] memory _tokenAddresses,
        address[] memory _chainLinkAssetAddresses)
        external returns (address [] memory);

    function getAllTokenPrices(address[] memory _tokenAddresses) 
        external returns (int[] memory);
}