// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import { Errors } from "./../libraries/Errors.sol";

contract TokenVesting is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    event CreatedVestingSchedule(address user, bytes32 scheduleId);

    /// <=============== STATE VARIABLES ===============>

    /// Blast TOKEN
    IERC20 public blastToken;

    struct VestingSchedule {
        // beneficiary of tokens after they are released
        address beneficiary;
        // start time of the vesting period
        uint256 start;
        // cliffStart time in seconds
        uint256 cliffStart;
        // duration of the vesting period in seconds
        uint256 duration;
        // the amount that is immediately vested at grant
        uint256 immediateVestedAmount;
        // total amount of tokens to be released at the end of the vesting EXCLUDING immediateVestedAmount
        uint256 amountTotal;
        // amount of tokens released
        uint256 released;
        // whether or not the vesting is revocable
        bool revocable;
        // whether or not the vesting has been revoked
        bool revoked;
    }

    bytes32[] private vestingSchedulesIds;
    mapping(bytes32 => VestingSchedule) private vestingSchedules;
    uint256 private vestingSchedulesTotalAmount;
    mapping(address => uint256) private holdersVestingCount;

    event Released(
        address beneficiary,
        bytes32 vestingScheduleId,
        uint256 amount,
        uint256 releaseTimestamp
    );
    event Revoked(bytes32 vestingScheduleId, uint256 revokeTimestamp);

    constructor(IERC20 _blastToken) {
        blastToken = _blastToken;
    }

    /// <=============== MUTATIVE METHODS ===============>

    /// @notice Creates a new vesting schedule for a beneficiary
    function createVestingSchedule(
        address _beneficiary,
        uint256 _start,
        uint256 _cliffDuration,
        uint256 _duration,
        uint256 _immediateReleaseAmount,
        uint256 _amountTotal,
        bool _revocable
    ) external whenNotPaused onlyOwner {
        require(_beneficiary != address(0), Errors.NO_ZERO_ADDRESS);
        require(getWithdrawableAmount() >= (_amountTotal + _immediateReleaseAmount), Errors.INSUFFICIENT_TOKENS);
        require(_duration > 0, Errors.DURATION_INVALID);
        require(_amountTotal > 0, Errors.INVALID_AMOUNT);
        require(_start > block.timestamp, Errors.START_TIME_INVALID);
        require(_cliffDuration <= _duration, Errors.DURATION_INVALID);

        bytes32 vestingScheduleId = computeNextVestingScheduleIdForHolder(
            _beneficiary
        );
        uint256 cliff = _start + _cliffDuration;
        vestingSchedules[vestingScheduleId] = VestingSchedule({
            beneficiary: _beneficiary,
            start: _start,
            cliffStart: cliff,
            duration: _duration,
            immediateVestedAmount: _immediateReleaseAmount,
            amountTotal: _amountTotal,
            released: 0,
            revocable: _revocable,
            revoked: false
        });
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount + _amountTotal + _immediateReleaseAmount;
        vestingSchedulesIds.push(vestingScheduleId);
        uint256 currentVestingCount = holdersVestingCount[_beneficiary];
        holdersVestingCount[_beneficiary] = currentVestingCount + 1;

        emit CreatedVestingSchedule(_beneficiary, vestingScheduleId);
    }

    /**
     * @notice Revokes the vesting schedule for given identifier.
     * @param vestingScheduleId the vesting schedule identifier
     */
    function revoke(bytes32 vestingScheduleId) external whenNotPaused onlyOwner {
        VestingSchedule storage vestingSchedule = vestingSchedules[vestingScheduleId];
        require(!vestingSchedule.revoked, Errors.SCHEDULE_REVOKED);
        require(vestingSchedule.revocable, Errors.NOT_REVOCABLE);
        uint256 releasableAmount = _computeReleasableAmount(vestingSchedule);
        if (releasableAmount > 0) {
            release(vestingScheduleId, releasableAmount);
        }
        uint256 unreleased = vestingSchedule.amountTotal -
            vestingSchedule.released;
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount - unreleased;
        vestingSchedule.revoked = true;
        blastToken.safeTransfer(owner(), unreleased);

        emit Revoked(vestingScheduleId, block.timestamp);
    }

    /// @notice Release vested amount of tokens.
    function release(bytes32 vestingScheduleId, uint256 amount)
        public
        whenNotPaused
        nonReentrant
    {
        VestingSchedule storage vestingSchedule = vestingSchedules[vestingScheduleId];
        require(!vestingSchedule.revoked, Errors.SCHEDULE_REVOKED);
        address beneficiary = vestingSchedule.beneficiary;
        bool isBeneficiary = _msgSender() == beneficiary;
        bool isOwner = _msgSender() == owner();
        require(isBeneficiary || isOwner, Errors.BENEFICIARY_OR_OWNER);
        uint256 releasableAmount = _computeReleasableAmount(vestingSchedule);
        require(releasableAmount >= amount, Errors.NOT_ENOUGH_TOKENS);
        vestingSchedule.released = vestingSchedule.released + amount;
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount - amount;
        blastToken.safeTransfer(beneficiary, amount);
        emit Released(_msgSender(), vestingScheduleId, amount, block.timestamp);
    }

    /// <=============== VIEWS ===============>

    /**
     * @dev Returns the amount of tokens that can be withdrawn by the owner.
     * @return the amount of tokens
     */
    function getWithdrawableAmount() public view returns (uint256) {
        return
            blastToken.balanceOf(address(this)) - vestingSchedulesTotalAmount;
    }

    /**
     * @dev Computes the next vesting schedule identifier for a given holder address.
     */
    function computeNextVestingScheduleIdForHolder(address holder)
        public
        view
        returns (bytes32)
    {
        return
            computeVestingScheduleIdForAddressAndIndex(
                holder,
                holdersVestingCount[holder]
            );
    }

    /**
     * @dev Computes the vesting schedule identifier for an address and an index.
     */
    function computeVestingScheduleIdForAddressAndIndex(
        address holder,
        uint256 index
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(holder, index));
    }

    /**
     * @notice Computes the vested amount of tokens for the given vesting schedule identifier.
     * @return the vested amount
     */
    function computeReleasableAmount(bytes32 vestingScheduleId)
        external
        view
        returns (uint256)
    {
        require(!vestingSchedules[vestingScheduleId].revoked, Errors.SCHEDULE_REVOKED);
        VestingSchedule storage vestingSchedule = vestingSchedules[
            vestingScheduleId
        ];
        return _computeReleasableAmount(vestingSchedule);
    }

    /**
     * @dev Computes the releasable amount of tokens for a vesting schedule.
     * @return the amount of releasable tokens
     */
    function _computeReleasableAmount(VestingSchedule memory vestingSchedule)
        internal
        view
        returns (uint256)
    {
        uint256 currentTime = block.timestamp;
        if (currentTime < vestingSchedule.cliffStart) {
            return vestingSchedule.immediateVestedAmount - vestingSchedule.released;
        } else if (
            currentTime >= vestingSchedule.cliffStart + vestingSchedule.duration
        ) {
            return
                vestingSchedule.amountTotal +
                vestingSchedule.immediateVestedAmount -
                vestingSchedule.released;
        } else {
            uint256 timeFromStart = currentTime - vestingSchedule.cliffStart;
            uint256 vestedAmount = vestingSchedule.amountTotal * timeFromStart / vestingSchedule.duration;
            vestedAmount = vestedAmount + vestingSchedule.immediateVestedAmount - vestingSchedule.released;
            return vestedAmount;
        }
    }

    /**
     * @notice Returns the vesting schedule information for a given identifier.
     * @return the vesting schedule structure information
     */
    function getVestingSchedule(bytes32 vestingScheduleId)
        public
        view
        returns (VestingSchedule memory)
    {
        return vestingSchedules[vestingScheduleId];
    }

    /**
     * @notice Returns the vesting schedule information for a given holder and index.
     * @return the vesting schedule structure information
     */
    function getVestingScheduleByAddressAndIndex(address holder, uint256 index)
        external
        view
        returns (VestingSchedule memory)
    {
        return
            getVestingSchedule(
                computeVestingScheduleIdForAddressAndIndex(holder, index)
            );
    }

    function pause(bool stop) external onlyOwner {
        if (stop) {
            _pause();
        } else {
            _unpause();
        }
    }
}
