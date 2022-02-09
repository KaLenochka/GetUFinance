pragma solidity ^0.8.5;
pragma abicoder v2;


import "./interfaces/IMarket.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract WAVAXGateway is Ownable {
    using SafeMath for uint256; 

    string public name = 'Wrapped Avalanche';
    string public symbol = 'WAVAX';
    uint8 public decimals = 18;
    address WAVAX;

    //event Approval(address indexed src, address indexed guy, uint256 wad);
    //event Transfer(address indexed src, address indexed dst, uint256 wad);
    //event Deposit(address indexed dst, uint256 wad);
    //event Withdrawal(address indexed src, uint256 wad);

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    /// @dev sets the WAVAX address 
    /// @param _wavax Address of the Wrapped Avalanche contract
    constructor(address _wavax) {
        WAVAX = _wavax;
    }
    
    /// @dev admits market maximum amount
    /// @param _underlyingTokenMarket address of underlying market to admit the amount
    /// @param _maxAmount amount to admit for the market
    /// @return true if the amount admited successfully
    function admitMarket(address _underlyingTokenMarket, uint256 _maxAmount) 
        external 
        onlyOwner 
        returns(bool) {

        allowance[msg.sender][_underlyingTokenMarket] = _maxAmount;
        //emit Approval(msg.sender, _underlyingTokenMarket, _maxAmount;
        return true;
    }

    /// @dev deposits WAVAX into the reserve, using native AVAX. 
    ///A corresponding amount of the overlying asset (gTokens) is minted.
    /// @param _underlyingTokenMarket address of the targeted underlying market
    /// @param _reciever address of the user who will receive 
    /// the gTokens representing the deposit
    /// @return true if deposit successful   
    function depositAVAX(    
        address _underlyingTokenMarket,
        address _reciever
        ) external payable returns(bool) {

        balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
        //emit Deposit(msg.sender, msg.value);     
        IMarket(_underlyingTokenMarket).deposit(WAVAX, _reciever, msg.value);

        return true; 
    }
    
    /// @dev withdraws the WAVAX _reserves of msg.sender.
    /// @param _underlyingTokenMarket address of the targeted underlying market
    /// @param _amountToWithdraw amount of gWAVAX to withdraw and receive native AVAX
    /// @param _to address of the user who will receive native AVAX   
    /// @return true if withdraw successful
    function withdrawAVAX(
        address _underlyingTokenMarket,
        uint256 _amountToWithdraw,
        address _to
        ) external payable returns(bool) {
            
        IMarket(_underlyingTokenMarket).withdraw(_underlyingTokenMarket, _to, _amountToWithdraw);
        require(balanceOf[msg.sender] >= _amountToWithdraw, "Insufficient balance for the withdrawing!");
        balanceOf[msg.sender] = balanceOf[msg.sender].sub(msg.value);        
        //emit Withdrawal(msg.sender, _amountToWithdraw);  
        return true;      
    }
    
    /// @dev repays a borrow on the WAVAX reserve, for the specified amount 
    /// @param _underlyingTokenMarket address of the targeted underlying market
    /// @param _amountToRepay the amount to repay    /
    /// @param _reciever the address for which msg.sender is repaying
    /// @return true if repay successful
    function repayAVAX(
    address _underlyingTokenMarket,
    uint256 _amountToRepay,   
    address _reciever
    ) external payable returns(bool) {
    
        require(msg.value >= _amountToRepay, 'msg.value is less than repayment amount');

        balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
        //emit Deposit(msg.sender, msg.value);     
        IMarket(_underlyingTokenMarket).repay(WAVAX, _reciever, msg.value);
        return true;
    }

    /// @dev borrow WAVAX, unwraps to AVAX and send both the AVAX and DebtGTokens to msg.sender, via Market.borrow
    /// @param _underlyingTokenMarket address of the targeted underlying market
    /// @param _amountToBorrow the amount of AVAX to borrow
    /// @return true if borrow successful
    function borrowAVAX(
    address _underlyingTokenMarket,
    uint256 _amountToBorrow
    ) external payable returns (bool) {
        IMarket(_underlyingTokenMarket).repay(WAVAX, msg.sender, _amountToBorrow);

        require(balanceOf[msg.sender] >= _amountToBorrow, "Insufficient balance for the borrowing!");
        balanceOf[msg.sender] = balanceOf[msg.sender].sub(msg.value);        
        //emit Withdrawal(msg.sender, _amountToBorrow);
        return true;
    }

    /// @dev transfer ERC20 from the utility contract, for ERC20 recovery in case of stuck tokens due
    /// direct transfers to the contract address.
    /// @param _tokenERC20 token to transfer
    /// @param _to recipient of the transfer
    /// @param _amount amount to send    
    /// @return true if transfer successful
    function forcedTokenTransfer(
    address _tokenERC20,
    address _to,
    uint256 _amount
    ) external onlyOwner returns(bool) {
    IERC20(_tokenERC20).transfer(_to, _amount);
    }
    
    /// @dev Get WETH address used by WETHGateway
    function getWAVAXAddress() external view returns (address) {
        return address(WAVAX);
    }
    
    /// @dev Only WAVAX contract is allowed to transfer AVAX here. 
    ///Prevent other addresses to send Avax to this contract.
    receive() external payable {
        require(msg.sender == address(WAVAX), 'Receive not allowed');
    }

    /// @dev Revert fallback calls
    fallback() external payable {
        revert('Fallback not allowed');
    }
}