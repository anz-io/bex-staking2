import { loadFixture, time } from "@nomicfoundation/hardhat-toolbox/network-helpers"
import { expect } from "chai"
import { ethers, upgrades } from "hardhat"
import { BONX, BondingsCore } from "../typechain-types"
import { Contract, Signer } from "ethers"

const testnetMode = true
const bondingContractName = testnetMode ? 'BondingsCoreTest' : 'BondingsCore'
const bonxNFTContractName = testnetMode ? 'BONXTest' : 'BONX'

function connectbondingsCore(bondingsCore: Contract, signer: Signer) {
  return bondingsCore.connect(signer) as BondingsCore
}

function connectBonxNFT(bonxNFT: Contract, signer: Signer) {
  return bonxNFT.connect(signer) as BONX
}

function nowTime() {
  return parseInt((Date.now() / 1000).toString())
}

async function getSig(signer: Signer) {
  return await signer.signMessage('test message' + nowTime())
}

describe("test the functions related to assets management", function () {

  async function deployAssets() {
    const [admin, carol, david, signer] = await ethers.getSigners()

    // Deploy contracts
    const mockUSDT = await ethers.deployContract('MockUSDT')
    const bonxNFTFactory = await ethers.getContractFactory(bonxNFTContractName)
    const bonxNFT = await upgrades.deployProxy(
      bonxNFTFactory, [signer.address, await mockUSDT.getAddress()]
    )

    const bondingsCoreFactory = await ethers.getContractFactory(bondingContractName)
    const bondingsCore = await upgrades.deployProxy(
      bondingsCoreFactory, [signer.address, await mockUSDT.getAddress()]
    )
    const bondingsCoreAddress = await bondingsCore.getAddress()

    // Mint Tokens to Carol & David
    const amount = ethers.parseUnits('40000', 6)
    await mockUSDT.transfer(carol.address, amount)
    await mockUSDT.transfer(david.address, amount)
    await mockUSDT.connect(carol).approve(bondingsCoreAddress, amount)
    await mockUSDT.connect(david).approve(bondingsCoreAddress, amount)
    
    return { admin, carol, david, bondingsCore, mockUSDT, bonxNFT }
  }


  it("should deploy the contract correctly", async function () {
    await loadFixture(deployAssets)
  })


  it("should finish user journey", async function () {
    const { admin, carol, david, bondingsCore, mockUSDT, bonxNFT } = await loadFixture(deployAssets)

    const bondingsCoreAdmin = connectbondingsCore(bondingsCore, admin)
    const bondingsCoreCarol = connectbondingsCore(bondingsCore, carol)
    const bondingsCoreDavid = connectbondingsCore(bondingsCore, david)
    const bonxNFTAdmin = connectBonxNFT(bonxNFT, admin)
    const bonxNFTCarol = connectBonxNFT(bonxNFT, carol)

    // Carol register a new bonx "hello"
    const name = 'hello'
    await bondingsCoreCarol.register(name, nowTime(), await getSig(carol))
    
    // Carol buy 10 bondings, David buy 5 bondings
    await bondingsCoreCarol.buyBondings(name, 9, 10000)    // expected: 2850 * 103%
    await bondingsCoreDavid.buyBondings(name, 5, 10000)     // expected: 7300 * 103%
    await bondingsCoreCarol.sellBondings(name, 7, 8000)     // expected: 8750 * 97%
    
    expect(await mockUSDT.balanceOf(carol.address)).to.equal
      ('40000005553')     // 40000_000000 - 2935(.5) + 8488(-.5) = 40000005553
    expect(await mockUSDT.balanceOf(david.address)).to.equal
      ('39999992481')     // 40000_000000 - 7300   = 39999992481.0
    
    // Mint limit
    await expect(bondingsCoreCarol.buyBondings(name, 11, 50000))
      .to.be.revertedWith("Exceed mint limit in stage 1!")

    // Award the winner
    await bonxNFTAdmin.safeMint(carol.address, name)
    expect(await bonxNFTAdmin.ownerOf(1)).to.equal(carol.address)
    expect(await bonxNFTAdmin.getNextTokenId()).to.equal(2)
    await bonxNFTCarol.transferFrom(carol.address, david.address, 1)
    expect(await bonxNFTAdmin.ownerOf(1)).to.equal(david.address)
    await bonxNFTAdmin.retrieveNFT(1)
    expect(await bonxNFTAdmin.ownerOf(1)).to.equal(admin.address)

    // Claim fees
    expect(await bondingsCoreAdmin.feeCollected()).to.equal
      ('566')             // 2850 * 3% + 7300 * 3% + 8750 * 3% = 85(.5) + 219 + 262(.5) = 566
    await bondingsCoreAdmin.claimFees()
    expect(await mockUSDT.balanceOf(admin.address)).to.equal
      ('920000000566')    // 1000000_000000 - 40000_000000 - 40000_000000 + 566
    expect(await bondingsCoreAdmin.feeCollected()).to.equal('0')
  })


  it("should process correctly at stage 1/2/3", async function () {
    const { admin, carol, david, bondingsCore, mockUSDT, bonxNFT } = await loadFixture(deployAssets)

    const bondingsCoreAdmin = connectbondingsCore(bondingsCore, admin)
    const bondingsCoreCarol = connectbondingsCore(bondingsCore, carol)
    const bondingsCoreDavid = connectbondingsCore(bondingsCore, david)

    // Carol register a new bonx "hello"
    const name = 'hello'
    await bondingsCoreCarol.register(name, nowTime(), await getSig(carol))
    
    // Carol buy 50 bonding and sell 10
    for (let i = 0; i < 4; i++) {
      await bondingsCoreCarol.buyBondings(name, 10, 400000)    
      // expected total: [2935.5, 22505.5, 62675.5, 123445.5, 204815.5]
    }

    await bondingsCoreCarol.buyBondings(name, 9, 400000)    
    expect(await mockUSDT.balanceOf(carol.address)).to.equal
      ('39999583625')    // 40000_000000 - 416375(+2.5) = 39999583623 
    
    await expect(bondingsCoreCarol.buyBondings(name, 10, 400000)).to.be
      .revertedWith("Exceed hold limit in stage 1!")
    await bondingsCoreCarol.sellBondings(name, 10, 10000)      // expected total: 198850 * 97%
    expect(await mockUSDT.balanceOf(carol.address)).to.equal
      ('39999776510')    // 39999583625 + 192885(-.5) = 39999776510

    // Change mint limit and hold limit
    await bondingsCoreAdmin.setHoldLimit(100)
    await bondingsCoreAdmin.setMintLimit(100)
    await bondingsCoreAdmin.setRestrictedSupply(100)

    // David buy 70 bonding
    await bondingsCoreDavid.buyBondings(name, 70, 5000000)      // expected total: 4170950 * 103%
    expect(await mockUSDT.balanceOf(david.address)).to.equal
      ('39995703922')    // 40000_000000 - 4296078(.5) = 39995703922
    expect(await bondingsCoreDavid.bondingsTotalShare(name)).to.equal('110')

    // Carol buy 500 bonding
    await bondingsCoreCarol.buyBondings(name, 500, 800_000000)   // expected total: 750367500 * 103%
    expect(await mockUSDT.balanceOf(carol.address)).to.equal
      ('39226897985')    // 39999_776510 - 772_878525 = 39226897985
    
    // console.log("collected fee: ", await bondingsCoreAdmin.feeCollected())
  })

})