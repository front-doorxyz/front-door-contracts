const { loadFixture } = require('@nomicfoundation/hardhat-toolbox/network-helpers');
const { expect } = require('chai');
const { ethers } = require('hardhat');
const { v4: uuidv4 } = require('uuid');
const { describe, it } = require('mocha');


function encodeEmail(email) {
  return ethers.utils.formatBytes32String(email);
}
describe('Recruitment Scoring', () => {
  const fixture = async () => {
    const [owner, company, referrer, referree, frontDoorWallet] = await ethers.getSigners();

    const frontDoorToken = await hre.ethers.deployContract('FrontDoorToken', []);
    await frontDoorToken.waitForDeployment();
    const frontDoorTokenAddress = frontDoorToken.target;

    const faucet = await hre.ethers.deployContract('FNDR_Faucet', [frontDoorTokenAddress]);
    await faucet.waitForDeployment();
    const faucetAddress = faucet.target;
    await frontDoorToken.setFaucet(faucetAddress);

    const recruitment = await hre.ethers.deployContract('Recruitment', [
      frontDoorTokenAddress,
      frontDoorWallet.address,
    ]);
    await recruitment.waitForDeployment();

    await faucet.connect(company).requestTokens(ethers.parseEther('5000000'));

    return { frontDoorToken, recruitment, owner, company, referrer, referree };
  };

  describe('Comprehensive Scoring Flow', () => {
    it('Test scoring functions', async () => {
      const {frontDoorToken, recruitment, company, referrer, referree} =
      await loadFixture(fixture);
    await recruitment.connect(company).registerCompany();
    const companyStruct = await recruitment.companyList(company.address);
    expect(company.address).to.equal(companyStruct.wallet);
    const bounty = ethers.parseEther('100');
    await frontDoorToken.connect(company).approve(recruitment.target, bounty);
    const jobId = await recruitment.connect(company).registerJob(bounty);
    const receipt = await jobId.wait();
    const email = ethers.encodeBytes32String('john.doe@mail.com');
    await recruitment.connect(referrer).registerReferrer(email);
    const referrerData = await recruitment.getReferrer(referrer.address);
    expect(referrerData.email).to.equal(email);
    const emailReferral = ethers.encodeBytes32String(
        'referralemail@mail.com',
    );
    const uuid = uuidv4().replaceAll('-', '');
    const uuidBytes = ethers.toUtf8Bytes(uuid);

    const tx = await recruitment
        .connect(referrer)
        .registerReferral(1, emailReferral, uuidBytes);
    await tx.wait();
    const jobsReffers = await recruitment
        .connect(referree)
        .confirmReferral(1, 1, uuidBytes);
    await jobsReffers.wait();
    const candadidatesForJob = await recruitment.getCandidateListForJob(1);
    const hire = await recruitment
        .connect(company)
        .hireCandidate(referree.address, 1);
    await hire.wait();
    const seconds = 31 * 24 * 60 * 60 * 3;
    await ethers.provider.send('evm_increaseTime', [seconds]);
    await recruitment.connect(company).disburseBounty(1);
    const referrerBal = await frontDoorToken.balanceOf(referrer.address);
    await recruitment.connect(referrer).claimBounty();
    expect(await frontDoorToken.balanceOf(referrer.address)).gt(referrerBal);
    const referreeBal = await frontDoorToken.balanceOf(referree.address);
    await recruitment.connect(referree).claimBounty();
    expect(await frontDoorToken.balanceOf(referree.address)).gt(referreeBal);
    // Set the score from the company to the candidate
    const candidateAddress = referree.address;
    const candidateScore = BigInt("4"); // Replace with the desired score
    await recruitment.connect(company).setCanidateScoreFromCompany(candidateAddress, candidateScore);

    // Set the score from the candidate to the company
    const companyAddress = company.address;
    const companyScore = BigInt("5"); // Replace with the desired score
    await recruitment.connect(referree).setCompanyScoreFromCandidate(companyAddress, companyScore);

    // Get and verify the scores
    const candidateScoreResult = await recruitment.getCandidateScore(candidateAddress);
    const companyScoreResult = await recruitment.getCompanyScore(companyAddress);

    // Assert that the scores are updated correctly
    expect(candidateScoreResult).to.equal(candidateScore);
    expect(referrerScoreResult).to.equal(candidateScore);
    expect(companyScoreResult).to.equal(companyScore);
    });
  });
});
