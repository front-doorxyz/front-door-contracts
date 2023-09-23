const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
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

    const tkns = ethers.parseEther("1000");
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
      await recruitment.connect(company).registerCompany();
      const companyStruct = await recruitment.companyList(company.address);
      expect(company.address).to.equal(companyStruct.wallet);
    });
    it("Register a job failed with no allowance", async () => {
      const { recruitment, company } = await loadFixture(fixture);
      await recruitment.connect(company).registerCompany();
      const companyStruct = await recruitment.companyList(company.address);
      expect(company.address).to.equal(companyStruct.wallet);
      const bounty = ethers.parseEther("500");
      await expect(
        recruitment.connect(company).registerJob(bounty)
      ).to.rejectedWith("ERC20: insufficient allowance");
    });
    it("Register a job", async () => {
      const { frontDoorToken, recruitment, company } = await loadFixture(
        fixture
      );
      await recruitment.connect(company).registerCompany();
      const companyStruct = await recruitment.companyList(company.address);
      expect(company.address).to.equal(companyStruct.wallet);
      const bounty = ethers.parseEther("750");
      await frontDoorToken.connect(company).approve(recruitment.target, bounty);
      await expect(recruitment.connect(company).registerJob(bounty))
        .to.emit(recruitment, "JobCreated")
        .withArgs(company.address, 1);
    });
  });
  it("Register a job (no callstatic), company account balance should increase", async () => {
    const { frontDoorToken, recruitment, company } = await loadFixture(fixture);
    await recruitment.connect(company).registerCompany();
    const companyStruct = await recruitment.companyList(company.address);
    expect(company.address).to.equal(companyStruct.wallet);
    const bounty = ethers.parseEther("150");
    await frontDoorToken.connect(company).approve(recruitment.target, bounty);
    const jobId = await recruitment.connect(company).registerJob(bounty);
    await jobId.wait();
    const companyBal = await recruitment.companyaccountBalances(
      company.address
    );
    expect(bounty).to.equal(companyBal);
  });
  it("Retrieve all jobs from company, should retreive 2 jobs", async () => {
    const { frontDoorToken, recruitment, company } = await loadFixture(fixture);
    await recruitment.connect(company).registerCompany();
    const companyStruct = await recruitment.companyList(company.address);
    expect(company.address).to.equal(companyStruct.wallet);
    const bounty = ethers.parseEther("150");
    await frontDoorToken.connect(company).approve(recruitment.target, bounty);
    const jobId = await recruitment.connect(company).registerJob(bounty);
    await jobId.wait();
    const companyBal = await recruitment.companyaccountBalances(
      company.address
    );
    expect(bounty).to.equal(companyBal);
    const bounty2 = ethers.parseEther("150");
    await frontDoorToken.connect(company).approve(recruitment.target, bounty2);
    const jobId2 = await recruitment.connect(company).registerJob(bounty2);
    await jobId2.wait();
    const companyBal2 = await recruitment.companyaccountBalances(
      company.address
    );
    expect(ethers.parseEther("300")).to.equal(companyBal2);
    const jobs = await recruitment.getAllJobsOfCompany(company.address);
    expect(jobs.length).to.equal(2);
  });
  it("Retrieve all jobs when no job is created", async () => {
    const { recruitment, company } = await loadFixture(fixture);
    await recruitment.connect(company).registerCompany();
    const companyStruct = await recruitment.companyList(company.address);
    expect(company.address).to.equal(companyStruct.wallet);
    const jobs = await recruitment.getAllJobsOfCompany(company.address);
    expect(jobs.length).to.equal(0);
  });
  describe("Register Referrer", () => {
    it("Register referrer", async () => {
      const { recruitment, referrer } = await loadFixture(fixture);
      const email = "john.doe@mail.com";
      await recruitment.connect(referrer).registerReferrer(email);
      const referrerData = await recruitment.getReferrer(referrer.address);
      expect(referrerData.email).to.equal(email);
    });
    it("Register referree with same email", async () => {
      const { recruitment, referrer, referree } = await loadFixture(fixture);
      const email = "john.doe@mail.com";
      await recruitment.connect(referrer).registerReferrer(email);
      const referrerData = await recruitment.getReferrer(referrer.address);
      expect(referrerData.email).to.equal(email);
      await recruitment.connect(referree).registerReferrer(email);
      const referreeData = await recruitment.getReferrer(referree.address);
    });
  });
  describe("Register Referral", () => {
    it("Register referral", async () => {
      const { frontDoorToken, recruitment, company, referrer } =
        await loadFixture(fixture);
      await recruitment.connect(company).registerCompany();
      const companyStruct = await recruitment.companyList(company.address);
      expect(company.address).to.equal(companyStruct.wallet);
      const bounty = ethers.parseEther("750");
      await frontDoorToken.connect(company).approve(recruitment.target, bounty);
      const jobId = await recruitment.connect(company).registerJob(bounty);
      await jobId.wait();
      const email = "john.doe@mail.com";
      await recruitment.connect(referrer).registerReferrer(email);
      const referrerData = await recruitment.getReferrer(referrer.address);
      expect(referrerData.email).to.equal(email);
      const emailReferral = "referralemail@mail.com";
      await recruitment.connect(referrer).registerReferral(1, emailReferral);
      const jobs = await recruitment.getAllJobsOfCompany(company.address);
    });
    it("Refer a candidate and apply for a job", async () => {
      const { frontDoorToken, recruitment, company, referrer, referree } =
        await loadFixture(fixture);
      await recruitment.connect(company).registerCompany();
      const companyStruct = await recruitment.companyList(company.address);
      expect(company.address).to.equal(companyStruct.wallet);
      const bounty = ethers.parseEther("100");
      await frontDoorToken.connect(company).approve(recruitment.target, bounty);
      const jobId = await recruitment.connect(company).registerJob(bounty);
      const receipt = await jobId.wait();

      const email = "john.doe@mail.com";
      await recruitment.connect(referrer).registerReferrer(email);
      const referrerData = await recruitment.getReferrer(referrer.address);
      expect(referrerData.email).to.equal(email);
      const emailReferral = "referralemail@mail.com";
      const tx = await recruitment
        .connect(referrer)
        .registerReferral(1, emailReferral);
      await tx.wait();
      const jobsReffers = await recruitment
        .connect(referree)
        .confirmReferral(1, 1);
      const data2 = await jobsReffers.wait();
      const candadidatesForJob = await recruitment.getCandidateListForJob(1);
      const hire = await recruitment
        .connect(company)
        .hireCandidate(referree.address, 1);
      await hire.wait();
      await recruitment.connect(company).diburseBounty(1);
    });
  });
});
