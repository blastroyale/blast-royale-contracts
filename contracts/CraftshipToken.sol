// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/// @title Blast Royale Secondary Token : Craftship ($CS)
/// @dev Based on OpenZeppelin Contracts.
contract CraftshipToken is ERC20, ERC20Pausable, AccessControl, EIP712 {
  using Counters for Counters.Counter;
  mapping(address => Counters.Counter) private _nonces;

  bytes32 public constant GAME_ROLE = keccak256("GAME_ROLE");

  /// @notice Token constructor
  /// @dev Creates the token and setup the initial supply and the Admin Role.
  /// @param name Name of the Token
  /// @param symbol Symbol of the token
  /// @param admin The Admin (owner) of the contract
  /// @param _supply Initial Supply
  constructor(string memory name, string memory symbol, address admin, uint256 _supply)
    EIP712(name, "1")
    ERC20(name, symbol) {
    _setupRole(DEFAULT_ADMIN_ROLE, admin);
    _mint(admin, _supply);
  }

  /// @notice Pauses the contract 
  /// @dev It stops transfer from happening. Only Owner can call it.
  function pause() public onlyRole(DEFAULT_ADMIN_ROLE) virtual {
    _pause();
  }

  /// @notice Unpauses the contract 
  /// @dev Transfers are possible again. Only Owner can call it.
  function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) virtual {
    _unpause();
  }

  /// @notice Mint new tokens
  /// @param amount Supply of tokens to be minted
  /// @param signature Signature of who can mint the tokens
  function mint(uint256 amount, bytes calldata signature) external {
    verify(signature, msg.sender, amount);
    _mint(msg.sender, amount);
    _nonces[msg.sender].increment();
  }

  /// @notice Verifications before Token Transfer
  /// @param from Address from
  /// @param from to Address from
  /// @param amount tokens to be transferred 
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override(ERC20, ERC20Pausable) {
    super._beforeTokenTransfer(from, to, amount);
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
    uint256 amount
  ) public view {
    bytes32 digest = _hashTypedDataV4(
      keccak256(abi.encode(keccak256("Call(address minter,uint256 amount,uint256 nonce)"), minter, amount, _nonces[minter].current()))
    );
    address recoveredSigner = ECDSA.recover(digest, signature);
    require(hasRole(GAME_ROLE, recoveredSigner), "Invalid Signature");
  }

  /// @notice Only GAME can call burnFrom
  /// @param account Address to burn tokens from
  /// @param amount Tokens to burn
  function burnFrom(address account, uint256 amount)
    public
    virtual
    onlyRole(GAME_ROLE) {
    _spendAllowance(account, _msgSender(), amount);
    _burn(account, amount);
  }

  /// @notice ChainID
  /// @return chaiId
  function getChainId() external view returns (uint256) {
    return block.chainid;
  }

}
