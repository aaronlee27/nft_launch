// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script } from "forge-std/Script.sol";
import { ProNFT } from "../src/NFTLaunch.sol";
import { ERC20 } from "../src/ERC20.sol";
import { DeployHelper } from "./DeployHelper.s.sol";
import { IVRFCoordinatorV2Plus } from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import { LinkTokenInterface } from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

contract DeployNFTLaunch is Script {
    ProNFT public nftLaunch;
    ERC20 public token;

    uint256 public constant START_TIME = 10000000;
    uint256 public constant END_TIME = 20000000;
    uint256 public constant MINT_FEE = 1 ether;
    uint256 public constant AMOUNT_TO_FUND = 3 ether;

    address linkToken;
    address vrfCoordinator;
    uint256 keyHash;
    uint256 subscriptionId;

    

    string[] metadatas = [
        "ipfs.io/ipfs/QmRqmMW1g6GLU8hq2HKuApbAnTx5p8Y7pGjvBsnxbwRB65?filename=common.json",
        "ipfs.io/ipfs/QmUyvtqc5gxtAeBisME5eHUyy8oiwLw13a1fjbJbzY77iR?filename=uncommon.json",
        "ipfs.io/ipfs/QmdBBnZznyrAb86n3QzkEXPGSaRsFEV9PWgunqoWqbJVkQ?filename=rare.json",
        "ipfs.io/ipfs/QmZ4NHwQYTpEdhSBC54AhvtynrvpUrZ6sXgmhmfV2ih4uT?filename=epic.json",
        "ipfs.io/ipfs/QmTC33DmwBKC7CF7bXsXcVq4CPukb7c26ztYNyg5mPxTzC?filename=legendary.json"
    ];


    function run() external returns (ERC20, ProNFT, uint256){
        DeployHelper config = new DeployHelper();
        vm.startBroadcast();
        config.run();
        vm.stopBroadcast();

        (linkToken, vrfCoordinator, keyHash) = config.config();
        
        vm.startBroadcast();

        token = new ERC20("Kyber Network Crystal", "KNC");
        nftLaunch = new ProNFT(
            "Kyber Network NFT",
            "KNFT",
            MINT_FEE,
            address(token),
            START_TIME,
            END_TIME,
            vrfCoordinator,
            metadatas
        );

        _createNewSubscription(address(nftLaunch));
        // topUpSubscription(AMOUNT_TO_FUND);

        vm.stopBroadcast();

        return (token, nftLaunch, subscriptionId);
        
    }

    function _createNewSubscription(address _contract) public returns (uint256) {
        subscriptionId = IVRFCoordinatorV2Plus(vrfCoordinator).createSubscription();
        IVRFCoordinatorV2Plus(vrfCoordinator).addConsumer(subscriptionId, _contract);
        return subscriptionId;
    }

    function topUpSubscription(uint256 amount) public {
        LinkTokenInterface(linkToken).transferAndCall(
            address(vrfCoordinator),
            amount,
            abi.encode(subscriptionId)
        );
    }


}