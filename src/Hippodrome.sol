// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IHippodrome} from "./interfaces/IHippodrome.sol";
import {IAccountModule} from "./interfaces/IAccount.sol";
import {ICollateralModule} from "./interfaces/ICollateralModule.sol";
import {IVaultModule} from "./interfaces/IVault.sol";
import {IRewardsManagerModule} from "./interfaces/IRewardsManagerModule.sol";
import {IWrapperModule} from "./interfaces/IWrapperModule.sol";
import {MockLiquidityToken} from "./MockLiquidityToken.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/Token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/Token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@aerodrome/interfaces/factories/IPoolFactory.sol";
import "@aerodrome/interfaces/IPool.sol";
import "@aerodrome/interfaces/IRouter.sol";


// this contract is an hackaton project which isnt production ready
// avoid deploying this contract on mainnet

contract Hippodrome is IERC721Receiver, IHippodrome {
    address internal fUSDC;
    uint8   internal _poolID = 1;
    uint24  internal contributionPrecision = 1e5; 
    
    address internal synthCoreProxy;
    address internal wrapProxy;
    address internal sUSDC;
    address internal aerodromePoolFactory;
    address internal aerodromeRouter;
    address internal mockLiquidityToken;
    uint public _campaignCounter; 

    mapping(uint => Campaign) internal s_campaigns;
    mapping(uint => uint128) internal s_campaignAccounts;
    mapping(address => mapping(uint128 => uint256)) internal s_userStakes;
    mapping(address => mapping(uint128 => uint256)) internal s_contributions;
    mapping(uint256 => Launch) internal s_launches;
    mapping(address => bool) internal s_tokens;
    mapping(address => mapping(uint128 => uint256)) internal s_claims;
    mapping(address => mapping(uint128 => uint256)) internal s_depositTimestamps;
    mapping(uint128 => bool) internal s_campaignResolved;

    modifier onlyActiveCampaign(uint128 campaignID) {
        if (
            !(block.timestamp >= s_campaigns[campaignID].startTimestamp &&
                block.timestamp <= s_campaigns[campaignID].endTimestamp)
        ) {
            revert CampaignNotActive();
        }
        _;
    }

    constructor(
        address _synthCoreProxy,
        address _fUSDC,
        address _wrapModule,
        address _sUSDC,
        address _aerodromePoolFactory,
        address _aerodromeRouter
    ) {
        synthCoreProxy = _synthCoreProxy;
        fUSDC = _fUSDC;
        wrapProxy = _wrapModule;
        sUSDC = _sUSDC;
        aerodromePoolFactory = _aerodromePoolFactory;
        aerodromeRouter = _aerodromeRouter;

        MockLiquidityToken mlt = new MockLiquidityToken();
        mockLiquidityToken = address(mlt);
    }

    //║══════════════════════════════════════════╗
    //║             USER FUNCTIONS               ║
    //║══════════════════════════════════════════╝

    function createCampaign(
        CampaignParams memory campaignParams
    ) external override returns (uint128 accountID) {
        if (campaignParams.startTimestamp < block.timestamp ||
            campaignParams.endTimestamp < campaignParams.startTimestamp
            ){
                revert InvalidCampaignTimeRange();
        }
        if  (campaignParams.unvestingStreamStart > campaignParams.endTimestamp || 
            campaignParams.unvestingStreamEnd < campaignParams.unvestingStreamStart
            ){
                revert InvalidStreamTimeRange();
        }
        if (s_tokens[campaignParams.tokenAddress])
            revert CampaignAlreadyExist();
        ++_campaignCounter;
        accountID = _createContractAndAccount(campaignParams);
    }

    function fundCampaign(
        uint128 campaignID,
        uint amount
    ) external override onlyActiveCampaign(campaignID) {
        s_userStakes[msg.sender][campaignID] += amount;
        _depositAndDelegateOnAccount(campaignID, amount);
        emit FundsAdded(campaignID, msg.sender, amount);
    }

    function withdrawFunds(
        uint128 campaignID,
        uint amount
    ) external override onlyActiveCampaign(campaignID) {
        // require(
        //     s_depositTimestamps[msg.sender][campaignID] < 10 days,
        //     "Synthetix claim period isn't  over"
        // );
        _claimUserCollateral(campaignID, msg.sender, amount);
        s_userStakes[msg.sender][campaignID] -= amount;
        
        emit FundsWithdrawed(campaignID, msg.sender, amount);
    }

    function claimRewards(uint128 campaignID) external override {
        require(s_campaignResolved[campaignID], "Hippodrome: campaign not resolved yet");
        uint rewards = _getUserRewards(msg.sender, campaignID);
        uint256 stake = s_userStakes[msg.sender][campaignID];
        if (stake > 0){
            IERC20(fUSDC).transfer(msg.sender, stake);
            delete s_userStakes[msg.sender][campaignID];
        }
        require(
            rewards > s_claims[msg.sender][campaignID],
            "Hippodrome: claimed"
        );
        Campaign memory campaign = s_campaigns[campaignID];
        
        uint128 accountID = s_campaignAccounts[campaignID];
        IERC20(campaign.tokenAddress).transfer(msg.sender, rewards);
        s_claims[msg.sender][campaignID] = rewards;
        
        emit RewardsClaimed(campaignID, msg.sender, rewards);

    }

    // either make it callable by anyone or automate
    function resolveCampaign(uint128 campaignID) external override {
        require(block.timestamp > s_campaigns[campaignID].endTimestamp && !s_campaignResolved[campaignID],
        "Hippodrome: Campaign already solved");
        Campaign memory campaign = s_campaigns[campaignID];

        _claimSynthetixRewards(campaignID);
        campaign.poolAddress = _createAerodromePoolAndAddLiquidity(
            campaign.tokenAddress,
            campaign.raised,
            campaign.poolSupply
        );
        s_campaignResolved[campaignID] = true;

        emit CampaignTerminated(campaignID,  campaign.raised);
    }
    
 
    //║═════════════════════════════════════════╗
    //║             VIEW FUNCTIONS              ║
    //║═════════════════════════════════════════╝


    function isCampaignResolved(uint128 campaignID) external view override returns(bool){
        return s_campaignResolved[campaignID];
    }

    function getUserStake(address user, uint128 campaignID) external view override returns(uint){
        return s_userStakes[user][campaignID];
    }

    function getAvailableUserRewards(
        address user,
        uint128 campaignID
    ) external view override returns (uint rewards) {
        _getUserRewards(user, campaignID);
    }

    function calculateContributionPercentage(
        uint128 campaignID,
        address user
    ) external view override returns (uint256 percentage) {
        _calculateContributionPercentage(campaignID, user);
    }

    function getUserRewardStatus(
        uint128 campaignID,
        address user
    ) external view override returns (uint totalUserRewards, uint claimed) {
        uint contributionPercentage = _calculateContributionPercentage(
            campaignID,
            user
        );
        Campaign memory campaign = s_campaigns[campaignID];
        totalUserRewards =
            (uint(campaign.rewardSupply) * contributionPercentage) /
            contributionPrecision;
        claimed = s_claims[user][campaignID];
    }

    function getCampaignTokenInfos(uint campaignID) external view override returns (string memory name, string memory symbol) {
        Campaign memory campaign = s_campaigns[campaignID];
        return (
            IERC20Metadata(campaign.tokenAddress).name(),
            IERC20Metadata(campaign.tokenAddress).symbol()
        );
    }

    function getCampaign(uint campaignID) external view override returns (
        address, uint96, address, uint, address, uint, uint88, uint88, uint88, uint88, uint96, string memory
    ) {
        Campaign memory campaign = s_campaigns[campaignID];
        return (
            campaign.founder, 
            campaign.poolSupply, 
            campaign.tokenAddress, 
            campaign.currentStake,
            campaign.poolAddress,
            campaign.raised,
            campaign.startTimestamp, 
            campaign.endTimestamp, 
            campaign.unvestStart,
            campaign.unvestEnd,
            campaign.rewardSupply,
            campaign.campaignURI
        );
    }
    
    function getCampaignAccountId(uint campaignID) public view override returns(uint128 accountID){
        accountID = s_campaignAccounts[campaignID];
    }

    //║═════════════════════════════════════════╗
    //║          internal FUNCTIONS             ║
    //║═════════════════════════════════════════╝

    function _calculateContributionPercentage(
        uint128 campaignID,
        address user
    ) internal view returns (uint256 percentage) {
        uint256 userContribution = _getUserContribution(campaignID, user);
        uint256 totalContribution = _getTotalContribution(campaignID);

        require(
            totalContribution > 0,
            "Total contribution must be greater than zero"
        );
        percentage =
            (userContribution * contributionPrecision) /
            totalContribution;
    }

    function _getUserRewards(
        address user,
        uint128 campaignID
    ) internal view returns (uint rewards) {
        uint contributionPercentage = _calculateContributionPercentage(
            campaignID,
            user
        );
        Campaign memory campaign = s_campaigns[campaignID];
        uint streamStart = campaign.unvestStart;
        uint streamEnd = campaign.unvestEnd;
        uint currentTime = block.timestamp;

        if (currentTime < streamStart) {
            return 0;
        } else if (currentTime > streamEnd) {
            currentTime = streamEnd;
        }

        uint totalUserRewards = (uint(campaign.rewardSupply) *
            contributionPercentage) / contributionPrecision;

        uint elapsedTime = currentTime - streamStart;
        uint streamDuration = streamEnd - streamStart;

        uint claimedRewards = s_claims[user][campaignID];

        rewards =
            ((totalUserRewards * elapsedTime) / streamDuration) -
            claimedRewards;
    }

    function _createContractAndAccount(
        CampaignParams memory campaignParams
    ) internal returns (uint128 accountID) {
        // get tokens from founder
        address campaignToken = campaignParams.tokenAddress;
        uint allocatedSupply = campaignParams.poolSupply +
            campaignParams.rewardSupply;
        IERC20(campaignToken).transferFrom(
            msg.sender,
            address(this),
            allocatedSupply
        );

        // create Synthetix Account
        accountID = IAccountModule(synthCoreProxy).createAccount();
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
            campaignParams.rewardSupply,
            campaignParams.campaignURI
        );

        s_tokens[campaignParams.tokenAddress] = true;
        emit CampaignCreated(
            _campaignCounter,
            msg.sender,
            s_campaigns[_campaignCounter]
        );
    }

    function _depositAndDelegateOnAccount(
        uint128 campaignID,
        uint amount
    ) internal {
        uint128 accountID = s_campaignAccounts[campaignID];
        address memoryFUsdc = fUSDC;
        address memorySUsdc = sUSDC;
        IERC20(memoryFUsdc).transferFrom(msg.sender, address(this), amount);

        // wrap
        IERC20(memoryFUsdc).approve(wrapProxy, amount);
        IWrapperModule(wrapProxy).wrap(1, amount, 0); // from 6 decimals to 18
        

        // deposit
        uint256 adjustedAmount =  amount* 1e12;
        IERC20(memorySUsdc).approve(synthCoreProxy, adjustedAmount);
        ICollateralModule(synthCoreProxy).deposit(accountID, memorySUsdc,  adjustedAmount);

        // make esteem of apy and mint some mockERC20 to use as liquidity 
        // apy is mocked at 20%
        // unfortunately synthetix delegate function has some very-hard-to-debug-solidity-code-and-errors so we can only mock that
        // nontheless testnet would require a simulation environemt, as it may easyly return negative apy. So we opted for a mock
        // the following replace delegate from synthetix
        uint256 amountToMint = (adjustedAmount * 20) / 100;
        MockLiquidityToken(mockLiquidityToken).mint(amountToMint);

        s_campaigns[campaignID].currentStake += uint256(amount);
        s_campaigns[campaignID].raised += uint256(amountToMint);

        _updateAddContribution(msg.sender, campaignID, amount);
    }


    function _claimSynthetixRewards(
        uint campaignID
    )
        internal
        returns (uint256[] memory claimableD18, address[] memory distributors)
    {
        // 10 days on synthetix before claim is available
        uint128 accountID = s_campaignAccounts[campaignID];
        Campaign memory campaign = s_campaigns[campaignID];
        (claimableD18, distributors) = IRewardsManagerModule(synthCoreProxy)
            .updateRewards(_poolID, sUSDC, accountID);
        s_campaigns[campaignID].raised += uint256(claimableD18[0]);
        IRewardsManagerModule(synthCoreProxy).claimRewards(
            accountID,
            _poolID,
            sUSDC,
            distributors[0]
        );
        // get back user tokens (fusdc)
       
        // _withdrawFundsFromAccount(campaign.currentStake);
    }

    function _claimUserCollateral(
        uint128 campaignID,
        address user,
        uint amount
    ) internal {
        uint128 accountID = s_campaignAccounts[campaignID];
        Campaign memory campaign = s_campaigns[campaignID];
        uint userStake = s_userStakes[msg.sender][campaignID];
        require(userStake >= amount, "");
        IRewardsManagerModule(synthCoreProxy).updateRewards(
            _poolID,
            sUSDC,
            accountID
        );
        s_campaigns[campaignID].currentStake -= uint256(amount);
        _updateWithdrawContribution(msg.sender, campaignID, amount);
        _redeemFromSyntethix(accountID, amount);
    }

    
    function _redeemFromSyntethix(uint128 accountID, uint amount) internal {
        uint256 adjustedAmount =  amount * 1e12;
        ICollateralModule(synthCoreProxy).withdraw(accountID, sUSDC, adjustedAmount);
        (uint returnedFusdc, ) = IWrapperModule(wrapProxy).unwrap(1, adjustedAmount, 0);
        IERC20(fUSDC).transfer(msg.sender, returnedFusdc);
    }

    function _createAerodromePoolAndAddLiquidity(
        address xToken,
        uint256 amountRaised,
        uint256 poolSupply
    ) internal returns (address poolAddress) {
        poolAddress = IPoolFactory(aerodromePoolFactory).createPool(
            xToken,
            mockLiquidityToken,
            false
        );
        IERC20(xToken).approve(aerodromeRouter, poolSupply);
        IERC20(mockLiquidityToken).approve(aerodromeRouter, amountRaised);
        IRouter(aerodromeRouter).addLiquidity(
            xToken,
            mockLiquidityToken,
            false,
            poolSupply,
            amountRaised,
            poolSupply,
            0,
            address(this),
            block.timestamp
        );
    }

    function _getUserContribution(
        uint128 campaignID,
        address user
    ) internal view returns (uint256 userContribution) {
        Launch storage launch = s_launches[campaignID];
        UserStake storage userStake = launch.userStakes[user];
        uint256 pastContribution = (block.timestamp - userStake.lastStakeTime) *
            userStake.amount;
        userContribution = userStake.totalContribution + pastContribution;
    }

    function _getTotalContribution(
        uint128 campaignID
    ) internal view returns (uint256 totalContribution) {
        Launch storage launch = s_launches[campaignID];
        uint256 pastContribution = (block.timestamp - launch.lastUpdateTime) *
            launch.totalStaked;
        totalContribution = launch.totalContribution + pastContribution;
    }

    function _updateAddContribution(
        address user,
        uint128 campaignID,
        uint256 amount
    ) internal {
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

    function _updateWithdrawContribution(
        address user,
        uint128 campaignID,
        uint256 amount
    ) internal {
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
