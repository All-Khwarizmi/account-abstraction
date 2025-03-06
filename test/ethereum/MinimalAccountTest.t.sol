// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {UserOperationLib} from "@account-abstraction/contracts/core/UserOperationLib.sol";
import {MinimalAccount} from "../../src/ethereum/MinimalAccount.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployMinimal} from "../../script/DeployMinimal.s.sol";
import {ERC20Mock} from "@openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "@account-abstraction/contracts/core/Helpers.sol";

contract MinimalAccountTest is Test {
    using UserOperationLib for PackedUserOperation;

    DeployMinimal deployMinimal;
    HelperConfig helperConfig;
    HelperConfig.NetworkConfig config;
    MinimalAccount minimalAccount;
    ERC20Mock usdc;
    uint256 AMOUNT = 100;
    address OWNER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 private PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 private constant MISSING_ACCOUNT_FUNDS = 100;

    function setUp() public {
        deployMinimal = new DeployMinimal();
        (minimalAccount, helperConfig) = deployMinimal.deployMinimalAccount(OWNER);
        config = helperConfig.getConfig();
        assertEq(minimalAccount.owner(), OWNER);
        // assertEq(helperConfig.getConfig().entryPoint, address(this));
        usdc = new ERC20Mock();
    }

    function testOwnerCanExecute() public {
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(this), AMOUNT);
        vm.startPrank(minimalAccount.owner());
        minimalAccount.execute(dest, value, functionData);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(this)), AMOUNT);
    }

    function testNonOwnerCannotExecute() public {
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(this), AMOUNT);
        vm.startPrank(address(this));
        vm.expectRevert(MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector);
        minimalAccount.execute(dest, value, functionData);
        vm.stopPrank();
    }

    function testShouldBeAbleToValidateSignature() public {
        PackedUserOperation memory userOp = _getPackedUserOp(minimalAccount.owner(), PRIVATE_KEY);

        bytes32 userOpHash = this._getUserOpHash(userOp, helperConfig.getConfig().entryPoint);

        uint256 validationData = minimalAccount._validateSignature(userOp, userOpHash);

        assertEq(validationData, SIG_VALIDATION_SUCCESS);
    }

    function testValidateUserOpReturnAffirmativeValidationData() public {
        // Create the packed user op
        PackedUserOperation memory userOp = _getPackedUserOp(minimalAccount.owner(), PRIVATE_KEY);
        // Get the user op hash (using method _getUserOpHash)
        bytes32 userOpHash = this._getUserOpHash(userOp, config.entryPoint);
        
        vm.deal(address(minimalAccount), MISSING_ACCOUNT_FUNDS);
       
        // Validate the user op
        vm.prank(config.entryPoint);
        uint256 validationData = minimalAccount.validateUserOp(userOp, userOpHash, MISSING_ACCOUNT_FUNDS);

        assertEq(validationData, SIG_VALIDATION_SUCCESS); // SIG_VALIDATION_SUCCESS = 0
    }

    function testValidateUserOpReturnNegativeValidationData() public {
        // Create the packed user op
        (address sender, uint256 privateKey) = makeAddrAndKey("user");
        PackedUserOperation memory userOp = _getPackedUserOp(sender, privateKey);
        // Get the user op hash (using method _getUserOpHash)
        bytes32 userOpHash = this._getUserOpHash(userOp, config.entryPoint);

        vm.deal(address(minimalAccount), MISSING_ACCOUNT_FUNDS);

        // Validate the user op
        vm.prank(config.entryPoint);
        uint256 validationData = minimalAccount.validateUserOp(userOp, userOpHash, MISSING_ACCOUNT_FUNDS);

        assertEq(validationData, SIG_VALIDATION_FAILED); // SIG_VALIDATION_FAILED = 1
    }

    function testValidateUserOpSendsMissingAccountFunds() public {
        PackedUserOperation memory userOp = _getPackedUserOp(minimalAccount.owner(), PRIVATE_KEY);

        bytes32 userOpHash = this._getUserOpHash(userOp, config.entryPoint);

        uint256 entryPointBalanceBefore = address(config.entryPoint).balance;
        assertEq(entryPointBalanceBefore, 0);

        vm.deal(address(minimalAccount), MISSING_ACCOUNT_FUNDS);

        vm.prank(config.entryPoint);
        minimalAccount.validateUserOp(userOp, userOpHash, MISSING_ACCOUNT_FUNDS);

        uint256 entryPointBalanceAfter = address(config.entryPoint).balance;

        assertEq(entryPointBalanceAfter, entryPointBalanceBefore + MISSING_ACCOUNT_FUNDS);
    }

    function _getPackedUserOp(address sender, uint256 privateKey) private view returns (PackedUserOperation memory) {
        uint256 nonce = 0;
        bytes32 accountGasLimits = bytes32(abi.encodePacked(uint256(0), uint256(0)));
        uint256 preVerificationGas = 0;
        bytes32 gasFees = bytes32(abi.encodePacked(uint256(0), uint256(0)));
        bytes memory paymasterAndData = new bytes(0);
        bytes memory signature;

        PackedUserOperation memory userOp = PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: new bytes(0),
            callData: new bytes(0),
            accountGasLimits: accountGasLimits,
            preVerificationGas: preVerificationGas,
            gasFees: gasFees,
            paymasterAndData: paymasterAndData,
            signature: signature
        });

        // Generate the signature
        userOp.signature = this._getUserSignature(userOp, config.entryPoint, privateKey);

        return userOp;
    }

    // Sender-verified signature over the entire request, the EntryPoint address and the chain ID
    function _getUserSignature(PackedUserOperation calldata userOp, address entryPointAddress, uint256 privateKey)
        public
        view
        returns (bytes memory)
    {
        bytes32 digest = _getUserOpHash(userOp, entryPointAddress);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        return abi.encodePacked(r, s, v);
    }

    /**
     *
     * @param userOp user operation
     * @return userOpHash hash of user operation
     * @dev the hash() method comes from UserOperationLib. We extend PackedUserOperation.
     * The address(this) is the address of the EntryPoint contract.
     */
    function _getUserOpHash(PackedUserOperation calldata userOp, address entryPoint) public view returns (bytes32) {
        return keccak256(abi.encodePacked(userOp.hash(), entryPoint, block.chainid));
    }
}
