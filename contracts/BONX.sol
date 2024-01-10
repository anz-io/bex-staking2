// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

contract BONX is ERC721Upgradeable, OwnableUpgradeable {

    uint256 private _nextTokenId;
    address public tokenAddress;
    uint256 public renewalFunds;

    // nft token id => bonding name
    mapping(uint256 => string) private _bonxNames;

    // keccak256(signature) => [whether this signature is used]
    mapping(bytes32 => bool) public signatureIsUsed;

    address public backendSigner;       // Signer for register a new bondings
    uint256 public signatureValidTime;  // Valid time for a signature

    event Renewal(uint256 nftTokenId, uint256 usdtAmount);
    event ClaimRenewalFunds(address indexed admin, uint256 usdtAmount);

    function initialize(address backendSigner_, address tokenAddress_) initializer public {
        _nextTokenId = 1;        // Skip 0 as tokenId
        __ERC721_init("BONX", "BONX NFT");
        __Ownable_init();
        tokenAddress = tokenAddress_;

        backendSigner = backendSigner_;
        signatureValidTime = 3 minutes;
    }
    
    /* ============================ Signature =========================== */
    function disableSignatureMode() public virtual pure returns (bool) {
        return false;       // Override this for debugging in the testnet
    }

    function consumeSignature(
        bytes4 selector,
        uint256 amount,
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
        bytes memory data = abi.encodePacked(selector, amount, user, timestamp);
        bytes32 signedMessageHash = ECDSA.toEthSignedMessageHash(data);
        address signer = ECDSA.recover(signedMessageHash, signature);
        require(signer == backendSigner || disableSignatureMode(), "Signature invalid!");
    }

    /* ========================= View functions ========================= */
    
    function getNextTokenId() public view returns (uint256) {
        return _nextTokenId;
    }

    function getBonxName(uint256 tokenId) public view returns (string memory) {
        return _bonxNames[tokenId];
    }


    /* ========================= Write functions ======================== */

    /* ---------------- For Admin --------------- */
    function safeMint(address to, string memory name) public onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _bonxNames[tokenId] = name;
        _safeMint(to, tokenId);
        return tokenId;
    }

    function retrieveNFT(uint256 tokenId) public onlyOwner {
        _transfer(ownerOf(tokenId), owner(), tokenId);
    }

    function claimRenewalFunds() public onlyOwner {
        uint256 renewalFunds_ = renewalFunds;
        renewalFunds = 0;
        IERC20(tokenAddress).transfer(_msgSender(), renewalFunds_);
        emit ClaimRenewalFunds(_msgSender(), renewalFunds_);
    }

    function setBackendSigner(address newBackendSigner) public onlyOwner {
        backendSigner = newBackendSigner;
    }

    /* ---------------- For Owner --------------- */
    function renewal(
        uint256 nftTokenId, 
        uint256 usdtAmount,
        uint256 timestamp,
        bytes memory signature
    ) public {
        // Check the signature
        consumeSignature(
            this.renewal.selector, usdtAmount, _msgSender(), timestamp, signature
        );

        // Update storage, transfer token and emit event
        renewalFunds += usdtAmount;
        IERC20(tokenAddress).transferFrom(_msgSender(), address(this), usdtAmount);
        emit Renewal(nftTokenId, usdtAmount);
    }

}
