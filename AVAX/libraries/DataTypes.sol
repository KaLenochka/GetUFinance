pragma solidity ^0.8.5;
pragma abicoder v2;

library DataTypes {

    struct market_s {
        address underlyingToken; //address of uderlying token contract
        address gToken; //address of gToken contract
        address debtgToken; //address of debptgToken contract
        address reserves; //address of reserves contract
        uint256 totalDeposits; //total value of deposites in USD
        uint256 totalBorrows; //total value of borrows in USD
        uint256 totalVolume; //total value of volume on market in USD
        uint256 depositRate; //APY of deposites on market
        uint256 borrowRate; //APY of borrows on market       
    }

    struct user_s {
        address userAddress; //user wallet address
        userMarket_s[] listOfUserMarket; //list of markets with user data inside
        uint256 totalDeposits; //total value of deposites in USD
        uint256 totalBorrows; //total value of borrows in USD
        uint256 borrowLimit; //limit value of borrow
    }

    struct userMarket_s {
        address underlyingToken; //address of uderlying token contract
        uint256 totalDeposits; //total value of deposites in token
        uint256 totalBorrows; //total value of borrows in token
        bool isUsedAsCollateral; //0: doesn't use, 1: use
    }
}