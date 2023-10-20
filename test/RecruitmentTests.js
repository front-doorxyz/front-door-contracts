const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Recruitment", () => {
  const fixture = async () => {
    const [owner, company, referrer, referree, frontDoorWallet] =
      await ethers.getSigners();

    const frontDoorToken = await hre.ethers.deployContract(
      "FrontDoorToken",
      []
    );
    await frontDoorToken.waitForDeployment();
    const frontDoorTokenAddress = frontDoorToken.target;

    const tkns = ethers.parseEther("750");
    await frontDoorToken.transfer(company.getAddress(), tkns);
    await frontDoorToken.transfer(referrer.getAddress(), tkns);
    await frontDoorToken.transfer(referree.getAddress(), tkns);

    const recruitment = await hre.ethers.deployContract("Recruitment", [
      frontDoorTokenAddress,
      frontDoorWallet.address,
    ]);
    await recruitment.waitForDeployment();

    return { frontDoorToken, recruitment, owner, company, referrer, referree };
  };

  describe("Initial deploy", () => {
    it("Owner in contract should be the deployer", async () => {
      const { recruitment, owner } = await loadFixture(fixture);
      const address = await recruitment.owner();
      expect(address).to.equal(owner.address);
    });
  });

  describe("Register Company", () => {
    it("Register company", async () => {
      const { recruitment, company } = await loadFixture(fixture);
      await recruitment.connect(company).registerAsCompany();
      const companyStruct = await recruitment.companyList(company.address);
      expect(company.address).to.equal(companyStruct.wallet);
    });

    it("Register a job failed with no allowance", async () => {
      const { recruitment, company } = await loadFixture(fixture);
      await recruitment.connect(company).registerAsCompany();
      const companyStruct = await recruitment.companyList(company.address);
      expect(company.address).to.equal(companyStruct.wallet);

      // Get the contract's address and allowance
      const recruitmentAddress = recruitment.target;
      const allowance = await frontDoorToken.allowance(
        company.address,
        recruitmentAddress
      );
      // Ensure that allowance is greater than the bounty
      const bounty = ethers.parseEther("500");
      expect(allowance).to.be.at.least(bounty);

      await expect(recruitment.connect(company).registerJob(bounty))
        .to.rejectedWith("ERC20: transfer amount exceeds balance");
    });

    it("Register a job", async () => {
      const { frontDoorToken, recruitment, company } = await loadFixture(fixture);
      await recruitment.connect(company).registerAsCompany();
      const companyStruct = await recruitment.companyList(company.address);
      expect(company.address).to.equal(companyStruct.wallet);

      // Approve allowance for the contract to spend tokens
      const bounty = ethers.parseEther("750");
      await frontDoorToken.connect(company).approve(recruitment.target, bounty);

      await expect(recruitment.connect(company).registerJob(bounty))
        .to.emit(recruitment, "JobCreated")
        .withArgs(company.address, 1);
    });
  });

  it("Register a job (no callstatic), company account balance should increase", async () => {
    const { frontDoorToken, recruitment, company } = await loadFixture(fixture);
    await recruitment.connect(company).registerAsCompany();
    const companyStruct = await recruitment.companyList(company.address);
    expect(company.address).to.equal(companyStruct.wallet);

    const bounty = ethers.parseEther("150");
    await frontDoorToken.connect(company).approve(recruitment.target, bounty);
    const jobId = await recruitment.connect(company).registerJob(bounty);
    await jobId.wait();

    // Verify that the company's balance has increased
    const companyBal = await recruitment.companyaccountBalances(company.address);
    expect(bounty).to.equal(companyBal);
  });

  it("Retrieve all jobs from company, should retrieve 2 jobs", async () => {
    const { frontDoorToken, recruitment, company } = await loadFixture(fixture);
    await recruitment.connect(company).registerAsCompany();
    const companyStruct = await recruitment.companyList(company.address);
    expect(company.address).to.equal(companyStruct.wallet);

    const bounty = ethers.parseEther("150");
    await frontDoorToken.connect(company).approve(recruitment.target, bounty);
    const jobId = await recruitment.connect(company).registerJob(bounty);
    await jobId.wait();

    const companyBal = await recruitment.companyaccountBalances(company.address);
    expect(bounty).to.equal(companyBal);

    const bounty2 = ethers.parseEther("150");
    await frontDoorToken.connect(company).approve(recruitment.target, bounty2);
    const jobId2 = await recruitment.connect(company).registerJob(bounty2);
    await jobId2.wait();

    const companyBal2 = await recruitment.companyaccountBalances(company.address);
    expect(ethers.parseEther("300")).to.equal(companyBal2);

    const jobs = await recruitment.getAllJobsOfCompany(company.address);
    expect(jobs.length).to.equal(2);
  });

  it("Retrieve all jobs when no job is created", async () => {
    const { recruitment, company } = await loadFixture(fixture);
    await recruitment.connect(company).registerAsCompany();
    const companyStruct = await recruitment.companyList(company.address);
    expect(company.address).to.equal(companyStruct.wallet);

    const jobs = await recruitment.getAllJobsOfCompany(company.address);
    expect(jobs.length).to.equal(0);
  });
});
