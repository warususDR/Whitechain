// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title MagicToken
 * @notice ERC20 token used as currency in the Cossack Business marketplace
 * @dev Tokens can only be minted by Marketplace contract on successful sales
 */
contract MagicToken is ERC20, AccessControl {
    bytes32 public constant MARKET_ROLE = keccak256("MARKET_ROLE");

    constructor(address admin) ERC20("Magic Token", "MAGIC") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @notice Mint MAGIC tokens to an address
    /// @param to The address to receive the minted tokens
    /// @param amount The amount of tokens to mint
    /// @dev Only callable by addresses with MARKET_ROLE (Marketplace)
    function mint(address to, uint256 amount) external onlyRole(MARKET_ROLE) {
        _mint(to, amount);
    }
}
