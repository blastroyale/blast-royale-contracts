import fs from "fs";
import path from "path";

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
