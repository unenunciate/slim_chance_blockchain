interface RewardReceiver {
  // note: assume every token implements basic ERC20 transfer function
  function addToReward( bytes32 rewardID, uint amount ) external;
}