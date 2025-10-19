// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title ItemNFT721
 * @notice ERC721 token representing craftable items in the Cossack Business game
 * @dev Items can be minted by CraftingSearch and burned by Marketplace
 */
contract ItemNFT721 is ERC721, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    uint256 public nextId = 1;

    constructor(address admin) ERC721("Cossack Items", "CITEM") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @notice Mint a new item to a specified address
    /// @param to The address to receive the minted item
    /// @return The ID of the newly minted item
    /// @dev Only callable by addresses with MINTER_ROLE (CraftingSearch)
    function mintTo(
        address to
    ) external onlyRole(MINTER_ROLE) returns (uint256) {
        uint256 id = nextId++;
        _safeMint(to, id);
        return id;
    }

    /// @notice Burn an item
    /// @param tokenId The ID of the item to burn
    /// @dev Only callable by addresses with BURNER_ROLE (Marketplace)
    function burn(uint256 tokenId) external onlyRole(BURNER_ROLE) {
        _burn(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
