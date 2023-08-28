// SPDX-License-Identifier: MIT
  pragma solidity 0.8.18;

  import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
  import "@openzeppelin/contracts/access/Ownable.sol";

  contract FrontDoorToken is ERC20, Ownable {
    
      // the max total supply is 10000000 for FrontDoor Tokens
      uint256 public constant maxTotalSupply = 10000000 * 10**18;

      constructor() ERC20("FroontDoor Token", "FNDR") {
        _mint(msg.sender, maxTotalSupply);
      }

  }