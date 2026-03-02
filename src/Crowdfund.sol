// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract CrowdFund {
    using SafeERC20 for IERC20;
    event Launch(uint256 indexed campaignId, address indexed launcher, uint256 goal, uint256 endTime);
    event Ended(uint256 indexed campaignId, address creator, uint256 totalAmount, uint256 endedAt, bool goalAchieved);
    event Pledged(uint256 amount, address indexed contributor, uint256 indexed campaignId);
    event Unpledge(address pledger, uint256 amount, uint256 indexed campaignId);
    event Refund(uint256 amount, address indexed sender);

    struct Campaign {
        address creator;
        uint256 goal;
        uint256 totalAmount;
        uint256 createdAt;
        uint256 campaignEnd;
        uint256 endedAt;
        uint256 campaignId;
        bool goalAchieved;
        bool ended;
    }

    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => uint256)) public contributions;
    IERC20 public immutable TOKEN;
    uint256 public count;

    function getCampaign(uint256 _campaignId) external view returns (Campaign memory) {
        return campaigns[_campaignId];
    }

    constructor(address erc20Token) {
        TOKEN = IERC20(erc20Token);
    }

    function launch(uint256 _campainGoal, uint256 _campainEndTime) external {
        require(_campainEndTime > block.timestamp, "Campaign end time must be set some day in the future");
        count += 1;
        campaigns[count] = Campaign({
            creator: msg.sender,
            goal: _campainGoal,
            totalAmount: 0,
            createdAt: block.timestamp,
            campaignEnd: _campainEndTime,
            endedAt: 0,
            campaignId: count,
            goalAchieved: false,
            ended: false
        });

        emit Launch(count, msg.sender, _campainGoal, _campainEndTime);
    }

    function cancel(uint256 _campaignId) external {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.creator != address(0), "Campaign does not exist");
        require(msg.sender == campaign.creator, "You do not have permission to cancel this campaign");
        require(!campaign.ended, "Campain already ended");

        campaign.ended = true;
        campaign.goalAchieved = false;
        campaign.endedAt = block.timestamp;

        emit Ended(count, campaign.creator, campaign.totalAmount, campaign.endedAt, campaign.goalAchieved);
    }

    function pledge(uint256 _amount, uint256 _campaignId) external {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.creator != address(0), "Campaign does not exist");
        require(!campaign.ended, "Campaign has ended");

        campaign.totalAmount += _amount;
        contributions[_campaignId][msg.sender] += _amount;
        TOKEN.safeTransferFrom(msg.sender, address(this), _amount);

        emit Pledged(_amount, msg.sender, _campaignId);
    }

    function unpledge(uint256 _amount, uint256 _campaignId) external {
        Campaign storage campaign = campaigns[_campaignId];
        require(!campaign.ended, "Campaign has ended, please call claim instead to get your funds");
        require(contributions[_campaignId][msg.sender] >= _amount, "You cannot withdraw more than you pledged");

        contributions[_campaignId][msg.sender] -= _amount;
        campaign.totalAmount -= _amount;

        TOKEN.safeTransfer(msg.sender, _amount);

        emit Unpledge(msg.sender, _amount, _campaignId);
    }

    function claim(uint256 _campaignId) external {
        Campaign storage campaign = campaigns[_campaignId];
        require(msg.sender == campaign.creator, "Only the creator can claim funds");
        require(campaign.goal <= campaign.totalAmount, "Campaign has not reached it's intended goal");
        require(!campaign.ended, "Campaign Already ended");

        campaign.goalAchieved = true;
        campaign.endedAt = block.timestamp;
        campaign.ended = true;

        TOKEN.safeTransfer(msg.sender, campaign.totalAmount);

        emit Ended(_campaignId, msg.sender, campaign.totalAmount, campaign.endedAt, campaign.goalAchieved);
    }

    function refund(uint256 _campaignId, uint256 _amount) external {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.ended, "Campaign has not ended. Unpledge instead");
        require(contributions[_campaignId][msg.sender] >= _amount, "Amount does not match pledge");

        campaign.totalAmount -= _amount;
        contributions[_campaignId][msg.sender] -= _amount;

        TOKEN.safeTransfer(msg.sender, _amount);
        emit Refund(_amount, msg.sender);
    }
}
