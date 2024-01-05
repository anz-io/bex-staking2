// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../BexCore.sol";

contract BexCoreTest is BexCore {

    /**
     * This is a test contract that inherits from the BexCore contract. 
     * We disabled the signature verification here.
     */

    function disableSignatureMode() public override pure returns (bool) {
        return true;
    }
    
}