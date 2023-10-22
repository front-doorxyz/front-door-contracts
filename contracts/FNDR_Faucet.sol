// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function mint(address to, uint256 amount) external;
}

contract FNDR_Faucet is Ownable {
    // FNDR token address
    address public FNDRAddress;

    mapping(address => uint) lastRequest;

    constructor(address _ERC20Address) {
        FNDRAddress = _ERC20Address;
    }

    function requestTokens(uint _amount) external {
        require(
            lastRequest[msg.sender] + 1 days < block.timestamp,
            "You can only request once per day"
        );

        lastRequest[msg.sender] = block.timestamp;
        IERC20(FNDRAddress).mint(msg.sender, _amount);
        emit TokensTransfered(msg.sender, _amount);
    }

    event TokensTransfered(address indexed user, uint256 amount);
}
