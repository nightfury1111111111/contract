// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.8.0;
pragma experimental ABIEncoderV2;

// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.2.0/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LuvNFT is ERC721, Ownable {
    constructor() public ERC721("LUVNFT", "LUV") {}

    uint256 public nextId = 0;

    mapping(uint256 => bool) public tokenIdIsExist;

    //mint new NFT to create new asset.
    function mint(string memory tokenURI) public onlyOwner {
        _mint(msg.sender, nextId);
        _setTokenURI(nextId, tokenURI);
        tokenIdIsExist[nextId]=true;
        nextId++;
    }
}
