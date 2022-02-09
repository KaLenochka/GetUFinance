pragma solidity ^0.8.5;
pragma abicoder v2;


interface IVolumeOracle {

    struct volume_s {
        uint volumeUSD;
        uint volumeNumber;
    }

    function setVolume(
        address _underlyingTokenAddress, 
        uint _volumeUSD, 
        uint _volumeNumber) external returns (volume_s memory);

    function getVolume(address _underlyingTokenAddress) external view returns (volume_s memory);

    function getAllVolumes(address[] memory _tokenAddresses) external returns (volume_s[] memory);

    function setVolumeOracle(address _oracleAddress) external returns (address);

    function getVolumeOracle() external returns (address);
}