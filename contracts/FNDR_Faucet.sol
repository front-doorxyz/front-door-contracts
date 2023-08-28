// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FNDR_Faucet is Ownable {
    // FNDR token address
    address public FNDRAddress;

    mapping (address => uint) lastRequest;
    constructor(address _ERC20Address) {
        FNDRAddress = _ERC20Address;
    }

    function request (uint _amount) external {
        require (lastRequest[msg.sender] + 1 days < block.timestamp, "You can only request once per day");
        require (IERC20(FNDRAddress).balanceOf(address(this)) >= _amount, "Not enough tokens in the faucet");
        lastRequest[msg.sender] = block.timestamp;
        IERC20(FNDRAddress).transfer(msg.sender, _amount);
    }
}
