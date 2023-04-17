// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2; // required to accept structs as function parameters

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IReplicator.sol";

contract LazyReplicate is EIP712, Ownable, ReentrancyGuard {
    string private constant SIGNING_DOMAIN = "LazyReplicate-Voucher";
    string private constant SIGNATURE_VERSION = "1";

    address public adminAddress;

    mapping(uint256 => bool) public idUsed;

    IReplicator public replicator;

    address public treasury;

    constructor(
        IReplicator _replicator,
        address _adminAddress,
        address _treasury
    ) EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) {
        require(address(_replicator) != address(0), "No Zero Address");
        replicator = _replicator;
        adminAddress = _adminAddress;
        treasury = _treasury;
    }

    /// @notice Represents an un replicated NFT, which has not yet been recorded into the blockchain. A signed voucher can be redeemed for a replication using the redeem function.
    struct ReplicateVoucher {
        /// @notice claim id to prevent using the same voucher twice.
        uint256 id;
        string hashString;
        string realUri;
        uint256 p1;
        uint256 p2;
        uint8 maxLevel;
        uint8 maxDurability;
        uint8 maxReplication;
        uint8 adjective;
        uint8 rarity;
        uint8 grade;
        string maticAmount;
        /// @notice the EIP-712 signature of all other fields in the ReplicateVoucher struct. For a voucher to be valid, it must be signed by an account with the MINTER_ROLE.
        bytes signature;
    }

    /// @notice Redeems an ReplicateVoucher for to perform replication, creating it in the process.
    /// @param voucher A signed ReplicateVoucher that describes the replication to be redeemed.
    function redeem(
        ReplicateVoucher calldata voucher
    ) public payable nonReentrant returns (uint256) {
        require(
            keccak256(abi.encodePacked(Strings.toString(msg.value))) ==
                keccak256(abi.encodePacked(voucher.maticAmount)),
            "correct amount of matic is required"
        );

        (bool sent, ) = payable(treasury).call{value: msg.value}("");
        require(sent, "Failed to send to treasure");
        // make sure the voucher has not been used
        require(!idUsed[voucher.id], "voucher had been used");
        // make sure signature is valid and get the address of the signer
        address signer = _verify(voucher);
        // make sure that the signer is authorized to replicate
        require(signer == adminAddress, "Signature invalid or unauthorized");

        IReplicator.StaticAttributes memory staticAttributes = IReplicator
            .StaticAttributes({
                maxLevel: voucher.maxLevel,
                maxDurability: voucher.maxDurability,
                maxReplication: voucher.maxReplication,
                adjective: voucher.adjective,
                rarity: voucher.rarity,
                grade: voucher.grade
            });

        // first assign the token to the signer, to establish provenance on-chain
        replicator.replicate(
            voucher.hashString,
            voucher.realUri,
            voucher.p1,
            voucher.p2,
            staticAttributes
        );

        // set id used as true
        idUsed[voucher.id] = true;

        return voucher.id;
    }

    /// @notice Returns a hash of the given ReplicateVoucher, prepared using EIP712 typed data hashing rules.
    /// @param voucher An ReplicateVoucher to hash.
    function _hash(
        ReplicateVoucher calldata voucher
    ) internal view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256(
                            "ReplicateVoucher(uint256 id,string hashString,string realUri,uint256 p1,uint256 p2,uint8 maxLevel,uint8 maxDurability,uint8 maxReplication,uint8 adjective,uint8 rarity,uint8 grade,string maticAmount)"
                        ),
                        voucher.id,
                        keccak256(bytes(voucher.hashString)),
                        keccak256(bytes(voucher.realUri)),
                        voucher.p1,
                        voucher.p2,
                        voucher.maxLevel,
                        voucher.maxDurability,
                        voucher.maxReplication,
                        voucher.adjective,
                        voucher.rarity,
                        voucher.grade,
                        keccak256(bytes(voucher.maticAmount))
                    )
                )
            );
    }

    /// @notice Returns the chain id of the current blockchain.
    /// @dev This is used to workaround an issue with ganache returning different values from the on-chain chainid() function and
    ///  the eth_chainId RPC method. See https://github.com/protocol/nft-website/issues/121 for context.
    function getChainID() external view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    function setAdminAddress(address _adminAddress) public onlyOwner {
        adminAddress = _adminAddress;
    }

    function setTreasuryAddress(address _treasuryAddress) public onlyOwner {
        treasury = _treasuryAddress;
    }

    /// @notice Verifies the signature for a given ReplicateVoucher, returning the address of the signer.
    /// @dev Will revert if the signature is invalid. Does not verify that the signer is authorized to replicate.
    /// @param voucher An ReplicateVoucher describing an unreplicated action.
    function _verify(
        ReplicateVoucher calldata voucher
    ) internal view returns (address) {
        bytes32 digest = _hash(voucher);
        return ECDSA.recover(digest, voucher.signature);
    }
}
