//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

error Raffle__NotIdle();
error Raffle__NotEnoughETH();
error Raffle__FailedToSendETH();
error Raffle__NotEnoughPlayers();
error Raffle__NotEnoughTimePassed();
error Raffle__UpkeepNotNeeded(uint256 _balance, uint256 _playersLength, State _state);

event EnteredRaffle(address indexed player);
event WinnerPicked(address indexed winner);
event WinnerRequested(uint256 indexed requestId);

enum State {
    IDLE, //0
    PROCESSING //1
}

/**
 * @title Raffle Sample Contract
 * @author Alex Bondarenko
 * @notice Creating a simple Raffle
 */
contract Raffle is VRFConsumerBaseV2Plus {
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_enteranceFee;
    uint256 private immutable i_secondsInterval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;

    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    uint32 private i_callbackGasLimit;
    address private s_lastWinner;

    State private s_state;

    constructor(
        uint256 _enteranceFee,
        uint256 _secondsInterval,
        address _vrfCoordinator,
        bytes32 _gasLane,
        uint256 _subscriptionId,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        i_enteranceFee = _enteranceFee;
        i_secondsInterval = _secondsInterval;
        s_lastTimeStamp = block.timestamp;
        i_keyHash = _gasLane;
        i_subscriptionId = _subscriptionId;
        i_callbackGasLimit = _callbackGasLimit;
        s_state = State.IDLE;
    }

    function enterRaffle() external payable {
        if (s_state != State.IDLE) {
            revert Raffle__NotIdle();
        }
        if (msg.value < i_enteranceFee) {
            revert Raffle__NotEnoughETH();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    /**
     * @dev The function that Chainlink node will call
     * to check if the upkeep is needed to pick a winner.
     * @param - ignored
     * @return upkeepNeeded - true if it is time to pick a winner
     * @return - ignored
     */
    function checkUpkeep(bytes memory) public view returns (bool upkeepNeeded, bytes memory) {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_secondsInterval;
        bool isOpen = s_state == State.IDLE;
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasPlayers && hasBalance;

        return (upkeepNeeded, "");
    }

    function pickWinner(bytes calldata) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, s_state);
        }
        s_state = State.PROCESSING;
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
            )
        });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);

        emit WinnerRequested(requestId);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint256 winnerIndex = randomWords[0] % s_players.length;
        address payable winner = s_players[winnerIndex];
        s_lastWinner = winner;
        s_state = State.IDLE;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(winner);

        (bool success,) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__FailedToSendETH();
        }
    }

    function getState() external view returns (State) {
        return s_state;
    }

    function getPlayers() external view returns (address payable[] memory) {
        return s_players;
    }
}
