// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IHippodromeTypes {

    event CampaignCreated(uint256 campaingID, CampaignParams campaign);

    event FundedCampaign(address funder, uint256 campaignID);

    event CampaignEnded(uint256 campaignID, bool success);


    struct Campaign{
        address founder; // ═══════════════════════════╗ campaign founder's address 
        uint96  allocatedSupply;//═════════════════════╝ Sum of the reward supply + countervalue of Aero pool
        address tokenAddress;// ════════════════════╗ address of    token start     ed with campaign
        uint56  currentStake;// ════════════════════╝ current amount of USDC staked on Synthetix
        address poolAddress; // ══════════════════╗ address of Aerodrome xToken/Usdc  
        uint56  raised; // ═══════════════════════╝ current Synthetix           rewards  
        uint88  startTimestamp; // ═════════════╗ address of the owner of the campaign
        uint88  endTimestamp; //                ║ current rewards of staked on Synthetix 
        uint8   rewardSupplyRate;// ════════════╝ Percentage of the total supply allocated for rewards
        uint88  unvestStart; // ═════════════╗ address of the owner of the campaign
        uint88  unvestEnd;   //  ════════════╝ Percentage of the total supply allocated for rewards
    }

    struct CampaignParams{
        uint96  allocatedSupply; 
        uint88  startTimestamp;  
        uint88  endTimestamp;
        uint88  unvestingStreamStart;
        uint88  unvestingStreamEnd;
        uint8   rewardSupplyRate;
        string  campaignURI;
        string  tokenName;
        string  tokenSymbol;
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