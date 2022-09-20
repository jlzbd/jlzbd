// SPDX-License-Identifier: FlowerFalconLLC
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract TokenA is ERC20, ERC20Burnable, Pausable, Ownable {
    constructor() ERC20("TokenA", "TKA") {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }
    
    // Self destruct function
    function destroyContract() public onlyOwner payable {
        address payable addr = payable(address(this));
        selfdestruct(addr);
    }
}

