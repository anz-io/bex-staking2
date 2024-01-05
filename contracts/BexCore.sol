// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC721Upgradeable.sol";
import "./BONX.sol";

contract BexCore is OwnableUpgradeable {

    /* ============================ Variables =========================== */
    /* ----------------- Supply ----------------- */
    uint256 public restrictedSupply;    // Supply for stage 1 <-> stage 2, inclusive for stage 1
    uint256 public mintLimit;           // Mint limit in stage 1
    uint256 public holdLimit;           // Hold limit in stage 1
    uint256 public maxSupply;           // Supply for stage 2 --> stage 3

    /* ---------------- Signature --------------- */
    address public backendSigner;       // Signer for register a new BONX
    uint256 public signatureValidTime;  // Valid time for a signature

    /* ------------------- Tax ------------------ */
    uint256 public taxBasePoint;        // Tax base point (default 3% = 300)

    /* ----------------- Address ---------------- */
    address public tokenAddress;
    address public bonxAddress;

    /* ----------------- Storage ---------------- */
    // Total fee collected for the protocol, owners and inviters
    uint256 public feeCollected;

    // Total renewal funds transferred to the protocol
    uint256 public renewalFunds;

    // bonx => [stage information for this bonx (0~3, 0 for not registered)]
    mapping(string => uint8) public bonxStage;

    // bonx => [total share num of the bonding]
    mapping(string => uint256) public bonxTotalShare;

    // bonx => user => [user's share num of this bonx]
    mapping(string => mapping(address => uint256)) public userShare;

    // keccak256(signature) => [whether this signature is used]
    mapping(bytes32 => bool) public signatureIsUsed;


    /* ============================= Events ============================= */
    event Registered(string indexed bonxName, address indexed user);
    event BuyShare(
        string indexed bonxName, address indexed user, uint256 share, 
        uint256 nextId, uint256 originCost, uint256 afterFeeCost, uint256 fee
    );
    event SellShare(
        string indexed bonxName, address indexed user, uint256 share, 
        uint256 nextId, uint256 originReward, uint256 afterFeeReward, uint256 fee
    );
    event ClaimFees(address indexed admin, uint256 amount);
    event ClaimRenewalFunds(address indexed admin, uint256 amount);
    event Renewal(string indexed bonxName, uint256 amount);


    /* =========================== Constructor ========================== */
    function initialize(address backendSigner_, address tokenAddress_, address bonxAddress_) public initializer {
        __Ownable_init();

        restrictedSupply = 1000;
        mintLimit = 10;
        holdLimit = 50;
        maxSupply = 15000;

        backendSigner = backendSigner_;
        signatureValidTime = 3 minutes;

        taxBasePoint = 300;

        tokenAddress = tokenAddress_;
        bonxAddress = bonxAddress_;
    }


    /* ========================= Pure functions ========================= */
    function disableSignatureMode() public virtual pure returns (bool) {
        return false;       // Override this for debugging in the testnet
    }

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

    /* ---------------- Signature --------------- */
    function consumeSignature(
        bytes4 selector,
        string memory name,
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
        bytes memory data = abi.encodePacked(selector, name, user, timestamp);
        bytes32 signedMessageHash = ECDSA.toEthSignedMessageHash(data);
        address signer = ECDSA.recover(signedMessageHash, signature);
        require(signer == backendSigner || disableSignatureMode(), "Signature invalid!");
    }

    /* ---------------- For User ---------------- */
    function register(
        string memory name,
        uint256 timestamp,
        bytes memory signature
    ) public {
        // Check signature
        consumeSignature(
            this.register.selector, name, _msgSender(), timestamp, signature
        );

        // Register the BONX
        bonxStage[name] = 1;

        // Event
        emit Registered(name, _msgSender());
    }


    function buyBonding(
        string memory name, 
        uint256 share, 
        uint256 maxOutTokenAmount
    ) public {
        // Local variables
        address user = _msgSender();
        uint8 stage = bonxStage[name];
        uint256 totalShare = bonxTotalShare[name];

        // Check requirements
        require(stage != 0, "BONX not registered!");
        require(bonxTotalShare[name] + share <= maxSupply, "Exceed max supply!");

        // Stage transition
        if (stage == 1) {
            require(share <= mintLimit, "Exceed mint limit in stage 1!");
            require(userShare[name][user] + share <= holdLimit, "Exceed hold limit in stage 1!");
            if (bonxTotalShare[name] + share > restrictedSupply) 
                bonxStage[name] = 2;           // Stage transition: 1 -> 2
        } else if (stage == 2) {
            if (bonxTotalShare[name] + share == maxSupply)
                bonxStage[name] = 3;           // Stage transition: 2 -> 3
        }

        // Calculate fees and transfer tokens
        uint256 cost = bindingSumExclusive(totalShare, totalShare + share);
        uint256 fee = cost * taxBasePoint / 10000;
        feeCollected += fee;
        uint256 actualCost = cost + fee;
        require(actualCost <= maxOutTokenAmount, "Total cost more than expected!");
        IERC20(tokenAddress).transferFrom(user, address(this), actualCost);
        
        // Update storage
        bonxTotalShare[name] += share;
        userShare[name][user] += share;

        // Event
        emit BuyShare(name, user, share, bonxTotalShare[name], cost, actualCost, fee);
    }


    function sellBonding(
        string memory name, 
        uint256 share, 
        uint256 minInTokenAmount
    ) public {
        // Local variables
        address user = _msgSender();
        uint8 stage = bonxStage[name];
        uint256 totalShare = bonxTotalShare[name];

        // Check stage and share num
        require(stage != 0, "BONX not registered!");
        require(userShare[name][user] >= share, "Not enough share for the buyer!");

        // Stage transition
        if (stage == 2) {
            if (bonxTotalShare[name] - share <= restrictedSupply)
                bonxStage[name] = 1;           // Stage transition: 2 -> 1
        }

        // Calculate fees and transfer tokens
        uint256 reward = bindingSumExclusive(totalShare - share, totalShare);
        uint256 fee = reward * taxBasePoint / 10000;
        feeCollected += fee;
        uint256 actualReward = reward - fee;
        require(actualReward >= minInTokenAmount, "Total reward less than expected!");
        IERC20(tokenAddress).transfer(user, actualReward);
        
        // Update storage
        bonxTotalShare[name] -= share;
        userShare[name][user] -= share;
        
        // Event
        emit SellShare(name, user, share, bonxTotalShare[name], reward, actualReward, fee);
    }


    /* ---------------- For Admin --------------- */
    // function startContest        [Off-chain!]
    // function endContest          [Off-chain!]
    // function retrieveOwnership   [Off-chain!]

    function claimFees() public onlyOwner {
        uint256 feeCollected_ = feeCollected;
        feeCollected = 0;
        IERC20(tokenAddress).transfer(_msgSender(), feeCollected_);
        emit ClaimFees(_msgSender(), feeCollected_);
    }

    function claimRenewalFunds() public onlyOwner {
        uint256 renewalFunds_ = renewalFunds;
        renewalFunds = 0;
        IERC20(tokenAddress).transfer(_msgSender(), renewalFunds_);
        emit ClaimRenewalFunds(_msgSender(), renewalFunds_);
    }
    
    function setRestrictedSupply(uint256 newRestrictedSupply) public onlyOwner {
        restrictedSupply = newRestrictedSupply;
    }

    function setMintLimit(uint256 newMintLimit) public onlyOwner {
        mintLimit = newMintLimit;
    }

    function setHoldLimit(uint256 newHoldLimit) public onlyOwner {
        holdLimit = newHoldLimit;
    }

    function setMaxSupply(uint256 newMaxSupply) public onlyOwner {
        maxSupply = newMaxSupply;
    }

    function setBackendSigner(address newBackendSigner) public onlyOwner {
        backendSigner = newBackendSigner;
    }

    function setTaxBasePoint(uint256 newTaxBasePoint) public onlyOwner {
        taxBasePoint = newTaxBasePoint;
    }


    /* ---------------- For Owner --------------- */
    // function claimFeeOwner       [Off-chain!]

    function renewal(string memory name, uint256 tokenAmount) public {
        renewalFunds += tokenAmount;
        IERC20(tokenAddress).transferFrom(_msgSender(), address(this), tokenAmount);
        emit Renewal(name, tokenAmount);
    }

}