import { loadFixture, time } from "@nomicfoundation/hardhat-toolbox/network-helpers"
import { expect } from "chai"
import { ethers, upgrades } from "hardhat"

const testnetMode = true
const contractName = testnetMode ? 'BexCoreTest' : 'BexCore'

describe("test the functions related to assets management", function () {

  async function deployAssets() {
    const [admin, carol, david, signer] = await ethers.getSigners()

    // Deploy contracts
    const MockUSDT = await ethers.deployContract('MockUSDT')
    const BonxNFT = await ethers.deployContract('BONX')

    const tokenAddress = await MockUSDT.getAddress()
    const bonxAddress = await BonxNFT.getAddress()

    const BexCoreFactory = await ethers.getContractFactory(contractName)
    const BexCore = await upgrades.deployProxy(
      BexCoreFactory, [signer.address, tokenAddress, bonxAddress]
    )
    // const BexCore = await BexCoreFactory.deploy(
    //   signer.address, tokenAddress, bonxAddress
    // )

    // Mint Tokens to Carol & David
    const amount = ethers.parseEther('40000')
    await MockUSDT.transfer(carol.address, amount)
//     await MasterToken.mint(david.address, amount)
//     await MasterToken.connect(carol).approve(await Assets.getAddress(), amount)
//     await MasterToken.connect(david).approve(await Assets.getAddress(), amount)

//     // Mint FunctionBot NFT to Carol & David
//     await FunctionBot.safeMint(carol.address, "")   // #0
//     await FunctionBot.safeMint(carol.address, "")   // #1
//     await FunctionBot.safeMint(carol.address, "")   // #2
//     await FunctionBot.safeMint(david.address, "")   // #3
//     await FunctionBot.connect(carol).approve(await Assets.getAddress(), 0)
//     await FunctionBot.connect(carol).approve(await Assets.getAddress(), 1)
//     await FunctionBot.connect(carol).approve(await Assets.getAddress(), 2)
//     await FunctionBot.connect(david).approve(await Assets.getAddress(), 3)

//     return { MasterToken, FunctionBot, Assets, owner, carol, david }
  }

  it("should deploy the contract correctly", async function () {
    await loadFixture(deployAssets)
  })


  
//   it("Assets functions test: part `Share`", async function () {
//     const { MasterToken, Assets, owner, carol, david } = await loadFixture(deployAssets)

//     await Assets.connect(carol).purchase()  // 400 - 1 = 399
//     await Assets.connect(carol).purchase()  // 399 - 2 = 397
//     expect(await MasterToken.balanceOf(carol.address)).to.equal(ethers.parseEther('397'))
//     await Assets.connect(david).purchase()  // 400 - 3 = 397
//     await Assets.connect(david).purchase()  // 397 - 4 = 393
//     expect(await MasterToken.balanceOf(david.address)).to.equal(ethers.parseEther('393'))

//     expect(await Assets.adminBalance()).to.equal(ethers.parseEther('0'))

//     await Assets.connect(carol).sell()      // 397 + 4 * 95% = 400.8
//     expect(await MasterToken.balanceOf(carol.address)).to.equal(ethers.parseEther('400.8'))
//     await Assets.connect(david).sell()      // 393 + 3 * 95% = 395.85
//     expect(await MasterToken.balanceOf(david.address)).to.equal(ethers.parseEther('395.85'))
//     await Assets.connect(carol).sell()      // 400.8 + 2 * 95% = 402.7
//     expect(await MasterToken.balanceOf(carol.address)).to.equal(ethers.parseEther('402.7'))
//     await expect(Assets.connect(carol).sell())
//       .to.be.revertedWith('You have no Share Tokens to sell')

//     // (4 + 3 + 2) * 5% = 0.45
//     expect(await Assets.adminBalance()).to.equal(ethers.parseEther('0.45'))

//     await Assets._claimAll()
//     expect(await Assets.adminBalance()).to.equal(ethers.parseEther('0'))
//     expect(await MasterToken.balanceOf(owner.address)).to.equal(ethers.parseEther('0.45'))
//   })



//   it("Assets function test: part `Energy`", async function () {
//     const { MasterToken, Assets, owner, carol } = await loadFixture(deployAssets)

//     // Charge for the first time
//     expect(await Assets.energyOf(carol.address)).to.equal(0)
//     await Assets.connect(carol).charge()    // Spend 1 $MTT for charging
//     expect(await Assets.energyOf(carol.address)).to.equal(20)
//     expect(await MasterToken.balanceOf(carol.address)).to.equal(ethers.parseEther('399'))

//     // After 5 days...
//     await time.increase(5 * 24 * 60 * 60)
//     expect(await Assets.energyOf(carol.address)).to.equal(15)
//     await Assets.connect(carol).charge()
//     expect(await Assets.energyOf(carol.address)).to.equal(35)

//     for (var _ of [0, 0, 0, 0]) { await Assets.connect(carol).charge() }
//     expect(await Assets.energyOf(carol.address)).to.equal(100)
//     await expect(Assets.connect(carol).charge()).to.be.revertedWith("No need to charge!")

//     // After 105 days...
//     await time.increase(105 * 24 * 60 * 60)
//     expect(await Assets.energyOf(carol.address)).to.equal(0)
//     await Assets.connect(carol).charge()
//     expect(await Assets.energyOf(carol.address)).to.equal(20)

//     await Assets._claimAll()
//     expect(await MasterToken.balanceOf(owner.address)).to.equal(ethers.parseEther('7'))
//   })



//   it("Assets function test: part `Slots`", async function () {
//     const { MasterToken, FunctionBot, Assets, owner, carol } = await loadFixture(deployAssets)

//     await expect(Assets.connect(carol).installBot(3, 3))
//       .to.be.revertedWith("You do not own this bot!")
//     await expect(Assets.connect(carol).installBot(3, 0))
//       .to.be.revertedWith("FunctionBot #0 is the reserved one!")
//     await expect(Assets.connect(carol).installBot(5, 1))
//       .to.be.revertedWith("Invalid slot ID")
//     await Assets.connect(carol).installBot(3, 1)
//     await expect(Assets.connect(carol).installBot(3, 2))
//       .to.be.revertedWith("Slot is already occupied.")

//     expect(await Assets.isInstalledOn(1)).to.equal(carol.address)
//     expect((await Assets.slotsOf(carol.address))[3]).to.equal(1)

//     await expect(Assets.connect(carol).uninstallBot(0))
//       .to.be.revertedWith("Slot is empty.")
//     await Assets.connect(carol).uninstallBot(3)

//     expect(await Assets.isInstalledOn(1)).to.equal(ethers.ZeroAddress)
//     expect((await Assets.slotsOf(carol.address))[3]).to.equal(0)
//   })

})