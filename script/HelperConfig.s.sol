// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        bytes32 vrf_keyHash;
        uint32 vrf_callbackGasLimit;
        address vrfCoordinatorV2Address;
        address erc20ContractAddress;
        uint256 deployerAddress;
    }
    NetworkConfig public activeNetworkConfig;
    uint256 public ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 11155111) {
            // activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getConfig();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        vm.startBroadcast(ANVIL_PRIVATE_KEY);
        VRFCoordinatorV2Mock vrfCoordinatorV2Mock = new VRFCoordinatorV2Mock(
            0,
            0
        );
        vm.stopBroadcast();

        activeNetworkConfig = NetworkConfig({
            vrf_keyHash: bytes32(0),
            vrf_callbackGasLimit: 0,
            vrfCoordinatorV2Address: address(vrfCoordinatorV2Mock),
            erc20ContractAddress: address(0),
            deployerAddress: ANVIL_PRIVATE_KEY
        });
        return activeNetworkConfig;
    }
}
