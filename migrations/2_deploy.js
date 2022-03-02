const NFTDescriptor = artifacts.require("NFTDescriptor");
const LuvNFT = artifacts.require("LuvNFT");
const Auction = artifacts.require("NFTAuction");

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(NFTDescriptor);
  await deployer.deploy(LuvNFT, { gas: 10000000 });
  await deployer.link(NFTDescriptor, Auction);
  await LuvNFT.deployed();
  await deployer.deploy(
    Auction,
    LuvNFT.address,
    "0xfed7ade2bf5d99934e0f5a991f1ea3d89a444885"
  );
};
