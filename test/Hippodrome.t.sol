// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {XToken} from "./utils/xToken.sol";
import "./utils/HippodromeMock.sol";
import {IHippodromeTypes} from "../src/interfaces//types/IHippodromeTypes.sol";


contract HippodromeTest is Test {
    
    address fUSDC = 0xc43708f8987Df3f3681801e5e640667D86Ce3C30;
    address accountRouter = 0x764F4C95FDA0D6f8114faC54f6709b1B45f919a1;
    address positionModule = 0xaD2fE7cd224c58871f541DAE01202F93928FEF72;
    address sUSDC = 0x8069c44244e72443722cfb22DcE5492cba239d39;
    address aerodromePoolFactory = 0x9F631b6E37045E0C66ed2d6AE28eEb53A5bda82D;
    address aerodromeRouter = 0x70bD534579cbaBbE9Cd4AD4210e29CC9BA1E9287;

    HippodromeMock hd;
    XToken xToken;
    function setUp() public {
        hd = new HippodromeMock(
            accountRouter,
            fUSDC,
            positionModule,
            sUSDC,
            aerodromePoolFactory,
            aerodromeRouter
            );
        xToken = new XToken("xToken", "xT");
    }

    function test_CreateCamapign() public {
     
        uint96 poolSupply = 100e6;
        // approve Hippodrome 
        IERC20(xToken).approve(address(hd), 110e6);
        // create campaignParams
        IHippodromeTypes.CampaignParams memory campaignParams = IHippodromeTypes.CampaignParams(
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
        uint128 accountID = hd.createCampaign(campaignParams);
        // assert counter increases accordigly
        assertTrue(
            hd._campaignCounter() == 1
        );
        // assert accountID is coupled with campaignID
        assertTrue(
            hd.s_campaignAccounts(1) == accountID
        );

        // expect revert on creating campaign on same token 
        vm.expectRevert(bytes4(keccak256("CampaignAlreadyExist()")));
        hd.createCampaign(campaignParams);
       
    }

    function test_fundCampaign() public {
        // self deal fUSDC to add liquidity
        deal(fUSDC, address(this), 1e8);
        // approve Hippodrome
        IERC20(fUSDC).approve(address(hd), 1e8);
        // expect revert if the campaign dosent exists due to onlyActiveCampaign() modifier
        vm.expectRevert();
        hd.fundCampaign(1, 1e8);
        // create campaign id 1
        createCampaign();
        // fund campaign
        hd.fundCampaign(1, 1e8);
        // assert user balance = 0 after funding
        assertTrue(
            IERC20(fUSDC).balanceOf(address(this)) == 0
        );
    }


    // function test_FundCampign() public {
    //     deal(fusdc,address(this), 1e30);
    //     IERC20(fusdc).approve(address(hd), 1e30);
    //     console.logUint(IERC20(fusdc).balanceOf(address(hd)));
    //     uint96 amount = 100e6;
    //     IHippodromeTypes.CampaignParams memory campaignParams = IHippodromeTypes.CampaignParams(
    //         amount, uint88(block.timestamp), uint88(block.timestamp + 1 days),  uint88(block.timestamp + 1 days), uint88(block.timestamp + 1 days), 2, "viva", "il", "duce" 
    //     );
    //     uint128 accountID = hd.createCampaign(campaignParams);

    //     hd.fundCampaign(1, amount);
    //     (uint256[] memory claimableD18, address[] memory distributors) =  hd._claimSynthetixRewards(1);
    // }

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
    


    
    //║══════════════════════════════════════════╗
    //║            Utility FUNCTIONS             ║
    //║══════════════════════════════════════════╝

        function createCampaign() internal {
        uint96 poolSupply = 100e6;
        // approve Hippodrome 
        IERC20(xToken).approve(address(hd), 110e6);
        // create campaignParams
        IHippodromeTypes.CampaignParams memory campaignParams = IHippodromeTypes.CampaignParams(
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
        uint128 accountID = hd.createCampaign(campaignParams);
    }
}
