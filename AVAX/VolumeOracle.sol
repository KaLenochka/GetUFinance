pragma solidity ^0.8.5;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";

contract VolumeOracle is Ownable {

    constructor() {}

    mapping (address => volume_s) tokenData; // underlyingTokenAddress => volume_s, map of all tokens with data
    address volumeOracleAddress; // Volume Oracle Address
    uint lastUpdateTimestamp;

    struct volume_s {
        uint volumeUSD;
        uint volumeNumber;
    }

    volume_s[] listOfVolumes;

    //set Volumes of tokenes both in USD and number
    function setVolume(
        address _underlyingTokenAddress, 
        uint _volumeUSD, 
        uint _volumeNumber) external onlyOwner returns (volume_s memory) {
            tokenData[_underlyingTokenAddress].volumeUSD = _volumeUSD;
            tokenData[_underlyingTokenAddress].volumeNumber = _volumeNumber;
            return tokenData[_underlyingTokenAddress];
    } 

    //return token volume by underlying token address
    function getVolume(address _underlyingTokenAddress) external view returns (volume_s memory) {
        return tokenData[_underlyingTokenAddress];
    } 

    //return all tokens volumes
    function getAllVolumes(address[] memory _tokenAddresses) external returns (volume_s[] memory) {
        //volume_s[] memory listOfVolumes;

        for (uint i=0; i<_tokenAddresses.length; i++) {
            listOfVolumes.push(tokenData[_tokenAddresses[i]]);
        }
        return listOfVolumes; 
    } 

    //set volume Oracle address, only Owner
    function setVolumeOracle(address oracleAddress) external onlyOwner returns (address) {
        volumeOracleAddress = oracleAddress;
        return volumeOracleAddress;
    } 

    //get volume oracle address
    function getVolumeOracle() external view returns (address) {
        return volumeOracleAddress;
    } 
}