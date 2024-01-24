// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract BondingsCore is OwnableUpgradeable {

    /* ============================ Variables =========================== */
    /* ----------------- Supply ----------------- */
    uint256 public fairLaunchSupply;    // Max supply for stage 1
    uint256 public mintLimit;           // Mint limit in stage 1
    uint256 public holdLimit;           // Hold limit in stage 1
    uint256 public maxSupply;           // Max supply for bondings

    /* ---------------- Signature --------------- */
    address public backendSigner;       // Signer for deploy new bondings
    uint256 public signatureValidTime;  // Valid time for a signature

    /* ------------------- Tax ------------------ */
    uint256 public protocolFeePercent;
    address public protocolFeeDestination;

    /* ----------------- Address ---------------- */
    address public unitTokenAddress;

    /* ----------------- Storage ---------------- */
    // bondings => [stage information for this bondings (0~3, 0 for not deployed)]
    mapping(string => uint8) public bondingsStage;

    // bondings => [total share num of the bondings]
    mapping(string => uint256) private bondingsTotalShare;

    // bondings => user => [user's share num of this bondings]
    mapping(string => mapping(address => uint256)) public userShare;

    // keccak256(signature) => [whether this signature is used]
    mapping(bytes32 => bool) public signatureIsUsed;
    

    /* ============================= Events ============================= */
    event Deployed(string bondingsName, address indexed user);
    event BuyBondings(
        string bondingsName, address indexed user, uint256 share, uint256 lastId, 
        uint256 buyPrice, uint256 buyPriceAfterFee, uint256 fee
    );
    event SellBondings(
        string bondingsName, address indexed user, uint256 share, uint256 lastId, 
        uint256 sellPrice, uint256 sellPriceAfterFee, uint256 fee
    );
    event TransferBondings(
        string bondingsName, address indexed from, address indexed to, uint256 share
    );


    /* =========================== Constructor ========================== */
    function initialize(
        address backendSigner_, address unitTokenAddress_, address protocolFeeDestination_
    ) public initializer {
        __Ownable_init();

        fairLaunchSupply = 1000;
        mintLimit = 10;
        holdLimit = 50;
        maxSupply = 1000000000;

        backendSigner = backendSigner_;
        signatureValidTime = 3 minutes;

        protocolFeePercent = 300;
        protocolFeeDestination = protocolFeeDestination_;

        unitTokenAddress = unitTokenAddress_;
    }


    /* ====================== Pure / View functions ===================== */
    function disableSignatureMode() public virtual pure returns (bool) {
        return false;       // Override this for debugging in the testnet
    }

    function getPrice(uint256 supply, uint256 amount) public pure returns (uint256) {
        uint256 sum1 = supply == 0 ? 0 : (supply - 1 ) * (supply) * (2 * (supply - 1) + 1) / 6;
        uint256 sum2 = (supply == 0 && amount == 1) ? 0 : 
            (supply + amount - 1) * (supply + amount) * (2 * (supply + amount - 1) + 1) / 6;
        uint256 summation = sum2 - sum1;
        return summation;
    }

    function getBuyPrice(string memory name, uint256 amount) public view returns (uint256) {
        return getPrice(bondingsTotalShare[name], amount);
    }

    function getSellPrice(string memory name, uint256 amount) public view returns (uint256) {
        return getPrice(bondingsTotalShare[name] - amount, amount);
    }

    function getBuyPriceAfterFee(string memory name, uint256 amount) public view returns (uint256) {
        uint256 price = getBuyPrice(name, amount);
        uint256 fee = price * protocolFeePercent / 10000;
        return price + fee;
    }

    function getSellPriceAfterFee(string memory name, uint256 amount) public view returns (uint256) {
        uint256 price = getSellPrice(name, amount);
        uint256 fee = price * protocolFeePercent / 10000;
        return price - fee;
    }

    function getBondingsTotalShare(string memory name) public view returns (uint256) {
        require(bondingsStage[name] != 0, "Bondings not deployed!");
        return bondingsTotalShare[name] - 1;
    }


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
    function deploy(
        string memory name,
        uint256 timestamp,
        bytes memory signature
    ) public {
        // Check signature
        consumeSignature(
            0x8580974c, name, _msgSender(), timestamp, signature
        );

        // Deploy the Bondings
        bondingsStage[name] = 1;
        bondingsTotalShare[name] = 1;

        // Event
        emit Deployed(name, _msgSender());
    }


    function buyBondings(
        string memory name, 
        uint256 share, 
        uint256 maxOutTokenAmount
    ) public {
        // Local variables
        address user = _msgSender();
        uint8 stage = bondingsStage[name];
        uint256 totalShare = bondingsTotalShare[name];

        // Check requirements
        require(share > 0, "Share must be greater than 0!");
        require(stage != 0, "Bondings not deployed!");
        require(totalShare + share <= maxSupply, "Exceed max supply!");

        // Stage transition
        if (stage == 1) {
            require(share <= mintLimit, "Exceed mint limit in stage 1!");
            require(userShare[name][user] + share <= holdLimit, "Exceed hold limit in stage 1!");
            if (totalShare + share > fairLaunchSupply) 
                bondingsStage[name] = 2;           // Stage transition: 1 -> 2
        } else if (stage == 2) {
            if (totalShare + share == maxSupply)
                bondingsStage[name] = 3;           // Stage transition: 2 -> 3
        }

        // Calculate fees and transfer tokens
        uint256 price = getBuyPrice(name, share);
        uint256 fee = price * protocolFeePercent / 10000;
        uint256 priceAfterFee = price + fee;
        require(priceAfterFee <= maxOutTokenAmount, "Slippage exceeded!");
        IERC20(unitTokenAddress).transferFrom(user, address(this), priceAfterFee);
        if (fee > 0)
            IERC20(unitTokenAddress).transfer(protocolFeeDestination, fee);
        
        // Update storage
        bondingsTotalShare[name] += share;
        userShare[name][user] += share;

        // Event
        emit BuyBondings(
            name, user, share, bondingsTotalShare[name] - 1, 
            price, priceAfterFee, fee
        );
    }


    function sellBondings(
        string memory name, 
        uint256 share, 
        uint256 minInTokenAmount
    ) public {
        // Local variables
        address user = _msgSender();
        uint8 stage = bondingsStage[name];
        uint256 totalShare = bondingsTotalShare[name];

        // Check stage and share num
        require(share > 0, "Share must be greater than 0!");
        require(stage != 0, "Bondings not deployed!");
        require(userShare[name][user] >= share, "Insufficient shares!");

        // Stage transition
        if (stage == 2) {
            if (totalShare - share <= fairLaunchSupply)
                bondingsStage[name] = 1;           // Stage transition: 2 -> 1
        }

        // Calculate fees and transfer tokens
        uint256 price = getSellPrice(name, share);
        uint256 fee = price * protocolFeePercent / 10000;
        uint256 priceAfterFee = price - fee;
        require(priceAfterFee >= minInTokenAmount, "Slippage exceeded!");
        IERC20(unitTokenAddress).transfer(user, priceAfterFee);
        if (fee > 0)
            IERC20(unitTokenAddress).transfer(protocolFeeDestination, fee);
        
        // Update storage
        bondingsTotalShare[name] -= share;
        userShare[name][user] -= share;
        
        // Event
        emit SellBondings(
            name, user, share, bondingsTotalShare[name], 
            price, priceAfterFee, fee
        );
    }


    function transferBondings(
        string memory name, 
        address to, 
        uint256 share
    ) public {
        // Local variables
        address user = _msgSender();
        uint8 stage = bondingsStage[name];

        // Check stage and share num
        require(stage == 3, "Transfer is only allowed in stage 3!");
        require(userShare[name][user] >= share, "Insufficient shares!");

        // Update storage
        userShare[name][user] -= share;
        userShare[name][to] += share;

        // Event
        emit TransferBondings(name, user, to, share);
    }


    /* ---------------- For Admin --------------- */
    // function startContest        [Off-chain!]
    // function endContest          [Off-chain!]
    // function claimFees           [Automatic!]

    function setFairLaunchSupply(uint256 newFairLaunchSupply) public onlyOwner {
        require(newFairLaunchSupply <= maxSupply, "Restricted supply must be less than max supply!");
        require(newFairLaunchSupply >= holdLimit, "Restricted supply must be greater than hold limit!");
        fairLaunchSupply = newFairLaunchSupply;
    }

    function setMintLimit(uint256 newMintLimit) public onlyOwner {
        require(newMintLimit <= holdLimit, "Mint limit must be less than hold limit!");
        mintLimit = newMintLimit;
    }

    function setHoldLimit(uint256 newHoldLimit) public onlyOwner {
        require(newHoldLimit >= mintLimit, "Hold limit must be greater than mint limit!");
        require(newHoldLimit <= fairLaunchSupply, "Hold limit must be less than restricted supply!");
        holdLimit = newHoldLimit;
    }

    function setMaxSupply(uint256 newMaxSupply) public onlyOwner {
        require(newMaxSupply >= fairLaunchSupply, "Max supply must be greater than restricted supply!");
        maxSupply = newMaxSupply;
    }

    function setProtocolFeePercent(uint256 newProtocolFeePercent) public onlyOwner {
        require(newProtocolFeePercent <= 10000, "Tax base point must be less than 10000!");
        protocolFeePercent = newProtocolFeePercent;
    }

    function setBackendSigner(address newBackendSigner) public onlyOwner {
        backendSigner = newBackendSigner;
    }

    function setProtocolFeeDestination(address newProtocolFeeDestination) public onlyOwner {
        protocolFeeDestination = newProtocolFeeDestination;
    }
}