// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC721Upgradeable.sol";

contract BexCore is OwnableUpgradeable {

    uint256 public restrictSupply;      // Supply for stage 1 -> stage 2
    uint256 public mintLimit;           // Mint limit in stage 1
    uint256 public holdLimit;           // Hold limit in stage 1
    uint256 public totalSupply;

    IERC721Upgradeable public bonxNFT;

    struct BonxInfo {
        uint8 stage;                    // 0,1,2,3 (0 for not registered)
        uint256 supply;
    }

    mapping(string => BonxInfo) public bonxInfo;

    function initialize(
        address BonxAddress
    ) public initializer {
        __Ownable_init();

        bonxNFT = IERC721Upgradeable(BonxAddress);
    }


    // function startContest() {}           // epoch++, 2 days
    // function endContest() {}             // has an owner, 90 days
    // function retrieveOwnership() {}      // admin retrieve

    // function renewal() {}         // [in another contract!]


}