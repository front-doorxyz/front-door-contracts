const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Faucet", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, user, user2 ] = await ethers.getSigners();

    const frontDoorToken = await hre.ethers.deployContract(
      "FrontDoorToken",
      []
    );
    await frontDoorToken.waitForDeployment();
    const frontDoorTokenAddress = frontDoorToken.target;

    const faucet = await hre.ethers.deployContract("FNDR_Faucet", [
      frontDoorTokenAddress,
    ]);
    await faucet.waitForDeployment();
    const faucetAddress = faucet.target;

    const value = ethers.parseEther("5000000");
    await frontDoorToken.transfer(faucetAddress, value);


    return { frontDoorToken, faucet, owner, user, user2 };
  }

  describe("Deployment", function () {
    it("Deploy", async function () {
      const { faucet, owner } = await loadFixture(deployFixture);
      const address = await faucet.owner();
      expect(address).to.equal(owner.address);
    });
    it("Balance of Faucet should be 5000000", async function () {
      const { frontDoorToken, faucet } = await loadFixture(deployFixture);
      const balance = await frontDoorToken.balanceOf(faucet.target);
      expect(balance).to.equal(ethers.parseEther("5000000"));
    });
  });
  describe("Request Tokens", function () {
    it("User should be able to request tokens to Faucet", async function () {
        const {frontDoorToken, faucet, owner, user } = await loadFixture(deployFixture);
        const balanceBefore = await frontDoorToken.balanceOf(user.address);
        await faucet.connect(user).requestTokens(ethers.parseEther("2500000"));
        const balanceAfter = await frontDoorToken.balanceOf(user.address);
        expect(balanceAfter).to.equal(balanceBefore + (ethers.parseEther("2500000")));
    });
    it("User should not be able to request tokens after timelock expires", async function () {
        const {frontDoorToken, faucet, owner, user } = await loadFixture(deployFixture);
        const balanceBefore = await frontDoorToken.balanceOf(user.address);
        await faucet.connect(user).requestTokens(ethers.parseEther("2500000"));
        const balanceAfter = await frontDoorToken.balanceOf(user.address);
        expect(balanceAfter).to.equal(balanceBefore + (ethers.parseEther("2500000")));
        await expect(faucet.connect(user).requestTokens(ethers.parseEther("2500000"))).to.revertedWith("You can only request once per day");
    });
    it("If faucet runs out of tokens, user should not be able to request tokens", async function () {
        const {frontDoorToken, faucet, owner, user, user2 } = await loadFixture(deployFixture);
        const balanceBefore = await frontDoorToken.balanceOf(user.address);
        await faucet.connect(user).requestTokens(ethers.parseEther("5000000"));
        const balanceAfter = await frontDoorToken.balanceOf(user.address);
        expect(balanceAfter).to.equal(balanceBefore + (ethers.parseEther("5000000")));
        const balanceOfFaucet = await faucet.getBalance();
        expect(balanceOfFaucet).to.equal(0);
        await expect(faucet.connect(user2).requestTokens(ethers.parseEther("2500000"))).to.revertedWith("Not enough tokens in the faucet");

    });
  })
});
