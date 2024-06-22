// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IHippodromeTypes} from "./types/IHippodromeTypes.sol";
interface IHippodrome is IHippodromeTypes{
    error Campaign_Closed();   
} 