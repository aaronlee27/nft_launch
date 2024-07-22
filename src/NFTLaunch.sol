// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { ERC20 } from "./ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { VRFConsumerBaseV2Plus } from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import { VRFV2PlusClient } from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract ProNFT is ERC721, VRFConsumerBaseV2Plus {
    error ProNFTMaxiumSupplyReached();
    error ProNFTCantMintMoreThanTwoInATransaction(address _user);
    error ProNFTMintFail();
    error ProNFTCantMintOutOfDuration();
    error MAX_MINT_REACHED(address _user);
    error ProNFTInsufficientFee();
    error ProNFTDurationNotEndYet();
    error ProNFTEntropyNotSetYet();
    error ProNFTDoesNotNeedToShuffle();
    error ProNFTShuffleExceedsLimit();
    error ProNFTIsNotCleared();
    error ProNFTTicketOutOfRange();
    error ProNFTTicketAlreadyClaimed();
    error ProNFTTicketNotOwner();
    error ProNFTCantCollectFeeBeforeEndTime();
    error ProNFTFeeCollected();
    error ProNFTTransferFail();
    error ProNFTOutOfDuration();
    error ProNFTEntropySetted();
    error ProNFTDoesNotNeedEntropy();
    error ProNFTNoMorePendingNFT();

    /// @notice Metadata for range of tokenIds
    struct Metadata {
        // Starting index (inclusive)
        uint256 startIndex;
        // Ending index (exclusive)
        uint256 endIndex;
        // Randomness for range of tokens
        uint256 entropy;
    }

    /// @notice Array of NFT metadata
    Metadata[] public metadatas;

    uint256 private immutable s_startTime;
    uint256 private immutable s_endTime;

    uint256 private s_mintFee;
    ERC20 private s_feeToken;
    uint256 private s_nftMinted;
    bool private s_ownerClaimed;

    uint256 s_clearingEntropy;
    bool s_clearingEntropySet;
    uint256 s_shuffleCount;
    uint256 s_revealNftCount = 0;

    uint256 s_subscriptionId;
    bytes32 s_keyHash;
    uint32 callbackGasLimit;
    uint16 requestConfirmations;
    uint32 numWords = 1;

    address[] private s_entries_list;

    string private COMMON;
    string private UNCOMMON;
    string private RARE;
    string private EPIC;
    string private LEGENDARY;

    mapping (address => uint256) private s_lastTransaction;
    mapping (address => bool) private s_isBanned;
    mapping (address => uint256) private s_entries;
    mapping (uint256 => bool) private s_isClaimed;
    mapping (uint256 => uint256) private s_ticketRequestId;

    uint256 public constant MAXIMUM_SUPPLY = 10000;
    uint256 public constant LIMIT_PER_TRANSACTION = 2;
    uint256 public constant MAX_PER_ADDRESS = 10;

    constructor(
        string memory _name,
        string memory _symbol, 
        uint256 _mintFee, 
        address _feeToken,
        uint256 _startTime,
        uint256 _endTime,
        address _vrfCoordinator,
        string[] memory _metadatas
    )   ERC721(_name, _symbol) 
        VRFConsumerBaseV2Plus(_vrfCoordinator)
    {
        s_mintFee = _mintFee;
        s_feeToken = ERC20(_feeToken);
        s_startTime = _startTime;
        s_endTime = _endTime;

        COMMON = _metadatas[0];
        UNCOMMON = _metadatas[1];
        RARE = _metadatas[2];
        EPIC = _metadatas[3];
        LEGENDARY = _metadatas[4];
    }

    /// @notice Join Raffle
    function enter() external {
        // Enter the NFT launch
        // 1. Ban user from minting more than 2 NFT in the same transaction
        // 2. Ban user from minting maximum per address (10 nft)
        // 3. Ban user from minting out of time duration
        if (block.timestamp < s_startTime || block.timestamp > s_endTime) {
            revert ProNFTCantMintOutOfDuration();
        }
        if (s_entries[msg.sender] >= MAX_PER_ADDRESS) {
            revert MAX_MINT_REACHED(msg.sender);
        }
        
        if (s_isBanned[tx.origin] && s_lastTransaction[tx.origin] == block.number) {
            revert ProNFTCantMintMoreThanTwoInATransaction(tx.origin);
        }

        // transfer token to contract
        bool success = s_feeToken.transferFrom(msg.sender, address(this), s_mintFee);
        if (!success) {
            revert ProNFTTransferFail();
        }
        
        s_entries[msg.sender]++;
        s_entries_list.push(msg.sender);


        if (block.number == s_lastTransaction[tx.origin]) {
            s_isBanned[tx.origin] = true;
        } else {
            s_lastTransaction[tx.origin] = block.number;
            s_isBanned[tx.origin] = false;
        }
    }

    // shuffling the entries
    function clear(uint256 _numShuffles) external {
        // 1. Time duration end
        // 2. Have entropy
        // 3. entries.length > maximum supply (if <=, don't need)
        // 4. numShuffles <= required shuffle 

        require(_numShuffles > 0, "ProNFT: Invalid number of shuffles");
        if (block.timestamp <= s_endTime) {
            revert ProNFTDurationNotEndYet();
        }

        if (!s_clearingEntropySet) {
            revert ProNFTEntropyNotSetYet();
        }

        if (s_entries_list.length <= MAXIMUM_SUPPLY) {
            revert ProNFTDoesNotNeedToShuffle();
        }
        
        if (_numShuffles > MAXIMUM_SUPPLY - s_shuffleCount) {
            revert ProNFTShuffleExceedsLimit();
        }

        for (uint256 i = s_shuffleCount; i < s_shuffleCount + _numShuffles; i++) {
            uint256 _indexToSwap = i + uint256(keccak256(abi.encode(s_clearingEntropy, i))) % (s_entries_list.length - i);
            address _temp = s_entries_list[i];
            s_entries_list[i] = s_entries_list[_indexToSwap];
            s_entries_list[_indexToSwap] = _temp;
        }

        s_shuffleCount += _numShuffles;
    }

    function claim(uint256[] calldata tickets) external {
        // 1. Time duration end
        // 2. Shuffled or doesn't need to shuffle
        require(tickets.length > 0, "ProNFT: Invalid number of tickets");

        if (block.timestamp <= s_endTime) {
            revert ProNFTDurationNotEndYet();
        }

        if (!(s_shuffleCount == MAXIMUM_SUPPLY || s_entries_list.length <= MAXIMUM_SUPPLY)) {
            revert ProNFTIsNotCleared();
        }
        uint256 _txNftMinted = 0;
        for (uint256 i = 0; i < tickets.length; i++) {
            if (tickets[i] >= s_entries_list.length) {
                revert ProNFTTicketOutOfRange();
            }
            if (s_isClaimed[tickets[i]]) {
                revert ProNFTTicketAlreadyClaimed();
            }
            if (s_entries_list[tickets[i]] != msg.sender) {
                revert ProNFTTicketNotOwner();
            }

            s_isClaimed[tickets[i]] = true;

            if (tickets[i] < MAXIMUM_SUPPLY){
                _safeMint(msg.sender, s_nftMinted);
                s_nftMinted++;
                _txNftMinted++;
            }

        }

        // repay
        if (_txNftMinted < tickets.length) {
            bool success = s_feeToken.transfer(msg.sender, s_mintFee * (tickets.length - _txNftMinted));
            if (!success) {
                revert ProNFTTransferFail();
            }
        }  
    }

    function requestClearingEntropy() external returns(uint256) {
        if (block.timestamp <= s_endTime) {
            revert ProNFTOutOfDuration();
        }
        if (s_clearingEntropySet) {
            revert ProNFTEntropySetted();
        }

        if (s_entries_list.length < MAXIMUM_SUPPLY) {
            revert ProNFTDoesNotNeedEntropy();
        }

        uint256 _requestId = s_vrfCoordinator.requestRandomWords(
            _buildVRFRequest()
        );
        return _requestId;
    }

    function revealPendingMetadata() external returns (uint256){
        if (s_nftMinted - s_revealNftCount == 0){
            revert ProNFTNoMorePendingNFT();
        }

        uint256 _requestId = s_vrfCoordinator.requestRandomWords(
            _buildVRFRequest()
        );
        return _requestId;
    }

    function _buildVRFRequest() public view returns (VRFV2PlusClient.RandomWordsRequest memory) {
        return 
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            });
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        if (s_clearingEntropySet || s_entries_list.length < MAXIMUM_SUPPLY) {
            metadatas.push(Metadata({
                startIndex: s_revealNftCount + 1,
                endIndex: s_nftMinted + 1,
                entropy: randomWords[0]
            }));
            s_revealNftCount = s_nftMinted;
            return;
        }

        s_clearingEntropy = randomWords[0];
        s_clearingEntropySet = true;
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        uint256 randomness;
        bool metadataCleared;


        for (uint256 i = 0; i < metadatas.length; i++) {
            if (_tokenId >= metadatas[i].startIndex && _tokenId < metadatas[i].endIndex) {
                randomness = metadatas[i].entropy;
                metadataCleared = true;
            }
        }

        if (metadataCleared == false){
            return "";
        }

        randomness = uint256(keccak256(abi.encode(randomness, _tokenId))) % 1000 + 1;

    

        if (randomness <= 1) {
            return COMMON;
        }

        else if (randomness <= 10) {
            return UNCOMMON;
        } 
        
        else if (randomness <= 50) {
            return RARE;
        }

        else if (randomness <= 250) {
            return EPIC;
        }

        else {
            return LEGENDARY;
        }
    } 

    function setSubscriptionId(uint256 subscriptionId) external onlyOwner {
        s_subscriptionId = subscriptionId;
    }

    function setKeyhash(bytes32 _keyHash) external onlyOwner {
        s_keyHash = _keyHash;
    }

    function setCallbackGasLimit(uint32 _callbackGasLimit) external onlyOwner {
        callbackGasLimit = _callbackGasLimit;
    }

    function setRequestConfirmations(uint16 _requestConfirmations) external onlyOwner {
        requestConfirmations = _requestConfirmations;
    }

    function updateMintFee(uint256 _newMintFee) external onlyOwner {
        s_mintFee = _newMintFee;
    }

    function collectFee() external onlyOwner {
        if (block.timestamp <= s_endTime){
            revert ProNFTCantCollectFeeBeforeEndTime();
        }
        if (s_ownerClaimed){
            revert ProNFTFeeCollected();
        }

        s_ownerClaimed = true;
        uint256 feeToCollect = (s_entries_list.length < MAXIMUM_SUPPLY) ? s_mintFee * s_entries_list.length : s_mintFee * MAXIMUM_SUPPLY;

        bool success = s_feeToken.transfer(msg.sender, feeToCollect);
        if (!success){
            revert ProNFTTransferFail();
        }
    } 

    function getMintFee() public view returns (uint256) {
        return s_mintFee;
    }

    function getUserLastTransaction(address _user) public view returns (uint256) {
        return s_lastTransaction[_user];
    }

    function getIsBanned(address _user) public view returns (bool){
        return s_isBanned[_user];
    }

    function getNumEntries(address _user) public view returns (uint256) {
        return s_entries[_user];
    }
}