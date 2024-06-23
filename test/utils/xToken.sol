// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/Token/ERC20/ERC20.sol";

contract XToken is ERC20 {
    constructor(string memory name, string memory symbol)ERC20(name, symbol){
        _mint(msg.sender, 1e30);
    }
}
