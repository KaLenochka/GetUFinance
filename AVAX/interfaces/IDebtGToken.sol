pragma solidity ^0.8.5;
pragma abicoder v2;


interface IDebtGToken {
    
    function getTheBalanceOfContractDebtGToken() external view returns(uint256);

    function balanceOfDebtGToken(address _user) external view returns (uint256);

    function mintDebtGToken(address _user, uint256 _amount) external returns (bool);

    function burnDebtGToken(
        address _user,        
        uint256 _amount) external returns (bool);
}