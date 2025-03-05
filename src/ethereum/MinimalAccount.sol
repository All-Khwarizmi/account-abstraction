// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IAccount} from "@account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "@account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";

contract MinimalAccount is IAccount, Ownable {
    error MinimalAccount__NotFromEntryPoint();
    error MinimalAccount__NotFromEntryPointOrOwner();
    error MinimalAccount__CallFailed(bytes returnData);

    IEntryPoint private immutable i_entryPoint;

    /*//////////////////////////////////////////////////////////////
                                MODIFIER
    //////////////////////////////////////////////////////////////*/
    modifier requireFromEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert MinimalAccount__NotFromEntryPoint();
        }
        _;
    }

    modifier onlyOwnerOrEntryPoint() {
        if (msg.sender != owner() && msg.sender != address(i_entryPoint)) {
            revert MinimalAccount__NotFromEntryPointOrOwner();
        }
        _;
    }

    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                          INTERNALS-FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        returns (uint256 validationData)
    {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);

        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }
        return SIG_VALIDATION_SUCCESS;
    }

    function _payPreFund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds > 0) {
            (bool success, bytes memory result) = payable(msg.sender).call{value: missingAccountFunds}("");
            if (!success) {
                revert MinimalAccount__CallFailed(result);
            }
        }
    }
    /*//////////////////////////////////////////////////////////////
                           EXTERNAL-FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        requireFromEntryPoint
        returns (uint256 validationData)
    {
        validationData = _validateSignature(userOp, userOpHash);
        _payPreFund(missingAccountFunds);
    }

    function execute(address dest, uint256 value, bytes calldata functionData) external onlyOwnerOrEntryPoint {
        (bool success,) = payable(dest).call{value: value}(functionData);
        require(success, "Failed to execute");
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/
    function getEntryPoint() public view returns (address) {
        return address(i_entryPoint);
    }
}
