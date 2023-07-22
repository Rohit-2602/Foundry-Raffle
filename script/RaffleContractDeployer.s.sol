// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {RaffleContract} from "../src/RaffleContract.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Interaction} from "./Interaction.s.sol";

contract RaffleContractDeployerScript is Script {
    function run() external {
        HelperConfig helperConfig = new HelperConfig();
        (
            bytes32 vrf_keyHash,
            uint32 vrf_callbackGasLimit,
            address vrfCoordinatorV2Address,
            address erc20ContractAddress,
            uint256 deployerAddress
        ) = helperConfig.activeNetworkConfig();

        Interaction interaction = new Interaction();

        uint64 subscriptionID = interaction.createSubscription(
            vrfCoordinatorV2Address,
            deployerAddress
        );
        interaction.fundSubscription(
            vrfCoordinatorV2Address,
            deployerAddress,
            subscriptionID,
            10 ether
        );

        vm.startBroadcast(deployerAddress);
        RaffleContract raffleContract = new RaffleContract(
            vrf_keyHash,
            subscriptionID,
            vrf_callbackGasLimit,
            vrfCoordinatorV2Address,
            erc20ContractAddress
        );
        vm.stopBroadcast();

        interaction.addConsumer(
            vrfCoordinatorV2Address,
            deployerAddress,
            subscriptionID,
            address(raffleContract)
        );
    }
}
