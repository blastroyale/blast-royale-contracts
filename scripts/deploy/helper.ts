import fs from "fs";
import path from "path";

export const writeAddress = (network: string, params: any) => {
  const PROJECT_ROOT = path.resolve(__dirname, "../..");
  const DEPLOYMENT_PATH = path.resolve(PROJECT_ROOT, "deployments");
  const networkFolderPath = path.resolve(DEPLOYMENT_PATH, network);

  fs.mkdirSync(networkFolderPath, { recursive: true });
  const filePath = path.resolve(networkFolderPath, "address.json");
  let addresses = {};
  if (fs.existsSync(filePath)) {
    addresses = JSON.parse(
      fs.readFileSync(filePath, {
        encoding: "utf8",
        flag: "r",
      })
    );
  }
  fs.writeFileSync(
    filePath,
    JSON.stringify(Object.assign(addresses, params), null, 2)
  );
};

export const getAddress = (network: string) => {
  const PROJECT_ROOT = path.resolve(__dirname, "../..");
  const DEPLOYMENT_PATH = path.resolve(PROJECT_ROOT, "deployments");
  const networkFolderPath = path.resolve(DEPLOYMENT_PATH, network);
  const filePath = path.resolve(networkFolderPath, "address.json");

  const addresses = JSON.parse(
    fs.readFileSync(filePath, {
      encoding: "utf8",
      flag: "r",
    })
  );
  return addresses;
};
