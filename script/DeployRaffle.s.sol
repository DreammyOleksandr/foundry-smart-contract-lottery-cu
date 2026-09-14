//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";

import {Raffle} from "src/Raffle.sol";
import {HelperConfigurator} from "script/HelperConfigurator.s.sol";
import {CreateSubscriptionManager} from "script/Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external {
        deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfigurator) {
        HelperConfigurator helperConfigurator = new HelperConfigurator();
        HelperConfigurator.NetworkConfig memory config = helperConfigurator.getConfig();

        if (config.subscriptionId == 0) {
            CreateSubscriptionManager subscriptionManager = new CreateSubscriptionManager();
            (config.subscriptionId, config.vrfCoordinator) = subscriptionManager.create(config.vrfCoordinator);
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle({
            _enteranceFee: config.entranceFee,
            _secondsInterval: config.secondsInterval,
            _vrfCoordinator: config.vrfCoordinator,
            _gasLane: config.gasLane,
            _subscriptionId: config.subscriptionId,
            _callbackGasLimit: config.callbackGasLimit
        });
        vm.stopBroadcast();
        return (raffle, helperConfigurator);
    }
}
