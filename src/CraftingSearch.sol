// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ResourceNFT1155} from "./ResourceNFT1155.sol";
import {ItemNFT721} from "./ItemNFT721.sol";

/**
 * @title CraftingSearch
 * @notice Handles resource searching and item crafting mechanics
 * @dev Players can search for random resources every 60 seconds and craft items from collected resources
 */
contract CraftingSearch is AccessControl {
    ResourceNFT1155 public resources;
    ItemNFT721 public items;

    uint256 public constant SEARCH_COOLDOWN = 60;
    
    mapping(address => uint256) public lastSearchTime;

    // Resource IDs
    uint256 public constant WOOD = 1;
    uint256 public constant IRON = 2;
    uint256 public constant GOLD = 3;
    uint256 public constant LEATHER = 4;
    uint256 public constant STONE = 5;
    uint256 public constant DIAMOND = 6;

    // Item Types
    uint256 public constant COSSACK_SABRE = 1;      // 3×Iron + 1×Wood + 1×Leather
    uint256 public constant ELDER_STAFF = 2;        // 2×Wood + 1×Gold + 1×Diamond
    uint256 public constant CHARAKTERNYK_ARMOR = 3; // 4×Leather + 2×Iron + 1×Gold
    uint256 public constant BATTLE_BRACELET = 4;    // 4×Iron + 2×Gold + 2×Diamond

    struct Recipe {
        uint256[] resourceIds;
        uint256[] amounts;
        bool exists;
    }

    mapping(uint256 => Recipe) public recipes;

    event SearchPerformed(address indexed player, uint256[] resourceIds, uint256[] amounts);
    event ItemCrafted(address indexed player, uint256 itemType, uint256 tokenId);

    constructor(address admin, ResourceNFT1155 _resources, ItemNFT721 _items) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        resources = _resources;
        items = _items;
        _initializeRecipes();
    }

    /// @dev Initialize all crafting recipes
    function _initializeRecipes() private {
        uint256[] memory sabreIds = new uint256[](3);
        uint256[] memory sabreAmounts = new uint256[](3);
        sabreIds[0] = IRON;
        sabreIds[1] = WOOD;
        sabreIds[2] = LEATHER;
        sabreAmounts[0] = 3;
        sabreAmounts[1] = 1;
        sabreAmounts[2] = 1;
        recipes[COSSACK_SABRE] = Recipe(sabreIds, sabreAmounts, true);

        uint256[] memory staffIds = new uint256[](3);
        uint256[] memory staffAmounts = new uint256[](3);
        staffIds[0] = WOOD;
        staffIds[1] = GOLD;
        staffIds[2] = DIAMOND;
        staffAmounts[0] = 2;
        staffAmounts[1] = 1;
        staffAmounts[2] = 1;
        recipes[ELDER_STAFF] = Recipe(staffIds, staffAmounts, true);

        uint256[] memory armorIds = new uint256[](3);
        uint256[] memory armorAmounts = new uint256[](3);
        armorIds[0] = LEATHER;
        armorIds[1] = IRON;
        armorIds[2] = GOLD;
        armorAmounts[0] = 4;
        armorAmounts[1] = 2;
        armorAmounts[2] = 1;
        recipes[CHARAKTERNYK_ARMOR] = Recipe(armorIds, armorAmounts, true);

        uint256[] memory braceletIds = new uint256[](3);
        uint256[] memory braceletAmounts = new uint256[](3);
        braceletIds[0] = IRON;
        braceletIds[1] = GOLD;
        braceletIds[2] = DIAMOND;
        braceletAmounts[0] = 4;
        braceletAmounts[1] = 2;
        braceletAmounts[2] = 2;
        recipes[BATTLE_BRACELET] = Recipe(braceletIds, braceletAmounts, true);
    }

    /// @notice Search for resources. Can be called once every 60 seconds per player.
    /// @dev Mints 3 random resources (IDs 1-6) to the caller via ResourceNFT1155.
    function search() external {
        if (lastSearchTime[msg.sender] != 0) {
            require(
                block.timestamp >= lastSearchTime[msg.sender] + SEARCH_COOLDOWN,
                "Cooldown active: wait 60 seconds between searches"
            );
        }
        
        lastSearchTime[msg.sender] = block.timestamp;
        
        uint256[] memory resourceIds = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        
        // Simple pseudo-random generation (note: not cryptographically secure, but fine for a game)
        // Using block.timestamp, block.prevrandao, and msg.sender for randomness
        uint256 randomSeed = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            msg.sender
        )));
        
        for (uint256 i = 0; i < 3; i++) {
            resourceIds[i] = (uint256(keccak256(abi.encodePacked(randomSeed, i))) % 6) + 1;
            amounts[i] = 1;
        }
        
        resources.mintBatch(msg.sender, resourceIds, amounts);

        emit SearchPerformed(msg.sender, resourceIds, amounts);
    }

    /// @notice Craft an item by burning required resources
    /// @param itemType The type of item to craft (1-4)
    /// @dev Burns resources from caller's balance and mints an ERC721 item
    function craft(uint256 itemType) external {
        require(recipes[itemType].exists, "Invalid item type");
        
        Recipe storage recipe = recipes[itemType];
        
        for (uint256 i = 0; i < recipe.resourceIds.length; i++) {
            uint256 balance = resources.balanceOf(msg.sender, recipe.resourceIds[i]);
            require(
                balance >= recipe.amounts[i],
                "Insufficient resources for crafting"
            );
        }
        
        resources.burnBatch(msg.sender, recipe.resourceIds, recipe.amounts);
        
        uint256 tokenId = items.mintTo(msg.sender);
        
        emit ItemCrafted(msg.sender, itemType, tokenId);
    }
}
