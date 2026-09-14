//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfigurator} from "script/HelperConfigurator.s.sol";

contract DeployRaffle is Script {
    function run() external {
        vm.startBroadcast();
        deployContract();
        vm.stopBroadcast();
    }

    function deployContract() public returns (Raffle, HelperConfigurator) {
        HelperConfigurator helperConfigurator = new HelperConfigurator();
        HelperConfigurator.NetworkConfig memory config = helperConfigurator.getConfig();
        Raffle raffle = new Raffle({
            _enteranceFee: config.entranceFee,
            _secondsInterval: config.secondsInterval,
            _vrfCoordinator: config.vrfCoordinator,
            _gasLane: config.gasLane,
            _subscriptionId: config.subscriptionId,
            _callbackGasLimit: config.callbackGasLimit
        });
        return (raffle, helperConfigurator);
    }
}
