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
    error RewardsAlreadyClaimed();
    // other errors 

    function createCampaign(CampaignParams memory campaignParams) external virtual returns(uint128 accountID);
    function fundCampaign(uint128 campaignId, uint amount) external virtual;
    function withdrawFunds(uint128 campaign, uint amount) external virtual;
    function claimRewards(uint128 campaignID) external virtual;
    function resolveCampaign(uint128 campaignID) external virtual;

    function getAvailableUserRewards(address user, uint128 campaignID) external view virtual returns (uint);
    function calculateContributionPercentage(uint128 campaignID, address user) external view virtual returns (uint);
    function getUserRewardStatus(uint128 campaignID, address user) external view virtual returns(uint, uint);
} 