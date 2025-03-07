// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {
    Transaction,
    MemoryTransactionHelper
} from "@zk-era-contracts/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {UserOperationLib} from "@account-abstraction/contracts/core/UserOperationLib.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployMinimal} from "../../script/DeployMinimal.s.sol";
import {ERC20Mock} from "@openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {ZkMinimalAccount} from "../../src/zksync/ZkMinimal.sol";
import {BOOTLOADER_FORMAL_ADDRESS} from "@zk-era-contracts/system-contracts/contracts/Constants.sol";
import {ACCOUNT_VALIDATION_SUCCESS_MAGIC} from "@zk-era-contracts/system-contracts/contracts/interfaces/IAccount.sol";

contract ZkMinimalAccountTest is Test {
    using UserOperationLib for PackedUserOperation;

    DeployMinimal deployMinimal;
    HelperConfig helperConfig;
    HelperConfig.NetworkConfig config;
    ZkMinimalAccount zkMinimalAccount;
    ERC20Mock usdc;
    uint256 AMOUNT = 100;
    address user;
    address randomUser = makeAddr("randomUser");
    uint256 private PRIVATE_KEY;
    bytes32 private constant EMPTY_BYTES32 = bytes32(0);

    function setUp() public {
        (user, PRIVATE_KEY) = makeAddrAndKey("user");
        helperConfig = new HelperConfig();
        config = helperConfig.getConfig();
        deployMinimal = new DeployMinimal();
        zkMinimalAccount = new ZkMinimalAccount(user);
        usdc = new ERC20Mock();
        (user, PRIVATE_KEY) = makeAddrAndKey("user");
    }

    function testOwnerCanExecute() public {
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, user, AMOUNT);
        Transaction memory transaction = _createTransaction(zkMinimalAccount.owner(), 113, dest, value, functionData);

        vm.startPrank(zkMinimalAccount.owner());
        zkMinimalAccount.executeTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(user)), AMOUNT);
    }

    function testNonOwnerCannotExecute() public {
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, user, AMOUNT);
        Transaction memory transaction = _createTransaction(user, 113, dest, value, functionData);

        vm.startPrank(randomUser);
        vm.expectRevert(ZkMinimalAccount.ZkMinimalAccount__NotFromBootloaderOrOwner.selector);
        zkMinimalAccount.executeTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);
        vm.stopPrank();
    }

    function testZkValidateTransaction() public {
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, user, AMOUNT);
        Transaction memory transaction = _createTransaction(zkMinimalAccount.owner(), 113, dest, value, functionData);
        transaction.signature = _signTransaction(transaction);
        vm.deal(address(zkMinimalAccount), type(uint256).max);
        vm.prank(BOOTLOADER_FORMAL_ADDRESS);
        bytes4 magic = zkMinimalAccount.validateTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);

        assertEq(magic, ACCOUNT_VALIDATION_SUCCESS_MAGIC);
    }

    function _createTransaction(address from, uint8 txType, address to, uint256 value, bytes memory data)
        internal
        view
        returns (Transaction memory)
    {
        uint256[4] memory reserved;
        uint256 nonce = vm.getNonce(address(zkMinimalAccount));
        bytes32[] memory factoryDeps = new bytes32[](0);

        Transaction memory transaction = Transaction({
            txType: txType,
            from: uint256(uint160(from)),
            to: uint256(uint160(to)),
            gasLimit: 16777216,
            gasPerPubdataByteLimit: 16777216,
            maxFeePerGas: 16777216,
            maxPriorityFeePerGas: 16777216,
            paymaster: 0,
            nonce: nonce,
            value: value,
            reserved: reserved,
            data: data,
            signature: hex"",
            factoryDeps: factoryDeps,
            paymasterInput: hex"",
            reservedDynamic: hex""
        });

        return transaction;
    }

    function _signTransaction(Transaction memory transaction) internal view returns (bytes memory signature) {
        bytes32 unsignedTxHash = MemoryTransactionHelper.encodeHash(transaction);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, unsignedTxHash);

        signature = abi.encodePacked(r, s, v);
    }
}
