// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import {IERC20} from 'aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {DistributionTypes} from './lib/DistributionTypes.sol';
import {GovernancePowerDelegationERC20} from './lib/GovernancePowerDelegationERC20.sol';
import {StakedTokenV3} from './StakedTokenV3.sol';
import {IGhoVariableDebtTokenTransferHook} from './interfaces/IGhoVariableDebtTokenTransferHook.sol';
import {SafeCast} from 'solidity-utils/contracts/oz-common/SafeCast.sol';
import {IStakedAaveV3} from './interfaces/IStakedAaveV3.sol';
import {IERC20WithPermit} from 'aave-v3-core/contracts/interfaces/IERC20WithPermit.sol';

/**
 * @title StakedAaveV3
 * @notice StakedTokenV3 with AAVE token as staked token
 * @author BGD Labs
 */
contract StakedAaveV3 is StakedTokenV3, IStakedAaveV3 {
  using SafeCast for uint256;

  uint32 internal _exchangeRateSnapshotsCount;
  /// @notice Snapshots of the exchangeRate for a given block
  mapping(uint256 => ExchangeRateSnapshot) internal _exchangeRateSnapshots;

  /// @notice GHO debt token to be used in the _beforeTokenTransfer hook
  IGhoVariableDebtTokenTransferHook public ghoDebtToken;

  function REVISION() public pure virtual override returns (uint256) {
    return 5;
  }

  constructor(
    address stakedToken,
    address rewardToken,
    uint256 unstakeWindow,
    address rewardsVault,
    address emissionManager,
    uint128 distributionDuration
  )
    StakedTokenV3(
      IERC20(stakedToken),
      IERC20(rewardToken),
      unstakeWindow,
      rewardsVault,
      emissionManager,
      distributionDuration
    )
  {
    // brick initialize
    lastInitializedRevision = REVISION();
  }

  /**
   * @dev Called by the proxy contract
   */
  function initialize(
    address slashingAdmin,
    address cooldownPauseAdmin,
    address claimHelper,
    uint256 maxSlashablePercentage,
    uint256 cooldownSeconds
  ) external override initializer {
    _initialize(
      slashingAdmin,
      cooldownPauseAdmin,
      claimHelper,
      maxSlashablePercentage,
      cooldownSeconds
    );

    // needed to claimRewardsAndStake works without a custom approval each time
    STAKED_TOKEN.approve(address(this), type(uint256).max);
  }

  /// @inheritdoc IStakedAaveV3
  function setGHODebtToken(IGhoVariableDebtTokenTransferHook newGHODebtToken)
    external
  {
    require(msg.sender == 0xEE56e2B3D491590B5b31738cC34d5232F378a8D5); // Short executor
    ghoDebtToken = newGHODebtToken;
    emit GHODebtTokenChanged(address(newGHODebtToken));
  }

  /// @inheritdoc IStakedAaveV3
  function claimRewardsAndStake(address to, uint256 amount)
    external
    override
    returns (uint256)
  {
    return _claimRewardsAndStakeOnBehalf(msg.sender, to, amount);
  }

  /// @inheritdoc IStakedAaveV3
  function claimRewardsAndStakeOnBehalf(
    address from,
    address to,
    uint256 amount
  ) external override onlyClaimHelper returns (uint256) {
    return _claimRewardsAndStakeOnBehalf(from, to, amount);
  }

  /// @inheritdoc IStakedAaveV3
  function stakeWithPermit(
    address from,
    uint256 amount,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external override {
    IERC20WithPermit(address(STAKED_TOKEN)).permit(
      from,
      address(this),
      amount,
      deadline,
      v,
      r,
      s
    );
    _stake(from, from, amount);
  }

  /// @inheritdoc IStakedAaveV3
  function getExchangeRateSnapshotsCount() external view returns (uint32) {
    return _exchangeRateSnapshotsCount;
  }

  /// @inheritdoc IStakedAaveV3
  function getExchangeRateSnapshot(uint32 index)
    external
    view
    returns (ExchangeRateSnapshot memory)
  {
    return _exchangeRateSnapshots[index];
  }

  /**
   * @dev Writes a snapshot before any operation involving transfer of value: _transfer, _mint and _burn
   * - On _transfer, it writes snapshots for both "from" and "to"
   * - On _mint, only for _to
   * - On _burn, only for _from
   * @param from the from address
   * @param to the to address
   * @param amount the amount to transfer
   */
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override {
    IGhoVariableDebtTokenTransferHook cachedGhoDebtToken = ghoDebtToken;
    if (address(cachedGhoDebtToken) != address(0)) {
      try
        cachedGhoDebtToken.updateDiscountDistribution(
          from,
          to,
          balanceOf(from),
          balanceOf(to),
          amount
        )
      {} catch (bytes memory) {}
    }
    address votingFromDelegatee = _votingDelegates[from];
    address votingToDelegatee = _votingDelegates[to];

    if (votingFromDelegatee == address(0)) {
      votingFromDelegatee = from;
    }
    if (votingToDelegatee == address(0)) {
      votingToDelegatee = to;
    }

    _moveDelegatesByType(
      votingFromDelegatee,
      votingToDelegatee,
      amount,
      DelegationType.VOTING_POWER
    );

    address propPowerFromDelegatee = _propositionPowerDelegates[from];
    address propPowerToDelegatee = _propositionPowerDelegates[to];

    if (propPowerFromDelegatee == address(0)) {
      propPowerFromDelegatee = from;
    }
    if (propPowerToDelegatee == address(0)) {
      propPowerToDelegatee = to;
    }

    _moveDelegatesByType(
      propPowerFromDelegatee,
      propPowerToDelegatee,
      amount,
      DelegationType.PROPOSITION_POWER
    );
  }

  /// @dev Modified version accounting for exchange rate at block
  /// @inheritdoc GovernancePowerDelegationERC20
  function _searchByBlockNumber(
    mapping(address => mapping(uint256 => Snapshot)) storage snapshots,
    mapping(address => uint256) storage snapshotsCounts,
    address user,
    uint256 blockNumber
  ) internal view override returns (uint256) {
    return
      (super._searchByBlockNumber(
        snapshots,
        snapshotsCounts,
        user,
        blockNumber
      ) * EXCHANGE_RATE_UNIT) /
      _binarySearchExchangeRate(
        _exchangeRateSnapshots,
        _exchangeRateSnapshotsCount,
        blockNumber
      );
  }

  /**
   * @dev Updates the exchangeRate and emits events accordingly
   * @param newExchangeRate the new exchange rate
   */
  function _updateExchangeRate(uint216 newExchangeRate) internal override {
    _exchangeRateSnapshots[_exchangeRateSnapshotsCount] = ExchangeRateSnapshot(
      block.number.toUint40(),
      newExchangeRate
    );
    ++_exchangeRateSnapshotsCount;
    super._updateExchangeRate(newExchangeRate);
  }

  function _binarySearchExchangeRate(
    mapping(uint256 => ExchangeRateSnapshot) storage snapshots,
    uint256 snapshotsCount,
    uint256 blockNumber
  ) internal view returns (uint256) {
    unchecked {
      // First check most recent balance
      if (snapshots[snapshotsCount - 1].blockNumber <= blockNumber) {
        return snapshots[snapshotsCount - 1].value;
      }

      uint256 lower = 0;
      uint256 upper = snapshotsCount - 1;
      while (upper > lower) {
        uint256 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
        ExchangeRateSnapshot memory snapshot = snapshots[center];
        if (snapshot.blockNumber == blockNumber) {
          return snapshot.value;
        } else if (snapshot.blockNumber < blockNumber) {
          lower = center;
        } else {
          upper = center - 1;
        }
      }
      return snapshots[lower].value;
    }
  }
}