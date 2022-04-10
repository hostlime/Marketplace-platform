// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MyTokenMarket is ERC20, AccessControl {

    bytes32 public constant MARKET_ROLE = keccak256("MARKET_ROLE");

    //constructor() ERC20("MyTokenMarket", "MTK") {}
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MARKET_ROLE, msg.sender);
        //_mint(msg.sender, 1000_000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external onlyRole(MARKET_ROLE) {
        _mint(to, amount);
    }
    function burn(address user, uint256 amount) external onlyRole(MARKET_ROLE) {
        _burn(user, amount);
    }
}