// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * @dev interface of replicator
 */
interface IReplicator {
    struct StaticAttributes {
        uint8 maxLevel;
        uint8 maxDurability;
        uint8 maxReplication;
        uint8 adjective;
        uint8 rarity;
        uint8 grade;
    }

    function replicate(
        string calldata _hashString,
        string calldata _realUri,
        uint256 _p1,
        uint256 _p2,
        StaticAttributes calldata _staticAttribute
    ) external;
}
