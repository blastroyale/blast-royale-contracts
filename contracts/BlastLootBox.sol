// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./IEquipmentNFT.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// import "hardhat/console.sol";

/// @title Blast LootBox NFT
/// @dev BlastLootBox ERC721 token
contract BlastLootBox is
  ERC721,
  AccessControl,
  EIP712
{
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIdCounter;
  mapping(address => Counters.Counter) private _nonces;
  mapping(uint => uint[]) private lootboxDetails;
  IEquipmentNFT private equipment;
  IERC20 private bltContract;
  address private _treasury;
  uint private _amount;
  uint private _origin;
  bool private _revealed;
  string private _lootURI;
  string private _nftURI;

  event Treasury(address indexed treasury);
  event PricesChanged(uint256 bltRepairPrice, uint256 csRepairPrice, uint256 bltCraftPrice, uint256 csCraftPrice);

  bytes32 public constant GAME_ROLE = keccak256("GAME_ROLE");

  /// @param name Name of the contract
  /// @param symbol Symbol of the contract
  constructor(
    string memory name,
    string memory symbol,
    IEquipmentNFT equipmentAddress,
    IERC20 bltAddress,
    address treasury,
    address game,
    uint amount,
    uint origin,
    string memory lootURI,
    string memory nftURI
  )
    ERC721(name, symbol) 
    EIP712(name, "1")
  {
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(GAME_ROLE, game);
    equipment = equipmentAddress;
    bltContract = bltAddress;
    _treasury = treasury;
    _revealed = false;
    _amount = amount;
    _origin = origin;
    _lootURI = lootURI;
    _nftURI = nftURI;
  }

  /// @notice Creates a new token for `to`. Its token ID will be automatically
  /// @param amount The number of NFTs to Mint
  /// @param to The address receiving the NFTs
  /// @param signature EIP712 Signature
  function safeMint(uint256 amount, uint256 price, address to, bytes calldata signature)
    external
  {
    verify(signature, to, amount, price);
    if (price > 0) {
      bltContract.transferFrom(
        _msgSender(),
        _treasury,
        price
      );
    }
    _nonces[to].increment();
    for (uint256 i = 0; i < amount; i = i + 1) {
      uint256 tokenId = _tokenIdCounter.current();
      _tokenIdCounter.increment();
      _safeMint(to, tokenId);
    }
  }

  /// @notice Open an array of lootboxes.
  /// @param tokens Array of tokens to open.
  function open(uint256[] memory tokens) external {
    require(_revealed, "Cannot Open yet");
    for (uint256 i = 0; i < tokens.length ; i = i + 1) {
      require(_exists(tokens[i]), "Open nonexistent token");
      equipment.safeMint(_amount, ownerOf(tokens[i]), _lootURI, _origin);
      _burn(tokens[i]);
    }
  }

  /// @notice Get the nonce for that address
  /// @param to Address to send the nonce fo
  /// @return The current nonce for one address
  function nonce(address to) public view returns(uint256) {
    return _nonces[to].current();
  }

  /// @notice Verify Signature by the owner of the contract
  /// @param signature Operation Signature
  /// @param minter Address of the Minter
  /// @param amount Ammount to mint
  function verify(
    bytes memory signature,
    address minter,
    uint256 amount,
    uint256 price 
  ) public view {
    bytes32 digest = _hashTypedDataV4(
      keccak256(abi.encode(keccak256("Call(address minter,uint256 amount,uint256 price,uint256 nonce)"), minter, amount, price, _nonces[minter].current()))
    );
    address recoveredSigner = ECDSA.recover(digest, signature);
    require(hasRole(GAME_ROLE, recoveredSigner), "Invalid Signature");
  }

  /// @notice Changes the Treasury address
  /// @param treasury Change Treasury Address
  function setTreasury(address treasury)
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    _treasury = treasury;
    emit Treasury(treasury);
  }

  /// @notice Reveals the LootBox.
  /// @dev Once revealed, lootboxes can be opened
  function reveal()
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    _revealed = true;
  }

  /// @notice Returns the TokenURI.
  /// @param tokenId Token ID.
  function tokenURI(uint256 tokenId)
    public
    view
    override(ERC721)
    returns (string memory)
  {
    return super.tokenURI(tokenId);
  }

  /// @dev See {IERC165-supportsInterface}.
  /// @param interfaceId Interface ID.
  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(AccessControl, ERC721)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }
}
