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

    /// @notice Event Revealed TokenURI
    event PermanentURI(string _value, uint256 indexed _id);

    function safeMint(
        address _to,
        string[] memory _uri,
        bytes32[] memory _hash,
        string[] memory _realUri
    ) external;

    function revealRealTokenURI(uint _tokenId) external;

    function setLevel(uint256 _tokenId, uint256 _newLevel) external;

    function setDurabilityRemaining(
        uint256 _tokenId,
        uint256 _newDurabilityRemaining
    ) external;

    function setRepairCount(uint256 _tokenId, uint256 _newRepairCount) external;

    function setReplicationCount(uint256 _tokenId, uint256 _newReplicationCount)
        external;

    // function replicate(address _to, string memory _uri, string memory _realUri, bytes32 _hash, uint _f1, uint _f2) external;

    function getAttributes(uint _tokenId) external view returns (uint, uint, uint, uint);
}
