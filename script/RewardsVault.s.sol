// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/FutureRewardsVault.sol";

contract RewardsVaultScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address lockRewards = vm.envAddress("LOCK_REWARDS_ADDRESS");
        address ownerAddress = vm.envAddress("OWNER_ADDRESS");
        vm.startBroadcast(deployerPrivateKey);

        FutureRewardsVault rewardsVault = new FutureRewardsVault(
            lockRewards,
            ownerAddress
        );
        vm.stopBroadcast();
    }
}
