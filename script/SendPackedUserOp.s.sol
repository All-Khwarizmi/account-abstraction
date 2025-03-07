// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";
import {EntryPoint, IEntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {MessageHashUtils} from "@openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

contract SendPackedUserOp is Script {
    function run() public {}

    uint256 private PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function generateSignedUserOp(address sender, bytes memory callData, HelperConfig.NetworkConfig memory config)
        public
        view
        returns (PackedUserOperation memory userOp, bytes32 ethSignedMessageHash)
    {
        userOp = _generateUnsignedUserOp(sender, callData);
        IEntryPoint entryPoint = IEntryPoint(config.entryPoint);

        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        uint8 v;
        bytes32 r;
        bytes32 s;
        if (block.chainid == 31337) {
            (v, r, s) = vm.sign(PRIVATE_KEY, ethSignedMessageHash);
        } else {
            (v, r, s) = vm.sign(config.account, ethSignedMessageHash);
        }

        userOp.signature = abi.encodePacked(r, s, v);
    }

    function _generateUnsignedUserOp(address sender, bytes memory callData)
        internal
        view
        returns (PackedUserOperation memory)
    {
        uint256 nonce = vm.getNonce(sender) - 1;
        uint128 verificationGasLimit = 16777216;
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;
        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit),
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}
