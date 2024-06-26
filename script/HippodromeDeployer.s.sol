// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import "../src/Hippodrome.sol";
contract HippodromeDeployer is Script {

    /*
        *** BASE Sepolia addresses ***
    */
    address fUSDC = 0xc43708f8987Df3f3681801e5e640667D86Ce3C30;
    address synthCoreProxy = 0x764F4C95FDA0D6f8114faC54f6709b1B45f919a1;
    address wrapProxy = 0xaD2fE7cd224c58871f541DAE01202F93928FEF72;
    address sUSDC = 0x8069c44244e72443722cfb22DcE5492cba239d39;
    address aerodromePoolFactory = 0x9F631b6E37045E0C66ed2d6AE28eEb53A5bda82D;
    address aerodromeRouter = 0x70bD534579cbaBbE9Cd4AD4210e29CC9BA1E9287;

    function setUp() public {}

    function run() public {
        vm.broadcast();
        Hippodrome hd = new Hippodrome(
            synthCoreProxy, 
            fUSDC,
            wrapProxy,
            sUSDC,
            aerodromePoolFactory,
            aerodromeRouter
        );
        console.log("Address deployed at: ");
        console.logAddress(address(hd));

    }
}
