// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script } from "forge-std/Script.sol";
import { VRFCoordinatorV2_5Mock } from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import { Parameters } from "./Parameters.sol";
import { VRFCoordinatorV2_5Mock } from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract DeployHelper is Script, Parameters {

    struct HelperConfig {
        address linkToken;
        address vrfCoordinator;
        uint256 keyHash;
    }

    HelperConfig public config;


    function run() external {
        if (block.chainid == ETHEREUM_SEPOLIA_CHAIN_ID){
            getEthereumSepoliaConfig();
        } else if (block.chainid == POLYGON_AMOY_CHAIN_ID){
            getPolygonAmoyConfig();
        } else if (block.chainid == AVALANCHE_FUJI_CHAIN_ID){
            getAvalancheFujiConfig();
        } else if (block.chainid == ARBITRUM_SEPOLIA_CHAIN_ID){
            getArbitrumSepoliaConfig();
        } else {
            getAnvilConfig();
        }
    }

    function getEthereumSepoliaConfig() public {
        config.linkToken = ETHEREUM_SEPOLIA_LINKTOKEN;
        config.vrfCoordinator = ETHEREUM_SEPOLIA_VRF_COORDINATOR;
        config.keyHash = ETHEREUM_SEPOLIA_KEYHASH;
    }

    function getPolygonAmoyConfig() public {
        config.linkToken = POLYGON_AMOY_LINKTOKEN;
        config.vrfCoordinator = POLYGON_AMOY_VRF_COORDINATOR;
        config.keyHash = POLYGON_AMOY_KEYHASH;
    }

    function getAvalancheFujiConfig() public {
        config.linkToken = AVALANCHE_FUJI_LINKTOKEN;
        config.vrfCoordinator = AVALANCHE_FUJI_VRF_COORDINATOR;
        config.keyHash = AVALANCHE_FUJI_KEYHASH;
    }

    function getArbitrumSepoliaConfig() public {
        config.linkToken = ARBITRUM_SEPOLIA_LINKTOKEN;
        config.vrfCoordinator = ARBITRUM_SEPOLIA_VRF_COORDINATOR;
        config.keyHash = ARBITRUM_SEPOLIA_KEYHASH;
    }

    function getAnvilConfig() public {
        
    }
    
}