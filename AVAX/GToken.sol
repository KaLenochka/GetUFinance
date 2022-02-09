pragma solidity ^0.8.5;
pragma abicoder v2;

import "./interfaces/IMarket.sol";
import "./libraries/Error.sol";
import "./libraries/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract GToken is ERC20 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    
    IMarket internal _market;    
    address internal _underlyingToken;    
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;     

    constructor(
        IMarket market,
        address underlyingToken,
        string memory gTokenName,
        string memory gTokenSymbol,
        uint8 gTokenDecimals) ERC20(gTokenName, gTokenSymbol) {
            _market = market;
            _underlyingToken  = underlyingToken;
            _name = gTokenName;
            _symbol = gTokenSymbol;
            _decimals = gTokenDecimals;
    }

    //ERC20 erc20 = new ERC20(_name, _symbol);

    modifier onlyMarket {
        require(msg.sender == address(_market), "Caller must be Market!");
        _;
    }

    /// @return the name of the token
    function getName() public view returns (string memory) {
        return _name;
    }

    /// @return the symbol of the token   
    function getSymbol() public view returns (string memory) {
        return _symbol;
    }

    /// @return the decimals of the token   
    function getDecimals() public view returns (uint8) {
        return _decimals;
    }

    /// @return the total emition of the token   
    function getTotalSupply() public view returns (uint256) {
        return totalSupply();
    }

    function getTheBalanceOfContractGToken() external view returns(uint256) {
        return address(this).balance;
    }

    /// @dev returns the address of the underlying token of this GToken  
    function underlyingTokenAddress() public view returns (address) {
        return _underlyingToken;
    }

    /// @return The balance of the token
    function balanceOfGToken(address _user) external view returns (uint256) {
        require(_user != address(0), "You try to get the balance of the zero address");
            return balanceOf(_user);
    }
        
    /// @dev Returns the address of the lending pool where this GToken is used   
    function marketAddress() public view returns (IMarket) {
        return _market;
    }    

    /// @dev moves `amount` tokens from the caller's account to `recipient`. Emits a {Transfer} event.
    /// @return a boolean value indicating whether the operation succeeded.
    function transferGToken(address _to, uint256 _amount) external returns(bool) {
        require(_to != address(0), "The address of reciever doesn't exist");
        require(_amount != 0, "You try to transfer zero tokens!");

        transfer(_to, _amount);
            return true;
    }
     

    /// @dev mints '_amount' of GTokens to the _user address, increases the amount of total emition,
    /// sends the equivalent amount of underlying to reserves     
    /// @param _user The address receiving the minted tokens
    /// @param _amount The amount of tokens getting minted    
    /// @return `true` if the the previous balance of the user was 0
    function mintGToken(address _user, uint256 _amount) external onlyMarket returns (bool) {        
        require(_amount != 0, "You try to mint zero tokens!");
        _mint(_user, _amount);        
            return true;
    }                
    
   /// @dev burns GTokens from `_user` and sends the equivalent amount 
   ///of underlying to `_sendUnderlyingTo`. Only callable by the Market
   /// @param _user The owner of the GTokens, getting them burned   
   /// @param _sendUnderlyingTo The address that will receive the underlying
   /// @param _amount The amount being burned
    function burnGToken(
        address _user,        
        address _sendUnderlyingTo,
        uint256 _amount) external onlyMarket returns (bool) {

        require(_user != address(0), "Burn from the zero address");
        require(_amount != 0, "You try to burn zero tokens!");        
        require(_sendUnderlyingTo != address(0), "You try to send underlying tokens to the zero address");
        require(IERC20(this).balanceOf(_user) >= _amount, "You don't have enough tokens to burn");

        _burn(_user, _amount);
        
        SafeERC20.safeTransferFrom(
            IERC20(_underlyingToken), 
            _user, 
            _sendUnderlyingTo, 
            _amount);   

            return true;   
    }

    /// @dev Transfers GTokens in the event of a borrow being liquidated, in case the liquidators reclaims the GToken
    /// - only callable by the Market
    /// @param _from The address getting liquidated, current owner of the GTokens
    /// @param _to The recipient
    /// @param _amount The amount of tokens getting transferred  
    function transferOnLiquidation(
        address _from,
        address _to,
        uint256 _amount
        ) external onlyMarket returns(bool) {        
            _transfer(_from, _to, _amount);
                return true;
    }    
}