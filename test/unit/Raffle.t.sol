// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Raffle, State} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfigurator} from "script/HelperConfigurator.s.sol";

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

    function testRaffleStartsAsIdle() public {
        assert(raffle.getRaffleState() == State.IDLE);
    }
}
