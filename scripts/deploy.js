// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  // const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  // const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
  // const unlockTime = currentTimestampInSeconds + ONE_YEAR_IN_SECS;

  // const lockedAmount = hre.ethers.utils.parseEther("1");
  // below is salvacoin dividend coin deployed on matic

  // const MyToken = await hre.ethers.getContractFactory("SalvaCoin");
  // const myToken = await MyToken.deploy();
  // await myToken.deployed();
  // console.log(
  //   `SalvaCoin contract deployed to ${myToken.address}`
  // );


  const SalvaICO = await hre.ethers.getContractFactory("SalvaICO");


  await getDeploymentCost(SalvaICO);


  const ico = await SalvaICO.deploy();
  await ico.deployed();
  console.log(
    `ICO contract deployed to ${ico.address}`
  );

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});


async function getDeploymentCost(SalvaICO,) {
  const gasPrice = await SalvaICO.signer.getGasPrice();
  console.log(`Current gas price ${gasPrice}`);

  const estimateGas = await SalvaICO.signer.estimateGas(
    SalvaICO.getDeployTransaction()
  );

  console.log(`Estimaged gas: ${estimateGas}`);

  const deploymentPrice = gasPrice.mul(estimateGas);

  const deployerBalance = await SalvaICO.signer.getBalance();
  console.log(
    `Deployer balance: ${ethers.utils.formatEther(deployerBalance)}`
  );
  console.log(
    `Deployment price: ${ethers.utils.formatEther(deploymentPrice)}`
  );

  if (Number(deployerBalance) < Number(deploymentPrice)) {
    throw new Error("You don't have enough balance to deploy this contract.");
  }
}

