// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "openzeppelin-contracts/governance/TimelockController.sol";
import "../src/LockRewards.sol";

uint256 constant LOCK_PERIOD = 3;
uint256 constant EPOCH_DURATION = 1;
uint256 constant MAX_EPOCH = 2;

contract LockRewardsScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 delay = vm.envUint("TIMELOCK_DELAY");
        address lockToken = vm.envAddress("LOCK_ADDRESS");
        address reward1Token = vm.envAddress("REWARD1_ADDRESS");
        address reward2Token = vm.envAddress("REWARD2_ADDRESS");
        address ownerAddress = vm.envAddress("OWNER_ADDRESS");
        vm.startBroadcast(deployerPrivateKey);
        address[] memory tokens = new address[](2);
        tokens[0] = reward1Token;
        tokens[1] = reward2Token;

        address[] memory proposers = new address[](1);
        proposers[1] = ownerAddress;

        address[] memory executors = new address[](1);
        proposers[1] = ownerAddress;

        TimelockController timeLock = new TimelockController(delay, proposers, executors, ownerAddress);

        LockRewards lockRewards = new LockRewards(
            lockToken,
            tokens,
            EPOCH_DURATION,
            LOCK_PERIOD,
            address(timeLock),
            ownerAddress,
            ownerAddress
        );

        vm.stopBroadcast();
    }
}
