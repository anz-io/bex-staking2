// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../BONX.sol";

contract BONXTest is BONX {

    /**
     * This is a test contract that inherits from the BexCore contract. 
     * We disabled the signature verification here.
     */

    function disableSignatureMode() public override pure returns (bool) {
        return true;
    }
    
}