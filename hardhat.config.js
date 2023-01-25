require("@nomicfoundation/hardhat-toolbox");
// require("@openzeppelin/hardhat-upgrades");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  defaultNetwork: "hardhat",
  solidity: "0.8.17",
  networks: {
    hardhat: {
      forking: {
        url: `https://mainnet.infura.io/v3/${process.env.RPC}`,
        // blockNumber: 15618886,
      },
    },
    matic: {
      url: "https://rpc-mumbai.maticvigil.com",
      accounts: [process.env.KEY],
    },
  },

  etherscan: {
    apiKey: process.env.SCAN,
  },
};
