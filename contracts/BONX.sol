// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract BONX is Initializable, ERC721Upgradeable, OwnableUpgradeable {
    uint256 private _nextTokenId;
    mapping(uint256 => string) private _bonxNames;

    function initialize() initializer public {
        _nextTokenId = 1;        // Skip 0 as tokenId
        __ERC721_init("BONX", "BONX NFT");
        __Ownable_init();
    }

    /* ========================= View functions ========================= */
    function getNextTokenId() public view returns (uint256) {
        return _nextTokenId;
    }

    function getBonxName(uint256 tokenId) public view returns (string memory) {
        return _bonxNames[tokenId];
    }

    /* ================ Write functions (only for admin) ================ */
    function safeMint(address to, string memory name) public onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _bonxNames[tokenId] = name;
        _safeMint(to, tokenId);
        return tokenId;
    }

    function retrieveNFT(uint256 tokenId) public onlyOwner {
        _transfer(ownerOf(tokenId), owner(), tokenId);
    }
}
