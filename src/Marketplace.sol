// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ItemNFT721} from "./ItemNFT721.sol";
import {MagicToken} from "./MagicToken.sol";

/**
 * @title Marketplace
 * @notice Marketplace for trading ERC721 items for MAGIC tokens
 * @dev Items are burned on purchase, and MAGIC tokens are minted to the seller
 */
contract Marketplace is AccessControl {
    ItemNFT721 public items;
    MagicToken public magic;

    struct Listing {
        address seller;
        uint256 price;
        bool active;
    }

    mapping(uint256 => Listing) public listings;

    event ItemListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event ItemDelisted(uint256 indexed tokenId, address indexed seller);
    event ItemPurchased(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price);

    constructor(address admin, ItemNFT721 _items, MagicToken _magic) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        items = _items;
        magic = _magic;
    }

    /// @notice List an item for sale
    /// @param tokenId The ID of the item to list
    /// @param price The price in MAGIC tokens
    function list(uint256 tokenId, uint256 price) external {
        require(price > 0, "Price must be greater than 0");
        
        require(items.ownerOf(tokenId) == msg.sender, "Not the owner of this item");
        
        require(!listings[tokenId].active, "Item already listed");
        
        listings[tokenId] = Listing({
            seller: msg.sender,
            price: price,
            active: true
        });
        
        emit ItemListed(tokenId, msg.sender, price);
    }

    /// @notice Remove an item from sale
    /// @param tokenId The ID of the item to delist
    function delist(uint256 tokenId) external {
        require(listings[tokenId].active, "Item not listed");
    
        require(listings[tokenId].seller == msg.sender, "Not the seller");
        
        listings[tokenId].active = false;
        emit ItemDelisted(tokenId, msg.sender);
    }

    /// @notice Purchase a listed item
    /// @param tokenId The ID of the item to purchase
    function purchase(uint256 tokenId) external {
        require(listings[tokenId].active, "Item not listed");
        
        Listing memory listing = listings[tokenId];
        
        require(items.ownerOf(tokenId) == listing.seller, "Seller no longer owns item");
        
        listings[tokenId].active = false;
        items.burn(tokenId);
        magic.mint(listing.seller, listing.price);
        emit ItemPurchased(tokenId, msg.sender, listing.seller, listing.price);
    }
}
