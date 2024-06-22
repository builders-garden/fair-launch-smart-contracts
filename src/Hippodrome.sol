// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IHippodrome} from "./interfaces/IHippodrome.sol";
import {IAccountModule} from "./interfaces/IAccount.sol";
import {ICollateralModule} from "./interfaces/ICollateralModule.sol";
import {IVaultModule} from "./interfaces/IVault.sol";
import {IRewardsManagerModule} from "./interfaces/IRewardsManagerModule.sol";
import "@openzeppelin/contracts/Token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@aerodrome/interfaces/factories/IPoolFactory.sol";
import "@aerodrome/interfaces/IPool.sol";
import "@aerodrome/interfaces/IRouter.sol";
    

contract Hippodrome is IERC721Receiver, IHippodrome { 

    address internal fUSDC;
    address internal accountRouter;
    address internal positionModule;
    address internal sUSDC;
    address internal aerodromePoolFactory;
    address internal aerodromeRouter;
    uint internal _campaignCounter;
    uint128 internal _poolID = 1;
    
    mapping(uint=>Campaign) public s_campaigns;
    mapping(uint=>uint128) internal s_campaignAccounts;
    mapping(address=>mapping(uint128=>uint256)) internal s_userStakes;
    mapping(address=>mapping(uint128=>uint256)) internal s_contributions;
    mapping(uint256 => Launch) public s_launches;
    mapping(address => bool) internal s_tokens;
    mapping(address=>mapping(uint128=>uint256)) internal s_claims;
    mapping(address=>mapping(uint128=>uint256)) internal s_depositTimestamps;
    
    constructor
    (
        address _accountRouter,
        address _fUSDC, 
        address _positionModule, 
        address _sUSDC, 
        address _aerodromePoolFactory, 
        address _aerodromeRouter
    ){
        accountRouter = _accountRouter;
        fUSDC = _fUSDC;
        positionModule = _positionModule;
        sUSDC = _sUSDC;
        aerodromePoolFactory = _aerodromePoolFactory;
        aerodromeRouter = _aerodromeRouter;
    }

    
    //║══════════════════════════════════════════╗
    //║             USER FUNCTIONS               ║
    //║══════════════════════════════════════════╝

    function createCampaign(CampaignParams memory campaignParams) external override returns(uint128 accountID){
        ++_campaignCounter;
        accountID = _createContractAndAccount(campaignParams);
    }
    
    function fundCampaign(uint128 campaignID, uint amount ) external override{    
        s_userStakes[msg.sender][campaignID] += amount;   
        _depositAndDelegateOnAccount(campaignID, amount);

        emit FundsAdded(campaignID, msg.sender, amount);
    }

    function withdrawFunds(uint128 campaignID, uint amount) external override{
        require(s_depositTimestamps[msg.sender][campaignID] < 10 days, "Synthetix claim period isn't  over");
        // stuff
    }

    function claimRewards(uint128 campaignID) external {
        uint rewards = _getUserRewards(msg.sender, campaignID);
        require(rewards > s_claims[msg.sender][campaignID], "Hippodrome: claimed");
        Campaign memory campaign = s_campaigns[campaignID];
      
        
        IERC20(campaign.tokenAddress).transfer(msg.sender, rewards);
        s_claims[msg.sender][campaignID] = rewards;

        emit RewardsClaimed(campaignID, msg.sender, rewards);
    }

    // either make it callable by anyone or automate
    function resolveCampaign(uint campaignID) external {
        Campaign memory campaign = s_campaigns[campaignID];
        _claimSynthetixRewards(campaignID);
        campaign.poolAddress = _createAerodromePoolAndAddLiquidity(campaign.tokenAddress, campaign.raised, campaign.poolSupply);
    }

    //║══════════════════════════════════════════╗
    //║             VIEW FUNCTIONS               ║
    //║══════════════════════════════════════════╝

    function getAvailableUserRewards(address user, uint128 campaignID) external view returns(uint rewards) {
        _getUserRewards(user, campaignID);
    }

    function calculateContributionPercentage(uint128 campaignID, address user) external view returns (uint256 percentage) {
        _calculateContributionPercentage(campaignID, user);
    }

    function getUserRewardStatus(address user, uint128 campaignID) external view returns(uint totalRewards, uint claimed){
        uint contributionPercentage = _calculateContributionPercentage(campaignID, user);
        Campaign memory campaign = s_campaigns[campaignID];
        totalRewards = (uint(campaign.rewardSupply) * contributionPercentage) / 100;
        claimed = s_claims[user][campaignID];
    }

    //║══════════════════════════════════════════╗
    //║            INTERNAL FUNCTIONS            ║
    //║══════════════════════════════════════════╝

    function _calculateContributionPercentage(uint128 campaignID, address user) internal view returns (uint256 percentage){
        uint256 userContribution = _getUserContribution(campaignID, user);
        uint256 totalContribution = _getTotalContribution(campaignID);
        
        require(totalContribution > 0, "Total contribution must be greater than zero");
        percentage = (userContribution * 100000) / totalContribution;
    }
    
    function _getUserRewards(address user, uint128 campaignID) internal view returns(uint rewards){
        uint contributionPercentage = _calculateContributionPercentage(campaignID, user);
        Campaign memory campaign = s_campaigns[campaignID];
        uint streamStart = campaign.unvestStart;
        uint streamEnd = campaign.unvestEnd;
        uint currentTime = block.timestamp;

      
        if (currentTime < streamStart) {
            return 0;
        } else if (currentTime > streamEnd) {
            currentTime = streamEnd;
        }
    
        uint totalRewards = (uint(campaign.rewardSupply) * contributionPercentage) / 100;

        uint elapsedTime = currentTime - streamStart;
        uint streamDuration = streamEnd - streamStart;

        uint claimedRewards = s_claims[user][campaignID];

        rewards = ((totalRewards * elapsedTime) / streamDuration) - claimedRewards;
    }


    function _createContractAndAccount(CampaignParams memory campaignParams) internal returns(uint128 accountID){
        // get tokens from founder
        address campaignToken = campaignParams.tokenAddress;
        IERC20(campaignToken).transferFrom(msg.sender, address(this), campaignParams.poolSupply);
        
        // create Synthetix Account
        accountID = IAccountModule(accountRouter).createAccount();
        // map the id 
        s_campaignAccounts[_campaignCounter] = accountID;
        // map the campaign params
        s_campaigns[_campaignCounter] = Campaign(
            msg.sender, 
            campaignParams.poolSupply,
            campaignToken,
            0,
            address(0),
            0,
            campaignParams.startTimestamp,
            campaignParams.endTimestamp,
            campaignParams.unvestingStreamStart, 
            campaignParams.unvestingStreamEnd,
            campaignParams.rewardSupply
        );
        emit CampaignCreated(_campaignCounter, msg.sender, s_campaigns[_campaignCounter]);
    }

    function _depositAndDelegateOnAccount(uint campaignID, uint value) internal{
        uint128 accountID = s_campaignAccounts[campaignID];
        IERC20(fUSDC).transferFrom(msg.sender, address(this), value);
        IERC20(fUSDC).approve(positionModule, value);
        _delegatePool(value);
        (uint totalDeposited, ,) = ICollateralModule(address(accountRouter)).getAccountCollateral(accountID, fUSDC);
        s_campaigns[campaignID].currentStake = uint56(totalDeposited);
    }

    function _delegatePool(uint value) internal returns (bool success) {
        (success, ) = address(positionModule).call(
            abi.encodePacked(
                hex"d7ce770c00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000a7d8c0",
                abi.encode(value)
                )
            );
        require(success, "Call failed");
    }

    function _claimSynthetixRewards(uint campaignID) public returns(uint256[] memory claimableD18, address[] memory distributors) {
        uint128 accountID = s_campaignAccounts[campaignID];
        (claimableD18, distributors) = IRewardsManagerModule(accountRouter).updateRewards(_poolID, sUSDC, accountID);
        s_campaigns[campaignID].raised += uint56(claimableD18[0]);
        IRewardsManagerModule(accountRouter).claimRewards(accountID, _poolID, sUSDC, distributors[0]);
    }
    
  

    function _createAerodromePoolAndAddLiquidity(address xToken, uint256 amountRaised, uint256 poolSupply) internal returns (address poolAddress){
        poolAddress = IPoolFactory(aerodromePoolFactory).createPool(xToken, fUSDC, false);
        IERC20(xToken).approve(aerodromeRouter, poolSupply);
        IERC20(fUSDC).approve(aerodromeRouter, amountRaised);
        IRouter(aerodromeRouter).addLiquidity(
            xToken, 
            fUSDC,
            false,
            poolSupply,
            amountRaised,
            poolSupply,
            amountRaised,
            address(this), 
            block.timestamp
        );
    }

    function _getUserContribution(uint128 campaignID, address user) internal view returns (uint256 userContribution) {
        Launch storage launch = s_launches[campaignID];
        UserStake storage userStake = launch.userStakes[user];
        uint256 pastContribution = (block.timestamp - userStake.lastStakeTime) * userStake.amount;
        userContribution = userStake.totalContribution + pastContribution;
    }

    function _getTotalContribution(uint128 campaignID) internal view returns (uint256 totalContribution) {
        Launch storage launch = s_launches[campaignID];
        uint256 pastContribution = (block.timestamp - launch.lastUpdateTime) * launch.totalStaked;
        totalContribution = launch.totalContribution + pastContribution;
    }

    function _updateAddContribution(address user, uint128 campaignID, uint256 amount) internal {
        require(amount > 0, "Amount must be greater than zero");

        Launch storage launch = s_launches[campaignID];
        UserStake storage userStake = launch.userStakes[user];


        uint256 timeElapsed = block.timestamp - launch.lastUpdateTime;
        if (launch.totalStaked > 0) {
            launch.totalContribution += timeElapsed * launch.totalStaked;
        }
        launch.lastUpdateTime = block.timestamp;


        if (userStake.amount > 0) {
            uint256 userTimeElapsed = block.timestamp - userStake.lastStakeTime;
            userStake.totalContribution += userTimeElapsed * userStake.amount;
        }


        userStake.amount += amount;
        userStake.lastStakeTime = block.timestamp;
        launch.totalStaked += amount;

        
    }

    function _updateWithdrawContribution(address user, uint128 campaignID, uint256 amount) internal {
        Launch storage launch = s_launches[campaignID];
        UserStake storage userStake = launch.userStakes[user];
        require(userStake.amount >= amount, "Insufficient staked amount");


        uint256 timeElapsed = block.timestamp - launch.lastUpdateTime;
        if (launch.totalStaked > 0) {
            launch.totalContribution += timeElapsed * launch.totalStaked;
        }
        launch.lastUpdateTime = block.timestamp;

        uint256 userTimeElapsed = block.timestamp - userStake.lastStakeTime;
        userStake.totalContribution += userTimeElapsed * userStake.amount;


        userStake.amount -= amount;
        userStake.lastStakeTime = block.timestamp;
        launch.totalStaked -= amount;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        // Return the selector to confirm the transfer
        return this.onERC721Received.selector;
    }
}
