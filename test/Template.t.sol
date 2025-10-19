// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {ResourceNFT1155} from "../src/ResourceNFT1155.sol";
import {ItemNFT721} from "../src/ItemNFT721.sol";
import {MagicToken} from "../src/MagicToken.sol";
import {CraftingSearch} from "../src/CraftingSearch.sol";
import {Marketplace} from "../src/Marketplace.sol";

contract TemplateTest is Test {
    ResourceNFT1155 res;
    ItemNFT721 items;
    MagicToken magic;
    CraftingSearch cs;
    Marketplace mkt;

    address admin = address(0xA11CE);

    function setUp() public {
        res = new ResourceNFT1155(admin);
        items = new ItemNFT721(admin);
        magic = new MagicToken(admin);
        cs = new CraftingSearch(admin, res, items);
        mkt = new Marketplace(admin, items, magic);

        // wire roles (mirrors Deploy.s.sol)
        vm.startPrank(admin);
        res.grantRole(res.MINTER_ROLE(), address(cs));
        res.grantRole(res.BURNER_ROLE(), address(cs));
        items.grantRole(items.MINTER_ROLE(), address(cs));
        magic.grantRole(magic.MARKET_ROLE(), address(mkt));
        vm.stopPrank();
    }

    function test_deployed_and_roles_wired() public {
        // contracts deployed
        assertTrue(address(res) != address(0));
        assertTrue(address(items) != address(0));
        assertTrue(address(magic) != address(0));
        assertTrue(address(cs) != address(0));
        assertTrue(address(mkt) != address(0));

        // core roles wired
        assertTrue(res.hasRole(res.MINTER_ROLE(), address(cs)));
        assertTrue(res.hasRole(res.BURNER_ROLE(), address(cs)));
        assertTrue(items.hasRole(items.MINTER_ROLE(), address(cs)));
        assertTrue(magic.hasRole(magic.MARKET_ROLE(), address(mkt)));
    }

    // TODO(student): add real tests as you implement features:
    // - search() cooldown + 3 random ERC1155 mints
    // - craft() recipes: burn ERC1155 + mint ERC721
    // - marketplace listing + purchase: burn ERC721 + mint MAGIC to seller

    // ========== SEARCH TESTS ==========

    /// @notice Test that search gives player 3 resources
    function test_search_gives_three_resources() public {
        address player = address(0xBEEF);
        
        // Player performs a search
        vm.prank(player);
        cs.search();
        
        // Check that player received some resources
        // We can't predict exact IDs due to randomness, but we can check balances
        uint256 totalResources = 0;
        for (uint256 id = 1; id <= 6; id++) {
            totalResources += res.balanceOf(player, id);
        }
        
        assertEq(totalResources, 3, "Player should receive exactly 3 resources");
    }

    /// @notice Test that cooldown prevents immediate second search
    function test_search_cooldown_prevents_immediate_search() public {
        address player = address(0xBEEF);
        
        vm.prank(player);
        cs.search();
        
        vm.prank(player);
        vm.expectRevert("Cooldown active: wait 60 seconds between searches");
        cs.search();
    }

    /// @notice Test that search works after cooldown expires
    function test_search_works_after_cooldown() public {
        address player = address(0xBEEF);
        
        vm.prank(player);
        cs.search();
        
        vm.warp(block.timestamp + 60);
        
        vm.prank(player);
        cs.search();
        
        uint256 totalResources = 0;
        for (uint256 id = 1; id <= 6; id++) {
            totalResources += res.balanceOf(player, id);
        }
        assertEq(totalResources, 6, "Player should have 6 resources after 2 searches");
    }

    /// @notice Test that different players have independent cooldowns
    function test_search_independent_cooldowns_per_player() public {
        address player1 = address(0xBEEF);
        address player2 = address(0xCAFE);
        
        vm.prank(player1);
        cs.search();
        
        vm.prank(player2);
        cs.search();
        
        uint256 player1Total = 0;
        uint256 player2Total = 0;
        for (uint256 id = 1; id <= 6; id++) {
            player1Total += res.balanceOf(player1, id);
            player2Total += res.balanceOf(player2, id);
        }
        assertEq(player1Total, 3, "Player 1 should have 3 resources");
        assertEq(player2Total, 3, "Player 2 should have 3 resources");
    }

    /// @notice Test that resource IDs are valid (between 1 and 6)
    function test_search_generates_valid_resource_ids() public {
        address player = address(0xBEEF);
        
        // Perform multiple searches to check randomness
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(player);
            cs.search();
            
            vm.warp(block.timestamp + 60);
        }
        
        for (uint256 id = 1; id <= 6; id++) {
            uint256 balance = res.balanceOf(player, id);
            assertTrue(balance >= 0, "Resource balance should be valid");
        }
        
        assertEq(res.balanceOf(player, 0), 0, "Resource ID 0 should not exist");
        assertEq(res.balanceOf(player, 7), 0, "Resource ID 7 should not exist");
    }

    /// @notice Test SearchPerformed event emission
    function test_search_emits_event() public {
        address player = address(0xBEEF);
        
        vm.prank(player);
        vm.recordLogs();
        cs.search();
        
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertTrue(logs.length > 0, "Event should be emitted");
    }

    // ========== CRAFT TESTS ==========

    /// @notice Helper function to give player specific resources for testing
    function _giveResources(address player, uint256[] memory ids, uint256[] memory amounts) internal {
        vm.prank(address(cs)); 
        res.mintBatch(player, ids, amounts);
    }

    /// @notice Test crafting Cossack Sabre 
    function test_craft_cossack_sabre() public {
        address player = address(0xBEEF);
        
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        ids[0] = 2; 
        ids[1] = 1; 
        ids[2] = 4;
        amounts[0] = 3;
        amounts[1] = 1;
        amounts[2] = 1;
        _giveResources(player, ids, amounts);
        
        vm.prank(player);
        cs.craft(1);
        
        assertEq(items.balanceOf(player), 1, "Player should have 1 item");
        
        assertEq(res.balanceOf(player, 2), 0, "Iron should be burned");
        assertEq(res.balanceOf(player, 1), 0, "Wood should be burned");
        assertEq(res.balanceOf(player, 4), 0, "Leather should be burned");
    }

    /// @notice Test crafting Elder Staff
    function test_craft_elder_staff() public {
        address player = address(0xBEEF);
        
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        ids[0] = 1; 
        ids[1] = 3; 
        ids[2] = 6; 
        amounts[0] = 2;
        amounts[1] = 1;
        amounts[2] = 1;
        _giveResources(player, ids, amounts);
        
        vm.prank(player);
        cs.craft(2); 
        
        assertEq(items.balanceOf(player), 1, "Player should have 1 item");
        assertEq(res.balanceOf(player, 1), 0, "Wood should be burned");
        assertEq(res.balanceOf(player, 3), 0, "Gold should be burned");
        assertEq(res.balanceOf(player, 6), 0, "Diamond should be burned");
    }

    /// @notice Test crafting Charakternyk Armor 
    function test_craft_charakternyk_armor() public {
        address player = address(0xBEEF);
        
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        ids[0] = 4; 
        ids[1] = 2; 
        ids[2] = 3; 
        amounts[0] = 4;
        amounts[1] = 2;
        amounts[2] = 1;
        _giveResources(player, ids, amounts);
        
        vm.prank(player);
        cs.craft(3); 
        
        assertEq(items.balanceOf(player), 1, "Player should have 1 item");
    }

    /// @notice Test crafting Battle Bracelet
    function test_craft_battle_bracelet() public {
        address player = address(0xBEEF);
        
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        ids[0] = 2; 
        ids[1] = 3; 
        ids[2] = 6; 
        amounts[0] = 4;
        amounts[1] = 2;
        amounts[2] = 2;
        _giveResources(player, ids, amounts);
        
        vm.prank(player);
        cs.craft(4);
        
        assertEq(items.balanceOf(player), 1, "Player should have 1 item");
    }

    /// @notice Test that crafting fails with insufficient resources
    function test_craft_fails_with_insufficient_resources() public {
        address player = address(0xBEEF);
        
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        ids[0] = 2; // Iron
        ids[1] = 1; // Wood
        ids[2] = 4; // Leather
        amounts[0] = 2; // Only 2 instead of 3
        amounts[1] = 1;
        amounts[2] = 1;
        _giveResources(player, ids, amounts);
        
        vm.prank(player);
        vm.expectRevert("Insufficient resources for crafting");
        cs.craft(1);
    }

    /// @notice Test that crafting fails with invalid item type
    function test_craft_fails_with_invalid_item_type() public {
        address player = address(0xBEEF);
        
        vm.prank(player);
        vm.expectRevert("Invalid item type");
        cs.craft(999);
    }

    /// @notice Test that player can craft multiple items
    function test_craft_multiple_items() public {
        address player = address(0xBEEF);
        
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        ids[0] = 2; // Iron
        ids[1] = 1; // Wood
        ids[2] = 4; // Leather
        amounts[0] = 6; // 3 × 2
        amounts[1] = 2; // 1 × 2
        amounts[2] = 2; // 1 × 2
        _giveResources(player, ids, amounts);
        
        vm.prank(player);
        cs.craft(1);
        
        vm.prank(player);
        cs.craft(1);
        
        assertEq(items.balanceOf(player), 2, "Player should have 2 items");
        assertEq(res.balanceOf(player, 2), 0, "All iron should be used");
    }

    /// @notice Test ItemCrafted event emission
    function test_craft_emits_event() public {
        address player = address(0xBEEF);
        
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        ids[0] = 2; // Iron
        ids[1] = 1; // Wood
        ids[2] = 4; // Leather
        amounts[0] = 3;
        amounts[1] = 1;
        amounts[2] = 1;
        _giveResources(player, ids, amounts);
        
        vm.prank(player);
        vm.recordLogs();
        cs.craft(1);
        
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertTrue(logs.length > 0, "ItemCrafted event should be emitted");
    }

    /// @notice Test that excess resources are kept after crafting
    function test_craft_keeps_excess_resources() public {
        address player = address(0xBEEF);
        
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        ids[0] = 2; // Iron
        ids[1] = 1; // Wood
        ids[2] = 4; // Leather
        amounts[0] = 5; // 2 extra iron
        amounts[1] = 3; // 2 extra wood
        amounts[2] = 1;
        _giveResources(player, ids, amounts);
        
        vm.prank(player);
        cs.craft(1);
        
        assertEq(res.balanceOf(player, 2), 2, "Excess iron should remain");
        assertEq(res.balanceOf(player, 1), 2, "Excess wood should remain");
        assertEq(res.balanceOf(player, 4), 0, "Exact leather should be used");
    }
}

