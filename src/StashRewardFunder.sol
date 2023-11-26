// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/security/Pausable.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/access/AccessControl.sol";
import "./interfaces/IStashRewardDistro.sol";

/**
 *  @title Adapter contract for rewards coming from psdnOCEAN
 *  @author miniroman
 *  @notice PsdnOcean booster contract relies on notifying about
 *  the rewards by calling queueNewRewards. This contract forwards those
 *  to Aura reward distributor for the next period. 
 */
contract StashRewardFunder is AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant REWARDS_ROLE = keccak256("REWARDS_ROLE");
    address private rewardToken;
    address private rewardDistro;
    uint256 private poolId;

    constructor(address _rewardToken, address _rewardDistro, uint256 _poolId, address _admin) {
        rewardToken = _rewardToken;
        rewardDistro = _rewardDistro;
        poolId = _poolId;
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(REWARDS_ROLE, _admin);
    }

    function queueNewRewards(uint256 amount) external {
        IERC20(rewardToken).approve(rewardDistro, amount);
        IStashRewardDistro(rewardDistro).fundPool(poolId, rewardToken, amount, 1);
    }

    function recoverERC20Token(address token) public onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(token).safeTransfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }
}
