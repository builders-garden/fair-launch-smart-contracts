// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract xERC20Token is ERC20 {
    address _parentContract;
    string private _newName;
    string private _newSymbol;
    uint public maxSupply; 
    constructor() ERC20("", "") {
        _parentContract = msg.sender;
    }   

    function init(string memory _name, string memory _symbol, uint _maxSupply) public {
        require(msg.sender != _parentContract, "Only the parent contract can call init"); // Avoid C2 Frontrun
        _newName = _name;
        _newSymbol = _symbol;
        maxSupply = _maxSupply;
        _mint(msg.sender, _maxSupply);
    }

    function name() public view override returns (string memory){
        return _newName;
    }

    function symbol() public view override returns (string memory){
        return _newSymbol;
    }

    function burn(uint amount) public {
        _burn(msg.sender, amount);
    }
}