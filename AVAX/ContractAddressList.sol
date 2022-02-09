pragma solidity ^0.8.5;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ContractAddressList is Ownable {

    address controller;
    address market;
    address priceOracle;
    address volumeOracle;
    address distributor;
    address staking;
    
    constructor(
        address _controller,
        address _market,
        address _priceOracle,
        address _volumeOracle,
        address _distributor,
        address _staking        
    ) {
        controller = _controller;
        market = _market;
        priceOracle = _priceOracle;
        volumeOracle = _volumeOracle;
        distributor = _distributor;
        staking = _staking;
    }

    function setDistributorAddress(address distributorAddress) public onlyOwner returns (address) {
        distributor = distributorAddress;
            return distributor;
    }

    function getDistributorAddress() external returns (address) {
        return distributor;
    }

    function setStakingAddress(address stakingAddress) public onlyOwner returns (address) {
        staking = stakingAddress;
            return staking;
    }

    function getStakingAddress() external returns (address) {
        return staking;
    }
 
    function setControllerAddress(address controllerAddress) public onlyOwner returns (address) {
        controller = controllerAddress;
            return controller;
    }

    function getControllerAddress() external returns (address) {
        return controller;
    }

    function setMarketAddress(address marketAddress) public onlyOwner returns (address) {
        market = marketAddress;
            return market;
    }

    function getMarketAddress() external returns (address marketAddress) {
        return market;
    }

    function setPriceOracleAddress(address priceOracleAddress) public onlyOwner returns (address) {
        priceOracle = priceOracleAddress;
            return priceOracle;
    }

    function getPriceOracleAddress() external returns (address) {
        return priceOracle;
    }

    function setVolumeOracleAddress(address volumeOracleAddress) public onlyOwner returns (address) {
        volumeOracle = volumeOracleAddress;
            return volumeOracle;
    }

    function getVolumeOracleAddress() external returns (address) {
        return volumeOracle;
    }
}