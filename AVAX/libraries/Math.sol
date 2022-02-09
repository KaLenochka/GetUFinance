pragma solidity ^0.8.5;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

library Math {
    using SafeMath for uint256;

    uint256 internal constant WAD = 1e18;
    uint256 internal constant halfWAD = WAD / 2; 

                
    /// @return one wad, 1e18
    function getWad() internal pure returns (uint256) {
        return WAD;
    }

    /// @return half ray, 1e18/2   
    function halfWad() internal pure returns (uint256) {
        return halfWAD;
    }

    /// @dev multiplies two wad, rounding half up to the nearest wad
    /// @param _a Wad
    /// @param _b Wad
    /// @return The result of a*b, in wad    
    function mulWad(uint256 _a, uint256 _b) internal pure returns (uint256) {
        if (_a == 0 || _b == 0) {
            return 0;
        }
        require(_a <= (type(uint256).max - halfWAD) / _b, "Multiplication overflow!");

            return (_a.mul(_b).add(halfWAD)).div(WAD);
    }

    /// @dev divides two wad-numbers, rounding half up to the nearest wad
    /// @param _a Wad
    /// @param _b Wad
    /// @return The result of a/b, in wad
    function divWad(uint256 _a, uint256 _b) internal pure returns (uint256) {
        require(_b != 0, "Division by zero!");
        uint256 halfB = _b / 2;
        require(_a <= (type(uint256).max - halfB) / WAD, "Division overflow!");

            return (_a * WAD + halfB) / _b;
    }


}
