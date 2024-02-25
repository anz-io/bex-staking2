// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interface/blast.sol";
import "./BondingsCore.sol";

contract BondingsCoreBlast is BondingsCore {
    /**
     * @notice These two address may be changed in Blast Mainnet. 
     *        See https://docs.blast.io/building/guides/weth-yield#getting-usdb for more.
     */
    address public constant BLAST_ETH = 0x4300000000000000000000000000000000000002;
    address public constant BLAST_USDB = 0x4200000000000000000000000000000000000022;

    function initialize(
        address backendSigner_, address unitTokenAddress_, address protocolFeeDestination_
    ) public override initializer {
        super.initialize(backendSigner_, unitTokenAddress_, protocolFeeDestination_);
		IBlast(BLAST_ETH).configureClaimableYield();
        IERC20Rebasing(BLAST_USDB).configure(YieldMode.CLAIMABLE);
    }

    function claimAllYield(address yieldRecipient) public onlyOwner {
        // Claim the ETH yield
        IBlast(BLAST_ETH).claimAllYield(address(this), yieldRecipient);

        // Claim the ETH gas refund
		IBlast(BLAST_ETH).claimAllGas(address(this), yieldRecipient);

        // Claim the USDB yield
        IERC20Rebasing(BLAST_USDB).claim(
            yieldRecipient, 
            IERC20Rebasing(BLAST_USDB).getClaimableAmount(address(this))
        );
    }

}