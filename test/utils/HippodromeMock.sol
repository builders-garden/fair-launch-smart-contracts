// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IHippodrome} from "../../src/interfaces/IHippodrome.sol";
import {IAccountModule} from "../../src/interfaces/IAccount.sol";
import {ICollateralModule} from "../../src/interfaces/ICollateralModule.sol";
import {IVaultModule} from "../../src/interfaces/IVault.sol";
import {IRewardsManagerModule} from "../../src/interfaces/IRewardsManagerModule.sol";
import {IWrapperModule} from "../../src/interfaces/IWrapperModule.sol";
import {MockLiquidityToken} from "./MockLiquidityToken.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/Token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@aerodrome/interfaces/factories/IPoolFactory.sol";
import "@aerodrome/interfaces/IPool.sol";
import "@aerodrome/interfaces/IRouter.sol";

contract HippodromeMock is IERC721Receiver, IHippodrome {
    address public fUSDC;
    uint8 public _poolID = 1;
    uint24 constant contributionPrecision = 1e5; 
    
    address public accountRouter;
    address public wrapProxy;
    address public sUSDC;
    address public aerodromePoolFactory;
    address public aerodromeRouter;
    address public mockLiquidityToken;
    uint public _campaignCounter; 

    mapping(uint => Campaign) public s_campaigns;
    mapping(uint => uint128) public s_campaignAccounts;
    mapping(address => mapping(uint128 => uint256)) public s_userStakes;
    mapping(address => mapping(uint128 => uint256)) public s_contributions;
    mapping(uint256 => Launch) public s_launches;
    mapping(address => bool) public s_tokens;
    mapping(address => mapping(uint128 => uint256)) public s_claims;
    mapping(address => mapping(uint128 => uint256)) public s_depositTimestamps;
    mapping(uint128 => bool) public s_campaignResolved;

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
        address _accountRouter,
        address _fUSDC,
        address _wrapModule,
        address _sUSDC,
        address _aerodromePoolFactory,
        address _aerodromeRouter
    ) {
        accountRouter = _accountRouter;
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
    }

    function claimRewards(uint128 campaignID) external override {
        uint rewards = _getUserRewards(msg.sender, campaignID);
        require(
            rewards > s_claims[msg.sender][campaignID],
            "Hippodrome: claimed"
        );
        Campaign memory campaign = s_campaigns[campaignID];

        IERC20(campaign.tokenAddress).transfer(msg.sender, rewards);
        s_claims[msg.sender][campaignID] = rewards;

        emit RewardsClaimed(campaignID, msg.sender, rewards);
    }

    // either make it callable by anyone or automate
    function resolveCampaign(uint128 campaignID) external override {
        Campaign memory campaign = s_campaigns[campaignID];

        _claimSynthetixRewards(campaignID);
        campaign.poolAddress = _createAerodromePoolAndAddLiquidity(
            campaign.tokenAddress,
            campaign.raised,
            campaign.poolSupply
        );
        s_campaignResolved[campaignID] = true;
    }

    //║═════════════════════════════════════════╗
    //║             VIEW FUNCTIONS              ║
    //║═════════════════════════════════════════╝

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
    ) external view override returns (uint totalRewards, uint claimed) {
        uint contributionPercentage = _calculateContributionPercentage(
            campaignID,
            user
        );
        Campaign memory campaign = s_campaigns[campaignID];
        totalRewards =
            (uint(campaign.rewardSupply) * contributionPercentage) /
            contributionPrecision;
        claimed = s_claims[user][campaignID];
    }

    //║═════════════════════════════════════════╗
    //║            public FUNCTIONS             ║
    //║═════════════════════════════════════════╝

    function _calculateContributionPercentage(
        uint128 campaignID,
        address user
    ) public view returns (uint256 percentage) {
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
    ) public view returns (uint rewards) {
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

        uint totalRewards = (uint(campaign.rewardSupply) *
            contributionPercentage) / contributionPrecision;

        uint elapsedTime = currentTime - streamStart;
        uint streamDuration = streamEnd - streamStart;

        uint claimedRewards = s_claims[user][campaignID];

        rewards =
            ((totalRewards * elapsedTime) / streamDuration) -
            claimedRewards;
    }

    function _createContractAndAccount(
        CampaignParams memory campaignParams
    ) public returns (uint128 accountID) {
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
    ) public {
        uint128 accountID = s_campaignAccounts[campaignID];
        address memoryFUsdc = fUSDC;
        address memorySUsdc = sUSDC;
        IERC20(memoryFUsdc).transferFrom(msg.sender, address(this), amount);

        // wrap
        IERC20(memoryFUsdc).approve(wrapProxy, amount);
        IWrapperModule(wrapProxy).wrap(1, amount, 0);
        

        // deposit
        IERC20(memorySUsdc).approve(accountRouter, 1e18);
        ICollateralModule(accountRouter).deposit(accountID, memorySUsdc, amount);

        // make esteem of apy and mint some mockERC20 to use as liquidity 
        // apy is always at 20%
        // unfortunately synthetix delegate function has some very-hard-to-debug-spaghetti-solidity-code-and-errors so we can only mock that
        // the following replace delegate from synthetix
        uint256 amountToMint = (amount * 20) / 100;
        MockLiquidityToken(mockLiquidityToken).mint(amountToMint);

        s_campaigns[campaignID].currentStake += uint256(amount);
        s_campaigns[campaignID].raised += uint256(amountToMint);

        _updateAddContribution(msg.sender, campaignID, amount);
    }


    function _claimSynthetixRewards(
        uint campaignID
    )
        public
        returns (uint256[] memory claimableD18, address[] memory distributors)
    {
        // 10 days on synthetix before claim is available
        uint128 accountID = s_campaignAccounts[campaignID];
        Campaign memory campaign = s_campaigns[campaignID];
        (claimableD18, distributors) = IRewardsManagerModule(accountRouter)
            .updateRewards(_poolID, sUSDC, accountID);
        s_campaigns[campaignID].raised += uint256(claimableD18[0]);
        IRewardsManagerModule(accountRouter).claimRewards(
            accountID,
            _poolID,
            sUSDC,
            distributors[0]
        );
        // _withdrawFundsFromAccount(campaign.currentStake);
    }

    function _claimUserCollateral(
        uint128 campaignID,
        address user,
        uint amount
    ) public {
        uint128 accountID = s_campaignAccounts[campaignID];
        Campaign memory campaign = s_campaigns[campaignID];
        uint userStake = s_userStakes[msg.sender][campaignID];
        require(userStake >= amount, "");
        IRewardsManagerModule(accountRouter).updateRewards(
            _poolID,
            sUSDC,
            accountID
        );
        s_campaigns[campaignID].currentStake -= uint256(amount);
        _updateWithdrawContribution(msg.sender, campaignID, amount);

        ICollateralModule(accountRouter).withdraw(accountID, sUSDC, amount);
        IWrapperModule(wrapProxy).unwrap(1, 1e18, 0);
    }

    function _createAerodromePoolAndAddLiquidity(
        address xToken,
        uint256 amountRaised,
        uint256 poolSupply
    ) public returns (address poolAddress) {
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
    ) public view returns (uint256 userContribution) {
        Launch storage launch = s_launches[campaignID];
        UserStake storage userStake = launch.userStakes[user];
        uint256 pastContribution = (block.timestamp - userStake.lastStakeTime) *
            userStake.amount;
        userContribution = userStake.totalContribution + pastContribution;
    }

    function _getTotalContribution(
        uint128 campaignID
    ) public view returns (uint256 totalContribution) {
        Launch storage launch = s_launches[campaignID];
        uint256 pastContribution = (block.timestamp - launch.lastUpdateTime) *
            launch.totalStaked;
        totalContribution = launch.totalContribution + pastContribution;
    }

    function _updateAddContribution(
        address user,
        uint128 campaignID,
        uint256 amount
    ) public {
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
    ) public {
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
