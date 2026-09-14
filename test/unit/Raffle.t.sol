// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Raffle, State, Raffle__NotEnoughETH, Raffle__NotIdle} from "src/Raffle.sol";
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
}
