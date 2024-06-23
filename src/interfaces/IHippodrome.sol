// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IHippodromeTypes} from "./types/IHippodromeTypes.sol";

interface IHippodrome is IHippodromeTypes{
    
    event CampaignCreated(uint indexed campaignID, address indexed founder, Campaign campaign);
    event FundsAdded(uint indexed campaignID, address indexed user, uint amount);
    event FundsWithdrawed(uint indexed campaignID, address indexed user, uint amount);
    event CampaignTerminated(uint campaignID, uint raised);
    event RewardsClaimed(uint indexed campaignID, address indexed user, uint amount);
    
    error CampaignNotActive();
    error WithdrawLocked(uint256 unlockTime);
    error RewardsAlreadyClaimed();
    error CampaignAlreadyExist();
    // other errors 

    function createCampaign(CampaignParams memory campaignParams) external  returns(uint128 accountID);
    function fundCampaign(uint128 campaignId, uint amount) external ;
    function withdrawFunds(uint128 campaign, uint amount) external ;
    function claimRewards(uint128 campaignID) external ;
    function resolveCampaign(uint128 campaignID) external ;

    function getAvailableUserRewards(address user, uint128 campaignID) external view  returns (uint);
    function calculateContributionPercentage(uint128 campaignID, address user) external view  returns (uint);
    function getUserRewardStatus(uint128 campaignID, address user) external view  returns(uint, uint);
} 