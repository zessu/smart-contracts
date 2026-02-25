
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract CrowdFund {

  event Launch(uint indexed campaignId, address indexed launcher, uint goal, uint endTime)
  event Ended(uint indexed campaignId, address creator, uint totalAmount, uint endedAt, bool goalAchieved);
  event Pledged(uint amount, address indexed contributor, uint indexed campaignId)
  event Unpledge(address pledger, uint amount, uint indexed campaignId);
  event Refund(uint amount, address indexed sender);

  struct Campaign {
    address creator;
    uint goal;
    uint totalAmount;
    uint createdAt;
    uint campaignEnd;
    uint endedAt; 
    uint campaignId;
    bool goalAchieved;
    bool ended;
  }

  mapping(uint => Campaign) public campaigns;
  mapping(uint => mapping(address => uint)) public contributions;
  IERC20 public immutable token;
  uint public count;

  constructor(address erc20_token) {
    token = IERC20(erc20_token);
  }
  
  function launch(uint _campainGoal, uint _campainEndTime) external {
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
      goalAchieved: false
      ended:false,
    });

    emit Launch(count, msg.sender, goal, _campainEndTime);
  }

  function cancel(uint _campaignId) external {
    Campaign storage campaign = campaigns[_campaignId];
    require(campaign, "Campaign does not exist");
    require(msg.sender === campaign.creator, "You do not have permission to cancel this campaign");
    require(!campaign.ended, "Campain already ended");

    campaign.ended = true;
    campaign.goalAchieved = false;
    campaign.endedAt = block.timestamp;

    emit Ended(count, creator, campaign.totalAmount, campaign.endedAt, campaign.goalAchieved);
  }

  function pledge(uint _amount, uint _campaignId) external {
    Campaign storage campaign = campaigns[_campaignId];
    require(campaign, "Campaign does not exist");
    require(!campaign.ended, "Campaign has ended");

    campaign.totalAmount += _amount;
    contributions[_campaignId][msg.sender] += _amount;
    token.transferFrom(msg.sender, address(this), _amount);

    emit Pledged(_amount, msg.sender, _campaignId);
  }

  function unpledge(uint _amount, uint _campaignId) external {
    Campaign storage campaign = campaignsp[_campaignId];
    require(!campaign.ended, "Campaign has ended, please call claim instead to get your funds");
    require(contributions[_campaignId][msg.sender] <= _amount, "You cannot withdraw more than you pledged");

    contributions[_campaignId][msg.sender] -= _amount;
    campaign.totalAmount -= _amount;

    token.transfer(msg.sender, _amount);

    emit Unpledge(msg.sender, amount, _campaignId);
  }

  function claim(uint _campaignId) external {
    Campaign storage campaign = campaigns[_campaignId];
    require(msg.sender === campaign.creator, "Only the creator can claim funds");
    require(campaign.goal <= campaign.totalAmount, "Campaign has not reached it's intended goal");
    require(!campaign.ended, "Campaign Already ended");

    campaign.goalAchieved = true;
    campaign.endedAt = block.timestamp;
    campaign.ended = true;

    token.transfer(msg.sender, campaign.totalAmount);

    emit Ended(_campaignId, msg.sender, campaign.totalAmount, campaign.endedAt, campaign.goalAchieved);
  }

  function refund(uint _campaignId, uint _amount) external {
    Campaign storage campaign = campaigns[_campaignId];
    require(campaign.ended, "Campaign has not ended. Unpledge instead");
    require(contributions[_campaignId][msg.sender] <= _amount, "Amount does not match pledge");

    campaign.totalAmount -= _amount;
    contributions[_campaignId][msg.sender] -= _amount;

    token.transfer(msg.sender, _amount);
    emit Refund(amount, msg.sender);
  }
}
