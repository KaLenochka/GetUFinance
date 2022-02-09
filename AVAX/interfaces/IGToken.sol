pragma solidity ^0.8.5;
pragma abicoder v2;


interface IGToken {

    function getTheBalanceOfContractGToken() external view returns(uint256);
    
    function balanceOfGToken(address _user) external view returns (uint256);

    function transferGToken(address _to, uint256 _amount) external returns(bool);

    function mintGToken(address _user, uint256 _amount) external returns (bool);

    function burnGToken(
        address _user,        
        address _sendUnderlyingTo,
        uint256 _amount) external returns (bool);

    function transferOnLiquidation(
        address _from,
        address _to,
        uint256 _amount) external returns(bool);
}