// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IAccount} from "@account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";

contract MinimalAccount is IAccount {
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        returns (uint256 validationData)
    {}

    function _validateSignature(bytes32 userOpHash, bytes memory userOpSignature) internal view returns (uint256) {
        return 1;
    }
}
