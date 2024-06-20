// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IHippodromeTypes} from "./types/HippodromeTypes.sol";
import {IAccountModule} from "./interfaces/IAccount.sol";
import {ICollateralModule} from "./interfaces/ICollateralModule.sol";
import {IVaultModule} from "./interfaces/IVault.sol";
import {IRewardsManagerModule} from "./interfaces/IRewardsManagerModule.sol";
import {xERC20Token} from "./xERC20Token.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/Token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@aerodrome/interfaces/factories/IPoolFactory.sol";
import "@aerodrome/interfaces/IPool.sol";
import "@aerodrome/interfaces/IRouter.sol";


contract Hippodrome is IERC721Receiver { 
    address fUSDC = 0xc43708f8987Df3f3681801e5e640667D86Ce3C30;
    address accountRouter = 0x764F4C95FDA0D6f8114faC54f6709b1B45f919a1;
    address positionModule = 0xaD2fE7cd224c58871f541DAE01202F93928FEF72;
    address sUSDC = 0x8069c44244e72443722cfb22DcE5492cba239d39;
    address aerodromePoolFactory = 0x9F631b6E37045E0C66ed2d6AE28eEb53A5bda82D;
    address aerodromeRouter = 0x70bD534579cbaBbE9Cd4AD4210e29CC9BA1E9287;
    uint internal _campaignCounter;
    address xERC20Implementation;
    uint128 internal _poolID = 1;
  
  
    mapping(uint=>IHippodromeTypes.Campaign) s_campaigns;
    mapping(uint=>uint128) s_campaignAccounts;
    mapping(address=>mapping(uint128=>uint256)) s_userStakes;
    mapping(address=>mapping(uint128=>uint256)) s_contributions;

    

    constructor(address _accountRouter) {
        xERC20Implementation = address(new xERC20Token());
        accountRouter = _accountRouter;
    }


     mapping(uint256 => Launch) public launches;


    function stake(uint256 campaignID, uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");

        Launch storage launch = launches[campaignID];
        UserStake storage userStake = launch.userStakes[msg.sender];

        // Update global total contribution with elapsed time since last update
        uint256 timeElapsed = block.timestamp - launch.lastUpdateTime;
        if (launch.totalStaked > 0) {
            launch.totalContribution += timeElapsed * launch.totalStaked;
        }
        launch.lastUpdateTime = block.timestamp;

        // If user already has a stake, calculate their contribution up to this point
        if (userStake.amount > 0) {
            uint256 userTimeElapsed = block.timestamp - userStake.lastStakeTime;
            userStake.totalContribution += userTimeElapsed * userStake.amount;
        }

        // Update user's stake and total staked
        userStake.amount += amount;
        userStake.lastStakeTime = block.timestamp;
        launch.totalStaked += amount;

        emit Staked(campaignID, msg.sender, amount);
    }

    function withdraw(uint256 campaignID, uint256 amount) external {
        Launch storage launch = launches[campaignID];
        UserStake storage userStake = launch.userStakes[msg.sender];
        require(userStake.amount >= amount, "Insufficient staked amount");

        // Update global total contribution with elapsed time since last update
        uint256 timeElapsed = block.timestamp - launch.lastUpdateTime;
        if (launch.totalStaked > 0) {
            launch.totalContribution += timeElapsed * launch.totalStaked;
        }
        launch.lastUpdateTime = block.timestamp;

        // Calculate user's contribution up to this point
        uint256 userTimeElapsed = block.timestamp - userStake.lastStakeTime;
        userStake.totalContribution += userTimeElapsed * userStake.amount;

        // Update user's stake and total staked
        userStake.amount -= amount;
        userStake.lastStakeTime = block.timestamp;
        launch.totalStaked -= amount;

        // Assume transfer of the token amount back to the user in a real scenario

        emit Withdrawn(campaignID, msg.sender, amount);
    }

    function getUserContribution(uint256 campaignID, address user) public view returns (uint256 userContribution) {
        Launch storage launch = launches[campaignID];
        UserStake storage userStake = launch.userStakes[user];
        uint256 pastContribution = (block.timestamp - userStake.lastStakeTime) * userStake.amount;
        userContribution = userStake.totalContribution + pastContribution;
    }

    function getTotalContribution(uint256 campaignID) public view returns (uint256 totalContribution) {
        Launch storage launch = launches[campaignID];
        uint256 pastContribution = (block.timestamp - launch.lastUpdateTime) * launch.totalStaked;
        totalContribution = launch.totalContribution + pastContribution;
    }

    function calculateContributionPercentage(uint256 campaignID, address user) public view returns (uint256 percentage) {
        uint256 userContribution = getUserContribution(campaignID, user);
        uint256 totalContribution = getTotalContribution(campaignID);

        require(totalContribution > 0, "Total contribution must be greater than zero");

        // Percentage as 100000 for 100%
        percentage = (userContribution * 100000) / totalContribution;
    }



    //║══════════════════════════════════════════╗
    //║             USER FUNCTIONS               ║
    //║══════════════════════════════════════════╝

    function createCampaign(IHippodromeTypes.CampaignParams memory campaignParams) public returns(uint128 accountID){
        ++_campaignCounter;
        accountID = _createContractAndAccount(campaignParams);
    }
    

    
    function fundCampaign(uint128 campaignID, uint amount, ) public {    
        s_userStakes[msg.sender][campaignID] += amount;   
        _depositAndDelegateOnAccount(campaignID, amount);
    }

    function claimRewards(uint128 campaignID) public {

    }


    //║══════════════════════════════════════════╗
    //║            INTERNAL FUNCTIONS            ║
    //║══════════════════════════════════════════╝

    function seeCurrentRewards(uint128 campaignID) public {

    }


    function _createContractAndAccount(IHippodromeTypes.CampaignParams memory campaignParams) internal returns(uint128 accountID){
        // clone implemntation
        address clone = Clones.clone(xERC20Implementation);
        // initialize clone contract
        xERC20Token(clone).init(campaignParams.tokenName,campaignParams.tokenSymbol,campaignParams.allocatedSupply);
        // create Synthetix Account
        accountID = IAccountModule(accountRouter).createAccount();
        // map the id 
        s_campaignAccounts[_campaignCounter] = accountID;
        // map the campaign params
        s_campaigns[_campaignCounter] = IHippodromeTypes.Campaign(
            msg.sender, 
            campaignParams.allocatedSupply,
            clone,
            0,
            address(0),
            0,
            campaignParams.startTimestamp,
            campaignParams.endTimestamp,
            campaignParams.rewardSupplyRate,
            campaignParams.unvestingStreamStart, 
            campaignParams.unvestingStreamEnd
        );
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
    
    function resolveCampaign(uint campaignID) public {
        IHippodromeTypes.Campaign memory campaign = s_campaigns[campaignID];
        _claimSynthetixRewards(campaignID);
        uint poolSupply = ((campaign.allocatedSupply * campaign.rewardSupplyRate) / 100);
        campaign.poolAddress = _createAerodromePool(campaign.tokenAddress, campaign.raised, poolSupply);
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


    
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        // Implement your logic here (e.g., logging, custom behavior, etc.)
        
        // Return the selector to confirm the transfer
        return this.onERC721Received.selector;
    }
}
