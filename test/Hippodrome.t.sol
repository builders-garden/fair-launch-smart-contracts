// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../src/Hippodrome.sol";

contract HippodromeTest is Test {
    address fusdc = 0xc43708f8987Df3f3681801e5e640667D86Ce3C30;
    address accountRouter = 0x764F4C95FDA0D6f8114faC54f6709b1B45f919a1;
    address positionModule =0xaD2fE7cd224c58871f541DAE01202F93928FEF72;
    Hippodrome hd;
    function setUp() public {
        hd = new Hippodrome(accountRouter);
    }

    function test_CreateCamapign() public {
        uint96 amount = 100e6;
        IHippodromeTypes.CampaignParams memory campaignParams = IHippodromeTypes.CampaignParams(
            amount, uint88(block.timestamp), uint88(block.timestamp + 1 days),  uint88(block.timestamp + 1 days), uint88(block.timestamp + 1 days), 2, "viva", "il", "duce" 
        );
        hd.createCampaign(campaignParams);
    }

    function test_FundCampign() public {
        deal(fusdc,address(this), 1e30);
        IERC20(fusdc).approve(address(hd), 1e30);
        console.logUint(IERC20(fusdc).balanceOf(address(hd)));
        uint96 amount = 100e6;
        IHippodromeTypes.CampaignParams memory campaignParams = IHippodromeTypes.CampaignParams(
            amount, uint88(block.timestamp), uint88(block.timestamp + 1 days),  uint88(block.timestamp + 1 days), uint88(block.timestamp + 1 days), 2, "viva", "il", "duce" 
        );
        uint128 accountID = hd.createCampaign(campaignParams);

        hd.fundCampaign(1, amount);
        (uint256[] memory claimableD18, address[] memory distributors) =  hd._claimSynthetixRewards(1);
    }

    // function test_resolveCampaign() public {
    //     deal(fusdc,address(this), 1e30);
      
    //     IERC20(fusdc).approve(address(hd), 1e30);
        
    //     uint96 amount = 100e6;
    //     IHippodromeTypes.CampaignParams memory campaignParams = IHippodromeTypes.CampaignParams(
    //         amount, uint88(block.timestamp), uint88(block.timestamp + 1 days),  uint88(block.timestamp + 1 days), uint88(block.timestamp + 1 days), 2, "viva", "il", "duce" 
    //     );
    //     uint128 accountID = hd.createCampaign(campaignParams);

    //     hd.fundCampaign(1, amount);
    //     (uint256[] memory claimableD18, address[] memory distributors) =  hd._claimSynthetixRewards(1);

    //     hd.resolveCampaign(1);
        
    // }

}
