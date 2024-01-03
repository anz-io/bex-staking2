// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC721Upgradeable.sol";

contract BexCore is OwnableUpgradeable {

    bool constant DISABLE_SIG_MODE = true;  // Just for debug. Will delete this later.
    
    /* ============================= Struct ============================= */
    struct BonxInfo {
        uint8 stage;                    // 0,1,2,3 (0 for not registered)
        uint16 epoch;                   // add 1 whenever a new contest has started
        uint256 totalShare;
        uint256 nftTokenId;
    }

    /* ============================ Variables =========================== */
    /* ------------- Supply related ------------- */
    uint256 public restrictSupply;      // Supply for stage 1 <-> stage 2
    uint256 public mintLimit;           // Mint limit in stage 1
    uint256 public holdLimit;           // Hold limit in stage 1
    uint256 public maxSupply;           // Supply for stage 2 --> stage 3

    /* ----------- Signature related ------------ */
    address public backendSigner;
    uint256 public signatureValidTime;

    /* -------------- Tax related --------------- */
    uint256 public taxBasePointProtocol;
    uint256 public taxBasePointOwner;
    uint256 public taxBasePointInviter;

    /* ------------ Address related ------------- */
    IERC20 public tokenAddress;
    IERC721Upgradeable public bonxAddress;

    /* ---------------- Storage ----------------- */
    // Total fee collected for the protocol
    uint256 public feeCollectedProtocol;

    // bonx => [fee collected for this bonx's owner]
    mapping(string => uint256) public feeCollectedOwner;

    // inviter => [fee collected for him]
    mapping(address => uint256) public feeCollectedInviter;

    // user => his inviter
    mapping(address => address) public inviters;

    // bonx => [storage information for this bonx]
    mapping(string => BonxInfo) public bonxInfo;

    // bonx => user => [user's share num of this bonx]
    mapping(string => mapping(address => uint256)) public userShare;

    // bonx => epoch => [participated user list of this bonx in this epoch]
    mapping(string => mapping(uint16 => address [])) userList;

    // bonx => epoch => user => [user's invested amount for this bonx in this epoch]
    mapping(string => mapping(uint16 => mapping(address => int))) userInvested;

    // keccak256(signature) => [whether this signature is used]
    mapping(bytes32 => bool) public signatureIsUsed;


    /* =========================== Constructor ========================== */
    function initialize(address tokenAddress_, address bonxAddress_) public initializer {
        __Ownable_init();

        restrictSupply = 1000;
        mintLimit = 10;
        holdLimit = 50;
        maxSupply = 15000;
        signatureValidTime = 3 minutes;

        taxBasePointProtocol = 100;
        taxBasePointOwner = 100;
        taxBasePointInviter = 100;

        tokenAddress = IERC20(tokenAddress_);
        bonxAddress = IERC721Upgradeable(bonxAddress_);
    }

    /* ========================= Pure functions ========================= */
    function bindingCurve(uint256 x) public virtual pure returns (uint256) {
        return 10 * x * x;
    }

    function bindingSumExclusive(uint256 start, uint256 end) 
        public virtual pure returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = start; i < end; i++) {
            sum += bindingCurve(i);
        }
        return sum;
    }

    /* ========================= View functions ========================= */

    /* ========================= Write functions ======================== */

    /* ----------- Internal management ---------- */
    function _userListManage(string memory name, uint16 epoch, address user) internal {
        if (userInvested[name][epoch][user] == 0)
            userList[name][epoch].push(user);
    }

    /* ---------------- Signature --------------- */
    function consumeSignature(
        bytes4 selector,
        string memory name,
        uint256 content,    // Share amount or token amount or `0`.
        address user,
        uint256 timestamp,
        bytes memory signature
    ) public {
        // Prevent replay attack
        bytes32 sigHash = keccak256(signature);
        require(!signatureIsUsed[sigHash], "Signature already used!");
        signatureIsUsed[sigHash] = true;

        // Check the signature timestamp
        require(block.timestamp <= timestamp + signatureValidTime, "Signature expired!");
        require(block.timestamp >= timestamp, "Timestamp error!");

        // Check the signature content
        bytes memory data = abi.encodePacked(
            selector,
            name,
            content,
            user,
            timestamp
        );
        bytes32 signedMessageHash = ECDSA.toEthSignedMessageHash(data);
        address signer = ECDSA.recover(signedMessageHash, signature);
        require(signer == backendSigner || DISABLE_SIG_MODE, "Signature invalid!"); 
            // Just for debug. Will delete `DISABLE_SIG_MODE` this later.
    }

    /* ---------- Register & Buy & Sell --------- */
    function register(
        string memory name,
        uint256 timestamp,
        bytes memory signature
    ) public {
        // Check signature
        consumeSignature(
            this.register.selector, name, 0,
            _msgSender(), timestamp, signature
        );

        // Register the BONX
        bonxInfo[name].stage = 1;

        // emit Registered
    }

    function buyBonding(
        string memory name, 
        uint256 share, 
        uint256 maxOutTokenAmount
    ) public {
        address user = _msgSender();
        uint8 stage = bonxInfo[name].stage;
        uint256 totalShare = bonxInfo[name].totalShare;

        // Check stage and share num
        require(stage != 0, "BONX not registered!");
        require(bonxInfo[name].totalShare + share <= maxSupply, "Exceed max supply!");

        // Stage transition
        if (stage == 1) {
            require(share <= mintLimit, "Exceed mint limit in stage 1!");
            require(userShare[name][user] + share <= holdLimit, "Exceed hold limit in stage 1!");
            if (bonxInfo[name].totalShare + share > restrictSupply) 
                bonxInfo[name].stage = 2;           // Stage transition: 1 -> 2
        } else if (stage == 2) {
            if (bonxInfo[name].totalShare + share == maxSupply)
                bonxInfo[name].stage = 3;           // Stage transition: 2 -> 3
        }

        // Transfer tokens
        uint256 totalCost = bindingSumExclusive(totalShare, totalShare + share);
        require(totalCost <= maxOutTokenAmount, "Total cost more than expected!");
        tokenAddress.transferFrom(user, address(this), totalCost);
        
        // Update storage
        _userListManage(name, bonxInfo[name].epoch, user);
        bonxInfo[name].totalShare += share;
        userShare[name][user] += share;
        userInvested[name][bonxInfo[name].epoch][user] += int(totalCost);

        // uint256 nextId = bonxInfo[name].totalShare;
        // emit BuyShare(name, user, share, totalCost, nextId);
    }


    function sellBonding(
        string memory name, 
        uint256 share, 
        uint256 minInTokenAmount
    ) public {
        address user = _msgSender();
        uint8 stage = bonxInfo[name].stage;
        uint256 totalShare = bonxInfo[name].totalShare;

        // Check stage and share num
        require(stage != 0, "BONX not registered!");
        require(bonxInfo[name].totalShare + share <= maxSupply, "Exceed max supply!");
        require(userShare[name][user] >= share, "Not enough share for the buyer!");

        // Stage transition
        if (stage == 2) {
            if (bonxInfo[name].totalShare - share <= restrictSupply)
                bonxInfo[name].stage = 1;           // Stage transition: 2 -> 1
        }

        // Calculate fees and transfer tokens
        uint256 totalReward = bindingSumExclusive(totalShare - share, totalShare);
        require(totalReward >= minInTokenAmount, "Total reward less than expected!");
        uint256 feeForProtocol = totalReward * taxBasePointProtocol / 10000;
        uint256 feeForOwner = totalReward * taxBasePointOwner / 10000;
        uint256 feeForInviter = totalReward * taxBasePointInviter / 10000;
        feeCollectedProtocol += feeForProtocol;
        feeCollectedOwner[name] += feeForOwner;
        feeCollectedInviter[inviters[user]] += feeForInviter;   // If the inviter is 0, admin can withdraw the fee.

        // Transfer tokens
        uint256 actualReward = totalReward - feeForProtocol - feeForOwner - feeForInviter;
        tokenAddress.transfer(user, actualReward);
        
        // Update storage
        _userListManage(name, bonxInfo[name].epoch, user);
        bonxInfo[name].totalShare -= share;
        userShare[name][user] -= share;
        userInvested[name][bonxInfo[name].epoch][user] -= int(totalReward);

        // uint256 nextId = bonxInfo[name].totalShare;
        // emit SellShare(name, user, shareNum, totalReward, nextId, feeForOwner, feeForProtocol);
    }


    // function renewal() {}         // [in another contract!]

    // For Admin
    // function startContest() {}           // epoch++, 2 days
    // function endContest() {}             // has an owner, 90 days, mint NFT
    // function retrieveOwnership() {}      // admin retrieve, burn  NFT?
    
}