// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "openzeppelin-contracts/governance/TimelockController.sol";
import "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
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
        address ownerAddress = vm.envAddress("OWNER_ADDRESS");
        vm.startBroadcast(deployerPrivateKey);
        address[] memory tokens = new address[](2);
        
        {
            tokens[0] = vm.envAddress("REWARD1_ADDRESS");
            tokens[1] = vm.envAddress("REWARD2_ADDRESS");
        }

        address[] memory proposers = new address[](1);
        proposers[0] = ownerAddress;

        address[] memory executors = new address[](1);
        executors[0] = ownerAddress;

        TimelockController timeLock = new TimelockController(delay, proposers, executors, ownerAddress);

        LockRewards implementation = new LockRewards();
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        proxyAdmin.transferOwnership(ownerAddress);


        new TransparentUpgradeableProxy(
            address(implementation),
            address(proxyAdmin),
            abi.encodeWithSelector(LockRewards(address(0)).initialize.selector, 
            lockToken,
            tokens,
            EPOCH_DURATION,
            LOCK_PERIOD,
            address(timeLock),
            ownerAddress,
            ownerAddress)
        );
        
        vm.stopBroadcast();
    }
}
