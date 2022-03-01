const IterableMapping = artifacts.require("IterableMapping");
const NFTDescriptor = artifacts.require("NFTDescriptor");
const LuvNFT = artifacts.require("LuvNFT");

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(IterableMapping);
  await deployer.link(IterableMapping, LuvNFT);
  await deployer.deploy(NFTDescriptor);
  await deployer.link(NFTDescriptor, LuvNFT);
  await deployer.deploy(LuvNFT, { gas: 10000000 });
  await LuvNFT.deployed();
};
