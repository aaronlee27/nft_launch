// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console } from "forge-std/Test.sol";
import { ProNFT } from "../../src/NFTLaunch.sol";
import { ERC20 } from "../../src/ERC20.sol";
import { VRFCoordinatorV2_5Mock } from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract TestNFTLaunchUnit is Test {
    ProNFT nftLaunch;
    ERC20 feeToken;
    VRFCoordinatorV2_5Mock vrfCoordinatorMock;
    uint256 subscriptionId;
    string[] metadatas;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public mark = makeAddr("mark");

    uint256 public constant INITIAL_BALANCE = 1000 ether;

    function setUp() external {
        feeToken = new ERC20("Kyber Network Crystal", "KNC");

        vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(100000000000000000, 1000000000, 4112263541310612);
        subscriptionId = vrfCoordinatorMock.createSubscription();
        vrfCoordinatorMock.fundSubscription(subscriptionId, 100000000000000000000);
        
        metadatas.push("ipfs.io/ipfs/QmRqmMW1g6GLU8hq2HKuApbAnTx5p8Y7pGjvBsnxbwRB65?filename=common.json");
        metadatas.push("ipfs.io/ipfs/QmUyvtqc5gxtAeBisME5eHUyy8oiwLw13a1fjbJbzY77iR?filename=uncommon.json");
        metadatas.push("ipfs.io/ipfs/QmdBBnZznyrAb86n3QzkEXPGSaRsFEV9PWgunqoWqbJVkQ?filename=rare.json");
        metadatas.push("ipfs.io/ipfs/QmZ4NHwQYTpEdhSBC54AhvtynrvpUrZ6sXgmhmfV2ih4uT?filename=epic.json");
        metadatas.push("ipfs.io/ipfs/QmTC33DmwBKC7CF7bXsXcVq4CPukb7c26ztYNyg5mPxTzC?filename=legendary.json");


        nftLaunch = new ProNFT(
            "Kyber NFT",
            "KNFT",
            1 ether,
            address(feeToken),
            block.timestamp,
            block.timestamp + 3 days,
            address(vrfCoordinatorMock),
            metadatas
        );

        nftLaunch.setSubscriptionId(subscriptionId);
        nftLaunch.setKeyhash(0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae);
        nftLaunch.setCallbackGasLimit(1000000);
        nftLaunch.setRequestConfirmations(3);

        vrfCoordinatorMock.addConsumer(subscriptionId, address(nftLaunch));

        feeToken.transfer(alice, INITIAL_BALANCE);
        feeToken.transfer(bob, INITIAL_BALANCE);
        feeToken.transfer(mark, INITIAL_BALANCE);
    }

    function testEnter() external {
        vm.startPrank(alice);

        nftLaunch.enter();

        vm.stopPrank();


        // assertion
        // 1. alice balance decrease, contract balance increase
        // 

    }
}