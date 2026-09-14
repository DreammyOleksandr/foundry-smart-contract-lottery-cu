//SPDX-LICENSE-IDENTIFIER: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfigurator} from "script/HelperConfigurator.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract SubscriptionManager is Script {
    function createByConfig() public returns (uint256, address) {
        HelperConfigurator configurator = new HelperConfigurator();
        address vrfCoordinator = configurator.getConfig().vrfCoordinator;

        return create(vrfCoordinator);
    }

    function create(address vrfCoordinator) public returns (uint256, address) {
        console2.log("Creating subscription on chain id:", block.chainid);
        vm.startBroadcast();
        uint256 subscriptionId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console2.log("Subscription id:", subscriptionId);
        console2.log("Please add the subscription id to the HelperConfigurator.s.sol");

        return (subscriptionId, vrfCoordinator);
    }

    function run() public {}
}
