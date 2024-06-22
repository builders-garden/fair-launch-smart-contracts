// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IHippodromeTypes} from "./types/IHippodromeTypes.sol";
interface IHippodrome is IHippodromeTypes{
    
    event CampaignCreated(uint indexed campaignID, address indexed founder, Campaign campaign);
    event FundsAdded(uint indexed campaignID, address indexed user, uint amount);
    event FundsWithdrawed(uint indexed campaignID, address indexed user, uint amount);
    event CampaignTerminated(uint campaignID, uint raised);
    event RewardsClaimed(uint indexed campaignID, address indexed user, uint amount);
    
    error CampaignEnded();
    error CampaignNotStarted();
    error WithdrawLocked(uint256 unlockTime);
    error RewardsClaimed();
    // other errors 



} 