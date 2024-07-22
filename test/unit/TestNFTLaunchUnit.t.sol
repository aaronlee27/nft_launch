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
    address public constant TX_ORIGIN = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    uint256 public constant INITIAL_BALANCE = 1000 ether;
    uint256 public constant START_LAUNCH = 3 days;
    uint256 public constant MAX_PER_ADDRESS = 10;
    uint256 public constant DURATION = 3 days;
    uint256 public constant END_LAUNCH = 6 days;

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
            START_LAUNCH,
            START_LAUNCH + 3 days,
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

        vm.prank(alice);
        feeToken.approve(address(nftLaunch), 10 ether);

        vm.prank(bob);
        feeToken.approve(address(nftLaunch), 10 ether);


        vm.prank(mark);
        feeToken.approve(address(nftLaunch), 10 ether);

        vm.warp(START_LAUNCH);
    }

    function enter(address user, uint256 _numTimes, uint256 _seed) internal {
        assert(_numTimes <= MAX_PER_ADDRESS);
        vm.startPrank(user);
        for (uint256 i = 0; i < _numTimes; i++){
            vm.warp(START_LAUNCH + (_seed + i) * 10 seconds);
            vm.roll(block.number + i);
            nftLaunch.enter();
        }
        vm.stopPrank();
    } 

    function multipleEnter() internal {
        enter(alice, 3, 0);
        enter(alice, 4, 3);
        enter(mark, 4, 2);
        enter(mark, 6, 10);
        enter(bob, 2, 1);
        enter(alice, 3, 0);
        enter(bob, 8, 10);
    }

    function setEntropy() internal {
        vm.warp(START_LAUNCH + 3 days + 10);
        uint256 _requestId = nftLaunch.requestClearingEntropy();
        vrfCoordinatorMock.fulfillRandomWords(_requestId, address(nftLaunch));
    }

    function clearing() internal {
        vm.warp(START_LAUNCH + 3 days + 10);
        nftLaunch.clear(nftLaunch.MAXIMUM_SUPPLY());        
    }

    function claim(address _user, uint256 _start, uint256 _end) internal {
        vm.warp(START_LAUNCH + 3 days + 10);
        uint256[] memory user_ticket = nftLaunch.getTickets(_user);
        uint256[] memory choosen_ticket = new uint256[](_end - _start);
        for (uint256 i = _start; i < _end; i++){
            choosen_ticket[i - _start] = user_ticket[i];
        }

        vm.startPrank(_user);
        nftLaunch.claim(choosen_ticket);
        vm.stopPrank();
    }

    function testEnter() external {
        vm.startPrank(alice);

        nftLaunch.enter();

        vm.stopPrank();

        // assertion
        // 1. alice balance decrease, contract balance increase
        // 2. check entries
        // 3. check block ban

        assert(feeToken.balanceOf(alice) == INITIAL_BALANCE - 1 ether);
        assert(feeToken.balanceOf(address(nftLaunch)) == 1 ether);
        assert(nftLaunch.getNumEntries(alice) == 1);
        assert(nftLaunch.getEntriesList().length == 1);
        assert(nftLaunch.getEntriesList()[0] == alice);
        assert(nftLaunch.getUserLastTransaction(TX_ORIGIN) == block.number);
        assert(nftLaunch.getIsBanned(TX_ORIGIN) == false);
    }

    function testCantEnterBeforeDuration() external {
        vm.startPrank(alice);

        vm.warp(START_LAUNCH - 2 days);

        vm.expectRevert(
            ProNFT.ProNFTCantMintOutOfDuration.selector
        );

        nftLaunch.enter();
        vm.stopPrank();
    }

    function testCanMintTwoInATransaction() external {
        vm.startPrank(alice);
        vm.warp(START_LAUNCH + 1 days);

        nftLaunch.enter();
        nftLaunch.enter();

        vm.stopPrank();

        assert(feeToken.balanceOf(alice) == INITIAL_BALANCE - 2 ether);
        assert(feeToken.balanceOf(address(nftLaunch)) == 2 ether);
        assert(nftLaunch.getNumEntries(alice) == 2);
        assert(nftLaunch.getEntriesList().length == 2);
        assert(nftLaunch.getEntriesList()[0] == alice && nftLaunch.getEntriesList()[1] == alice);
        assert(nftLaunch.getUserLastTransaction(TX_ORIGIN) == block.number);
        assert(nftLaunch.getIsBanned(TX_ORIGIN) == true);

    }

    function testCantMintMoreThanTwoInATransaction() external {
        vm.startPrank(alice);
        vm.warp(START_LAUNCH + 1 days);

        nftLaunch.enter();
        nftLaunch.enter();
        vm.expectRevert(
            abi.encodeWithSelector(
                ProNFT.ProNFTCantMintMoreThanTwoInATransaction.selector,
                TX_ORIGIN
            )
        );

        nftLaunch.enter();
        vm.stopPrank();
    }

    function testCantMintMoreThanTwoInATransactionWithDifferentAccount() external {
        vm.startPrank(alice);
        vm.warp(START_LAUNCH + 1 days);

        nftLaunch.enter();
        nftLaunch.enter();

        vm.stopPrank();

        vm.startPrank(bob);

        vm.expectRevert(
            abi.encodeWithSelector(
                ProNFT.ProNFTCantMintMoreThanTwoInATransaction.selector,
                TX_ORIGIN
            )
        );

        nftLaunch.enter();

        vm.stopPrank();
    }

    function testCanMintMoreThanTwoInDifferentTransaction() external {
        vm.startPrank(alice);

        vm.warp(START_LAUNCH + 1 days);

        console.log(block.number);

        nftLaunch.enter();
        nftLaunch.enter();

        vm.warp(START_LAUNCH + 1 days + 10 seconds);
        vm.roll(block.number + 1);

        console.log(block.number);
        nftLaunch.enter();

        vm.stopPrank();

        assert(feeToken.balanceOf(alice) == INITIAL_BALANCE - 3 ether);
        assert(feeToken.balanceOf(address(nftLaunch)) == 3 ether);
        assert(nftLaunch.getNumEntries(alice) == 3);
        assert(nftLaunch.getEntriesList().length == 3);
        assert(nftLaunch.getEntriesList()[0] == alice && nftLaunch.getEntriesList()[1] == alice && nftLaunch.getEntriesList()[2] == alice);
        assert(nftLaunch.getUserLastTransaction(TX_ORIGIN) == block.number);
        assert(nftLaunch.getIsBanned(TX_ORIGIN) == false);
    }

    function testCanMintMoreThanTwoInDifferentTransaction2() external {{}
        vm.startPrank(alice);

        vm.warp(START_LAUNCH + 1 days);
        nftLaunch.enter();

        vm.warp(START_LAUNCH + 1 days + 10 seconds);
        vm.roll(block.number + 1);

        nftLaunch.enter();
        nftLaunch.enter();

        vm.stopPrank();

        assert(feeToken.balanceOf(alice) == INITIAL_BALANCE - 3 ether);
        assert(feeToken.balanceOf(address(nftLaunch)) == 3 ether);
        assert(nftLaunch.getNumEntries(alice) == 3);
        assert(nftLaunch.getEntriesList().length == 3);
        assert(nftLaunch.getEntriesList()[0] == alice && nftLaunch.getEntriesList()[1] == alice && nftLaunch.getEntriesList()[2] == alice);
        assert(nftLaunch.getUserLastTransaction(TX_ORIGIN) == block.number);
        assert(nftLaunch.getIsBanned(TX_ORIGIN) == true);
    }

    function testCanEnterMultipleTimesLessThanMaxPerAddress() external {
        uint256 numEntries = 10;
        for (uint256 i = 0; i < numEntries; i++){
            vm.startPrank(alice);
            vm.warp(START_LAUNCH + 1 days + i * 10 seconds);
            vm.roll(block.number + i);
            nftLaunch.enter();
            vm.stopPrank();
        }

        address[] memory entries_list = nftLaunch.getEntriesList();

        assert(feeToken.balanceOf(alice) == INITIAL_BALANCE - numEntries * 1 ether);
        assert(feeToken.balanceOf(address(nftLaunch)) == numEntries * 1 ether);
        assert(nftLaunch.getNumEntries(alice) == numEntries);
        assert(entries_list.length == numEntries);
        for (uint256 i = 0; i < numEntries; i++){
            assert(entries_list[i] == alice);
        }
    }

    function testCantEnterMultipleTimesMoreThanMaxPerAddress() external {
        uint256 numEntries = 10;
        for (uint256 i = 0; i < numEntries; i++){
            vm.startPrank(alice);
            vm.warp(START_LAUNCH + 1 days + i * 10 seconds);
            vm.roll(i + 1);

            nftLaunch.enter();
            vm.stopPrank();
            console.log(i);
            console.log(nftLaunch.getNumEntries(alice));
        }

        vm.warp(START_LAUNCH + 1 days + numEntries * 10 seconds);
        vm.roll(11);

        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ProNFT.MAX_MINT_REACHED.selector,
                alice
            )
        );
        nftLaunch.enter();


        vm.stopPrank();
    }

    function testSetClearingEntropy() external {
        multipleEnter();

        vm.warp(START_LAUNCH + 3 days + 10);
        uint256 _requestId = nftLaunch.requestClearingEntropy();
        vrfCoordinatorMock.fulfillRandomWords(_requestId, address(nftLaunch));

        console.log(nftLaunch.getClearingEntropy());

        assert(nftLaunch.getClearingEntropy() != 0);
        assert(nftLaunch.getClearingEntropySet());
    }

    function testClearing() external {
        vm.warp(START_LAUNCH + 3 days + 10);

        // set ClearingEntropy
        multipleEnter();

        vm.warp(START_LAUNCH + 3 days + 10);
        uint256 _requestId = nftLaunch.requestClearingEntropy();
        vrfCoordinatorMock.fulfillRandomWords(_requestId, address(nftLaunch));

        console.log("Entries list before clearing: ");
        address[] memory entries_list = nftLaunch.getEntriesList();
        for (uint256 i = 0; i < entries_list.length; i++){
            console.log(entries_list[i]);
        }
    
        // Clearing
        nftLaunch.clear(3);
        nftLaunch.clear(2);
        nftLaunch.clear(1);
        nftLaunch.clear(4);
        nftLaunch.clear(5);

        console.log("Entries list after clearing: ");
        entries_list = nftLaunch.getEntriesList();
        for (uint256 i = 0; i < entries_list.length; i++){
            console.log(entries_list[i]);
        }

        assert(nftLaunch.getShuffleCount() == nftLaunch.MAXIMUM_SUPPLY());
    }

    function testCantClearBeforeEnding() external {
        vm.warp(START_LAUNCH + 1 days + 10);

        vm.expectRevert(
            ProNFT.ProNFTDurationNotEndYet.selector
        );
        nftLaunch.clear(3);
    }

    function testCantClearIfClearingEntropyNotSet() external {
        vm.warp(START_LAUNCH + 3 days + 10);

        vm.expectRevert(
            ProNFT.ProNFTEntropyNotSetYet.selector
        );
        nftLaunch.clear(3);
    }

    function testDoesntNeedEntropy() external {
        vm.prank(alice);
        nftLaunch.enter();

        vm.warp(START_LAUNCH + 3 days + 10);

        vm.expectRevert(
            ProNFT.ProNFTDoesNotNeedEntropy.selector
        );  
        
        nftLaunch.requestClearingEntropy();
    }

    function testClaim() external {
        multipleEnter();
        setEntropy();
        clearing();

        uint256[] memory alice_ticket = nftLaunch.getTickets(alice);
        uint256 _aliceNumTickets = alice_ticket.length;
        uint256 aliceWinning = 0;
        console.log("Alice tickets: ");
        for (uint256 i = 0; i < alice_ticket.length; i++){
            console.log(alice_ticket[i]);
            if (alice_ticket[i] < nftLaunch.MAXIMUM_SUPPLY()){
                aliceWinning++;
            }
        }


        vm.startPrank(alice);
        nftLaunch.claim(alice_ticket);
        vm.stopPrank();

        // Assertion
        // 1. check num of winning nfts for alice
        // 2. check if alice has refunds
        // 3. check if alice is the owner of winning nft
        // 4. check claimed nfts
        // 5. check num nft minted

        // check balance

        assert(feeToken.balanceOf(alice) == INITIAL_BALANCE - _aliceNumTickets * 1 ether + (_aliceNumTickets - aliceWinning) * 1 ether);

        for (uint i = 0; i < aliceWinning; i++){
            assert(nftLaunch.ownerOf(i) == alice);
        }

        for (uint i = 0; i < _aliceNumTickets; i++){
            assert(nftLaunch.getClaimed(alice_ticket[i]));
        }


        assert(nftLaunch.getNumNFTMinted() == aliceWinning);
    }   

    function testCantClaimBeforeClearing() external {
        multipleEnter();

        uint256[] memory alice_ticket = nftLaunch.getTickets(alice);

        vm.warp(START_LAUNCH + 3 days + 10);

        vm.expectRevert(
            ProNFT.ProNFTIsNotCleared.selector
        );
        nftLaunch.claim(alice_ticket);
    }

    function testCantClaimOutOfRangeTicket() external {
        multipleEnter();
        setEntropy();
        clearing();

        uint256[] memory alice_ticket = new uint256[](1);
        alice_ticket[0] = 100;

        vm.expectRevert(
            ProNFT.ProNFTTicketOutOfRange.selector
        );

        nftLaunch.claim(alice_ticket);
    }

    function testCantClaimOthersNFT() external {
        multipleEnter();
        setEntropy();
        clearing();

        uint256[] memory alice_ticket = new uint256[](1);
        alice_ticket[0] = 0;

        vm.expectRevert(
            ProNFT.ProNFTTicketNotOwner.selector
        );

        nftLaunch.claim(alice_ticket);
    }
    
    function testCantClaimClaimedNFT() external {
        multipleEnter();
        setEntropy();
        clearing();

        uint256[] memory alice_ticket = nftLaunch.getTickets(alice);

        vm.startPrank(alice);
        nftLaunch.claim(alice_ticket);

        vm.expectRevert(
            ProNFT.ProNFTTicketAlreadyClaimed.selector
        );

        nftLaunch.claim(alice_ticket);

        vm.stopPrank();
    }

    function testRevealMetadata() external {
        multipleEnter();
        setEntropy();
        clearing();

        claim(alice, 0, 3);
        claim(bob, 0, 2);

        console.log(nftLaunch.getNumNFTMinted());

        uint256 _requestId = nftLaunch.revealPendingMetadata();
        vrfCoordinatorMock.fulfillRandomWords(_requestId, address(nftLaunch));

        claim(mark, 0, 4);
        claim(alice, 3, 7);
        claim(bob, 2, 10);

        _requestId = nftLaunch.revealPendingMetadata();
        vrfCoordinatorMock.fulfillRandomWords(_requestId, address(nftLaunch));

        console.log(nftLaunch.getNumNFTMinted());

        claim(alice, 7, 10);
        claim(mark, 4, 10);

        _requestId = nftLaunch.revealPendingMetadata();
        vrfCoordinatorMock.fulfillRandomWords(_requestId, address(nftLaunch));

        console.log(nftLaunch.getNumNFTMinted());


        for (uint i = 0; i < nftLaunch.MAXIMUM_SUPPLY(); i++) {
            console.log(nftLaunch.tokenURI(i));
        }
    }

}