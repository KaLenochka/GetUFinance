pragma solidity ^0.8.5;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./DataTypes.sol";
import "./Math.sol";
import "../interfaces/IGToken.sol";
import "../interfaces/IDebtGToken.sol";
import "../interfaces/IPriceOracle.sol";
import "../interfaces/IVolumeOracle.sol";

library Logic {
    
    using SafeMath for uint256;
    using Math for uint256;

    function updateListOfUserMarkets(
        DataTypes.userMarket_s memory userMarketToCheck,
        DataTypes.userMarket_s[] memory _listOfMarketsToUpdate) 
        internal 
        pure 
        returns(DataTypes.userMarket_s[] memory){

        //check if the market exists in array, if not -> add it to the list of markets of use                
        uint256 lengthOfArray = _listOfMarketsToUpdate.length;
        bool marketExists = false;

        for(uint256 i=0; i<lengthOfArray; i++) {
            if (_listOfMarketsToUpdate[i].underlyingToken == userMarketToCheck.underlyingToken) {
                marketExists = true;
            }
        }
        
        if(marketExists == false) {
            _listOfMarketsToUpdate[lengthOfArray - 1] = userMarketToCheck;
        }
        return _listOfMarketsToUpdate;
    }

    //need to use structure to avoid Error: Stack too deep, try removing local variables.
    struct calculateUserDataLocalVars {
        uint256 totalDepositedTokens;
        uint256 totalBorrowedTokens;
        uint256 totalDepositedUSD;
        uint256 totalBorrowedUSD;
        uint256 borrowLimit;
        DataTypes.user_s userUpdatedInfoUSD; 
        DataTypes.userMarket_s userUpdatedInfoToken;
        DataTypes.userMarket_s[] listOfUserMarkets;
        uint256 lengthOfArray;
        bool marketExists;
    }

    struct calculateUserDataInputVars {
        address _user;
        address _underlyingToken;
        uint256 _totalDepositedTokens;
        uint256 _totalBorrowedTokens;
        uint256 _borrowLimit; 
        uint256 _depositedAmountOfTokens;
        uint256 _withdrawedAmountOfTokens;
        uint256 _borrowedAmountOfTokens;
        uint256 _repayedAmountOfTokens;
        uint256 _totalDepositedUSD;
        uint256 _totalBorrowedUSD;
        int _tokenPrice;
    }
    
    function calculateUserData(calculateUserDataInputVars memory inputVars) 
        internal 
        pure 
        returns(DataTypes.userMarket_s memory, DataTypes.user_s memory) {
        
        calculateUserDataLocalVars memory localVars;
        
        //calculate and update the amount of deposited/borrowed tokens
        localVars.totalDepositedTokens = inputVars._totalDepositedTokens
            .add(inputVars._depositedAmountOfTokens)
            .sub(inputVars._withdrawedAmountOfTokens);
        localVars.totalBorrowedTokens = inputVars._totalBorrowedTokens
            .add(inputVars._borrowedAmountOfTokens)
            .sub(inputVars._repayedAmountOfTokens);

        //calculate and update deposited/borrowed amount in USD
        localVars.totalDepositedUSD = inputVars._totalDepositedUSD
            .add(inputVars._depositedAmountOfTokens.mul(uint256(inputVars._tokenPrice)))
            .sub(inputVars._withdrawedAmountOfTokens.mul(uint256(inputVars._tokenPrice)));
        localVars.totalBorrowedUSD = inputVars._totalBorrowedUSD
            .add(inputVars._borrowedAmountOfTokens.mul(uint256(inputVars._tokenPrice)))
            .sub(inputVars._repayedAmountOfTokens.mul(uint256(inputVars._tokenPrice)));

        //calculate and update borrow limit of user
        localVars.borrowLimit = inputVars._borrowLimit; //??? what formula has to be used ???
        
        //initiate the new instance of the struct userMarket_s
        localVars.userUpdatedInfoToken = DataTypes.userMarket_s(
            inputVars._underlyingToken, 
            localVars.totalDepositedTokens, 
            localVars.totalBorrowedTokens, 
            true);
        /**
        //check if the market exists in array, if not -> add it to the list of markets of user
        localVars.listOfUserMarkets;
        localVars.lengthOfArray = localVars.listOfUserMarkets.length;
        localVars.marketExists = false;

        for(uint256 i=0; i<localVars.lengthOfArray; i++) {
            if (localVars.listOfUserMarkets[i].underlyingToken == inputVars._underlyingToken) {
                localVars.marketExists = true;
            }
        
        if(localVars.marketExists == false) {
            localVars.listOfUserMarkets[localVars.lengthOfArray - 1] = localVars.userUpdatedInfoToken;
            }
        }
         */

        //initiate the new instance of the struct user_s
        localVars.userUpdatedInfoUSD = DataTypes.user_s(
            inputVars._user,
            localVars.listOfUserMarkets,
            localVars.totalDepositedUSD,
            localVars.totalBorrowedUSD,
            localVars.borrowLimit
        );    

        return (localVars.userUpdatedInfoToken, localVars.userUpdatedInfoUSD);
    }
    
    /// @notice calculates and updates the amount of deposited tokens
    /// @param _totalDepositedUSD whole amount of deposited USD before updating
    /// @param _depositedAmountOfTokens amount of tokens, which user deposits
    /// @param _tokenPrice price of underlying token to make calculations, 
    /// @return returns whole updated sum of deposited USD in market
    function calculateMarketDeposit(
        uint256 _totalDepositedUSD, 
        uint256 _depositedAmountOfTokens, 
        int _tokenPrice) internal pure returns(uint256) {

        //calcutate and update the whole deposited amount in USD 
        uint256 totalDepositedUSD = _totalDepositedUSD
            .add(_depositedAmountOfTokens.mul(uint256(_tokenPrice)));

        return (totalDepositedUSD);
    }

    /// @notice calculates and records to the struct userMarket_s amount of deposited tokens
    /// and to the struct market_s the amount of the whole deposited USD
    /// @param _totalDepositedUSD whole amount of deposited USD before updating
    /// @param _withdrawedAmountOfToken amount of tokens, which user withdraws
    /// @param _tokenPrice price of underlying token to make calculations
    /// @return returns whole updated sum of deposited USD in market
    function calculateMarketWithdraw(
        uint256 _totalDepositedUSD,
        uint256 _withdrawedAmountOfToken, 
        int _tokenPrice) internal pure returns (uint256) {
        
        //calcutate and update the whole deposited amount in USD 
        uint256 totalDepositedUSD = _totalDepositedUSD
            .sub(_withdrawedAmountOfToken.mul(uint256(_tokenPrice)));
    
        return (totalDepositedUSD);
    }

    /// @notice calculates and updates whole amount of borrowed USD
    /// @param _totalBorrowedUSD whole amount of borrowed USD before updating
    /// @param _borrowedAmountOfToken amount of tokens, which user borrows
    /// @param _tokenPrice price of underlying token to make calculations, 
    /// @return returns whole updated sum of borrowed USD in market
    function calculateMarketBorrow(
        uint256 _totalBorrowedUSD, 
        uint256 _borrowedAmountOfToken, 
        int _tokenPrice) internal pure returns (uint256) {

        //calcutate and update the whole deposited amount in USD 
        uint256 totalBorrowedUSD = _totalBorrowedUSD
            .add(_borrowedAmountOfToken.mul(uint256(_tokenPrice)));

        return (totalBorrowedUSD);
    }

    /// @notice calculates and updates the whole amount of the borrowed USD
    /// @param _totalBorrowedUSD whole amount of borrowed USD before updating
    /// @param _repayedAmountOfToken amount of tokens, which user repays
    /// @param _tokenPrice price of underlying token to make calculations, 
    /// we take it from the Market function updateMarketRepay
    /// @return returns two amounts: borrowed tokens of user and whole sum of borrowed USD in market
    function calculateMarketRepay(
        uint256 _totalBorrowedUSD, 
        uint256 _repayedAmountOfToken, 
        int _tokenPrice) internal pure returns (uint256) {

        //calcutate and update the whole deposited amount in USD
        uint256 totalBorrowedUSD = _totalBorrowedUSD
            .sub(_repayedAmountOfToken.mul(uint256(_tokenPrice)));

        return (totalBorrowedUSD);
    }

    //Update state of distribution interests
    function calculateInterestRates() internal pure returns(uint256) {
        return 0;
    }

    /// @dev calculates the amount of collateral balance in USD, user has
    /// @param userInfoUSD struct user_s for user to know his collateral balance
    /// @return returns the total collateral balance in USD 
    function calculateUserCollateralBalance(DataTypes.user_s memory userInfoUSD) 
        external 
        returns(uint256) {

        IPriceOracle iPriceOracle;
        
        //takes struct user_s from mapping userData according to user address
        uint256 totalColateralBalance = 0;
        
        //if balance is collateral, add it to amount of USD to borrow
        for (uint256 i=0; i<userInfoUSD.listOfUserMarket.length; i++ ) {
            //apply to the struct userMarket_s with the help of listOfUserMarket from strust user_s
            if(userInfoUSD.listOfUserMarket[i].isUsedAsCollateral){
                int tokenPrice = iPriceOracle.getTokenPrice(userInfoUSD.listOfUserMarket[i].underlyingToken);                
                totalColateralBalance = totalColateralBalance
                .add(userInfoUSD.listOfUserMarket[i].totalDeposits.mul(uint256(tokenPrice)));
            }
        }
        return totalColateralBalance;
    }

    /// @dev count user HealthRate    
    /// @param _user address of user
    /// @param _collateralBalance all collateral balance of user in USD
    /// @param _totalBorrows whole amount of borrowed tokens in USD
    /// @return returns user HealthRate
    function calculateUserHealthRate(address _user, uint256 _collateralBalance, uint256 _totalBorrows) internal returns(uint256) {
        //∑Collateral in USD x Avarage Liquidation Coefficient/Total Borrows in USD
        uint avarageLiquidationCoefficient;
        return (_collateralBalance.mul(avarageLiquidationCoefficient)).div(_totalBorrows);
    }
    
    /// @return returns if the deposited tokens are collateral from the struct userMarket_s
    /// _isCollateral will take from the mapping userMarket
    function checkCollateralStatus(bool _isCollateral) internal pure returns (bool) {
        return _isCollateral;
    }


    function calculateLiquidationValue(
        uint256 _userTotalBorrow, 
        uint256 _amountToRepayByUser, 
        uint256 _interestOfLiquidation) internal returns(uint256) {
        /**
B0t- current user borrow value (amount of debtGTokens on user balance)
cl - coefficient of borrow liquidation (up to 50%)
ia-additional bonus interest of liquidation (pre setuped) 
         */
        uint256 coefficientOfLiquidation = _amountToRepayByUser.div(_userTotalBorrow).mul(100);
            return coefficientOfLiquidation.mul(_userTotalBorrow.mul(_interestOfLiquidation.add(1)));

    }

    /// @dev check all requires to let user deposit tokens
    /// @param _underlyingToken address of underlying token to deposit
    /// @param _market address of market of underlying tokens user whants to deposit
    /// @param _user address of user who deposits
    /// @param _amount amount of tokens to deposit
    /// @return returns true if all requires are true
     function verifyDeposit(
         address _underlyingToken, 
         address _market, 
         address _user, 
         uint256 _amount) internal view returns(bool){  
        
        //The amount to deposit has to be >0 
        require(_amount > 0,
        "Amount must be > 0");     

        //User address has to exist
        require(_user != address(0),
        "User doesn't exists");

        //Check user underlying token balance
        require(IERC20(_underlyingToken).balanceOf(_user) >= _amount, 
        'Insufficient balance for the operation!');

        //Check does market exist
        require(_market != address(0),
        "Market doesn't exists");

        return true;
    }

    /// @dev check all requires to let user withdraw tokens
    /// @param _market address of market of underlying token which user wants to withdraw
    /// @param _underlyingToken address of underlying tokens to withdraw
    /// @param _reserves address of reserves in underlying tokens which user withdraws
    /// @param _user address of user who withdraws
    /// @param _amount amount of tokens to withdraw
    /// @param _healthRate calculated factor of 'health' of user, his ability to withdraw
    /// @param _totalCollateral amount of total collateral of user in usd
    /// @param _totalBorrow amount of total borrows of user in usd
    /// @param _borrowLimitIndex borrow limit index is predefined
    /// @param _isUsedAsCollateral bool if the market of tokens to withdraw is used as collateral
    /// @return returns true if all requires are true
    function verifyWithdraw(
        address _market,
        address _underlyingToken, 
        address _reserves, 
        address _user, 
        uint256 _amount,
        uint256 _healthRate,        
        uint256 _totalCollateral,
        uint256 _totalBorrow,
        uint256 _borrowLimitIndex,
        bool _isUsedAsCollateral) internal view returns(bool) {        
        
        //Amount to borrow has to be >0
        require(_amount > 0,
        "Amount must be > 0");     

        //User address has to exist
        require(_user != address(0),
        "User doesn't exists");
 
        //Check user gToken balance, if not enough -> revert
        require(IGToken(_underlyingToken).balanceOfGToken(_user) >= _amount,
        "Insufficient balance of GToken for the operation!");

        //Reserve available liquidity is enought -> if not: revert
        require(IERC20(_underlyingToken).balanceOf(_reserves) >= _amount, 
        "Insufficient balance of reserves for the operation!");

        //Check if the market exists
        require(_market != address(0), 
        "Market doesn't exist");

        //User health factor is above 1, if not -> revert
        require(_healthRate > 1,
        "Your health factor is not enough to borrow!");

        //Check borrow limit - has to be within the permitted limits after withdrawing 
        //TODO if market is used like collateral -> amount <= TotalCollateral-TotalBorrow/borrowLimitIndex 
        //_borrowLimit; //??? what formula has to be used ???
        if(_isUsedAsCollateral){
            require(_amount <= _totalCollateral.sub((_totalBorrow.div(_borrowLimitIndex))), 
            "Amount to withdraw is more than user borrow limit!");
        }
        return true;
    }

    /// @dev check all requires to let user borrow tokens
    /// @param _underlyingToken address of underlying tokens to borrow
    /// @param _market address of market of underlying tokens to borrow
    /// @param _reserves address of reserves in underlying tokens which user borrows
    /// @param _amount amount of tokens to borrow
    /// @param _collateralBalance calculated collateral balance of user
    /// @param _healthRate calculated factor of 'health' of user, his ability to borrow
    /// @return returns true if all requires are true
    function verifyBorrow(
        address _user,
        address _market, 
        address _underlyingToken, 
        address _reserves, 
        uint256 _amount,
        uint256 _collateralBalance,
        uint256 _healthRate) internal view returns(bool) {

        //Amount to borrow has to be >0
        require(_amount > 0,
        "Amount must be > 0");     

        //Does user exist
        require(_user != address(0),
        "User doesn't exists");
        
        //Check if the market exists
        require(_market != address(0), 
        "Market doesn't exist");

        //Market has enough reserves, if not -> revert
        require(IERC20(_underlyingToken).balanceOf(_reserves) >= _amount, 
        "Insufficient balance of reserves for the operation!");

        //User collateral balance is enough, if not -> revert
        require(_collateralBalance <= _amount, 
        "Insufficient collateral balance for the operation!");
        
        //User health factor is above 1, if not -> revert
        require(_healthRate > 1,
        "Your health factor is not enough to borrow!");

        //??? if First borrow -> Add market to distribution record for accounting interest ???

        return true;
    }

    /// @dev check all requires to let user repay tokens
    /// @param _totalBorrow amount of total borrow of user in underlying token
    /// @param _market address of market of underlying tokens to repay
    /// @param _user address of user wallet
    /// @param _amount amount of tokens to repay
    /// @param _healthRate calculated factor of 'health' of user, his ability to borrow    
    /// @return returns true if all requires are true
    function verifyRepay(
        uint256 _totalBorrow, 
        address _market, 
        address _user, 
        uint256 _amount,
        uint256 _wholeAmountToRepay,
        uint256 _healthRate) internal view returns(bool) {

        //Amount to repay has to be >0
        require(_amount > 0,
        "Amount must be > 0");     

        //User address has to exist
        require(_user != address(0),
        "User doesn't exists");

        //Check do user has borrow, if not -> Revert
        require(_totalBorrow > 0, 
        "User doesn't have borrow!");

        //User health factor is above 1, if not -> revert
        require(_healthRate > 1,
        "Your health factor is not enough to borrow!");

        //Repay amount <= borrow + reserveFactor -> Update fee (reserveFactor) amount
        require(_amount <= _wholeAmountToRepay, "Amount ot repay is bigger than total borrow amount!");
        
        //Total borrow sum + fee for using loan == amount of DebtGTokens
        //Repay amount = debtGToken balance
        require(IDebtGToken(_market).balanceOfDebtGToken(_user) == _wholeAmountToRepay,
        "Insufficient balance of DebtGToken! It doesn't equal to the sum to repay!");

        //require(debtGToken.balanceOf(_user) >= _amount, 
        require(IDebtGToken(_market).balanceOfDebtGToken(_user) >= _amount,
        "Insufficient balance of DebtGToken for the operation!");

        //Verify borrow
        require(_market != address(0), 
        "Market doesn't exist");

        return true;
    }

    /// @param _owner the address of user who wants to liquidate 
    /// @param _healthRate of borrower
    /// @param _reserves address of reserves of underlying token of asset from borower collateral, which user want to take
    /// @param _underlyingToken underlying token address of asset from borower collateral, which user want to take
    /// @param _amountToRepay amount of debtGToken user wants to repay for borrower
    /// @param _valueToPayUser amount of underlying token(gToken) to pay user
    function verifyLiquidation(
        address _owner, 
        uint256 _healthRate, 
        address _reserves, 
        address _underlyingToken,
        uint256 _amountToRepay,
        uint256 _valueToPayUser,
        uint256 _liquidationBorrowerValue,
        uint256 _collateralBalance) internal view returns(bool) {

        //Validate caller, caller = owner
        require(_owner == msg.sender, "Only owner can liquidate");

        //Borrow is in liquidation status (health rate < 1), if not -> revert
        require(_healthRate < 1, "Your health rate is not < 1!");

        //Amount to repay has to be less then 50% of liquidation value of borrower
        require(_amountToRepay <= _liquidationBorrowerValue.div(2), 
        "Amount can not be above 50% of the principle!");

        //The user has collateral the caller wants to, if not -> revert
        require(_collateralBalance >= _valueToPayUser, 
        "The borrower doesn't have enaught collateral!");

        //Check borrowing asset reserve balance, if it enaugh to pay to user
        require(IERC20(_underlyingToken).balanceOf(_reserves) >= _valueToPayUser); 

        return true;
    }

    /// @param _underlyingToken underlying Token to calculate factor 
    /// @param _volumeOracleContract address of volumeOracleContract
    /// @param _totalMarketDeposit amount of deposits in market
    /// @param _totalMarketBorrows amount of borrows in market
    /// @param _totalValueOfMarketReserves amount of gToken of underlying token 
    /// @param _GetUReserves amount of reserves of underlying token market
    /// @return the reserveBorrowFactor
    function calculateReserveBorrowFactor(
        address _underlyingToken,
        address _volumeOracleContract,
        uint256 _totalMarketDeposit, //D
        uint256 _totalMarketBorrows, //B
        uint256 _totalValueOfMarketReserves, //C C- balance gToken of underlying token
        uint256 _GetUReserves //Cp C_p - balance reserve by underlying token      
        ) internal returns (uint256) {
        /**
Rf-Reserve factor, GetU protocol reserve interest
M-Market index based on avarage mantisa of market for last time period
V- Asset Volume for last 24 hours (GetU.Finance volume oracle updates every block)
D- Total Market Deposits
B- Total Market Borrows
C- Total value of Market underlying token in Market reserves //C C- balance gToken of underlying token
Cp- GetU Reserves, Protocol historical market income  //Cp C_p - balance reserve by underlying token
i0- base interst      
*/      
        
        //IVolumeOracle.volume_s memory assetVolume;

        uint256 marketIndexMantissa;
        IVolumeOracle.volume_s memory assetVolume = IVolumeOracle(_volumeOracleContract).getVolume(_underlyingToken);
        uint256 baseInterest = marketIndexMantissa.divWad(assetVolume.volumeUSD);        

        uint256 reserveBorrowFactor = (SafeMath.add(1, baseInterest))
            .mulWad(
            ((_totalValueOfMarketReserves.add(_totalMarketBorrows)).sub(_GetUReserves))
            .divWad(_totalMarketDeposit)
            );    
        
        return reserveBorrowFactor;
    }

     function calculateReserveDepositFactor(
        uint256 reserveBorrowFactor, //Rb                
        uint256 totalMarketDeposit, //D
        uint256 totalMarketBorrows //B
        ) internal pure returns (uint256) {  

        uint256 reserveFactor; //predefined        

        uint256 reserveDepositFactor = (totalMarketBorrows.divWad(totalMarketDeposit))
            .mulWad(reserveBorrowFactor)
            .mulWad(SafeMath.sub(1, reserveFactor)); 

        return reserveDepositFactor;
    }

        
}