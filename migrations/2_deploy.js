const NFTDescriptor = artifacts.require("NFTDescriptor");
const LuvNFT = artifacts.require("LuvNFT");
const Auction = artifacts.require("NFTAuction");

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(NFTDescriptor);
  await deployer.link(NFTDescriptor, LuvNFT);
  await deployer.deploy(LuvNFT, { gas: 10000000 });
  await LuvNFT.deployed();
  await deployer.deploy(Auction, LuvNFT.address);
};
