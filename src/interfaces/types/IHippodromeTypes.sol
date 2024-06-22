// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IHippodromeTypes {
    struct Campaign{
        address founder;//═════════════════════════════╗ 
        uint96  poolSupply;//══════════════════════════╝
        address tokenAddress;//════════════════════════╗ 
        uint56  currentStake;//════════════════════════╝ 
        address poolAddress;//═════════════════════════╗ 
        uint56  raised;//══════════════════════════════╝ 
        uint88  startTimestamp;//══════════════════════╗ 
        uint88  endTimestamp;//════════════════════════╝ 
        uint88  unvestStart;//═════════════════════════╗ 
        uint88  unvestEnd;//═══════════════════════════╝ 
        uint96  rewardSupply;
    }

    struct CampaignParams{
        uint96  poolSupply; 
        uint88  startTimestamp;  
        uint88  endTimestamp;
        uint88  unvestingStreamStart;
        uint88  unvestingStreamEnd;
        uint96  rewardSupply;
        address tokenAddress;
        string  campaignURI;
    }

    struct UserStake {
        uint256 amount;
        uint256 lastStakeTime;
        uint256 totalContribution;
    }
    
    struct Launch {
        mapping(address => UserStake) userStakes;
        uint256 totalStaked;
        uint256 totalContribution;
        uint256 lastUpdateTime;
    }
} 