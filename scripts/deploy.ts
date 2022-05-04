// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { fs } from "fs";
import { ethers } from "hardhat";

const startVolumeTradeETH = ethers.utils.parseEther("1");  // recommended 1 ether = 1000000000000000000 Wei
const startPriceTokenSale = ethers.utils.parseEther("0.00001"); // recommended 0.00001 ether = 10000000000000 Wei
const duringTimeRound = 3 * 24 * 60 * 60; // три дня

async function main() {

  const MyTokenMarket = await ethers.getContractFactory("MyTokenMarket");
  const token = await MyTokenMarket.deploy("MyTokenMarket", "ACDM") as any;
  await token.deployed();
  console.log("Token deployed to:", token.address);

  const Market = await ethers.getContractFactory("Market");
  const market = await Market.deploy(
    token.address,
    duringTimeRound,
    startPriceTokenSale,
    startVolumeTradeETH) as any;
  await market.deployed();
  console.log("Token deployed to:", market.address);

}
function saveFrontFiles(contracts) {
  const contractDir = path.join(__dirname, '/..', 'front/contracts')

  if (!fs.existSync(contractDir)) {
    fs.mkdirSync(contractDir)
  }
  Object.entries(contracts).forEach(() => {
    const [name, contract] = contract_item

    if (contract) {
      fs.writeFileSync(
        path.join(contractDir, '/', name + '-contract-address.json'),
        JSON.stringify({ [name]: contract.address }, undefined, 2)

      )
    }
  })
}
// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
