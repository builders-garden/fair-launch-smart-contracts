// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {XToken} from "./utils/xToken.sol";
import "./utils/HippodromeMock.sol";
import {IHippodromeTypes} from "../src/interfaces//types/IHippodromeTypes.sol";
import {ICollateralModule} from "./interfaces/ICollateralModule.sol";
import {IWrapperModule} from "../src/interfaces/IWrapperModule.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";


contract HippodromeTest is Test, IERC721Receiver {
    address fUSDC = 0xc43708f8987Df3f3681801e5e640667D86Ce3C30;
    address synthCoreProxy = 0x764F4C95FDA0D6f8114faC54f6709b1B45f919a1;
    address wrapProxy = 0xaD2fE7cd224c58871f541DAE01202F93928FEF72;
    address sUSDC = 0x8069c44244e72443722cfb22DcE5492cba239d39;
    address aerodromePoolFactory = 0x9F631b6E37045E0C66ed2d6AE28eEb53A5bda82D;
    address aerodromeRouter = 0x70bD534579cbaBbE9Cd4AD4210e29CC9BA1E9287;

    HippodromeMock hd;
    XToken xToken;
    uint128 public accountID;
    function setUp() public {
        hd = new HippodromeMock(
            synthCoreProxy,
            fUSDC,
            wrapProxy,
            sUSDC,
            aerodromePoolFactory,
            aerodromeRouter
        );
        xToken = new XToken("xToken", "xT");
    }

    modifier campaignCreated() {
        uint96 poolSupply = 100e6;
        // approve Hippodrome
        IERC20(xToken).approve(address(hd), 110e6);
        // create campaignParams
        IHippodromeTypes.CampaignParams memory campaignParams = IHippodromeTypes
            .CampaignParams(
                poolSupply,
                uint88(block.timestamp), // now
                uint88(block.timestamp + 30 days), // end
                uint88(block.timestamp + 30 days), // vest start
                uint88(block.timestamp + 60 days), // vest end
                poolSupply / 10, // 10% of pool supply
                address(xToken),
                "data"
            );
        // create campaign
        accountID = hd.createCampaign(campaignParams);
        _;
    }

    // to run it: forge test --fork-url https://sepolia.base.org -vvv --mt test_SV3_DepositAndWithdraw
    function test_SV3_DepositAndWithdraw() public campaignCreated {
        uint256 initialDeposit = 1e6;
        uint256 initialStake = hd.s_userStakes(address(this),1);
        assertEq(initialStake, 0);


        deal(fUSDC, address(this), initialDeposit);
        IERC20(fUSDC).approve(address(hd), initialDeposit);
        hd.fundCampaign(1, initialDeposit);
        uint256 stakeAfterDeposit = hd.s_userStakes(address(this),1);
        assertEq(stakeAfterDeposit, initialDeposit);
        hd.withdrawFunds(1, initialDeposit);
        uint256 stakeAfterWithdraw = hd.s_userStakes(address(this),1);
        assertEq(stakeAfterWithdraw, 0);
    }



    function test_CreateCamapign() public {
         uint96 poolSupply = 100e6;
        // approve Hippodrome
        IERC20(xToken).approve(address(hd), 110e6);
        // create campaignParams
        IHippodromeTypes.CampaignParams memory campaignParams = IHippodromeTypes
            .CampaignParams(
                poolSupply,
                uint88(block.timestamp), // now
                uint88(block.timestamp + 30 days), // end
                uint88(block.timestamp + 30 days), // vest start
                uint88(block.timestamp + 60 days), // vest end
                poolSupply / 10, // 10% of pool supply
                address(xToken),
                "data"
            );
        // create campaign
        accountID = hd.createCampaign(campaignParams);
        // assert counter increases accordigly
        assertTrue(hd._campaignCounter() == 1);
        // assert accountID is coupled with campaignID
        assertTrue(hd.s_campaignAccounts(1) == accountID);

        // expect revert on creating campaign on same token
        vm.expectRevert(bytes4(keccak256("CampaignAlreadyExist()")));
        hd.createCampaign(campaignParams);
    }

    function test_fundCampaign() public campaignCreated {
        // self deal fUSDC to add liquidity
        deal(fUSDC, address(this), 1e8);

        // approve Hippodrome
        IERC20(fUSDC).approve(address(hd), 1e8);
        // expect revert if the campaign dosent exists due to onlyActiveCampaign() modifier
        vm.expectRevert();
        hd.fundCampaign(10, 1e8);
        // create campaign id 1
        // fund campaign
        hd.fundCampaign(1, 1e8);
        // assert user balance = 0 after funding
        assertTrue(IERC20(fUSDC).balanceOf(address(this)) == 0);
    }

    function test_withdrawFunds() public campaignCreated {
        // withdraw funds
        vm.expectRevert();
        hd.withdrawFunds(10, 1e8);

    }

    function test_resolveCampaign() public campaignCreated {
        deal(fUSDC, address(this), 1e8);
        deal(fUSDC, address(hd), 1e8);
        IERC20(fUSDC).approve(address(hd), 1e30);
        // createCampaign();
        hd.fundCampaign(1, 1e8);
        // warp 30 days ahead
        vm.warp(block.timestamp + 90 days);

        IERC20(sUSDC).approve(address(hd), 1e30);
        // assert user balance = 0 after funding
        (uint256[] memory claimableD18, address[] memory distributors) = hd
            ._claimSynthetixRewards(1);
        hd.resolveCampaign(1);
        

        // finally claim rewards
        hd.claimRewards(1);
        
    }

    //║══════════════════════════════════════════╗
    //║            Utility FUNCTIONS             ║
    //║══════════════════════════════════════════╝
    function createCampaign() internal returns (uint128 accountID) {
        uint96 poolSupply = 100e6;
        // approve Hippodrome
        IERC20(xToken).approve(address(hd), 110e6);
        // create campaignParams
        IHippodromeTypes.CampaignParams memory campaignParams = IHippodromeTypes
            .CampaignParams(
                poolSupply,
                uint88(block.timestamp), // now
                uint88(block.timestamp + 30 days), // end
                uint88(block.timestamp + 30 days), // vest start
                uint88(block.timestamp + 60 days), // vest end
                poolSupply / 10, // 10% of pool supply
                address(xToken),
                "data"
            );
        // create campaign
        accountID = hd.createCampaign(campaignParams);
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
