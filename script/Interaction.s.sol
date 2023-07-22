// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract Interaction is Script {
    function createSubscription(
        address vrfCoordinatorV2Address,
        uint256 deployerAddress
    ) public returns (uint64) {
        vm.startBroadcast(deployerAddress);
        VRFCoordinatorV2Mock vRFCoordinatorV2Mock = VRFCoordinatorV2Mock(
            vrfCoordinatorV2Address
        );
        uint64 subscriptionId = vRFCoordinatorV2Mock.createSubscription();
        vm.stopBroadcast();
        console.log("Subscription ID: ", subscriptionId);
        return subscriptionId;
    }

    function addConsumer(
        address vrfCoordinatorV2Address,
        uint256 deployerAddress,
        uint64 subscriptionId,
        address contractAddress
    ) public {
        vm.startBroadcast(deployerAddress);
        VRFCoordinatorV2Mock vRFCoordinatorV2Mock = VRFCoordinatorV2Mock(
            vrfCoordinatorV2Address
        );
        vRFCoordinatorV2Mock.addConsumer(subscriptionId, contractAddress);
        vm.stopBroadcast();
        console.log("Consumer Added Successfully");
    }

    function fundSubscription(
        address vrfCoordinatorV2Address,
        uint256 deployerAddress,
        uint64 subscriptionId,
        uint96 amount
    ) public {
        vm.startBroadcast(deployerAddress);
        VRFCoordinatorV2Mock vRFCoordinatorV2Mock = VRFCoordinatorV2Mock(
            vrfCoordinatorV2Address
        );
        vRFCoordinatorV2Mock.fundSubscription(subscriptionId, amount);
        vm.stopBroadcast();
        console.log("Subscription Funded Successfully");
    }
}
