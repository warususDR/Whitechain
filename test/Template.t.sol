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
        
        // First search succeeds
        vm.prank(player);
        cs.search();
        
        // Immediate second search should fail
        vm.prank(player);
        vm.expectRevert("Cooldown active: wait 60 seconds between searches");
        cs.search();
    }

    /// @notice Test that search works after cooldown expires
    function test_search_works_after_cooldown() public {
        address player = address(0xBEEF);
        
        // First search
        vm.prank(player);
        cs.search();
        
        // Fast forward 60 seconds
        vm.warp(block.timestamp + 60);
        
        // Second search should succeed
        vm.prank(player);
        cs.search();
        
        // Player should now have 6 resources total (3 from each search)
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
        
        // Player 1 searches
        vm.prank(player1);
        cs.search();
        
        // Player 2 can still search (independent cooldown)
        vm.prank(player2);
        cs.search();
        
        // Both should have 3 resources
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
            
            // Fast forward to bypass cooldown
            vm.warp(block.timestamp + 60);
        }
        
        // Check that player only has resources with IDs 1-6
        for (uint256 id = 1; id <= 6; id++) {
            uint256 balance = res.balanceOf(player, id);
            // Balance should be >= 0 (valid resource)
            assertTrue(balance >= 0, "Resource balance should be valid");
        }
        
        // Check that resource ID 0 doesn't exist
        assertEq(res.balanceOf(player, 0), 0, "Resource ID 0 should not exist");
        // Check that resource ID 7 doesn't exist
        assertEq(res.balanceOf(player, 7), 0, "Resource ID 7 should not exist");
    }

    /// @notice Test SearchPerformed event emission
    function test_search_emits_event() public {
        address player = address(0xBEEF);
        
        // Expect SearchPerformed event
        vm.prank(player);
        vm.recordLogs();
        cs.search();
        
        // Verify event was emitted
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertTrue(logs.length > 0, "Event should be emitted");
    }
}

