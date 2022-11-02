import * as dotenv from 'dotenv'

import { HardhatUserConfig } from 'hardhat/config'
import '@nomiclabs/hardhat-etherscan'
import '@nomiclabs/hardhat-waffle'
import '@typechain/hardhat'
import 'hardhat-gas-reporter'
import 'hardhat-abi-exporter'
import 'hardhat-deploy'
import 'hardhat-deploy-ethers'
import 'solidity-coverage'
import './tasks'

dotenv.config()

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.9',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },

  namedAccounts: {
    deployer: 0
  },

  networks: {
    localhost: {
      url: 'http://localhost:8545',
      accounts: [
        '0x3e139eae34f41cecf4b4adccbeaa3a51c0b05c695733d8416df121b5b6d5e79b'
      ]
    },
    mumbai: {
      url: 'https://polygon-mumbai.g.alchemy.com/v2/5E3uKzM68Q7UH_13K8FXajwvNSf0-vAq',
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : []
    },
    polygon: {
      url: 'https://polygon-mainnet.g.alchemy.com/v2/jTV72NyhEAhoLQHDaEE4ReaXL-8ecyRC',
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : []
    }
  },

  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: 'USD'
  },

  etherscan: {
    apiKey: {
      polygon: process.env.POLYGON_API_KEY || '',
      polygonMumbai: process.env.POLYGON_API_KEY || ''
    }
  },

  abiExporter: [
    {
      path: './abi/pretty',
      pretty: true
    },
    {
      path: './abi/ugly',
      pretty: false
    }
  ],

  typechain: {
    outDir: 'typechain',
    target: 'ethers-v5',
    alwaysGenerateOverloads: false, // should overloads with full signatures like deposit(uint256) be generated always, even if there are no overloads?
    externalArtifacts: ['externalArtifacts/*.json'] // optional array of glob patterns with external artifacts to process (for example external libs from node_modules)
  }
}

export default config
