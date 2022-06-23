import fs from "fs";
import path from "path";
import { ethers } from "hardhat";
import { MerkleTree } from "merkletreejs";

export const writeAddress = (params: any) => {
  const filePath = path.resolve(__dirname, "../address.json");
  const addresses = JSON.parse(
    fs.readFileSync(filePath, {
      encoding: "utf8",
      flag: "r",
    })
  );
  fs.writeFileSync(filePath, JSON.stringify(Object.assign(addresses, params)));
};

export const getAddress = () => {
  const filePath = path.resolve(__dirname, "../address.json");
  const addresses = JSON.parse(
    fs.readFileSync(filePath, {
      encoding: "utf8",
      flag: "r",
    })
  );
  return addresses;
};


export const getMerkleRoots = async () => {
const _whitelist = fs.readFileSync("./scripts/WL.json", {
    encoding: "utf8",
    flag: "r",
  });
  const whiltelist = JSON.parse(_whitelist);
  if (!whiltelist) return;
  
  const _luckyWhitelist = fs.readFileSync("./scripts/luckyWL.json", {
    encoding: "utf8",
    flag: "r",
  });
  const luckyWhitelist = JSON.parse(_luckyWhitelist);
  if (!luckyWhitelist) return;

    const leaves = await Promise.all(
        whiltelist.map(async (address:string) => {
            return ethers.utils.keccak256(address);
        })
    ); 

    const luckyLeaves = await Promise.all(
        luckyWhitelist.map(async (address:string) => {
            return ethers.utils.keccak256(address);
        })
    );
    
    const tree = new MerkleTree(leaves, ethers.utils.keccak256, {
      sortPairs: true,
    });
    const merkleRoot = tree.getHexRoot();
    console.log("merkleRoot: ",merkleRoot)

    const luckyTree = new MerkleTree(luckyLeaves, ethers.utils.keccak256, {
      sortPairs: true,
    });
    const luckyMerkleRoot = luckyTree.getHexRoot();
    console.log("luckyMerkleRoot: ",luckyMerkleRoot)

    return {merkleRoot,luckyMerkleRoot}
};

export const writeMerkleRoots = (params: any) => {
  const filePath = path.resolve(__dirname, "../merkleRoots.json");
  const merkleRoots = JSON.parse(
    fs.readFileSync(filePath, {
      encoding: "utf8",
      flag: "r",
    })
  );
  fs.writeFileSync(filePath, JSON.stringify(Object.assign(merkleRoots, params)));
};