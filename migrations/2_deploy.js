const NFTDescriptor = artifacts.require("NFTDescriptor");
const LuvNFT = artifacts.require("LuvNFT");

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(NFTDescriptor);
  await deployer.link(NFTDescriptor, LuvNFT);
  await deployer.deploy(LuvNFT, { gas: 10000000 });
  const luvNft = await LuvNFT.deployed();
  console.log(luvNft.address);
};
