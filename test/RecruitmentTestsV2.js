/* eslint-disable no-undef */
const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const { v4: uuidv4 } = require("uuid");
const { describe, it } = require("mocha");

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

    const faucet = await hre.ethers.deployContract("FNDR_Faucet", [
      frontDoorTokenAddress,
    ]);
    await faucet.waitForDeployment();
    const faucetAddress = faucet.target;
    await frontDoorToken.setFaucet(faucetAddress);

    const recruitment = await hre.ethers.deployContract("RecruitmentV2", [
      frontDoorTokenAddress,
      frontDoorWallet.address,
    ]);
    await recruitment.waitForDeployment();

    await faucet.connect(company).requestTokens(ethers.parseEther("5000000"));

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
      const companyStruct = await recruitment.companies(company.address);
      expect(company.address).to.equal(companyStruct.companyAddress);
    });
  });
  describe("Register Jobs", () => {
    it("Register a job failed with no allowance", async () => {
      const { recruitment, company } = await loadFixture(fixture);
      await recruitment.connect(company).registerCompany();
      const companyStruct = await recruitment.companies(company.address);
      expect(company.address).to.equal(companyStruct.companyAddress);
      const bounty = ethers.parseEther("500");
      await expect(
        recruitment.connect(company).registerJob(bounty, 1)
      ).to.rejectedWith("ERC20: insufficient allowance");
    });
    it("Register a job", async () => {
      const { frontDoorToken, recruitment, company } = await loadFixture(
        fixture
      );
      await recruitment.connect(company).registerCompany();
      const companyStruct = await recruitment.companies(company.address);
      expect(company.address).to.equal(companyStruct.companyAddress);
      const bounty = ethers.parseEther("750");
      await frontDoorToken.connect(company).approve(recruitment.target, bounty);
      await expect(recruitment.connect(company).registerJob(bounty, 1)).to.emit(
        recruitment,
        "JobCreated"
      );
    });
    it("Register a job, company account balance should increase", async () => {
      const { frontDoorToken, recruitment, company } = await loadFixture(
        fixture
      );
      await recruitment.connect(company).registerCompany();
      const companyStruct = await recruitment.companies(company.address);
      expect(company.address).to.equal(companyStruct.companyAddress);
      const bounty = ethers.parseEther("150");
      await frontDoorToken.connect(company).approve(recruitment.target, bounty);
      const jobId = await recruitment.connect(company).registerJob(bounty, 1);
      await jobId.wait();
      const companyBal = await recruitment.balances(company.address);
      expect(bounty).to.equal(companyBal);
    });
    it("Retrieve all jobs from company, should retreive 2 jobs", async () => {
      const { frontDoorToken, recruitment, company } = await loadFixture(
        fixture
      );
      await recruitment.connect(company).registerCompany();
      const companyStruct = await recruitment.companies(company.address);
      expect(company.address).to.equal(companyStruct.companyAddress);
      const bounty = ethers.parseEther("150");
      await frontDoorToken.connect(company).approve(recruitment.target, bounty);
      const jobId = await recruitment.connect(company).registerJob(bounty, 1);
      await jobId.wait();
      const companyBal = await recruitment.balances(company.address);
      expect(bounty).to.equal(companyBal);
      const bounty2 = ethers.parseEther("150");
      await frontDoorToken
        .connect(company)
        .approve(recruitment.target, bounty2);
      const jobId2 = await recruitment.connect(company).registerJob(bounty2, 1);
      await jobId2.wait();
      const companyBal2 = await recruitment.balances(company.address);
      expect(ethers.parseEther("300")).to.equal(companyBal2);
      const jobs = await recruitment.getCompanyJobs(company.address);
      expect(jobs.length).to.equal(2);
    });
    it("Retrieve all jobs when no job is created", async () => {
      const { recruitment, company } = await loadFixture(fixture);
      await recruitment.connect(company).registerCompany();
      const companyStruct = await recruitment.companies(company.address);
      expect(company.address).to.equal(companyStruct.companyAddress);
      const jobs = await recruitment.getCompanyJobs(company.address);
      expect(jobs.length).to.equal(0);
    });
  });
  describe("Register Referrer", () => {
    it("Register referrer", async () => {
      const { recruitment, referrer } = await loadFixture(fixture);
      const email = ethers.encodeBytes32String("john.doe@mail.com");
      await recruitment.connect(referrer).registerReferrer(email);
      const referrerData = await recruitment.referrers(referrer.address);
      expect(referrerData.email).to.equal(email);
    });
    it("Register referrer with another address with same email should revert", async () => {
      const { recruitment, referrer, referree } = await loadFixture(fixture);
      const email = ethers.encodeBytes32String("john.doe@mail.com");
      await recruitment.connect(referrer).registerReferrer(email);
      const referrerData = await recruitment.referrers(referrer.address);
      expect(referrerData.email).to.equal(email);
      await expect(
        recruitment.connect(referree).registerReferrer(email)
      ).to.revertedWith("Email already registered");
    });
  });
  describe("Register Referral", () => {
    it("Register referral", async () => {
      const { frontDoorToken, recruitment, company, referrer } =
        await loadFixture(fixture);
      await recruitment.connect(company).registerCompany();
      const companyStruct = await recruitment.companies(company.address);
      expect(company.address).to.equal(companyStruct.companyAddress);
      const bounty = ethers.parseEther("750");
      await frontDoorToken.connect(company).approve(recruitment.target, bounty);
      const jobId = await recruitment.connect(company).registerJob(bounty, 1);
      await jobId.wait();
      const jobs = await recruitment.getCompanyJobs(company.address);
      const email = ethers.encodeBytes32String("john.doe@mail.com");
      await recruitment.connect(referrer).registerReferrer(email);
      const referrerData = await recruitment.referrers(referrer.address);
      expect(referrerData.email).to.equal(email);
      const emailReferral = ethers.encodeBytes32String(
        "referralemail@mail.com"
      );
      const uuid = uuidv4().replaceAll("-", "");
      const uuidBytes = ethers.toUtf8Bytes(uuid);
      const refer = await recruitment
        .connect(referrer)
        .referCandidate(jobs[0], emailReferral, uuidBytes);
      await refer.wait();
      const referralsJob = await recruitment.getReferralsOfJobId(jobs[0]);
      expect(referralsJob.length).to.equal(1);
      const referral = await recruitment.referrals(referralsJob[0]);
      await expect(referral.candidateEmail).to.equal(emailReferral);
    });
    it("Refer a candidate and apply for a job", async () => {
      const { frontDoorToken, recruitment, company, referrer, referree } =
        await loadFixture(fixture);
      await recruitment.connect(company).registerCompany();
      const companyStruct = await recruitment.companies(company.address);
      expect(company.address).to.equal(companyStruct.companyAddress);
      const bounty = ethers.parseEther("100");
      await frontDoorToken.connect(company).approve(recruitment.target, bounty);
      const jobId = await recruitment.connect(company).registerJob(bounty, 1);
      await jobId.wait();
      const jobs = await recruitment.getCompanyJobs(company.address);
      console.log("jobs : ", jobs);
      const email = ethers.encodeBytes32String("john.doe@mail.com");
      await recruitment.connect(referrer).registerReferrer(email);
      const referrerData = await recruitment.referrers(referrer.address);
      expect(referrerData.email).to.equal(email);
      const emailReferral = ethers.encodeBytes32String(
        "referralemail@mail.com"
      );
      const uuid = uuidv4().replaceAll("-", "");
      const uuidBytes = ethers.toUtf8Bytes(uuid);
      const tx = await recruitment
        .connect(referrer)
        .referCandidate(jobs[0], emailReferral, uuidBytes);
      await tx.wait();
      const referralsJob = await recruitment.getReferralsOfJobId(jobs[0]);
      console.log("referralsJob : ", referralsJob);
      const referral = await recruitment.referrals(referralsJob[0]);

      const jobsReffers = await recruitment
        .connect(referree)
        .confirmReferral(referral.id, referral.referralCode, emailReferral);
      await jobsReffers.wait();
      const candidates = await recruitment.getReferralsOfJobId(jobs[0]);
      console.log("candidates : ", candidates);
      const hire = await recruitment
        .connect(company)
        .hireCandidate(referral.id);
      await hire.wait();
      const seconds = 31 * 24 * 60 * 60 * 3;
      await ethers.provider.send("evm_increaseTime", [seconds]);
      await recruitment.connect(company).disburseBounty(jobs[0]);
    });
    it("Cannot disburse if timelock did not expired", async () => {
      const { frontDoorToken, recruitment, company, referrer, referree } =
        await loadFixture(fixture);
      await recruitment.connect(company).registerCompany();
      const companyStruct = await recruitment.companies(company.address);
      expect(company.address).to.equal(companyStruct.companyAddress);
      const bounty = ethers.parseEther("100");
      await frontDoorToken.connect(company).approve(recruitment.target, bounty);
      const jobId = await recruitment.connect(company).registerJob(bounty, 1);
      await jobId.wait();
      const jobs = await recruitment.getCompanyJobs(company.address);
      console.log("jobs : ", jobs);
      const email = ethers.encodeBytes32String("john.doe@mail.com");
      await recruitment.connect(referrer).registerReferrer(email);
      const referrerData = await recruitment.referrers(referrer.address);
      expect(referrerData.email).to.equal(email);
      const emailReferral = ethers.encodeBytes32String(
        "referralemail@mail.com"
      );
      const uuid = uuidv4().replaceAll("-", "");
      const uuidBytes = ethers.toUtf8Bytes(uuid);
      const tx = await recruitment
        .connect(referrer)
        .referCandidate(jobs[0], emailReferral, uuidBytes);
      await tx.wait();
      const referralsJob = await recruitment.getReferralsOfJobId(jobs[0]);
      console.log("referralsJob : ", referralsJob);
      const referral = await recruitment.referrals(referralsJob[0]);

      const jobsReffers = await recruitment
        .connect(referree)
        .confirmReferral(referral.id, referral.referralCode, emailReferral);
      await jobsReffers.wait();
      const hire = await recruitment
        .connect(company)
        .hireCandidate(referral.id);
      await hire.wait();

      await expect(
        recruitment.connect(company).disburseBounty(jobs[0])
      ).to.revertedWith("90 days are not completed yet");
    });
  });

  describe("Claim bounties", () => {
    it("Cannot claim bounty if nothing is to claim", async () => {
     const { recruitment, referrer } = await loadFixture(fixture);
      await expect(
        recruitment.connect(referrer).claimRewards()
      ).to.rejectedWith("No rewards to claim");
    });
    
    it("Rewarded can claim their rewards", async () => {
        const { frontDoorToken, recruitment, company, referrer, referree } =
        await loadFixture(fixture);
      await recruitment.connect(company).registerCompany();
      const companyStruct = await recruitment.companies(company.address);
      expect(company.address).to.equal(companyStruct.companyAddress);
      const bounty = ethers.parseEther("100");
      await frontDoorToken.connect(company).approve(recruitment.target, bounty);
      const jobId = await recruitment.connect(company).registerJob(bounty, 1);
      await jobId.wait();
      const jobs = await recruitment.getCompanyJobs(company.address);
      console.log("jobs : ", jobs);
      const email = ethers.encodeBytes32String("john.doe@mail.com");
      await recruitment.connect(referrer).registerReferrer(email);
      const referrerData = await recruitment.referrers(referrer.address);
      expect(referrerData.email).to.equal(email);
      const emailReferral = ethers.encodeBytes32String(
        "referralemail@mail.com"
      );
      const uuid = uuidv4().replaceAll("-", "");
      const uuidBytes = ethers.toUtf8Bytes(uuid);
      const tx = await recruitment
        .connect(referrer)
        .referCandidate(jobs[0], emailReferral, uuidBytes);
      await tx.wait();
      const referralsJob = await recruitment.getReferralsOfJobId(jobs[0]);
      console.log("referralsJob : ", referralsJob);
      const referral = await recruitment.referrals(referralsJob[0]);

      const jobsReffers = await recruitment
        .connect(referree)
        .confirmReferral(referral.id, referral.referralCode, emailReferral);
      await jobsReffers.wait();
      const candidates = await recruitment.getReferralsOfJobId(jobs[0]);
      console.log("candidates : ", candidates);
      const hire = await recruitment
        .connect(company)
        .hireCandidate(referral.id);
      await hire.wait();
      const seconds = 31 * 24 * 60 * 60 * 3;
      await ethers.provider.send("evm_increaseTime", [seconds]);
      const referrerBal = await frontDoorToken.balanceOf(referrer.address);
      await recruitment.connect(company).disburseBounty(jobs[0]);
        await recruitment.connect(referrer).claimRewards();
      expect(await frontDoorToken.balanceOf(referrer.address)).gt(referrerBal);
    });
  });
});
