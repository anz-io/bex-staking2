import { ethers, upgrades } from "hardhat"
import "dotenv/config"
import { BONX, BondingsCore, MockUSDT } from "../typechain-types"

async function main() {
  const testMode = true
  
  const adminAddress = process.env.ADDRESS_ADMIN!
  const mUSDSTAddress = process.env.MOCK_USDT!
  const treasuryAddress = process.env.ADDRESS_TREASURY!

  // const mUSDT = await deployMockUSDT()
  // console.log("\x1b[0mMockUSDT deployed to:\x1b[32m", await mUSDT.getAddress())

  const bonxNFT = await deployBONX(
    adminAddress, mUSDSTAddress, treasuryAddress, testMode
  )
  console.log("\x1b[0mBONX deployed to:\x1b[32m", await bonxNFT.getAddress())

  const bondingsCore = await deployBondingsCore(
    adminAddress, mUSDSTAddress, treasuryAddress, testMode
  )
  console.log("\x1b[0mBondingsCore deployed to:\x1b[32m", await bondingsCore.getAddress())
}

async function deployMockUSDT() {
  return (await ethers.deployContract("MockUSDT")) as MockUSDT
}

async function deployBONX(backendSigner: string, tokenAddress: string, treasuryAddress: string, testMode: boolean) {
  const bonxNFTContractName = testMode ? "BONXTest" : "BONX"
  const bonxNFTFactory = await ethers.getContractFactory(bonxNFTContractName)
  const bonxNFT = await upgrades.deployProxy(
    bonxNFTFactory, [backendSigner, tokenAddress, treasuryAddress]
  )
  return (bonxNFT as unknown as BONX)
}

async function deployBondingsCore(backendSigner: string, tokenAddress: string, treasuryAddress: string, testMode: boolean) {
  const bondingsCoreContractName = testMode ? "BondingsCoreTest" : "BondingsCore"
  const bondingsCoreFactory = await ethers.getContractFactory(bondingsCoreContractName)
  const bondingsCore = await upgrades.deployProxy(
    bondingsCoreFactory, [backendSigner, tokenAddress, treasuryAddress]
  )
  return (bondingsCore as unknown as BondingsCore)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });