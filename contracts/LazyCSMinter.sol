// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2; // required to accept structs as function parameters

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "./ICraftSpiceToken.sol";

contract LazyCSMinter is EIP712, Ownable {
    //   bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    string private constant SIGNING_DOMAIN = "LazyNFT-Voucher";
    string private constant SIGNATURE_VERSION = "1";

    address public adminAddress;

    ICraftSpiceToken public csToken;

    constructor(
        ICraftSpiceToken _csToken,
        address _adminAddress
    ) EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) {
        require(address(_csToken) != address(0), "No Zero Address");
        csToken = _csToken;
        adminAddress = _adminAddress;
    }

    /// @notice Represents an un-minted NFT, which has not yet been recorded into the blockchain. A signed voucher can be redeemed for a real NFT using the redeem function.
    struct CSVoucher {
        /// @notice The amount of CS.
        uint256 amount;
        // @notice The minter of this token.
        address minter;
        /// @notice the EIP-712 signature of all other fields in the CSVoucher struct. For a voucher to be valid, it must be signed by an account with the MINTER_ROLE.
        bytes signature;
    }

    /// @notice Redeems an CSVoucher for an actual NFT, creating it in the process.
    /// @param voucher A signed CSVoucher that describes the NFT to be redeemed.
    function redeem(
        CSVoucher calldata voucher
    ) public payable returns (uint256) {
        // make sure signature is valid and get the address of the signer
        address signer = _verify(voucher);

        // make sure that the signer is authorized to mint NFTs
        require(signer == adminAddress, "Signature invalid or unauthorized");

        // first assign the token to the signer, to establish provenance on-chain
        csToken.claim(voucher.minter, voucher.amount);

        return voucher.amount;
    }

    /// @notice Returns a hash of the given CSVoucher, prepared using EIP712 typed data hashing rules.
    /// @param voucher An CSVoucher to hash.
    function _hash(CSVoucher calldata voucher) internal view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256("CSVoucher(uint256 amount,address minter)"),
                        voucher.amount,
                        voucher.minter
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

    /// @notice Verifies the signature for a given CSVoucher, returning the address of the signer.
    /// @dev Will revert if the signature is invalid. Does not verify that the signer is authorized to mint NFTs.
    /// @param voucher An CSVoucher describing an unminted amount of CS.
    function _verify(
        CSVoucher calldata voucher
    ) internal view returns (address) {
        bytes32 digest = _hash(voucher);
        return ECDSA.recover(digest, voucher.signature);
    }
}
