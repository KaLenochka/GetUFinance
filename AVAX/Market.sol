pragma solidity ^0.8.5;
pragma abicoder v2;


import "./interfaces/IPriceOracle.sol";
import "./interfaces/IGToken.sol";
import "./interfaces/IDebtGToken.sol";
import "./interfaces/IVolumeOracle.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./libraries/Math.sol";
import "./libraries/Error.sol";
import "./libraries/Logic.sol";
import "./libraries/DataTypes.sol";



contract Market is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    constructor(
        address _controller, 
        address _priceOracle, 
        address _volumeOracle, 
        address _distributor) {
            controllerAddress = _controller;
            priceOracleAddress = _priceOracle;
            volumeOracleAddress = _volumeOracle;
            distributorAddress = _distributor;
        }

    address[] listOfMarkets; //list of all markets
    mapping(address => mapping (address=>DataTypes.userMarket_s)) userMarket; // list of markets, where user has funds (userAddress => (underlyingToken=>userMarket_s))
    mapping(address => DataTypes.market_s) underlyingTokenMarket; //market details ((underlyingToken => market_s))
    mapping(address => DataTypes.user_s) userData; //user data ((userAddress => user_s))
    address controllerAddress; //address of controller contract
    address priceOracleAddress; //address of price oracle contract
    address volumeOracleAddress; //address of volume oracle
    address distributorAddress; //address of token distributor address
    uint256 borrowLimitIndex; 
    uint256 reserveFactor; //predefined amount of fee

    
    //event NewDistributor ();
    //event NewController ();
    //event NewPriceOracle ();
    //event AssetPrice ();
    //event NewVolumeOracle ();
    //event AssetVolume ();


    /*Distributor functions*/

    //update distributor address
    function setDistributorAddress(address _newDistributorAddress) external onlyOwner returns (address) { //onlyOwner 
        distributorAddress = _newDistributorAddress;
        //emit NewDistributor();
        return distributorAddress;
    }

    //return distributor address
    function getDistributor() external view returns (address){
        return distributorAddress;
    } 

    //Start GETU distribution
    function startDistribute() internal {}

    //Finish GETU distribution
    function stopDistribute() internal {}
    
    /*Controller functions*/

    //update controller address
    function setController(address _newControllerAddr) external onlyOwner returns (address) { //onlyOwner
        controllerAddress = _newControllerAddr;
        //emit NewController();
        return controllerAddress;
    } 

    //return controller address
    function getController() external view returns (address) {
        return controllerAddress;
    } 

    /*Price Oracle Functions*/

    //update price oracle address
    function setPriceOracle(address _newPriceOracleAddr) external onlyOwner returns (address) { //onlyOwner 
        priceOracleAddress = _newPriceOracleAddr;
        //emit NewPriceOracle();
        //emit AssetPrice();
        return priceOracleAddress;
    } 

    //get price oracle
    function getPriceOracle() external view returns (address) {
        return priceOracleAddress;
    } 

    //get asset price from Chainlink oracle
    function getAssetPrice() external view returns (uint256) {
        return 0;
    } 

    /*Volume Oracle functions*/

    //update Volume Oracle address
    function setVolumeOracle(address _newVolumeOracle) external onlyOwner returns (address) { //onlyOwner 
        volumeOracleAddress = _newVolumeOracle;
        //emit newVolumeOracle();
        //emit AssetVolume();
        return volumeOracleAddress;
    }

    //return Volume Oracle address
    function getVolumeOracle() external view returns (address) {
        return volumeOracleAddress;
    } 

    //return asset volume from our volume oracle
    function getAssetVolume(address underlyingTokenAddress) external view returns (uint256) {
        return 0;
    } 

    /*Market functions*/
    
    /*function enterMarket() returns (address underlyingTokenAddress) {
        return underlyingTokenAddress;
    }*/

    /*function leaveMarket() returns (address none) {
        return address(0);
    }*/

    /// @dev Transfer underlying tokens from user account to reserves, 
    /// mints GTokens to the user balance, updates all data of user and user market
    /// @param _underlyingToken address of contract of underlying token to deposit
    /// @param _user address of the user who deposits
    /// @param _amount amount of tokens to deposit
    /// @return returns total value of deposites of user in USD
    function deposit(
        address _underlyingToken, 
        address _user, 
        uint256 _amount) external returns (uint256) {
            
        //Verify deposit market/user data:
        Logic.verifyDeposit(
            _underlyingToken, 
            underlyingTokenMarket[_underlyingToken].underlyingToken,
            _user, 
            _amount);

        //Update interest rates with the help of function updateReserveDepositFactor defined below        
        this.updateReserveDepositFactor(_underlyingToken);

        //Mint equivalent to deposited value gTokens
        //Mint gToken with the help of function mint from GToken contract(through interface IGToken)        
        IGToken(underlyingTokenMarket[_underlyingToken].gToken).mintGToken(_user, _amount);      

        //TODO: look through the documentation, how to implement function calling 

        //Start GETU distribution
        startDistribute();
        
        //First deposit on market -> Add market to distribution record for accounting interests
        
        //Update user data and user market data recording to the mappings userMarket and userData        
        //(userMarket[_user][_underlyingToken], userData[_user]) = 
        //updateUserData(_user, _underlyingToken, _amount, 0, 0, 0);        

        //Transfer underlying asset to reserve
        SafeERC20.safeTransferFrom(
            IERC20(_underlyingToken), 
            _user, 
            underlyingTokenMarket[_underlyingToken].reserves, 
            _amount);

        //Update market data
        underlyingTokenMarket[_underlyingToken].totalDeposits = updateMarketDeposit(_underlyingToken, _amount);
        
        //DONE
        return userData[_user].totalDeposits;
    }

    /// @dev Transfer underlying tokens from reserves to user account, 
    /// burns GTokens from the user balance, updates all data of user and user market
    /// @param _underlyingToken address of contract of underlying token to deposit
    /// @param _user address of the user who deposits
    /// @param _amount amount of tokens to withdraw
    /// @return returns total value of deposites of user in USD
    function withdraw(
        address _underlyingToken,
        address _user, 
        uint256 _amount) external returns (uint256) {              

        //Verify withdraw market/user data
        Logic.verifyWithdraw(
            userMarket[_user][_underlyingToken].underlyingToken,
            _underlyingToken, 
            underlyingTokenMarket[_underlyingToken].reserves,
            _user, 
            _amount,
            this.getUserHealthRate(_user),           
            this.getUserCollateralBalance(_user),
            userData[_user].totalBorrows,
            borrowLimitIndex,
            userMarket[_user][_underlyingToken].isUsedAsCollateral);

        //Burn withdrawal value of gTokens and transfer underlying asset to user 
        ///with the help of function burn from GToken contract
        IGToken(underlyingTokenMarket[_underlyingToken].gToken).burnGToken(
            _user, 
            underlyingTokenMarket[_underlyingToken].reserves, 
            _amount);
        
        //Update market/user data
        underlyingTokenMarket[_underlyingToken].totalDeposits = updateMarketWithdraw(_underlyingToken, _amount);

        //Update deposit interest rates
        underlyingTokenMarket[_underlyingToken].depositRate = this.updateReserveDepositFactor(_underlyingToken);
        
        //Update user data and market data with the help of function updateUserData
        //(userMarket[_user][_underlyingToken], userData[_user]) = updateUserData(_user, _underlyingToken, 0, _amount, 0, 0);                              
        
        //Finish GETU distribution
        stopDistribute();

        //DONE
        return userData[_user].totalDeposits;
    }

    /// @dev Transfer underlying tokens from reserves to user account, 
    /// mints debtGTokens for user, updates all data of user and user market
    /// @param _underlyingToken address of contract of underlying token to borrow
    /// @param _user address of the user who borrows
    /// @param _amount amount of tokens to borrow
    /// @return returns total value of borrows of user in USD
    function borrow(
        address _underlyingToken, 
        address _user, 
        uint256 _amount) external returns (uint256) {           
        
        //Verify borrow user/market data:
        Logic.verifyBorrow(
            _user,
            underlyingTokenMarket[_underlyingToken].underlyingToken,
            _underlyingToken, 
            underlyingTokenMarket[_underlyingToken].reserves,
            _amount,
            this.getUserCollateralBalance(_user),
            this.getUserHealthRate(_user));

        // if First borrow -> Add market to distribution record for accounting interest ?????        

        //Update market data
        underlyingTokenMarket[_underlyingToken].totalBorrows = updateMarketBorrow(_underlyingToken, _amount);

        //Update interest rates
        underlyingTokenMarket[_underlyingToken].borrowRate = this.updateReserveBorrowFactor(_underlyingToken);
        
        //With the help of function updateUserData:
        //Check is user in market, if not -> Add user to market

        //Start GETU distribution
        startDistribute();

        //Update user data
        //Update market data
        //(userMarket[_user][_underlyingToken], userData[_user]) = updateUserData(_user, _underlyingToken, 0, 0, _amount, 0);

        //Mint borrowed value of debtGTokens with the help of function mint from debtGToken contract        
        IDebtGToken(underlyingTokenMarket[_underlyingToken].debtgToken).mintDebtGToken(_user, _amount);

        //Transfer underlying assets to user
        SafeERC20.safeTransferFrom(
            IERC20(_underlyingToken),              
            underlyingTokenMarket[_underlyingToken].reserves, 
            _user,
            _amount);

        //DONE
         return userData[_user].totalBorrows;
    }

    /// @dev Transfer underlying tokens user account to reserves, 
    /// burns debtGTokens of user, updates all data of user and user market
    /// @param _underlyingToken address of contract of underlying token to repay
    /// @param _user address of the user who repays
    /// @param _amount amount of tokens to repay
    /// @return returns total value of borrows of user in USD
    function repay(
        address _underlyingToken, 
        address _user, 
        uint256 _amount) external returns (uint256) {  
        
        //Calculate the fee for using the loan
        uint256 interest =  this.getReserveBorrowFactor(_underlyingToken);

        //Mint the amount of debtGTokens equal to calculated interest
        IDebtGToken(underlyingTokenMarket[_underlyingToken].debtgToken).mintDebtGToken(_user, interest);

        //Add the accrued interest to current borrow balance (in tokens)
        uint256 amountToFinalRepay = userData[_user].totalBorrows.add(interest);

        //Verify repay
        Logic.verifyRepay(
            userMarket[_user][_underlyingToken].totalBorrows, 
            underlyingTokenMarket[_underlyingToken].underlyingToken, 
            _user, 
            _amount,
            amountToFinalRepay,
            this.getUserHealthRate(_user));        

        //Subtracts the amount to repay(minus interest) 
        //Update reserve total borrows by rate
        //Increases the reserve total by the accrued interest
               
        //Start GETU distribution
        startDistribute();

        //Update market data:
        underlyingTokenMarket[_underlyingToken].totalBorrows = updateMarketRepay(_underlyingToken, _amount);

        //Update user data
        //(userMarket[_user][_underlyingToken], userData[_user]) = updateUserData(_user, _underlyingToken, 0, 0, _amount, 0);       

        //Transfer underlying assets to reserve
        SafeERC20.safeTransferFrom(
            IERC20(_underlyingToken), 
            _user, 
            underlyingTokenMarket[_underlyingToken].reserves, 
            _amount);

        //Burn debtgToken
        IDebtGToken(underlyingTokenMarket[_underlyingToken].debtgToken)
        .burnDebtGToken(_user, _amount);

        //Update interest rates        
        underlyingTokenMarket[_underlyingToken].borrowRate = this.updateReserveBorrowFactor(_underlyingToken);

        //DONE
        return userData[_user].totalBorrows;
    }

  
    /// @param _borrower - borrower to liquidate address
    /// @param _assetFromCollateral - underlying token address of asset from borower collateral, which user want to take    
    /// @param _repayAssets - asset which user want to repay by borrower
    /// @param _amount amount of debtGToken user wants to repay by borrower
    /// @param _gToken - user want to receive tokens in gToken (true) or in underlying tokens(false)     
    function liquidate(
        address _borrower, 
        address _assetFromCollateral, 
        address _repayAssets, 
        uint256 _amount, 
        bool _gToken) external onlyOwner returns(bool) {

            uint256 liquidationBonus; //!!!!!!!!!!additional bonus interest of liquidation (pre setuped)

            //Calculate liquidation value - function in lib Logic (amount of borrow+%)
            uint256 liquidationValue = Logic.calculateLiquidationValue(
                IDebtGToken(underlyingTokenMarket[_repayAssets].debtgToken).balanceOfDebtGToken(_borrower),                
                _amount, 
                liquidationBonus); 
            
            //Value to return user in underlyingToken (calculate)
            uint256 valueToPayToUser = _amount
                .mul(uint256(IPriceOracle(priceOracleAddress).getTokenPrice(_repayAssets)))
                .add(liquidationBonus);
            
            DataTypes.user_s memory borrowerDataUSD = userData[_borrower];
            DataTypes.userMarket_s memory borrowerDataToken = userMarket[_borrower][_assetFromCollateral];

            //Verify the liquidation with the help of function from the lib Logic
            Logic.verifyLiquidation(
                msg.sender, 
                Logic.calculateUserHealthRate(
                    _borrower, 
                    Logic.calculateUserCollateralBalance(borrowerDataUSD), 
                    borrowerDataToken.totalBorrows), 
                underlyingTokenMarket[_assetFromCollateral].reserves, 
                _assetFromCollateral, 
                _amount, 
                valueToPayToUser, 
                liquidationValue,
                Logic.calculateUserCollateralBalance(borrowerDataUSD));           
            
            //Burn the repayed amount of tokens from the borrower account
            IDebtGToken(_repayAssets).burnDebtGToken(
                _borrower,                 
                _amount);   

            //Update the data in markets 
            updateMarketRepay(_repayAssets, _amount);                  

            //Send to user his value in the token he wants                        
            if(_gToken){
                IGToken(underlyingTokenMarket[_assetFromCollateral].gToken)
                .transferOnLiquidation(_borrower, msg.sender, valueToPayToUser);
                
            } else {
                IGToken(underlyingTokenMarket[_assetFromCollateral].gToken)
                .burnGToken(_borrower, msg.sender, valueToPayToUser);   

                updateMarketWithdraw(_assetFromCollateral, valueToPayToUser);                                
            }
            
            //UPDATE ALL DATES OF USER AND BOROOWER!!! - will add, when fix the problem with memory/storage
         

            //Get liquidation amount of tokens from Reserve balance            
            //Liquidate user borrow
            //Transfer collateral tokens to reserve
            //Update Liquidator data
            //The user has collateral the caller wants to, if not -> revert
            //Calculate accrued interest in the principal balance
            //Increases the reserve total liquidity by the accrued interest
            //Calculate the amount of collateral in principal currency
            //Amount not above 50% of the principle, if not -> revert
            //Decrease reserve total borrows
            //Decrease user principal borrow balance
            //Transfer to user
            //DONE
            
        return true;
    }

    /// @dev set collateral as true
    /// @param _underlyingToken address of contract of underlying token to repay
    /// @param _user address of the user who repays
    /// @return isUsedAsCollateral is true
    function useAsCollateral(address _user, address _underlyingToken) external returns (bool) {
        userMarket[_user][_underlyingToken].isUsedAsCollateral = true;
        return userMarket[_user][_underlyingToken].isUsedAsCollateral;
    }

    /// @dev set collateral as false
    /// @param _underlyingToken address of contract of underlying token to repay
    /// @param _user address of the user who repays
    /// @return isUsedAsCollateral is false
    function unuseAsCollateral(address _user, address _underlyingToken) external returns (bool) {
        userMarket[_user][_underlyingToken].isUsedAsCollateral = false;
        return userMarket[_user][_underlyingToken].isUsedAsCollateral;
    }   

    /// @dev set borrow fee
    /// @param _underlyingToken address of underlying token to update its fee - reserveBorrowFactor
    /// @return the amount of updated borrow fee - reserveBorrowFactor from the struct market_s
    function updateReserveBorrowFactor(address _underlyingToken) external returns(uint256) {        
        
        underlyingTokenMarket[_underlyingToken].borrowRate = 
            Logic.calculateReserveBorrowFactor(
                _underlyingToken, 
                volumeOracleAddress, 
                underlyingTokenMarket[_underlyingToken].totalDeposits, 
                underlyingTokenMarket[_underlyingToken].totalBorrows, 
                IGToken(underlyingTokenMarket[_underlyingToken].gToken).getTheBalanceOfContractGToken(), 
                IERC20(_underlyingToken).balanceOf(underlyingTokenMarket[_underlyingToken].reserves));            
            
            return underlyingTokenMarket[_underlyingToken].borrowRate;
    } 

    /// @dev set deposit fee
    /// @param _underlyingToken address of underlying token to update its fee - reserveDepositFactor
    /// @return the amount of updated deposit fee - reserveDepositFactor from the struct market_s
    function updateReserveDepositFactor(address _underlyingToken) external returns(uint256) {
        
        underlyingTokenMarket[_underlyingToken].depositRate = 
            Logic.calculateReserveDepositFactor(
                underlyingTokenMarket[_underlyingToken].borrowRate, 
                underlyingTokenMarket[_underlyingToken].totalDeposits, 
                underlyingTokenMarket[_underlyingToken].totalBorrows);

            return underlyingTokenMarket[_underlyingToken].depositRate;
    } 

    /// @dev get borrow fee of the underlying token
    /// @param _underlyingToken address of underlying token to get its fee - reserveBorrowFactor
    /// @return the fee - reserveBorrowFactor from the struct market_s
    function getReserveBorrowFactor(address _underlyingToken) external view returns(uint256) {
        return underlyingTokenMarket[_underlyingToken].borrowRate;
    } 

    /// @dev get deposit fee of the underlying token
    /// @param _underlyingToken address of underlying token to get its fee - reserveDepositFactor
    /// @return the fee - reserveDepositFactor from the struct market_s
    function getReserveDepositFactor(address _underlyingToken) external view returns(uint256) {
        return underlyingTokenMarket[_underlyingToken].depositRate;
    } 

    /// @param _userAddress address of user wallet
    /// @param _underlyingToken address of underlying token to update user data
    /// @param _depositedAmount amount of tokens, which user deposited
    /// @param _withdrawedAmount amount of tokens, which user withdrawed
    /// @param _borrowedAmount amount of tokens, which user borrowed
    /// @param _repayedAmount amount of tokens, which user repayed
    /// @return returns the tuple of struct user_s 
    /// and struct userMarket_s with updated user data
     function updateUserData(
        address _userAddress,
        address _underlyingToken, 
        uint256 _depositedAmount,
        uint256 _withdrawedAmount,
        uint256 _borrowedAmount,
        uint256 _repayedAmount) 
        internal 
        returns(DataTypes.userMarket_s memory, DataTypes.user_s memory) { 
                
        int tokenPrice = IPriceOracle(priceOracleAddress).getTokenPrice(_underlyingToken);

        DataTypes.userMarket_s memory updatedUserMarket = userMarket[_userAddress][_underlyingToken];
        DataTypes.user_s memory updatedUser = userData[_userAddress];
        Logic.calculateUserDataInputVars memory inputVars;
        
        
        inputVars = Logic.calculateUserDataInputVars(
            _userAddress,
            _underlyingToken,
            updatedUserMarket.totalDeposits,
            updatedUserMarket.totalBorrows,
            updatedUser.borrowLimit,
            _depositedAmount, 
            _withdrawedAmount, 
            _borrowedAmount, 
            _repayedAmount,
            updatedUser.totalDeposits,
            updatedUser.totalBorrows,
            tokenPrice);

        //all calculations makes function calculateUserData from library Logic
        //record updated struct user_s to the mapping userData
        //and updated struct userMarket_s to the mapping userMarket        
        (updatedUserMarket, updatedUser) = 
        Logic.calculateUserData(inputVars);

        return (updatedUserMarket, updatedUser);  
    }

    /// @dev updates total value of deposites in USD in market 
    /// @param _underlyingToken address of underlying token to update deposited amount
    /// @param _depositedAmount amount of tokens, which user deposits
    /// @return returns the amount of deposited USD from the mapping underlyingTokenMarket
    function updateMarketDeposit(        
        address _underlyingToken, 
        uint256 _depositedAmount) internal returns(uint256) {
        
        int tokenPrice = IPriceOracle(priceOracleAddress).getTokenPrice(_underlyingToken);

        //all calculations makes function calculateMarketDeposit from library Logic
        //record updated amount of deposited USD to the mapping underlyingTokenMarket        
        underlyingTokenMarket[_underlyingToken].totalDeposits = 
        Logic.calculateMarketDeposit(
            underlyingTokenMarket[_underlyingToken].totalDeposits,
            _depositedAmount, 
            tokenPrice);

        return underlyingTokenMarket[_underlyingToken].totalDeposits;
    }

    /// @dev updates total value of deposited USD in market   
    /// @param _underlyingToken address of underlying token to update deposited amount
    /// @param _withdrawedAmount amount of tokens, which user withdraws
    /// @return returns the amount of deposited tokens from the mapping underlyingTokenMarket
    function updateMarketWithdraw(        
        address _underlyingToken, 
        uint256 _withdrawedAmount) internal returns (uint256) {
        
        int tokenPrice = IPriceOracle(priceOracleAddress).getTokenPrice(_underlyingToken);

        //all calculations makes function calculateMarketWithdraw from library Logic
        //records updated the whole sum of deposited USD to the mapping underlyingTokenMarket
        underlyingTokenMarket[_underlyingToken].totalDeposits = 
        Logic.calculateMarketWithdraw(
            underlyingTokenMarket[_underlyingToken].totalDeposits,
            _withdrawedAmount, 
            tokenPrice);

        return underlyingTokenMarket[_underlyingToken].totalDeposits;
    }

    /// @dev updates the whole sum of borrowed USD in market     
    /// @param _underlyingToken address of underlying token to update borrowed amount
    /// @param _borrowedAmount amount of tokens, which user borrows
    /// @return returns the amount of borrowed tokens from the mapping underlyingTokenMarket
    function updateMarketBorrow(         
        address _underlyingToken, 
        uint256 _borrowedAmount) internal returns (uint256) {
        
        int tokenPrice = IPriceOracle(priceOracleAddress).getTokenPrice(_underlyingToken);

        //all calculations makes function calculateMarketBorrow from library Logic
        //records the whole sum of borrowed USD to the mapping underlyingTokenMarket
        underlyingTokenMarket[_underlyingToken].totalBorrows = 
        Logic.calculateMarketBorrow(
            underlyingTokenMarket[_underlyingToken].totalBorrows,
            _borrowedAmount, 
            tokenPrice);

        return underlyingTokenMarket[_underlyingToken].totalBorrows;
    }

    /// @dev updates the whole sum of borrowed USD in market    
    /// @param _underlyingToken address of underlying token to update borrowed amount
    /// @param _repayedAmount amount of tokens, which user repays
    /// @return returns the amount of borrowed tokens from the mapping underlyingtokenMarket
    function updateMarketRepay(
        address _underlyingToken, 
        uint256 _repayedAmount) internal returns (uint256) {

        int tokenPrice = IPriceOracle(priceOracleAddress).getTokenPrice(_underlyingToken);
        
        //all calculations makes function calculateMarketRepay from library Logic
        //records the whole sum of borrowed USD to the mapping underlyingTokenMarket         
        underlyingTokenMarket[_underlyingToken].totalBorrows = 
        Logic.calculateMarketRepay(
            underlyingTokenMarket[_underlyingToken].totalBorrows,
            _repayedAmount, 
            tokenPrice);

        return underlyingTokenMarket[_underlyingToken].totalBorrows;
    }

    //update interest rates with the help of function calculateInterestRates from lib Logic
    function updateInterestRates() internal pure returns(uint256) {
        return Logic.calculateInterestRates();
    }

    /*View market/user functions*/   

    /// @param _userAddress address of the user 
    /// @return the list of all user markets
    function getMarkets(address _userAddress) external view returns (DataTypes.userMarket_s[] memory) {
        DataTypes.userMarket_s[] memory userMarketList = userData[_userAddress].listOfUserMarket;
        return userMarketList;
    }

    
    /// @param _userAddress address of the user 
    /// @return user's data in USD
    function getUserData(address _userAddress) external view returns (DataTypes.user_s memory) {
        require (userData[_userAddress].userAddress != address(0), 'User address does not exist!');
            return userData[_userAddress];
    } 

    /// @param _userAddress address of the user 
    /// @param _underlyingToken address of the underlying token to deposit
    /// @return max amount in underlying tokens which user can deposit
    function getUserMaxDeposit(address _userAddress, address _underlyingToken) external view returns (uint256) {
        
        require (userData[_userAddress].userAddress != address(0), 'User address does not exist!');
        require (underlyingTokenMarket[_underlyingToken].underlyingToken != address (0), "Token doesn't exist!");
        
        //takes address of the contract of underlyingToken from the struct market_s 
        address underlyingTokenContract = underlyingTokenMarket[_underlyingToken].underlyingToken;

        return IERC20(underlyingTokenContract).balanceOf(_userAddress);
    }

    /// @param _userAddress address of the user 
    /// @param _underlyingToken address of the underlying token to withdraw
    /// @return max amount of underlying tokens which user can withdraw
    function getUserMaxWithdraw(address _userAddress, address _underlyingToken) external view returns (uint256) {

        require (userData[_userAddress].userAddress != address(0), 'User address does not exist!');
        require (underlyingTokenMarket[_underlyingToken].underlyingToken != address (0), "Token doesn't exist!");

        //takes address of the contract of GToken from the struct market_s
        address contractGToken = underlyingTokenMarket[_underlyingToken].gToken;
        //takes address of the reserves from the struct market_s
        address reserves = underlyingTokenMarket[_underlyingToken].reserves;
        //user balance of GTokens
        uint256 userDepositedBalance = IERC20(contractGToken).balanceOf(_userAddress);
        //balance of underlying token on reserve account
        uint256 reserveBalance = IERC20(contractGToken).balanceOf(reserves);

        if (userDepositedBalance <= reserveBalance) {
            return userDepositedBalance;
        } else {
            return reserveBalance;
        }
    }


    /// @param _userAddress address of the user 
    /// @param _underlyingToken address of the underlying token to withdraw
    /// @return max amount which user can borrow (in tokens)
    function getUserMaxBorrow(address _userAddress, address _underlyingToken) external returns (uint256) {

        require (userData[_userAddress].userAddress != address(0), 'User address does not exist!');
        require (underlyingTokenMarket[_underlyingToken].underlyingToken != address (0), "Token doesn't exist!");
        
        //takes struct user_s from mapping userData according to user address
        DataTypes.user_s storage userInfo = userData[_userAddress];
        
        //takes address of the reserves from the struct market_s
        address reserves = underlyingTokenMarket[_underlyingToken].reserves;
        //takes address of the reserves from the struct market_s
        address contractGToken = underlyingTokenMarket[_underlyingToken].gToken;
        //balance of underlying token on reserve account
        uint256 reserveBalance = IERC20(contractGToken).balanceOf(reserves);
        //calculates the limit to borrow considering the borrow_limit_index
        uint256 sumToBorrowUSD = (this.getUserCollateralBalance(_userAddress).mul(borrowLimitIndex)).sub(userInfo.totalBorrows);

        if (sumToBorrowUSD <= reserveBalance) {
            return sumToBorrowUSD.div(uint256(IPriceOracle(priceOracleAddress).getTokenPrice(_underlyingToken)));
        } else { 
            return reserveBalance.div(uint256(IPriceOracle(priceOracleAddress).getTokenPrice(_underlyingToken)));
        }
    }

    /// @param _userAddress address of the user 
    /// @param _underlyingToken address of the underlying token to repay
    /// @return max amount which user can repay (in tokens)
    function getUserMaxRepay(address _userAddress, address _underlyingToken) external view returns (uint256) {

        require (userData[_userAddress].userAddress != address(0), 'User address does not exist!');
        require (underlyingTokenMarket[_underlyingToken].underlyingToken != address (0), "Token doesn't exist!");
        
        //takes struct userMarket_s from mapping userMarket according to user address and underlying token 
        DataTypes.userMarket_s storage userTokenMarket = userMarket[_userAddress][_underlyingToken];

        //compare the amount of total borrows and the balance of undelying token in user account
        if (userTokenMarket.totalBorrows <= IERC20(_underlyingToken).balanceOf(_userAddress)){
            return userTokenMarket.totalBorrows;
        } else {
            return IERC20(_underlyingToken).balanceOf(_userAddress);
        }
    }
         
    /// @param _underlyingToken address of the underlying token to get market data
    /// @return data from the struct market_s of the certain underlying token
    function getMarketData(address _underlyingToken) external view returns (DataTypes.market_s memory) {

        require (underlyingTokenMarket[_underlyingToken].underlyingToken != address (0), "Token doesn't exist!");
        return underlyingTokenMarket[_underlyingToken];
    }

    /// @param _userAddress address of the user 
    /// @param _underlyingToken address of the underlying token to get user market data
    /// @return data from the struct userMarket_s of the certain user and underlying token
    function getUserMarketData(address _userAddress, address _underlyingToken) external view returns (DataTypes.userMarket_s memory) {

        require (userData[_userAddress].userAddress != address(0), 'User address does not exist!');
        require (underlyingTokenMarket[_underlyingToken].underlyingToken != address (0), "Token doesn't exist!");
        return userMarket[_userAddress][_underlyingToken];
    }

    /// @dev get the amount of user HealthRate from the function in the SC Logic
    /// @param _user address of user wallet
    /// @return returns the user HealthRate 
    function getUserHealthRate(address _user) external returns(uint256){
        return Logic.calculateUserHealthRate(
            _user, 
            this.getUserCollateralBalance(_user), 
            userData[_user].totalBorrows);
    }

    /// @dev get the amount of collateral balance in USD from the function in the SC Logic
    /// @param _user address of user wallet
    /// @return returns the total collateral balance in USD 
    function getUserCollateralBalance(address _user) external returns(uint256) {    
        return Logic.calculateUserCollateralBalance(userData[_user]);
    }

    /*Market setup functions*/

    function createMarket(
        address _underlyingToken, 
        address _gToken,
        address _debtgToken,
        address _reserves) external returns (DataTypes.market_s memory) { //onlyController 

            DataTypes.market_s storage tokenMarket = underlyingTokenMarket[_underlyingToken];
            require(tokenMarket.underlyingToken == address(0), 'Market is already exists!' );

            tokenMarket.underlyingToken = _underlyingToken;
            tokenMarket.gToken = _gToken;
            tokenMarket.debtgToken = _debtgToken;
            tokenMarket.reserves = _reserves;

            underlyingTokenMarket[_underlyingToken] = tokenMarket;
           
            return underlyingTokenMarket[_underlyingToken];
        }

    function updateMarket(
        address _underlyingToken, 
        address _gToken,
        address _debtgToken, 
        address _reserves) external returns (DataTypes.market_s memory) { //onlyController 

            DataTypes.market_s storage tokenMarket = underlyingTokenMarket[_underlyingToken];
            require(tokenMarket.underlyingToken == _underlyingToken, "Market doesn't exist!" );

            tokenMarket.underlyingToken = _underlyingToken;
            tokenMarket.gToken = _gToken;
            tokenMarket.debtgToken = _debtgToken;
            tokenMarket.reserves = _reserves;

            underlyingTokenMarket[_underlyingToken] = tokenMarket;
           
            return underlyingTokenMarket[_underlyingToken];
        }

    function deleteMarket(address _underlyingToken) external returns (bool){ //onlyController 
        require (underlyingTokenMarket[_underlyingToken].underlyingToken != address (0), "Token doesn't exist!");

        DataTypes.market_s storage tokenMarket = underlyingTokenMarket[_underlyingToken];
        require(tokenMarket.underlyingToken == _underlyingToken, "Market doesn't exist!" );

        delete underlyingTokenMarket[_underlyingToken];
            return tokenMarket.underlyingToken == address(0);
    }
}