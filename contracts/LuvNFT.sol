pragma solidity >=0.4.22 <0.8.0;
pragma experimental ABIEncoderV2;

// import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.2.0/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./GenerativeNFT.sol";

contract LuvNFT is ERC721, Ownable {
    constructor() public ERC721("LUVNFT", "LUV") {}

    uint256 public nextId = 0;

    mapping(uint256 => uint256) public tokenIdToPrice;
    mapping(uint256 => bool) public tokenIdIsExist;

    event NftPriceChanged(uint256 tokenId, uint256 price);

    //mint new NFT to create new asset.
    function mint(string memory tokenURI, uint256 price) public onlyOwner {
        tokenIdToPrice[nextId] = price; //1 ONE=1e18 wei
        _mint(msg.sender, nextId);
        _setTokenURI(nextId, tokenURI);
        tokenIdIsExist[nextId]=true;
        nextId++;
    }

    //get the price of NFT
    function getPriceOf(uint256 tokenId) public view returns (uint256) {
        return tokenIdToPrice[tokenId];
    }

    //set the price of NFT:only owner can set this.
    function setPriceOf(uint256 tokenId, uint256 price) public {
        require(
            ownerOf(tokenId) == msg.sender,
            "Only owner of NFT can set price"
        );
        tokenIdToPrice[tokenId] = price;
        emit NftPriceChanged(tokenId, price);
    }

    //get the owner of NFT
    function getOwnerOf(uint256 tokenId) public view returns (address) {
        return ownerOf(tokenId);
    }

    //get the detail info of NFT
    function getTokenInfo(uint256 tokenId) public view returns (string memory) {
        return tokenURI(tokenId);
    }

    //create svg file automatically.
    function getSVG(
        uint256 tokenId,
        string memory latitude,
        string memory longitude,
        string memory name
    ) public view returns (string memory) {
        return
            NFTDescriptor.constructTokenURI(
                NFTDescriptor.URIParams({
                    tokenId: tokenId,
                    blockNumber: block.number,
                    latitude: latitude,
                    longitude: longitude,
                    name: name
                })
            );
    }
}
