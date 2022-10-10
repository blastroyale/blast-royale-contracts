import fs from 'fs'
import path from 'path'
import axios from 'axios'
import ethers from 'ethers'
import { MerkleTree } from 'merkletreejs'
import TokenArgs from '../constants/TokenArgs.json'

const TOKEN_ARGS: any = TokenArgs

const WHITELIST_SHEET_ID =
  process.env.WHITELIST_SHEET_ID ||
  '1MMJ9Rt6zk6Qpquar1Z2Q9cuBTVGbKtQRuIDgZGzO_Hg'

export const writeAddress = (network: string, params: any) => {
  const PROJECT_ROOT = path.resolve(__dirname, '..')
  const DEPLOYMENT_PATH = path.resolve(PROJECT_ROOT, 'deployments')
  const networkFolderPath = path.resolve(DEPLOYMENT_PATH, network)

  fs.mkdirSync(networkFolderPath, { recursive: true })
  const filePath = path.resolve(networkFolderPath, 'address.json')
  let addresses = {}
  if (fs.existsSync(filePath)) {
    addresses = JSON.parse(
      fs.readFileSync(filePath, {
        encoding: 'utf8',
        flag: 'r'
      })
    )
  }
  fs.writeFileSync(
    filePath,
    JSON.stringify(Object.assign(addresses, params), null, 2)
  )
}

export const getAddress = (network: string) => {
  const PROJECT_ROOT = path.resolve(__dirname, '../..')
  const DEPLOYMENT_PATH = path.resolve(PROJECT_ROOT, 'deployments')
  const networkFolderPath = path.resolve(DEPLOYMENT_PATH, network)
  const filePath = path.resolve(networkFolderPath, 'address.json')

  const addresses = JSON.parse(
    fs.readFileSync(filePath, {
      encoding: 'utf8',
      flag: 'r'
    })
  )
  return addresses
}

export const getContractArguments = (network: string, contractName: string) => {
  return TOKEN_ARGS[contractName][network]
}

const googleSheetLoadfromUrl = async (sheetNameParam = 'Whitelist') => {
  const base = `https://docs.google.com/spreadsheets/d/${WHITELIST_SHEET_ID}/gviz/tq?`
  const sheetName = sheetNameParam
  const query = encodeURIComponent('Select *')
  const url = `${base}&sheet=${sheetName}&tq=${query}`
  console.log(url)

  try {
    const { data: json } = await axios.get(url)
    const data: any = []
    // Remove additional text and extract only JSON:
    const jsonData = JSON.parse(json.substring(47).slice(0, -2))

    // extract row data:
    jsonData.table.rows.forEach((rowData: any) => {
      const row = rowData.c[0] != null ? rowData.c[0].v : ''
      data.push(row)
    })
    return data
  } catch (error) {
    console.log(error)
    return []
  }
}

const getWLUserList = async () => {
  const list = await googleSheetLoadfromUrl()
  return list.filter((wallet: any) => ethers.utils.isAddress(wallet))
}

const getWLLuckyUserList = async () => {
  const list = await googleSheetLoadfromUrl('WLLucky')
  return list.filter((wallet: any) => ethers.utils.isAddress(wallet))
}

export const getMerkleRoots = async () => {
  const whitelist = await getWLUserList()
  const luckyWhitelist = await getWLLuckyUserList()
  if (!whitelist) return
  if (!luckyWhitelist) return

  const leaves = await Promise.all(
    whitelist.map(async (address: string) => {
      return ethers.utils.keccak256(address)
    })
  )

  const luckyLeaves = await Promise.all(
    luckyWhitelist.map(async (address: string) => {
      return ethers.utils.keccak256(address)
    })
  )

  const tree = new MerkleTree(leaves, ethers.utils.keccak256, {
    sortPairs: true
  })
  const merkleRoot = tree.getHexRoot()

  const luckyTree = new MerkleTree(luckyLeaves, ethers.utils.keccak256, {
    sortPairs: true
  })
  const luckyMerkleRoot = luckyTree.getHexRoot()

  return { merkleRoot, luckyMerkleRoot }
}
