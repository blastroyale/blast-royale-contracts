// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @dev required interface of an Equipment NFT.
 */
interface IBlastEquipmentNFT is IERC721 {
    /// @notice Event Attribute Added
    event AttributeAdded(
        uint256 tokenId,
        uint256 level,
        uint256 durabilityRemaining,
        uint256 repairCount,
        uint256 replicationCount
    );

    /// @notice Event Attribute Updated
    event AttributeUpdated(
        uint256 tokenId,
        uint256 level,
        uint256 durabilityRemaining,
        uint256 repairCount,
        uint256 replicationCount
    );

    function safeMint(
        address _to,
        string[] memory _uri,
        bytes32[] memory _hash
    ) external;

    function setLevel(uint256 _tokenId, uint256 _newLevel) external;

    function setDurabilityRemaining(
        uint256 _tokenId,
        uint256 _newDurabilityRemaining
    ) external;

    function setRepairCount(uint256 _tokenId, uint256 _newRepairCount) external;

    function setReplicationCount(uint256 _tokenId, uint256 _newReplicationCount)
        external;
}
