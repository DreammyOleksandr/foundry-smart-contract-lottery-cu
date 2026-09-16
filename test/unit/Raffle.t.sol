// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Raffle, State, Raffle__NotEnoughETH, Raffle__NotIdle, Raffle__UpkeepNotNeeded} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfigurator} from "script/HelperConfigurator.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

event EnteredRaffle(address indexed player);
event WinnerPicked(address indexed winner);

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfigurator public helperConfig;

    uint256 entranceFee;
    uint256 secondsInterval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;

    address public player = makeAddr("player");
    uint256 public constant STARTING_BALANCE = 10 ether;

    function setUp() public {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        vm.deal(player, STARTING_BALANCE);
        HelperConfigurator.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        secondsInterval = config.secondsInterval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;
    }

    modifier raffleEntered() {
        vm.prank(player);

        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + secondsInterval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testRaffleStartsAsIdle() public view {
        assert(raffle.getState() == State.IDLE);
    }

    function testRevertsWhenEnteranceFeeIsNotEnough() public {
        vm.expectRevert(Raffle__NotEnoughETH.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersEnter() public {
        vm.prank(player);

        raffle.enterRaffle{value: entranceFee}();

        assert(raffle.getPlayers().length == 1);
        assert(raffle.getPlayers()[0] == player);
    }

    function testExpectEmittedEnteredRaffleOnRaffleEnter() public {
        vm.prank(player);

        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(player);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testRaffleDontAllowEnteranceWhenProcessing() public raffleEntered {
        raffle.pickWinner("");

        vm.expectRevert(Raffle__NotIdle.selector);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCheckUpkeepReturnsFalseWithInsufficientBalance() public {
        vm.warp(block.timestamp + secondsInterval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsNotIdle() public raffleEntered {
        raffle.pickWinner("");

        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testUpkeepReturnsFalseIfEnoughTimeHasNotPassed() public {
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testUpkeepReturnsTrueWhenParametersAreMet() public raffleEntered {
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assert(upkeepNeeded);
    }

    function testPickWinnerCanRunOnlyWhenCheckUpkeepReturnsTrue() public raffleEntered {
        raffle.pickWinner("");
    }

    function testPickWinnerRevertsWhenCheckUpkeepReturnsFalse() public {
        uint256 currentBalance = 0;
        uint256 playersLength = 0;
        State state = raffle.getState();

        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance += entranceFee;
        playersLength = 1;

        vm.expectRevert(abi.encodeWithSelector(Raffle__UpkeepNotNeeded.selector, currentBalance, playersLength, state));
        raffle.pickWinner("");
    }

    function testPickWinnerUpdatesStateAndEmitsWinnerRequested() public raffleEntered {
        vm.recordLogs();
        raffle.pickWinner("");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 requestId = logs[1].topics[1];

        State state = raffle.getState();
        assert(state == State.PROCESSING);
        assert(requestId != 0);
    }

    function testFulfillRandomWordsIsCalledOnlyAfterPickWinner(uint256 randomRequestId) public raffleEntered {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulfillRandomWordsPicksWinnerResetsStateAndSendsMoney() public raffleEntered {
        uint256 additionalPlayers = 3;
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (uint256 i = startingIndex; i < startingIndex + additionalPlayers; i++) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 100 ether);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        vm.recordLogs();
        raffle.pickWinner("");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 requestId = logs[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        State state = raffle.getState();
        address lastWinner = raffle.getLastWinner();
        uint256 lastWinnerBalance = lastWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalPlayers + 1);

        assert(lastWinner == expectedWinner);
        assert(winnerStartingBalance + prize == lastWinnerBalance);
        assert(state == State.IDLE);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
