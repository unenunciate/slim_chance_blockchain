// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface RewardReciever {
  // note: assume every token implements basic ERC20 transfer function
  function addToReward( bytes32 rewardID, uint amount ) external;
}