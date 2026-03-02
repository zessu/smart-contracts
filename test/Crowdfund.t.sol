// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {CrowdFund} from "../src/Crowdfund.sol";

contract CrowdFundTest is Test {
    ERC20Mock public token;
    CrowdFund public crowdFund;

    address public owner;
    address public contributor1;
    address public contributor2;

    uint256 constant INITIAL_MINT = 1000e18;

    function setUp() public {
        token = new ERC20Mock();
        crowdFund = new CrowdFund(address(token));

        owner = vm.addr(1);
        contributor1 = vm.addr(2);
        contributor2 = vm.addr(3);

        token.mint(contributor1, INITIAL_MINT);
        token.mint(contributor2, INITIAL_MINT);
    }

    function testLaunch() public {
        uint256 goal = 100e18;
        uint256 duration = 1 weeks;

        vm.prank(owner);
        crowdFund.launch(goal, duration);

        assertEq(crowdFund.getCampaign(1).creator, owner);
        assertEq(crowdFund.getCampaign(1).goal, goal);
        assertGt(crowdFund.getCampaign(1).campaignEnd, block.timestamp);
        assertEq(crowdFund.getCampaign(1).totalAmount, 0);
        assertEq(crowdFund.getCampaign(1).ended, false);
        assertEq(crowdFund.count(), 1);
    }

    function testPledge() public {
        uint256 goal = 100e18;
        uint256 duration = 1 weeks;
        uint256 pledgeAmount = 50e18;

        vm.prank(owner);
        crowdFund.launch(goal, duration);

        vm.prank(contributor1);
        token.approve(address(crowdFund), pledgeAmount);
        vm.prank(contributor1);
        crowdFund.pledge(pledgeAmount, 1);

        assertEq(crowdFund.getCampaign(1).totalAmount, pledgeAmount);
        assertEq(crowdFund.contributions(1, contributor1), pledgeAmount);
    }

    function testPledgeFailsIfCampaignEnded() public {
        uint256 goal = 100e18;
        uint256 duration = 1 weeks;

        vm.prank(owner);
        crowdFund.launch(goal, duration);

        vm.prank(contributor1);
        token.approve(address(crowdFund), 50e18);
        vm.prank(contributor1);
        crowdFund.pledge(50e18, 1);

        vm.prank(owner);
        crowdFund.cancel(1);

        vm.prank(contributor2);
        vm.expectRevert();
        crowdFund.pledge(50e18, 1);
    }

    function testUnpledge() public {
        uint256 goal = 100e18;
        uint256 duration = 1 weeks;
        uint256 pledgeAmount = 50e18;

        vm.prank(owner);
        crowdFund.launch(goal, duration);

        vm.prank(contributor1);
        token.approve(address(crowdFund), pledgeAmount);
        vm.prank(contributor1);
        crowdFund.pledge(pledgeAmount, 1);

        uint256 balanceBefore = token.balanceOf(contributor1);

        vm.prank(contributor1);
        crowdFund.unpledge(pledgeAmount, 1);

        assertEq(crowdFund.getCampaign(1).totalAmount, 0);
        assertEq(crowdFund.contributions(1, contributor1), 0);
        assertEq(token.balanceOf(contributor1), balanceBefore + pledgeAmount);
    }

    function testClaim() public {
        uint256 goal = 100e18;
        uint256 duration = 1 weeks;
        uint256 pledgeAmount = 100e18;

        vm.prank(owner);
        crowdFund.launch(goal, duration);

        vm.prank(contributor1);
        token.approve(address(crowdFund), pledgeAmount);
        vm.prank(contributor1);
        crowdFund.pledge(pledgeAmount, 1);

        uint256 balanceBefore = token.balanceOf(owner);

        vm.prank(owner);
        crowdFund.claim(1);

        assertEq(crowdFund.getCampaign(1).ended, true);
        assertEq(crowdFund.getCampaign(1).goalAchieved, true);
        assertEq(token.balanceOf(owner), balanceBefore + pledgeAmount);
    }

    function testClaimFailsIfGoalNotMet() public {
        uint256 goal = 100e18;
        uint256 duration = 1 weeks;
        uint256 pledgeAmount = 50e18;

        vm.prank(owner);
        crowdFund.launch(goal, duration);

        vm.prank(contributor1);
        token.approve(address(crowdFund), pledgeAmount);
        vm.prank(contributor1);
        crowdFund.pledge(pledgeAmount, 1);

        vm.prank(owner);
        vm.expectRevert();
        crowdFund.claim(1);
    }

    function testCancel() public {
        uint256 goal = 100e18;
        uint256 duration = 1 weeks;

        vm.prank(owner);
        crowdFund.launch(goal, duration);

        vm.prank(owner);
        crowdFund.cancel(1);

        assertEq(crowdFund.getCampaign(1).ended, true);
        assertEq(crowdFund.getCampaign(1).goalAchieved, false);
    }

    function testCancelFailsIfNotCreator() public {
        uint256 goal = 100e18;
        uint256 duration = 1 weeks;

        vm.prank(owner);
        crowdFund.launch(goal, duration);

        vm.prank(contributor1);
        vm.expectRevert();
        crowdFund.cancel(1);
    }

    function testRefund() public {
        uint256 goal = 100e18;
        uint256 duration = 1 weeks;
        uint256 pledgeAmount = 50e18;

        vm.prank(owner);
        crowdFund.launch(goal, duration);

        vm.prank(contributor1);
        token.approve(address(crowdFund), pledgeAmount);
        vm.prank(contributor1);
        crowdFund.pledge(pledgeAmount, 1);

        vm.prank(owner);
        crowdFund.cancel(1);

        uint256 balanceBefore = token.balanceOf(contributor1);

        vm.prank(contributor1);
        crowdFund.refund(1, pledgeAmount);

        assertEq(crowdFund.contributions(1, contributor1), 0);
        assertEq(token.balanceOf(contributor1), balanceBefore + pledgeAmount);
    }

    function testRefundFailsIfCampaignNotEnded() public {
        uint256 goal = 100e18;
        uint256 duration = 1 weeks;
        uint256 pledgeAmount = 50e18;

        vm.prank(owner);
        crowdFund.launch(goal, duration);

        vm.prank(contributor1);
        token.approve(address(crowdFund), pledgeAmount);
        vm.prank(contributor1);
        crowdFund.pledge(pledgeAmount, 1);

        vm.prank(contributor1);
        vm.expectRevert();
        crowdFund.refund(1, pledgeAmount);
    }
}
