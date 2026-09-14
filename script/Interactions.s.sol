//SPDX-LICENSE-IDENTIFIER: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfigurator, WithConstants} from "script/HelperConfigurator.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

uint256 constant SUBSCRIPTION_FUND_AMOUNT = 3 ether;

contract CreateSubscriptionManager is Script {
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

    function run() public {
        createByConfig();
    }
}

contract FundSubscriptionManager is Script, WithConstants {
    function fundByConfig() public {
        HelperConfigurator configurator = new HelperConfigurator();
        address vrfCoordinator = configurator.getConfig().vrfCoordinator;
        uint256 subscriptionId = configurator.getConfig().subscriptionId;
        address linkToken = configurator.getConfig().link;
        fund(vrfCoordinator, subscriptionId, linkToken);
    }

    function fund(address vrfCoordinator, uint256 subscriptionId, address linkToken) public {
        console2.log("Funding subscription", subscriptionId, "on chain id:", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, SUBSCRIPTION_FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(vrfCoordinator, SUBSCRIPTION_FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }

    function run() public {
        fundByConfig();
    }
}

contract AddConsumerManager is Script, WithConstants {
    
}
