// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/Token/ERC20/ERC20.sol";

contract MockLiquidityToken is ERC20 {
    error MockLiquidityToken__CallerIsNotProtocol();

    address immutable public i_protocol;

    modifier onlyProtocol {
        if(msg.sender != i_protocol){
            
            revert MockLiquidityToken__CallerIsNotProtocol();
        }
        _;
    }
    constructor() ERC20("MockLiquidityToken", "MLT") {
        i_protocol = msg.sender;
    }

    function mint(uint256 amount) external onlyProtocol{
        _mint(msg.sender, amount);
    }
}
