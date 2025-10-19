// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title ResourceNFT1155
 * @notice ERC1155 token representing collectible resources in the Cossack Business game
 * @dev Resources can only be minted/burned by CraftingSearch contract
 */
contract ResourceNFT1155 is ERC1155, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /// @notice Resource ID for Wood (ID: 1)
    uint256 public constant WOOD = 1;

    constructor(address admin) ERC1155("") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @notice Mint multiple resources to an address
    /// @param to The address to receive the resources
    /// @param ids Array of resource IDs to mint
    /// @param amounts Array of amounts to mint for each resource ID
    /// @dev Only callable by addresses with MINTER_ROLE (CraftingSearch)
    function mintBatch(
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external onlyRole(MINTER_ROLE) {
        _mintBatch(to, ids, amounts, "");
    }

    /// @notice Burn multiple resources from an address
    /// @param from The address to burn resources from
    /// @param ids Array of resource IDs to burn
    /// @param amounts Array of amounts to burn for each resource ID
    /// @dev Only callable by addresses with BURNER_ROLE (CraftingSearch)
    function burnBatch(
        address from,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external onlyRole(BURNER_ROLE) {
        _burnBatch(from, ids, amounts);
    }

    /// @inheritdoc ERC1155
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
