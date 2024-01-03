// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface IBONX is IERC721Upgradeable {
    function safeMint(address to) external;
}

contract BONX is Initializable, ERC721Upgradeable, ERC721BurnableUpgradeable, OwnableUpgradeable {
    uint256 private _nextTokenId;

    function initialize() initializer public {
        _nextTokenId = 1;        // Skip 0 as tokenId
        __ERC721_init("BONX", "BONX NFT");
        __ERC721Burnable_init();
        __Ownable_init();
    }

    function safeMint(address to) public onlyOwner {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
    }
}
