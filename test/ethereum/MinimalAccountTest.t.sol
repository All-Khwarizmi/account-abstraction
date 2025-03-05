// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {MinimalAccount} from "../../src/ethereum/MinimalAccount.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployMinimal} from "../../script/DeployMinimal.s.sol";
import {ERC20Mock} from "@openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract MinimalAccountTest is Test {
    DeployMinimal deployMinimal;
    HelperConfig helperConfig;
    MinimalAccount minimalAccount;
    ERC20Mock usdc;
    uint256 AMOUNT = 100;
    address user = makeAddr("user");

    function setUp() public {
        deployMinimal = new DeployMinimal();
        (minimalAccount, helperConfig) = deployMinimal.deployMinimalAccount();
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
        vm.startPrank(user);
        vm.expectRevert(MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector);
        minimalAccount.execute(dest, value, functionData);
        vm.stopPrank();
    }
}
