// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Raffle, State, Raffle__NotEnoughETH, Raffle__NotIdle, Raffle__UpkeepNotNeeded} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfigurator} from "script/HelperConfigurator.s.sol";

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

    function testRaffleDontAllowEnteranceWhenProcessing() public {
        vm.prank(player);

        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + secondsInterval + 1);
        vm.roll(block.number + 1);
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

    function testCheckUpkeepReturnsFalseIfRaffleIsNotIdle() public {
        vm.prank(player);

        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + secondsInterval + 1);
        vm.roll(block.number + 1);
        raffle.pickWinner("");

        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testUpkeepReturnsFalseIfEnoughTimeHasNotPassed() public {
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testUpkeepReturnsTrueWhenParametersAreMet() public {
        vm.prank(player);

        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + secondsInterval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assert(upkeepNeeded);
    }

    function testPickWinnerCanRunOnlyWhenCheckUpkeepReturnsTrue() public {
        vm.prank(player);

        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + secondsInterval + 1);
        vm.roll(block.number + 1);

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
}
