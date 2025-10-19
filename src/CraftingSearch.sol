// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ResourceNFT1155} from "./ResourceNFT1155.sol";
import {ItemNFT721} from "./ItemNFT721.sol";

/**
 * @title CraftingSearch (Template)
 * @notice Minimal wiring only. No randomness, no recipes. You will implement logic.
 *
 * TODO:
 * - Implement `search()` with a 60s cooldown that mints 3 random resources via ResourceNFT1155.
 * - Define recipe storage and implement `craft()`:
 *   * burn resources in ResourceNFT1155
 *   * mint item in ItemNFT721
 */
contract CraftingSearch is AccessControl {
    ResourceNFT1155 public resources;
    ItemNFT721 public items;

    // Cooldown duration: 60 seconds between searches
    uint256 public constant SEARCH_COOLDOWN = 60;
    
    // Track last search timestamp for each player
    mapping(address => uint256) public lastSearchTime;

    // Events for transparency
    event SearchPerformed(address indexed player, uint256[] resourceIds, uint256[] amounts);

    constructor(address admin, ResourceNFT1155 _resources, ItemNFT721 _items) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        resources = _resources;
        items = _items;
    }

    /// @notice Search for resources. Can be called once every 60 seconds per player.
    /// @dev Mints 3 random resources (IDs 1-6) to the caller via ResourceNFT1155.
    function search() external {
        // Check cooldown: ensure 60 seconds have passed since last search
        // Allow first search if lastSearchTime is 0 (never searched before)
        if (lastSearchTime[msg.sender] != 0) {
            require(
                block.timestamp >= lastSearchTime[msg.sender] + SEARCH_COOLDOWN,
                "Cooldown active: wait 60 seconds between searches"
            );
        }
        
        // Update last search timestamp for this player
        lastSearchTime[msg.sender] = block.timestamp;
        
        // Generate 3 random resource IDs (1-6 representing: Wood, Iron, Gold, Leather, Stone, Diamond)
        uint256[] memory resourceIds = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        
        // Simple pseudo-random generation (note: not cryptographically secure, but fine for a game)
        // Using block.timestamp, block.prevrandao, and msg.sender for randomness
        uint256 randomSeed = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            msg.sender
        )));
        
        // Generate 3 random resources
        for (uint256 i = 0; i < 3; i++) {
            // Get random number between 1-6 (resource IDs)
            resourceIds[i] = (uint256(keccak256(abi.encodePacked(randomSeed, i))) % 6) + 1;
            // Each search gives 1 of each resource
            amounts[i] = 1;
        }
        
        // Mint the resources to the player
        resources.mintBatch(msg.sender, resourceIds, amounts);
        
        // Emit event for tracking
        emit SearchPerformed(msg.sender, resourceIds, amounts);
    }

    /// @notice TODO: implement crafting according to recipes (burnBatch + mintTo).
    function craft(uint256 /*itemType*/) external pure {
        revert("TODO: implement craft()");
    }
}
