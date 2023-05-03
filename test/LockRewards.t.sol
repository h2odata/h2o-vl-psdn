// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "openzeppelin-contracts/interfaces/IERC20.sol";
import "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/utils/Strings.sol";
import "../src/LockRewards.sol";
import "../src/interfaces/ILockRewards.sol";

uint256 constant DAY = 86400;
uint256 constant LOCK_PERIOD = 1;
uint256 constant EPOCH_DURATION = 7;
uint256 constant MAX_EPOCH = 4;
address constant LOCK_ADDRESS = address(0x98585dFc8d9e7D48F0b1aE47ce33332CF4237D96);
address constant REWARD1_ADDRESS = address(0x98585dFc8d9e7D48F0b1aE47ce33332CF4237D96);
address constant REWARD2_ADDRESS = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
address constant REWARD3_ADDRESS = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
address constant USER = address(0xf8e0C93Fd48B4C34A4194d3AF436b13032E641F3);
address constant USER2 = address(0xdb36b23964FAB32dCa717c99D6AEFC9FB5748f3a);

contract LockRewardsTest is Test {
    using SafeERC20 for IERC20;

    LockRewards public lockRewardsContract;
    address public lockRewards;
    address public user;
    address public user2;

    function setUp() public {
        address[] memory tokens = new address[](2);
        tokens[0] = REWARD1_ADDRESS;
        tokens[1] = REWARD2_ADDRESS;

        lockRewardsContract = new LockRewards(
            LOCK_ADDRESS,
            tokens,
            EPOCH_DURATION,
            LOCK_PERIOD,
            address(this)
        );
        lockRewardsContract.grantRole(lockRewardsContract.EPOCH_SETTER_ROLE(), address(this));
        lockRewards = address(lockRewardsContract);
        user = USER;
        user2 = USER2;

        deal(lockRewards, 1000 ether);
        deal(user, 1000 ether);
        deal(LOCK_ADDRESS, user, 100e18);
        deal(LOCK_ADDRESS, user2, 100e18);
    }

    /* Constructor Tests*/
    function testOwnerShouldBeDeployer() public {
        address owner = lockRewardsContract.owner();
        assertEq(owner, address(this));
    }

    function testRewardsTokenShouldBeNewO() public {
        address addr = lockRewardsContract.rewardTokens(0);
        assertEq(addr, REWARD1_ADDRESS);
    }

    function testRewardsTokenShouldBeWETH() public {
        address addr = lockRewardsContract.rewardTokens(1);
        assertEq(addr, REWARD2_ADDRESS);
    }

    function testCurrentEpochShouldBe1() public {
        uint256 currentEpoch = lockRewardsContract.currentEpoch();
        assertEq(currentEpoch, 1);
    }

    /* View Functions Tests */
    function testBalanceOfShouldBeTotalLockedByTheUser() public {
        uint256 deposit = 1e18;
        _deposit(user, deposit);

        uint256 balance = lockRewardsContract.balanceOf(user);

        assertEq(balance, deposit);
    }

    function testBalanceOfInEpochShouldBeTotalLockedByTheUserInEpoch() public {
        uint256 deposit = 1e18;
        _deposit(user, deposit);

        uint256 balance = lockRewardsContract.balanceOfInEpoch(user, 1);
        assertEq(balance, deposit);
        uint256 balanceInEpoch = lockRewardsContract.balanceOfInEpoch(user, MAX_EPOCH);
        assertEq(balanceInEpoch, 0);
    }

    function testTotalLockedShouldBeAllTokensLocked() public {
        uint256 deposit = 1e18;
        _deposit(user, deposit);

        uint256 balance = lockRewardsContract.totalLocked();

        assertEq(balance, deposit);
    }

    function testGetCurrentEpochShouldReturnInformationAboutCurrentEpoch() public {
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        _transferRewards(reward1, reward2);

        lockRewardsContract.setNextEpoch(values);

        (uint256 start, uint256 finish,, uint256[] memory rewards,) = lockRewardsContract.getCurrentEpoch();

        assertEq(finish - start, EPOCH_DURATION * DAY);
        assertEq(rewards[0], reward1);
        assertEq(rewards[1], reward2);
    }

    function testGetNextEpochShouldReturn0WhenEpochIsNotSetted() public {
        (uint256 start, uint256 finish, uint256 locked, uint256[] memory rewards,) = lockRewardsContract.getNextEpoch();

        assertEq(start, 0);
        assertEq(finish, 0);
        assertEq(locked, 0);
        assertEq(rewards[0], 0);
        assertEq(rewards[1], 0);
    }

    function testGetEpochBalanceLockShouldReturnCallerBalanceLocked() public {
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        uint256 deposit = 1e18;
        _transferRewards(reward1, reward2);
        lockRewardsContract.setLockDuration(2);

        _deposit(user, deposit);

        vm.startPrank(user);
        uint256 user1epoch1BalanceLocked = lockRewardsContract.getEpochBalanceLocked(1);
        uint256 user1epoch2BalanceLocked = lockRewardsContract.getEpochBalanceLocked(2);
        vm.stopPrank();

        assertEq(user1epoch1BalanceLocked, deposit);
        assertEq(user1epoch2BalanceLocked, deposit);

        vm.startPrank(user2);
        uint256 user2epoch1BalanceLocked = lockRewardsContract.getEpochBalanceLocked(1);
        uint256 user2epoch2BalanceLocked = lockRewardsContract.getEpochBalanceLocked(2);
        vm.stopPrank();

        assertEq(user2epoch1BalanceLocked, 0);
        assertEq(user2epoch2BalanceLocked, 0);
    }

    function testGetEpochShouldReturnInformationAboutSpecificEpoch() public {
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        uint256 deposit = 1e18;
        _transferRewards(reward1, reward2);

        _deposit(user, deposit);

        lockRewardsContract.setNextEpoch(values);

        (uint256 epoch1Start, uint256 epoch1Finish, uint256 epoch1Locked, uint256[] memory epoch1Rewards,) =
            lockRewardsContract.getEpoch(1);
        (uint256 epoch2Start, uint256 epoch2Finish, uint256 epoch2Locked, uint256[] memory epoch2Rewards,) =
            lockRewardsContract.getEpoch(2);

        assertEq(epoch1Start + 7 * 86400, epoch1Finish);
        assertEq(epoch1Locked, deposit);
        assertEq(epoch1Rewards[0], reward1);
        assertEq(epoch1Rewards[1], reward2);

        assertEq(epoch2Start, 0);
        assertEq(epoch2Finish, 0);
        assertEq(epoch2Locked, 0);
        assertEq(epoch2Rewards.length, 0);
    }

    function testGetAccountShouldReturnInformationAboutAccount() public {
        uint256 deposit = 1e18;

        _deposit(user, deposit);

        (uint256 balance, uint256 lockEpochs, uint256 lastEpochPaid, uint256[] memory rewards) =
            lockRewardsContract.getAccount(user);

        assertEq(balance, deposit);
        assertEq(lockEpochs, 1);
        assertEq(lastEpochPaid, 1);
        assertEq(rewards[0], 0);
        assertEq(rewards[1], 0);
    }

    function testGetRewardTokensShouldReturnRewardTokensArray() public {
        address[] memory rewardTokens = lockRewardsContract.getRewardTokens();

        assertEq(rewardTokens.length, 2);
        assertEq(rewardTokens[0], REWARD1_ADDRESS);
        assertEq(rewardTokens[1], REWARD2_ADDRESS);
    }

    /* Set Lock Duration Tests */
    function testSetLockDurationShouldBeCallableOnlyByOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user);
        lockRewardsContract.setLockDuration(3);
    }

    function testCannotSetSameLockDuration() public {
        vm.expectRevert(abi.encodeWithSelector(ILockRewards.IncorrectLockDuration.selector));
        lockRewardsContract.setLockDuration(1);
    }

    function testSetLockDurationShouldUpdateLockPeriod() public {
        uint256 lockPeriod = lockRewardsContract.lockDuration();
        uint256 newLockPeriod = 3;

        assertEq(lockPeriod, LOCK_PERIOD);

        lockRewardsContract.setLockDuration(newLockPeriod);
        assertEq(lockRewardsContract.lockDuration(), newLockPeriod);
    }

    function testSetLockDurationShouldAffectFutureDeposits() public {
        uint256 newLockPeriod = 3;
        lockRewardsContract.setLockDuration(newLockPeriod);

        uint256 deposit = 1e18;
        _deposit(user, deposit);

        (, uint256 lockEpochs,,) = lockRewardsContract.getAccount(user);

        assertEq(lockEpochs, newLockPeriod);
    }

    function testSetLockDurationShouldNotAffectPreviousDeposits() public {
        uint256 deposit = 1e18;
        _deposit(user, deposit);

        uint256 newLockPeriod = 3;
        lockRewardsContract.setLockDuration(newLockPeriod);

        (, uint256 lockEpochs,,) = lockRewardsContract.getAccount(user);

        assertEq(lockEpochs, LOCK_PERIOD);
    }

    function testSetLockDurationIntegration() public {
        uint256 blockTime = block.timestamp;
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        _transferRewards(3 * reward1, 3 * reward2);
        uint256 deposit = 1e18;

        // Lock for next epoch
        _deposit(user, deposit);
        lockRewardsContract.setNextEpoch(values);
        // Change Lock duration to 3 epochs
        lockRewardsContract.setLockDuration(3);

        // Travel to end of 1st epoch
        vm.warp(blockTime + _day(8));

        uint256 balanceBefore = IERC20(LOCK_ADDRESS).balanceOf(user);

        // User should be albe to withdraw deposit (locked vefore lock duration change)
        vm.prank(user);
        lockRewardsContract.withdraw(deposit);

        uint256 balanceAfter = IERC20(LOCK_ADDRESS).balanceOf(user);

        assertEq(balanceAfter, balanceBefore + deposit);

        // Lock for updated (3) number of epochs;
        _deposit(user, deposit);
        lockRewardsContract.setNextEpoch(values);
        lockRewardsContract.setNextEpoch(values);

        // Travel to middle of 2nd epoch
        vm.warp(blockTime + _day(15));

        // User should not be able to withdraw deposit before updated number of epochs
        vm.prank(user);
        vm.expectRevert();
        lockRewardsContract.withdraw(deposit);

        lockRewardsContract.setNextEpoch(values);

        // Travel to end of 4th epoch
        vm.warp(blockTime + _day(100));

        // User should be able to withdraw
        vm.prank(user);
        lockRewardsContract.withdraw(deposit);
    }

    /* Set Reward Tests */
    function testSetRewardShouldBeCallableOnlyByOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user);
        lockRewardsContract.setReward(REWARD3_ADDRESS);
    }

    function testSetRewardShouldRevertWhenAlreadyInRewards() public {
        vm.expectRevert(abi.encodeWithSelector(ILockRewards.RewardTokenAlreadyExists.selector, REWARD2_ADDRESS));
        lockRewardsContract.setReward(REWARD2_ADDRESS);
    }

    function testSetRewardShouldRevertWhenTryingToSetLockToken() public {
        vm.expectRevert(abi.encodeWithSelector(ILockRewards.RewardTokenCannotBeLockToken.selector, LOCK_ADDRESS));
        lockRewardsContract.setReward(LOCK_ADDRESS);
    }

    function testSetRewardShouldAddRewardToken() public {
        address[] memory initialTokens = lockRewardsContract.getRewardTokens();

        assertEq(initialTokens.length, 2);
        assertEq(initialTokens[0], REWARD1_ADDRESS);
        assertEq(initialTokens[1], REWARD2_ADDRESS);

        lockRewardsContract.setReward(REWARD3_ADDRESS);
        address[] memory tokens = lockRewardsContract.getRewardTokens();

        assertEq(tokens.length, 3);
        assertEq(tokens[0], REWARD1_ADDRESS);
        assertEq(tokens[1], REWARD2_ADDRESS);
        assertEq(tokens[2], REWARD3_ADDRESS);
    }

    function testSetRewardShouldNotChangePastDeposits() public {
        uint256 blockTime = block.timestamp;
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        _transferRewards(3 * reward1, 3 * reward2);
        uint256 deposit = 1e18;

        // Lock for next epoch
        _deposit(user, deposit);
        lockRewardsContract.setNextEpoch(values);

        // Update Rewards
        lockRewardsContract.setReward(REWARD3_ADDRESS);

        vm.warp(blockTime + _day(8));

        uint256 reward1Balance = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2Balance = IERC20(REWARD2_ADDRESS).balanceOf(user);
        uint256 reward3Balance = IERC20(REWARD3_ADDRESS).balanceOf(user);

        vm.prank(user);
        lockRewardsContract.claimReward();

        uint256 reward1ClaimedBalance = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2ClaimedBalance = IERC20(REWARD2_ADDRESS).balanceOf(user);
        uint256 reward3ClaimedBalance = IERC20(REWARD3_ADDRESS).balanceOf(user);

        // User should not receive any rewards for new token
        assertEq(reward1ClaimedBalance - reward1, reward1Balance);
        assertEq(reward2ClaimedBalance - reward2, reward2Balance);
        assertEq(reward3ClaimedBalance, reward3Balance);
    }

    function testSetRewardIntegration() public {
        uint256 blockTime = block.timestamp;
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256 reward3 = 10e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        _transferRewards(3 * reward1, 3 * reward2, 3 * reward3);
        uint256 deposit = 1e18;

        // Lock for next epoch
        _deposit(user, deposit);
        lockRewardsContract.setNextEpoch(values);

        // Update Rewards
        lockRewardsContract.setReward(REWARD3_ADDRESS);

        vm.warp(blockTime + _day(8));

        // Lock for next epoch with updated rewards
        _deposit(user, deposit);
        uint256[] memory updatedValues = new uint256[](3);
        updatedValues[0] = reward1;
        updatedValues[1] = reward2;
        updatedValues[2] = reward3;
        lockRewardsContract.setNextEpoch(updatedValues);

        // Travel to end of 2nd epoch
        vm.warp(blockTime + _day(15));

        uint256 reward1Balance = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2Balance = IERC20(REWARD2_ADDRESS).balanceOf(user);
        uint256 reward3Balance = IERC20(REWARD3_ADDRESS).balanceOf(user);

        vm.prank(user);
        lockRewardsContract.claimReward();

        uint256 reward1ClaimedBalance = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2ClaimedBalance = IERC20(REWARD2_ADDRESS).balanceOf(user);
        uint256 reward3ClaimedBalance = IERC20(REWARD3_ADDRESS).balanceOf(user);

        // User should receive reward1 and reward2 for 1st epoch and reward1, reward2 and reward3 for 2nd epoch
        assertEq(reward1ClaimedBalance, reward1Balance + 2 * reward1);
        assertEq(reward2ClaimedBalance, reward2Balance + 2 * reward2);
        assertEq(reward3ClaimedBalance, reward3Balance + reward3);
    }

    /* Remove Reward Tests */
    function testRemoveRewardShouldBeCallableOnlyByOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user);
        lockRewardsContract.removeReward(REWARD2_ADDRESS);
    }

    function testRemoveRewardShouldRevertWhenTokenIsNotRewardToken() public {
        vm.expectRevert(abi.encodeWithSelector(ILockRewards.RewardTokenDoesNotExist.selector, REWARD3_ADDRESS));
        lockRewardsContract.removeReward(REWARD3_ADDRESS);
    }

    function testRemoveRewardShouldRemoveRewardToken() public {
        address[] memory initialTokens = lockRewardsContract.getRewardTokens();

        assertEq(initialTokens.length, 2);
        assertEq(initialTokens[0], REWARD1_ADDRESS);
        assertEq(initialTokens[1], REWARD2_ADDRESS);

        lockRewardsContract.removeReward(REWARD2_ADDRESS);
        address[] memory tokens = lockRewardsContract.getRewardTokens();

        assertEq(tokens.length, 1);
        assertEq(tokens[0], REWARD1_ADDRESS);
    }

    function testRemoveRewardShouldNotChangePastDeposits() public {
        uint256 blockTime = block.timestamp;
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        _transferRewards(3 * reward1, 3 * reward2);
        uint256 deposit = 1e18;

        // Lock for next epoch
        _deposit(user, deposit);
        lockRewardsContract.setNextEpoch(values);

        // Update Rewards
        lockRewardsContract.removeReward(REWARD1_ADDRESS);

        vm.warp(blockTime + _day(8));

        uint256 reward1Balance = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2Balance = IERC20(REWARD2_ADDRESS).balanceOf(user);

        vm.prank(user);
        lockRewardsContract.claimReward();

        uint256 reward1ClaimedBalance = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2ClaimedBalance = IERC20(REWARD2_ADDRESS).balanceOf(user);

        // User should still claim rewards for removed token
        assertEq(reward1ClaimedBalance - reward1, reward1Balance);
        assertEq(reward2ClaimedBalance - reward2, reward2Balance);
    }

    function testRemoveRewardIntegration() public {
        uint256 blockTime = block.timestamp;
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        _transferRewards(3 * reward1, 3 * reward2);
        uint256 deposit = 1e18;

        // Lock for next epoch
        _deposit(user, deposit);
        lockRewardsContract.setNextEpoch(values);

        // Update Rewards
        lockRewardsContract.removeReward(REWARD1_ADDRESS);

        vm.warp(blockTime + _day(8));

        // Lock for next epoch with updated rewards
        _deposit(user, deposit);
        uint256[] memory updatedValues = new uint256[](1);
        updatedValues[0] = reward2;
        lockRewardsContract.setNextEpoch(updatedValues);

        // Travel to end of 2nd epoch
        vm.warp(blockTime + _day(15));

        uint256 reward1Balance = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2Balance = IERC20(REWARD2_ADDRESS).balanceOf(user);

        vm.prank(user);
        lockRewardsContract.claimReward();

        uint256 reward1ClaimedBalance = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2ClaimedBalance = IERC20(REWARD2_ADDRESS).balanceOf(user);

        // User should receive reward1 and reward2 for 1st epoch and only reward2 for 2nd epoch
        assertEq(reward1ClaimedBalance, reward1Balance + reward1);
        assertEq(reward2ClaimedBalance, reward2Balance + 2 * reward2);
    }

    /* SetNextEpoch Tests */
    function testSetNextEpochCanBeCalledOnlyByEpochSetterRoleOwner() public {
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;

        vm.expectRevert(
            bytes(
                string.concat(
                    "AccessControl: account ",
                    Strings.toHexString(user),
                    " is missing role ",
                    Strings.toHexString(uint256(lockRewardsContract.EPOCH_SETTER_ROLE()), 32)
                )
            )
        );
        vm.prank(user);
        lockRewardsContract.setNextEpoch(values);
    }

    function testSetNextEpochPassingIncorrectNumberOfRewardsShouldRevert() public {
        // Add 3rd reward
        lockRewardsContract.setReward(REWARD3_ADDRESS);

        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;

        // Should revert because rewards provided only for 2 tokens
        vm.expectRevert(abi.encodeWithSelector(ILockRewards.IncorrectRewards.selector, values.length, 3));
        lockRewardsContract.setNextEpoch(values);
    }

    function testSetNextEpochRevertsWhenInsufficientFunds() public {
        vm.expectRevert();

        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        _transferRewards(reward1 - 1, reward2);

        vm.expectRevert(
            abi.encodeWithSelector(
                ILockRewards.InsufficientFundsForRewards.selector, REWARD1_ADDRESS, reward1 - 1, reward1
            )
        );
        lockRewardsContract.setNextEpoch(values);
    }

    function testSetNextEpochShouldSetTheFirstEpochWhenCalledFirstTime() public {
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        _transferRewards(reward1, reward2);

        lockRewardsContract.setNextEpoch(values);

        (uint256 start, uint256 finish,, uint256[] memory rewards,) = lockRewardsContract.getEpoch(1);

        assertEq(finish - start, 7 * 86400);
        assertEq(rewards[0], reward1);
        assertEq(rewards[1], reward2);
    }

    function testSetNextEpochShouldSetNextEpochWhenFirstIsSet() public {
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        _transferRewards(2 * reward1, 2 * reward2);

        lockRewardsContract.setNextEpoch(values);
        lockRewardsContract.setNextEpoch(values);

        (, uint256 epochOneFinish,,,) = lockRewardsContract.getEpoch(1);
        (uint256 start,,, uint256[] memory rewards,) = lockRewardsContract.getEpoch(2);

        assertEq(epochOneFinish + 1, start);
        assertEq(rewards[0], reward1);
        assertEq(rewards[1], reward2);
    }

    function testSetNextEpochShouldRevertWhenMoreThan2EpochsAreSet() public {
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        _transferRewards(3 * reward1, 3 * reward2);

        lockRewardsContract.setNextEpoch(values);
        lockRewardsContract.setNextEpoch(values);
        vm.expectRevert(abi.encodeWithSelector(ILockRewards.EpochMaxReached.selector, 2));
        lockRewardsContract.setNextEpoch(values);
    }

    function testLockingShouldTransferFundsFromCaller() public {
        uint256 balance = IERC20(LOCK_ADDRESS).balanceOf(user);
        uint256 deposit = 1e18;

        _deposit(user, deposit);
        uint256 balanceAfterDeposit = IERC20(LOCK_ADDRESS).balanceOf(user);

        assertEq(balance - deposit, balanceAfterDeposit);
    }

    function testLockingShouldUpdateAccountBalanceInfo() public {
        uint256 deposit = 1e18;

        vm.prank(user);
        uint256 balanceLocked = lockRewardsContract.getEpochBalanceLocked(1);
        uint256 balance = IERC20(LOCK_ADDRESS).balanceOf(user);
        uint256 contractBalance = lockRewardsContract.totalAssets();
        (uint256 lockBalance, uint256 lock,,) = lockRewardsContract.getAccount(user);
        _deposit(user, deposit);

        vm.prank(user);
        uint256 balanceLockedAfter = lockRewardsContract.getEpochBalanceLocked(1);
        uint256 balanceAfter = IERC20(LOCK_ADDRESS).balanceOf(user);
        uint256 contractBalanceAfter = lockRewardsContract.totalAssets();
        (uint256 lockBalanceAfterDeposit, uint256 afterLock,,) = lockRewardsContract.getAccount(user);

        uint256 reward1Balance = IERC20(REWARD1_ADDRESS).balanceOf(user);

        assertEq(balanceLockedAfter, balanceLocked + deposit);
        assertEq(balanceAfter, balance - deposit);
        assertEq(lockBalanceAfterDeposit, lockBalance + deposit);
        assertEq(contractBalanceAfter, contractBalance + deposit);
        assertEq(afterLock, lock + LOCK_PERIOD);
    }

    function testRelockingShouldUpdateEpochsInfoAndTotalAssetsButNotLockEpochs() public {
        uint256 deposit = 1e18;
        lockRewardsContract.setLockDuration(2);

        _deposit(user, deposit);
        _deposit(user, deposit);

        uint256 totalAssets = lockRewardsContract.totalAssets();

        assertEq(totalAssets, deposit * 2);

        (,, uint256 epochOnelocked,,) = lockRewardsContract.getEpoch(1);
        (,, uint256 epochTwolocked,,) = lockRewardsContract.getEpoch(2);
        (,, uint256 epochThreelocked,,) = lockRewardsContract.getEpoch(3);
        (,, uint256 epochFourlocked,,) = lockRewardsContract.getEpoch(4);
        (,, uint256 epochFiveLocked,,) = lockRewardsContract.getEpoch(5);

        assertEq(epochOnelocked, deposit * 2);
        assertEq(epochTwolocked, deposit * 2);
        assertEq(epochThreelocked, deposit * 2);
        assertEq(epochFourlocked, deposit * 2);
        assertEq(epochFiveLocked, 0);

        (uint256 balance, uint256 lockEpochs, uint256 lastEpochPaid,) = lockRewardsContract.getAccount(user);

        assertEq(balance, 2 * deposit);
        assertEq(lockEpochs, 4);
        assertEq(lastEpochPaid, 1);
    }

    /* Integrated Relocking Tests */
    function testUserLocksBeforeFirstEpochShouldBeAbleToClaimAfterSecondEpochStart() public {
        uint256 blockTime = block.timestamp;
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        _transferRewards(3 * reward1, 3 * reward2);
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        uint256 deposit = 1e18;

        // Lock for next epoch
        _deposit(user, deposit);

        lockRewardsContract.setNextEpoch(values);

        // Move 1 day
        vm.warp(blockTime + _day(1));

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(ILockRewards.FundsInLockPeriod.selector, deposit));
        lockRewardsContract.withdraw(deposit);

        vm.warp(blockTime + _day(9));

        uint256 reward1Balance = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2Balance = IERC20(REWARD2_ADDRESS).balanceOf(user);

        vm.prank(user);
        lockRewardsContract.claimReward();

        uint256 reward1ClaimedBalance = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2ClaimedBalance = IERC20(REWARD2_ADDRESS).balanceOf(user);

        assertEq(reward1ClaimedBalance - reward1, reward1Balance);
        assertEq(reward2ClaimedBalance - reward2, reward2Balance);

        uint256 balance = IERC20(LOCK_ADDRESS).balanceOf(user);

        vm.prank(user);
        lockRewardsContract.withdraw(deposit);

        uint256 balanceAfter = IERC20(LOCK_ADDRESS).balanceOf(user);

        assertEq(balance, balanceAfter - deposit);
    }

    function testUserShouldBeAbleToRelockMoreTokensForSameAmountEpochs() public {
        uint256 blockTime = block.timestamp;
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        _transferRewards(3 * reward1, 3 * reward2);
        uint256 deposit = 1e18;

        // Lock for next epoch
        _deposit(user, deposit);

        (uint256 balanceAfterDeposit, uint256 lockEpochsAfterDeposit,,) = lockRewardsContract.getAccount(user);
        _redeposit(user, deposit);

        lockRewardsContract.setNextEpoch(values);

        (uint256 balanceAfterRedeposit, uint256 lockEpochsAfterRedeposit,,) = lockRewardsContract.getAccount(user);

        assertEq(balanceAfterRedeposit, balanceAfterDeposit + deposit);
        assertEq(lockEpochsAfterDeposit, lockEpochsAfterRedeposit);

        vm.warp(blockTime + _day(9));

        uint256 balanceBefore = IERC20(LOCK_ADDRESS).balanceOf(user);

        vm.prank(user);
        lockRewardsContract.withdraw(deposit * 2);

        uint256 balanceAfter = IERC20(LOCK_ADDRESS).balanceOf(user);

        assertEq(balanceAfter, balanceBefore + deposit * 2);
    }

    function testUserLocksForOneEpochAndRelockForAnotherEpochShouldClaimAfterFirstEpochButWithdrawAfterSecond()
        public
    {
        uint256 blockTime = block.timestamp;
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        _transferRewards(3 * reward1, 3 * reward2);
        uint256 deposit = 1e18;

        // Lock for next epoch
        _deposit(user, deposit);

        //Set 1st and 2nd Epoch
        lockRewardsContract.setNextEpoch(values);
        lockRewardsContract.setNextEpoch(values);
        // Relock in the middle of first epoch for one more epoch
        _deposit(user, deposit);

        // time travel to the middle of second epoch
        vm.warp(blockTime + _day(9));

        // Withdraw should revert
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(ILockRewards.FundsInLockPeriod.selector, 2 * deposit));
        lockRewardsContract.withdraw(deposit);

        // user should be able to claim first epoch rewards
        uint256 reward1Balance1 = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2Balance1 = IERC20(REWARD2_ADDRESS).balanceOf(user);

        vm.prank(user);
        lockRewardsContract.claimReward();

        assertEq(IERC20(REWARD1_ADDRESS).balanceOf(user) - reward1, reward1Balance1);
        assertEq(IERC20(REWARD2_ADDRESS).balanceOf(user) - reward2, reward2Balance1);

        // time travel to the middle of third epoch
        vm.warp(blockTime + _day(18));

        // user withdraw in the middle of third epoch
        uint256 balanceBefore = IERC20(LOCK_ADDRESS).balanceOf(user);

        vm.prank(user);
        lockRewardsContract.withdraw(deposit * 2);

        uint256 balanceAfter = IERC20(LOCK_ADDRESS).balanceOf(user);

        assertEq(balanceAfter, balanceBefore + deposit * 2);

        // user should be able to claim first epoch rewards
        uint256 reward1Balance2 = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2Balance2 = IERC20(REWARD2_ADDRESS).balanceOf(user);

        vm.prank(user);
        lockRewardsContract.claimReward();

        assertEq(IERC20(REWARD1_ADDRESS).balanceOf(user) - reward1, reward1Balance2);
        assertEq(IERC20(REWARD2_ADDRESS).balanceOf(user) - reward2, reward2Balance2);
    }

    /* Rewards Distribution Test */
    function testUserShouldNotEarnAnyRewardsUntilEndOfEpoch() public {
        uint256 blockTime = block.timestamp;
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        _transferRewards(3 * reward1, 3 * reward2);
        uint256 deposit = 1e18;

        // Lock for next epoch
        _deposit(user, deposit);
        lockRewardsContract.setNextEpoch(values);

        vm.warp(blockTime + _day(2));

        // user should earn 0 rewards
        uint256 reward1Balance = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2Balance = IERC20(REWARD2_ADDRESS).balanceOf(user);

        vm.prank(user);
        lockRewardsContract.claimReward();

        uint256 reward1ClaimedBalance = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2ClaimedBalance = IERC20(REWARD2_ADDRESS).balanceOf(user);

        assertEq(reward1ClaimedBalance, reward1Balance);
        assertEq(reward2ClaimedBalance, reward2Balance);
    }

    function testUserShouldEarnRightAmountOfRewardsIfEpochIsOver() public {
        uint256 blockTime = block.timestamp;
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        _transferRewards(3 * reward1, 3 * reward2);
        uint256 deposit = 1e18;

        // Lock for next epoch
        _deposit(user, deposit);
        lockRewardsContract.setNextEpoch(values);

        vm.warp(blockTime + _day(9));

        // user should earn all rewards (only user locked in)
        uint256 reward1Balance = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2Balance = IERC20(REWARD2_ADDRESS).balanceOf(user);

        vm.prank(user);
        lockRewardsContract.claimReward();

        uint256 reward1ClaimedBalance = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2ClaimedBalance = IERC20(REWARD2_ADDRESS).balanceOf(user);

        assertEq(reward1ClaimedBalance, reward1Balance + reward1);
        assertEq(reward2ClaimedBalance, reward2Balance + reward2);
    }

    function testUserLockInMiddleOfEpochHeWillBeAbleToCollectRewardsAfterNextEpochEnds() public {
        uint256 blockTime = block.timestamp;
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        _transferRewards(3 * reward1, 3 * reward2);
        uint256 deposit = 1e18;

        // Set second epoch. It will start automatically.
        lockRewardsContract.setNextEpoch(values);

        // Set third epoch. It will start in the end of second epoch
        lockRewardsContract.setNextEpoch(values);

        vm.warp(blockTime + _day(2));

        // lock for one epoch in the middle of second epoch
        _deposit(user, deposit);

        // time travel to the middle of third epoch
        vm.warp(blockTime + _day(10));

        // user should earn 0 rewards
        uint256 reward1Balance = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2Balance = IERC20(REWARD2_ADDRESS).balanceOf(user);

        vm.prank(user);
        lockRewardsContract.claimReward();

        uint256 reward1ClaimedBalance = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2ClaimedBalance = IERC20(REWARD2_ADDRESS).balanceOf(user);

        assertEq(reward1ClaimedBalance, reward1Balance);
        assertEq(reward2ClaimedBalance, reward2Balance);

        // time travel to the end of third epoch (user should be able to claim rewards now)
        vm.warp(blockTime + _day(100));

        // user should earn rewards
        uint256 reward1Balance2 = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2Balance2 = IERC20(REWARD2_ADDRESS).balanceOf(user);

        vm.prank(user);
        lockRewardsContract.claimReward();

        uint256 reward1ClaimedBalance2 = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2ClaimedBalance2 = IERC20(REWARD2_ADDRESS).balanceOf(user);

        assertEq(reward1ClaimedBalance2, reward1Balance2 + reward1);
        assertEq(reward2ClaimedBalance2, reward2Balance2 + reward2);
    }

    function testUserShouldBeAbleToClaimRewardsFromAllPastEpochs() public {
        uint256 blockTime = block.timestamp;
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        _transferRewards(3 * reward1, 3 * reward2);
        uint256 deposit = 1e18;

        // Lock for next 3 epochs
        lockRewardsContract.setLockDuration(3);
        _deposit(user, deposit);

        // Set epochs
        lockRewardsContract.setNextEpoch(values);
        lockRewardsContract.setNextEpoch(values);

        vm.warp(blockTime + _day(8));
        lockRewardsContract.setNextEpoch(values);

        // time travel to the end of third epoch (user should be able to claim rewards now)
        vm.warp(blockTime + _day(100));
        // user should earn rewards
        uint256 reward1Balance = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2Balance = IERC20(REWARD2_ADDRESS).balanceOf(user);

        vm.prank(user);
        lockRewardsContract.claimReward();

        uint256 reward1ClaimedBalance = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2ClaimedBalance = IERC20(REWARD2_ADDRESS).balanceOf(user);

        assertEq(reward1ClaimedBalance, reward1Balance + reward1 * 3);
        assertEq(reward2ClaimedBalance, reward2Balance + reward2 * 3);

        (,,, uint256[] memory rewards) = lockRewardsContract.getAccount(user);
        assertEq(rewards[0], 0);
        assertEq(rewards[1], 0);
    }

    function testUserShouldEarnRewardsBasedOnTheAmountOfLockedTokens() public {
        uint256 blockTime = block.timestamp;
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        _transferRewards(3 * reward1, 3 * reward2);
        uint256 deposit = 1e18;

        _deposit(user2, deposit);
        _deposit(user, deposit * 2);

        lockRewardsContract.setNextEpoch(values);

        vm.warp(blockTime + _day(8));

        // user1
        uint256 userReward1Balance = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 userReward2Balance = IERC20(REWARD2_ADDRESS).balanceOf(user);

        vm.prank(user);
        lockRewardsContract.claimReward();

        uint256 userReward1ClaimedBalance = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 userReward2ClaimedBalance = IERC20(REWARD2_ADDRESS).balanceOf(user);
        uint256 userReward1Claimed = userReward1ClaimedBalance - userReward1Balance;
        uint256 userReward2Claimed = userReward2ClaimedBalance - userReward2Balance;

        // user2
        uint256 user2Reward1Balance = IERC20(REWARD1_ADDRESS).balanceOf(user2);
        uint256 user2Reward2Balance = IERC20(REWARD2_ADDRESS).balanceOf(user2);

        vm.prank(user2);
        lockRewardsContract.claimReward();

        uint256 user2Reward1ClaimedBalance = IERC20(REWARD1_ADDRESS).balanceOf(user2);
        uint256 user2Reward2ClaimedBalance = IERC20(REWARD2_ADDRESS).balanceOf(user2);
        uint256 user2Reward1Claimed = user2Reward1ClaimedBalance - user2Reward1Balance;
        uint256 user2Reward2Claimed = user2Reward2ClaimedBalance - user2Reward2Balance;

        assertEq(userReward1Claimed, user2Reward1Claimed * 2);
        assertEq(userReward2Claimed, user2Reward2Claimed * 2);
    }

    /* Withdraw Test */
    function testUserShouldNotBeAbleToWithdrawMoreThanHisBalance() public {
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        _transferRewards(3 * reward1, 3 * reward2);
        uint256 deposit = 1e18;

        _deposit(user, deposit);
        lockRewardsContract.setNextEpoch(values);

        vm.expectRevert(abi.encodeWithSelector(ILockRewards.InsufficientAmount.selector));
        vm.prank(user);
        lockRewardsContract.withdraw(deposit * 2);
    }

    function testUserShouldNotBeAbleToWithdrawDuringLockingPeriod() public {
        uint256 blockTime = block.timestamp;
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        _transferRewards(3 * reward1, 3 * reward2);
        uint256 deposit = 1e18;

        _deposit(user, deposit);
        lockRewardsContract.setNextEpoch(values);

        vm.warp(blockTime + _day(2));

        vm.expectRevert(abi.encodeWithSelector(ILockRewards.FundsInLockPeriod.selector, deposit));
        vm.prank(user);
        lockRewardsContract.withdraw(deposit);
    }

    function testUserShouldBeAbleToWithdrawAfterLockingPeriod() public {
        uint256 blockTime = block.timestamp;
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        _transferRewards(3 * reward1, 3 * reward2);
        uint256 deposit = 1e18;

        _deposit(user, deposit);
        lockRewardsContract.setNextEpoch(values);

        vm.warp(blockTime + _day(11));

        uint256 balanceBefore = IERC20(LOCK_ADDRESS).balanceOf(user);

        vm.prank(user);
        lockRewardsContract.withdraw(deposit);

        uint256 balanceAfter = IERC20(LOCK_ADDRESS).balanceOf(user);

        assertEq(balanceAfter, balanceBefore + deposit);
    }

    function testWithdrawShouldUpdateTotalAssetsAndUserAccountInfo() public {
        uint256 blockTime = block.timestamp;
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        _transferRewards(3 * reward1, 3 * reward2);
        uint256 deposit = 1e18;

        _deposit(user, deposit);
        lockRewardsContract.setNextEpoch(values);

        uint256 totalAssets = lockRewardsContract.totalAssets();
        assertEq(totalAssets, deposit);
        (uint256 balance,,, uint256[] memory rewards) = lockRewardsContract.getAccount(user);
        assertEq(balance, deposit);
        assertEq(rewards[0], 0);
        assertEq(rewards[0], 0);

        vm.warp(blockTime + _day(11));

        vm.prank(user);
        lockRewardsContract.withdraw(deposit);

        uint256 totalAssetsAfter = lockRewardsContract.totalAssets();
        assertEq(totalAssetsAfter, 0);

        (uint256 balanceAfter,,, uint256[] memory rewardsAfter) = lockRewardsContract.getAccount(user);
        assertEq(balanceAfter, 0);
        assertEq(rewardsAfter[0], reward1);
        assertEq(rewardsAfter[1], reward2);
    }

    /* Claim Reward Tests */

    function testClaimRewardShouldNotBeAbleToClaimEmptyRewards() public {
        uint256 blockTime = block.timestamp;
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        _transferRewards(3 * reward1, 3 * reward2);
        uint256 deposit = 1e18;

        // Lock for next 3 epochs
        lockRewardsContract.setLockDuration(3);

        // Set epochs
        lockRewardsContract.setNextEpoch(values);
        lockRewardsContract.setNextEpoch(values);

        vm.warp(blockTime + _day(8));
        lockRewardsContract.setNextEpoch(values);

        // time travel to the end of third epoch (user should be able to claim rewards now)
        vm.warp(blockTime + _day(100));
        // user should earn rewards
        uint256 reward1Balance = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2Balance = IERC20(REWARD2_ADDRESS).balanceOf(user);

        vm.prank(user);
        lockRewardsContract.claimReward();

        uint256 reward1ClaimedBalance = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2ClaimedBalance = IERC20(REWARD2_ADDRESS).balanceOf(user);

        assertEq(reward1ClaimedBalance, reward1Balance);
        assertEq(reward2ClaimedBalance, reward2Balance);
    }

    function testClaimRewardsShouldNotClaimRewardsTwice() public {
        uint256 blockTime = block.timestamp;
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        _transferRewards(3 * reward1, 3 * reward2);
        uint256 deposit = 1e18;

        // Lock for next 3 epochs
        lockRewardsContract.setLockDuration(3);
        _deposit(user, deposit);

        // Set epochs
        lockRewardsContract.setNextEpoch(values);
        lockRewardsContract.setNextEpoch(values);

        vm.warp(blockTime + _day(8));
        lockRewardsContract.setNextEpoch(values);

        // time travel to the end of third epoch (user should be able to claim rewards now)
        vm.warp(blockTime + _day(100));
        // user should earn rewards
        uint256 reward1Balance = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2Balance = IERC20(REWARD2_ADDRESS).balanceOf(user);

        vm.prank(user);
        lockRewardsContract.claimReward();

        uint256 reward1ClaimedBalance = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2ClaimedBalance = IERC20(REWARD2_ADDRESS).balanceOf(user);

        assertEq(reward1ClaimedBalance, reward1Balance + reward1 * 3);
        assertEq(reward2ClaimedBalance, reward2Balance + reward2 * 3);

        vm.warp(blockTime + _day(1));
        vm.prank(user);
        lockRewardsContract.claimReward();

        uint256 reward1ClaimedAgainBalance = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2ClaimedAgainBalance = IERC20(REWARD2_ADDRESS).balanceOf(user);

        assertEq(reward1ClaimedBalance, reward1ClaimedAgainBalance);
        assertEq(reward2ClaimedBalance, reward2ClaimedAgainBalance);
    }

    function testClaimRewardShouldClaimOnlySingleReward() public {
        uint256 blockTime = block.timestamp;
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        _transferRewards(3 * reward1, 3 * reward2);
        uint256 deposit = 1e18;

        // Lock for next 3 epochs
        lockRewardsContract.setLockDuration(3);
        _deposit(user, deposit);

        // Set epochs
        lockRewardsContract.setNextEpoch(values);
        lockRewardsContract.setNextEpoch(values);

        vm.warp(blockTime + _day(8));
        lockRewardsContract.setNextEpoch(values);

        // time travel to the end of third epoch (user should be able to claim rewards now)
        vm.warp(blockTime + _day(100));
        // user should earn rewards
        uint256 reward1Balance = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2Balance = IERC20(REWARD2_ADDRESS).balanceOf(user);

        vm.prank(user);
        lockRewardsContract.claimReward(REWARD1_ADDRESS);

        uint256 reward1ClaimedBalance = IERC20(REWARD1_ADDRESS).balanceOf(user);
        uint256 reward2ClaimedBalance = IERC20(REWARD2_ADDRESS).balanceOf(user);

        assertEq(reward1ClaimedBalance, reward1Balance + reward1 * 3);
        assertEq(reward2ClaimedBalance, reward2Balance);
    }

    /* Exit Test */
    function testExitShouldWithdrawAndClaimEverything() public {
        uint256 blockTime = block.timestamp;
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        _transferRewards(3 * reward1, 3 * reward2);
        uint256 deposit = 1e18;

        _deposit(user, deposit);
        lockRewardsContract.setNextEpoch(values);

        vm.warp(blockTime + _day(11));

        uint256 balance = IERC20(LOCK_ADDRESS).balanceOf(user);

        vm.prank(user);
        lockRewardsContract.exit();

        uint256 exitBalance = IERC20(LOCK_ADDRESS).balanceOf(user);
        uint256 exitReward2Balance = IERC20(REWARD2_ADDRESS).balanceOf(user);

        // REWARD1 is also deposit
        assertEq(exitBalance, balance + deposit + reward1);
        assertEq(exitReward2Balance, reward2);
    }

    /* Emergency Exit Test */
    function testUserShouldBeAbleToWithdrawDuringLockingPeriodWhenLockedTooLong() public {
        uint256 blockTime = block.timestamp;
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        _transferRewards(3 * reward1, 3 * reward2);
        uint256 deposit = 1e18;
        lockRewardsContract.setLockDuration(7);

        _deposit(user, deposit);

        lockRewardsContract.setNextEpoch(values);

        vm.warp(blockTime + _day(7));

        vm.expectRevert(abi.encodeWithSelector(ILockRewards.FundsInLockPeriod.selector, deposit));
        vm.prank(user);
        lockRewardsContract.emergencyExit();

        // Move to more than twice as long as should locking period be
        vm.warp(blockTime + _day(2 * 7 * EPOCH_DURATION + 1));

        uint256 contractBalance = lockRewardsContract.totalLocked();
        uint256 balance = IERC20(LOCK_ADDRESS).balanceOf(user);

        vm.prank(user);
        lockRewardsContract.emergencyExit();

        vm.prank(user);
        uint256 exitBalanceLocked = lockRewardsContract.getEpochBalanceLocked(2);
        uint256 exitContractBalance = lockRewardsContract.totalLocked();
        uint256 exitBalance = IERC20(LOCK_ADDRESS).balanceOf(user);
        uint256 exitReward2Balance = IERC20(REWARD2_ADDRESS).balanceOf(user);

        // User should get rewards for previous epochs
        // Note: REWARD1 is also deposit
        assertEq(exitBalance, balance + deposit + reward1);
        assertEq(exitReward2Balance, reward2);
        assertEq(exitContractBalance, contractBalance - deposit);

        uint256 currentEpoch = lockRewardsContract.currentEpoch();
        (uint256 exitLockedBalance, uint256 exitLockEpochs, uint256 exitLastEpochPaid, uint256[] memory exitRewards) =
            lockRewardsContract.getAccount(user);

        // User should not get rewards for upcoming epochs
        assertEq(exitBalanceLocked, 0);
        assertEq(exitLockedBalance, 0);
        assertEq(exitLockEpochs, 0);
        assertEq(exitLastEpochPaid, currentEpoch);
        assertEq(exitRewards[0], 0);
        assertEq(exitRewards[1], 0);
    }

    /* Integrated Tests */
    function testLockAndRelockInTheMiddleOfEpoch() public {
        uint256 blockTime = block.timestamp;
        uint256 reward1 = 1000e18;
        uint256 reward2 = 1e18;
        uint256[] memory values = new uint256[](2);
        values[0] = reward1;
        values[1] = reward2;
        _transferRewards(3 * reward1, 3 * reward2);
        uint256 deposit = 1e18;

        _deposit(user, deposit);
        lockRewardsContract.setNextEpoch(values);

        // Move to middle of epoch
        vm.warp(blockTime + _day(2));

        vm.expectRevert(abi.encodeWithSelector(ILockRewards.FundsInLockPeriod.selector, deposit));
        vm.prank(user);
        lockRewardsContract.withdraw(deposit);

        // Relock in the middle of epoch
        _deposit(user, deposit);
        vm.expectRevert(abi.encodeWithSelector(ILockRewards.FundsInLockPeriod.selector, 2 * deposit));
        vm.prank(user);
        lockRewardsContract.withdraw(deposit);

        // Set 2nd epoch
        lockRewardsContract.setNextEpoch(values);

        // Move to middle of 2nd epoch
        vm.warp(blockTime + _day(8));

        // User should not be able to withdraw because of relock
        vm.expectRevert(abi.encodeWithSelector(ILockRewards.FundsInLockPeriod.selector, 2 * deposit));
        vm.prank(user);
        lockRewardsContract.withdraw(deposit);

        // Move to 3rd epoch
        vm.warp(blockTime + _day(15));

        // User should be able to withdraw
        uint256 balance = IERC20(LOCK_ADDRESS).balanceOf(user);
        vm.prank(user);
        lockRewardsContract.withdraw(deposit * 2);

        uint256 balanceAfter = IERC20(LOCK_ADDRESS).balanceOf(user);
        assertEq(balanceAfter, balance + deposit * 2);
    }

    /* Pause Tests */
    function testPauseShouldBeOnlyCallableByOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user);
        lockRewardsContract.pause();
    }

    function testUnpauseShouldBeOnlyCallableByOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user);
        lockRewardsContract.unpause();
    }

    function testUnpauseShouldRevertWhenItIsNotPaused() public {
        vm.expectRevert("Pausable: not paused");
        lockRewardsContract.unpause();
    }

    function testUnpauseShouldUnpause() public {
        lockRewardsContract.pause();

        bool paused = lockRewardsContract.paused();
        assertEq(paused, true);

        lockRewardsContract.unpause();

        paused = lockRewardsContract.paused();

        assertEq(paused, false);
    }

    function testPauseShouldSetContractToPauseMode() public {
        uint256 deposit = 1e18;
        lockRewardsContract.pause();

        bool paused = lockRewardsContract.paused();
        assertEq(paused, true);

        vm.prank(user);
        IERC20(LOCK_ADDRESS).approve(lockRewards, deposit);
        vm.expectRevert("Pausable: paused");
        vm.prank(user);
        lockRewardsContract.deposit(deposit);
        vm.expectRevert("Pausable: paused");
        vm.prank(user);
        lockRewardsContract.withdraw(deposit);
        vm.expectRevert("Pausable: paused");
        vm.prank(user);
        lockRewardsContract.claimReward();
        vm.expectRevert("Pausable: paused");
        vm.prank(user);
        lockRewardsContract.exit();
    }

    /* Utils */
    function _day(uint256 amount) internal pure returns (uint256 valueInSeconds) {
        return DAY * amount;
    }

    function _deposit(address to, uint256 value) internal {
        vm.startPrank(to);
        IERC20(LOCK_ADDRESS).approve(lockRewards, value);
        lockRewardsContract.deposit(value);
        vm.stopPrank();
    }

    function _redeposit(address to, uint256 value) internal {
        vm.startPrank(to);
        IERC20(LOCK_ADDRESS).approve(lockRewards, value);
        lockRewardsContract.redeposit(value);
        vm.stopPrank();
    }

    function _transferRewards(uint256 reward1, uint256 reward2) internal {
        deal(REWARD1_ADDRESS, lockRewards, reward1);
        deal(REWARD2_ADDRESS, lockRewards, reward2);
    }

    function _transferRewards(uint256 reward1, uint256 reward2, uint256 reward3) internal {
        _transferRewards(reward1, reward2);
        deal(REWARD3_ADDRESS, lockRewards, reward3);
    }
}
