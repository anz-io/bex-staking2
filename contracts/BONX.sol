// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract BONX is Initializable, ERC721Upgradeable, OwnableUpgradeable {

    uint256 private _nextTokenId;
    address public tokenAddress;
    uint256 public renewalFunds;

    mapping(uint256 => string) private _bonxNames;

    event Renewal(uint256 tokenId, uint256 tokenAmount);
    event ClaimRenewalFunds(address indexed admin, uint256 tokenAmount);

    function initialize(address tokenAddress_) initializer public {
        _nextTokenId = 1;        // Skip 0 as tokenId
        __ERC721_init("BONX", "BONX NFT");
        __Ownable_init();
        tokenAddress = tokenAddress_;
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

    /* ---------------- For Owner --------------- */
    function renewal(uint256 tokenId, uint256 tokenAmount) public {
        renewalFunds += tokenAmount;
        IERC20(tokenAddress).transferFrom(_msgSender(), address(this), tokenAmount);
        emit Renewal(tokenId, tokenAmount);
    }

}
