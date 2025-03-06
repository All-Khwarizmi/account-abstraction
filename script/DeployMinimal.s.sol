// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployMinimal is Script {
    function run() public {}

    function deployMinimalAccount(address owner) public returns (MinimalAccount, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        vm.startBroadcast(networkConfig.account);
        MinimalAccount minimalAccount = new MinimalAccount(networkConfig.entryPoint);
        minimalAccount.transferOwnership(owner);
        vm.stopBroadcast();

        return (minimalAccount, helperConfig);
    }
}
