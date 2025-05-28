// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract InscriptionToken is ERC20 {
    uint256 public maxSupply;
    uint256 public perMint;
    uint256 public price;
    address public factory;
    string private _tokenSymbol;

    constructor() ERC20("Inscription", "TEMP") {
        // Disable direct initialization
        maxSupply = 0;
        perMint = 0;
        price = 0;
        factory = address(0);
    }

    function initialize(
        string memory _symbol,
        uint256 _maxSupply,
        uint256 _perMint,
        uint256 _price,
        address _factory
    ) external {
        require(factory == address(0), "Already initialized");
        _tokenSymbol = _symbol;
        maxSupply = _maxSupply;
        perMint = _perMint;
        price = _price;
        factory = _factory;
    }

    function symbol() public view override returns (string memory) {
        return _tokenSymbol;
    }

    function name() public view override returns (string memory) {
        return string(abi.encodePacked("Inscription ", _tokenSymbol));
    }

    function mint(address to) external {
        require(msg.sender == factory, "Only factory can mint");
        require(totalSupply() + perMint <= maxSupply, "Exceeds max supply");
        
        _mint(to, perMint);
        // Auto-approve factory for transfers
        _approve(to, factory, perMint);
    }
}
