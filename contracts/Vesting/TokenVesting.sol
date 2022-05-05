// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/// cannot create vesting schedule because not sufficient tokens
error InsufficientTokens();
/// duration must be > 0
error DurationInvalid();
/// amount must be > 0
error AmountInvalid();
/// only beneficiary and owner can release vested tokens
error BeneficiayrOrOwner();
/// cannot release tokens, not enough vested tokens
error NotEnoughTokens();
/// Reverts if the vesting schedule has been revoked
error ScheduleRevoked();
/// Vesting is not revocable
error NotRevocable();

contract TokenVesting is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    /// <=============== STATE VARIABLES ===============>

    /// Blast TOKEN
    IERC20 public blastToken;

    struct VestingSchedule {
        // beneficiary of tokens after they are released
        address beneficiary;
        // start time of the vesting period
        uint256 start;
        // cliff period in seconds
        uint256 cliffStart;
        // duration of the vesting period in seconds
        uint256 duration;
        // total amount of tokens to be released at the end of the vesting
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
        uint256 amount
    );
    event Revoked(bytes32 vestingScheduleId);

    constructor(IERC20 _blastToken) {
        blastToken = _blastToken;
    }

    receive() external payable {}

    fallback() external payable {}

    /// <=============== MUTATIVE METHODS ===============>

    /// @notice Creates a new vesting schedule for a beneficiary
    function createVestingSchedule(
        address _beneficiary,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        uint256 _amount,
        uint256 _immediateReleaseAmount,
        bool _revocable
    ) public onlyOwner {
        if (getWithdrawableAmount() < _amount) revert InsufficientTokens();
        if (_duration <= 0) revert DurationInvalid();
        if (_amount <= 0) revert AmountInvalid();
        bytes32 vestingScheduleId = computeNextVestingScheduleIdForHolder(
            _beneficiary
        );
        uint256 cliff = _start.add(_cliff);
        vestingSchedules[vestingScheduleId] = VestingSchedule(
            _beneficiary,
            _start,
            cliff,
            _duration,
            _amount,
            0,
            _revocable,
            false
        );
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount.add(_amount);
        vestingSchedulesIds.push(vestingScheduleId);
        uint256 currentVestingCount = holdersVestingCount[_beneficiary];
        holdersVestingCount[_beneficiary] = currentVestingCount.add(1);
    }

    /**
     * @notice Revokes the vesting schedule for given identifier.
     * @param vestingScheduleId the vesting schedule identifier
     */
    function revoke(bytes32 vestingScheduleId)
        public
        onlyOwner
    {
        if (vestingSchedules[vestingScheduleId].revoked) revert ScheduleRevoked();
        VestingSchedule storage vestingSchedule = vestingSchedules[
            vestingScheduleId
        ];
        if (!vestingSchedule.revocable) revert NotRevocable();
        uint256 vestedAmount = _computeReleasableAmount(vestingSchedule);
        if (vestedAmount > 0) {
            release(vestingScheduleId, vestedAmount);
        }
        uint256 unreleased = vestingSchedule.amountTotal.sub(
            vestingSchedule.released
        );
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount.sub(
            unreleased
        );
        vestingSchedule.revoked = true;

        emit Revoked(vestingScheduleId);
    }

    /// @notice Release vested amount of tokens.
    function release(bytes32 vestingScheduleId, uint256 amount)
        public
        nonReentrant
    {
        if (vestingSchedules[vestingScheduleId].revoked) revert ScheduleRevoked();
        VestingSchedule storage vestingSchedule = vestingSchedules[
            vestingScheduleId
        ];
        bool isBeneficiary = msg.sender == vestingSchedule.beneficiary;
        bool isOwner = msg.sender == owner();
        if (!(isBeneficiary || isOwner)) revert BeneficiayrOrOwner();
        uint256 vestedAmount = _computeReleasableAmount(vestingSchedule);
        if (vestedAmount < amount) revert NotEnoughTokens();
        vestingSchedule.released = vestingSchedule.released.add(amount);
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount.sub(amount);
        blastToken.transfer(vestingSchedule.beneficiary, amount);

        emit Released(msg.sender, vestingScheduleId, amount);
    }

    /// <=============== VIEWS ===============>

    /**
     * @dev Returns the amount of tokens that can be withdrawn by the owner.
     * @return the amount of tokens
     */
    function getWithdrawableAmount() public view returns (uint256) {
        return
            blastToken.balanceOf(address(this)).sub(
                vestingSchedulesTotalAmount
            );
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
            return 0;
        } else if (
            currentTime >= vestingSchedule.start.add(vestingSchedule.duration)
        ) {
            return vestingSchedule.amountTotal.sub(vestingSchedule.released);
        } else {
            uint256 timeFromStart = currentTime.sub(vestingSchedule.cliffStart);
            uint256 vestedAmount = vestingSchedule
                .amountTotal
                .mul(timeFromStart)
                .div(vestingSchedule.duration);
            vestedAmount = vestedAmount.sub(vestingSchedule.released);
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
}
