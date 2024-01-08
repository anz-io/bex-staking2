import { ethers, upgrades } from "hardhat"
import "dotenv/config"
import { BONX, BexCore, MockUSDT } from "../typechain-types"

async function main() {
  const testMode = true
  
  const adminAddress = process.env.ADDRESS_ADMIN!
  const mUSDSTAddress = process.env.MOCK_USDT!

  // const mUSDT = await deployMockUSDT()
  // console.log("\x1b[0mMockUSDT deployed to:\x1b[32m", await mUSDT.getAddress())

  const bonxNFT = await deployBONX(mUSDSTAddress)
  console.log("\x1b[0mBONX deployed to:\x1b[32m", await bonxNFT.getAddress())

  const bexCore = await deployBexCore(
    adminAddress, mUSDSTAddress, testMode
  )
  console.log("\x1b[0mBexCore deployed to:\x1b[32m", await bexCore.getAddress())
}

async function deployMockUSDT() {
  return (await ethers.deployContract("MockUSDT")) as MockUSDT
}

async function deployBONX(tokenAddress: string) {
  const bonxNFTFactory = await ethers.getContractFactory('BONX')
  const bonxNFT = await upgrades.deployProxy(
    bonxNFTFactory, [tokenAddress]
  )
  return (bonxNFT as unknown as BONX)
}

async function deployBexCore(backendSigner: string, tokenAddress: string, testMode: boolean) {
  const bexCoreContractName = testMode ? "BexCoreTest" : "BexCore"
  const bexCoreFactory = await ethers.getContractFactory(bexCoreContractName)
  const bexCore = await upgrades.deployProxy(
    bexCoreFactory, [backendSigner, tokenAddress]
  )
  return (bexCore as unknown as BexCore)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });