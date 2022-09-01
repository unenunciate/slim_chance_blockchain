pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC20.sol";

import "./interfaces/IConditionalTokens.sol";

import  "./interfaces/RewardReciever.sol";

contract Treasured {
  address public treasurer;

  constructor() public { treasurer = msg.sender; }

  function setTreasurer( address newTreasurer ) public onlyTreasurer
  { treasurer = newTreasurer; }

  modifier onlyTreasurer {
    require( msg.sender == treasurer );
    _;
  }
}

contract Treasury is Treasured, RewardReciever {
    
    IConditionalTokens public ctf;

    IERC20 public collateralToken;

    struct ChallengeData {
        /// @notice Request timestamp, set when a request is made to the Optimistic Oracle
        /// @dev Used to identify the request and NOT used by the DVM to determine validity
        uint256 requestTimestamp;
        /// @notice Reward offered to a successful proposer
        uint256 bond;
        /// @notice Flag marking whether a question is resolved
        bool resolved;
        bool goalAchieved;
        /// @notice The address of the question creator
        address creator;
        /// @notice Data used to resolve a condition
        uint goalWeight;
        bytes32 deadline;
    }

    mapping(bytes32 => ChallengeData) public challenges;

    mapping(bytes32 => uint) public rewards;

    bytes32[] public challengeIDs;

    event ChallengeInitialized(
        bytes32 indexed challengeID,
        uint256 indexed requestTimestamp,
        address indexed creator,
        uint256 bond,
        uint256 goalWeight,
        bytes32 deadline
    );

    event ChallengeResolved(bytes32 indexed challengeID, uint256[] payouts);

    event RewardsWithdrawn(bytes32 indexed challengeID);

    event TreasuryWithdrawn(uint256 amount);

    constructor(address _ctf, address _collateralToken) {
        ctf = IConditionalTokens(_ctf);
        collateralToken = IERC20(_collateralToken);
    }

    modifier onlyCTF {
        require( msg.sender == address(ctf) );
        _;
    }

    function initializeChallenge(
        uint goalWeight,
        bytes32 deadline,
        uint256 bond
    ) external returns (bytes32) {
        bytes32 challengeID = getChallengeID(msg.sender, goalWeight, deadline);
        require(goalWeight > 0, "Goal weight invalid!");
        require(!isInitialized(challengeID), "Already Initialized!");
        require(_hasActiveChallenge(msg.sender) != true, "Participant has active challenge.");

        uint256 requestTimestamp = block.timestamp;

        // Save the question parameters in storage
        _saveChallenge(msg.sender, challengeID, requestTimestamp, bond, goalWeight, deadline);
        
        // Prepare the question on the CTF
        _prepareChallenge(challengeID);

        _transferBondToTreasury(bond, challengeID);

        emit ChallengeInitialized(
            challengeID,
            requestTimestamp,
            msg.sender,
            bond,
            goalWeight,
            deadline
        );
        return challengeID;
    }

    function isInitialized(bytes32 challengeID) public view returns (bool) {
        return challenges[challengeID].goalWeight > 0;
    }

    function addToReward(bytes32 rewardID, uint256 amount) external onlyCTF {
        _addToReward(rewardID, amount);
    }

    function getChallengeID(address creator, uint256 goalWeight, bytes32 deadline) public view returns (bytes32) {
        return keccak256(abi.encode(address(this), creator, goalWeight, deadline));
    }


    function resolve(bytes32 challengeID, uint256[] calldata payouts) external onlyTreasurer {
        require(isInitialized(challengeID), "Not Initialized!");
        require(payouts.length == 2, "NonBinaryPayouts");

        ChallengeData storage challengeData = challenges[challengeID];

        challengeData.resolved = true;

        if(payouts[0] == 1) {
            challengeData.goalAchieved = true;
        }

        ctf.reportPayouts(challengeID, payouts);
        emit ChallengeResolved(challengeID, payouts);
    }

    function withdrawRewards(bytes32 challengeID) external {
        require(isInitialized(challengeID), "Not Initialized");
        require(challenges[challengeID].resolved == true, "Challenge not yet resolved!");
        require(challenges[challengeID].goalAchieved == true, "Goal not achieved!");
        require(challenges[challengeID].creator == msg.sender, "Requester not the participant!");
        
        collateralToken.transfer(msg.sender, rewards[challengeID]);

        emit RewardsWithdrawn(challengeID);
    }

    function withdrawFromTreasury(uint amount) external onlyTreasurer {
        collateralToken.transfer(msg.sender, amount);

        emit TreasuryWithdrawn(amount);
    }
    

    /*///////////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS 
    //////////////////////////////////////////////////////////////////*/

    function _saveChallenge(
        address creator,
        bytes32 challengeID,
        uint256 requestTimestamp,
        uint256 bond,
        uint256 goalWeight,
        bytes32 deadline
    ) internal {
 
        challenges[challengeID] = ChallengeData({
            creator: creator,
            requestTimestamp: requestTimestamp,
            bond: bond,
            resolved: false,
            goalAchieved: false,
            goalWeight: goalWeight,
            deadline: deadline
        });

        challengeIDs.push(challengeID);
    }

     function _addToReward(bytes32 rewardID, uint amount) internal {
        rewards[rewardID] += amount;
    }

    function _hasActiveChallenge(address participant) internal returns (bool) {
        for (uint i = 0; i < challengeIDs.length; i++) {
            if(challenges[challengeIDs[i]].creator == participant) {
                if(challenges[challengeIDs[i]].resolved == false) {
                    return true;
                }
            }
        }

        return false;
    }

    function _transferBondToTreasury(uint256 amount, bytes32 rewardId) internal {
        require(collateralToken.transferFrom(msg.sender, address(this), amount), "Bond transfer to treasury failed.");
        uint256 converted = ((amount)*(26))/10;

        _addToReward(rewardId, converted);
    }

    /// @notice Prepares the question on the CTF
    function _prepareChallenge(bytes32 challengeID) internal {
        ctf.prepareCondition(address(this), challengeID, 2);
    }
}

