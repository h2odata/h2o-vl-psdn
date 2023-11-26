// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "openzeppelin-contracts/governance/TimelockController.sol";
import "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../src/LockRewards.sol";

import "../src/mocks/ERC20Mock.sol";

uint256 constant LOCK_PERIOD = 3;
uint256 constant EPOCH_DURATION = 1;
uint256 constant MAX_EPOCH = 2;

contract DeployMocksScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address ownerAddress = vm.envAddress("OWNER_ADDRESS");
        vm.startBroadcast(deployerPrivateKey);
        ERC20Mock h2o = new ERC20Mock("H2O", "H2O");
        ERC20Mock psdnOcean = new ERC20Mock("psdnOcean", "psdnOcean");
        ERC20Mock psdnOceanLP = new ERC20Mock("80psdnOCEAN-20OCEAN", "80psdnOCEAN-20OCEAN");
        
        // ERC20Mock ocean = new ERC20Mock("OCEAN", "OCEAN");
        // ERC20Mock psdn = new ERC20Mock("Poseidon", "PSDN");
        // ERC20Mock psdnLp = new ERC20Mock("80PSDN-20ETH", "80PSDN-20ETH");

        vm.stopBroadcast();
    }
}
