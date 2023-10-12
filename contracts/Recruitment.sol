
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "hardhat/console.sol";

import {FrontDoorStructs} from "./DataModel.sol";
import {Errors} from "./Errors.sol";


contract Recruitment is Ownable, ReentrancyGuard {

  mapping(address => FrontDoorStructs.Candidate) public candidateList;
  mapping(address => FrontDoorStructs.Recruiter) public RecruiterList;
  mapping(address => FrontDoorStructs.Company) public companyList;
  mapping(string => address) private getAddressFromMail;
  mapping(uint16 => FrontDoorStructs.Job) public jobList;
  mapping(uint16 => FrontDoorStructs.Referral) public referralList;
  address[] public companies;
  address[] public candidates;
  address[] public recruiters;

  address acceptedTokenAddress;
  address frontDoorAddress;
  uint16 private jobIdCounter = 1;
  uint16 private referralCounter = 1;

  constructor(address _acceptedTokenAddress, address _frontDoorAddress) {
    acceptedTokenAddress = _acceptedTokenAddress;
    frontDoorAddress = _frontDoorAddress;
  }

  modifier checkIfItisACompany(address _address) {
    require(isCompanyRegistered(_address), "Company is not registered yet");
  }

  modifier checkIfCandidateHiredByCompany(address candidateAddress, address companyAddress) 
  {
    require(candidateList(candidateAddress).isHired, 'Candidate is not hired yet');
  }

  modifier isCompanyRegistered(address _company) {
    require(companyList(_company).wallet,'Company is not Registered');
  }
  function isAlreadyReferred(uint jobId, string mail) public view return(bool)
  {
    require(getAddressFromMail(mail), 'No candidate found');
    for(uint i=0;i<jobList[jobId].referredCandidates.length;i++)
      if(jobList[jobId].referredCandidates[i].email == mail) return true;
    return false;
  }
  function registerRecruiter(string memory email) external {
    FrontDoorStructs.Recruiter memory recruiter = FrontDoorStructs.Recruiter(msg.sender, email, 0, 0, 0);
    recruiterList[msg.sender]=recruiter;
  }

  function registerJob(uint256 bounty) external payable nonReentrant checkIfItisACompany(msg.sender) returns (uint16) {
    require(bounty > 0, "Bounty should be greater than 0");
    uint16 jobId = jobIdCounter;
    FrontDoorStructs.Job memory job = FrontDoorStructs.Job(jobId, bounty, msg.sender, uint40(block.timestamp) ,new address[](0) ,new address[](0) ,false ,false ,false);
    jobList[jobId] = job;
    jobIdCounter++;
    companyList[msg.sender].jobs.push(job);
    ERC20(acceptedTokenAddress).approve(address(this), bounty);
    bool success = ERC20(acceptedTokenAddress).transferFrom(msg.sender, address(this), bounty);
    if (!success) {
      revert Errors.BountyNotPaid();
    }
    companyList[msg.sender].ballance += bounty;
    emit DepositCompleted(msg.sender, bounty, jobId);
    emit JobCreated(msg.sender, jobId);
    return jobId;
  }

  function registerCompany() external {
    FrontDoorStructs.Company memory company = FrontDoorStructs.Company(msg.sender, 0, 0, new address[](0));
    companyList[msg.sender] = company;
    companies.push(msg.sender);
  }

  function registerReferral(uint16 jobId, string memory candidateEMail) external nonReentrant returns (uint16){
    require(jobId > 0, "Job Id should be greater than 0");
    require(bytes(candidateEMail).length > 0, "Referee Mail should not be empty");
    if(!isAlreadyReferred(jobId,candidateEMail)) return;
    
    int referId = referralCounter++;
    candidateList[getAddressFromMail[candidateEMail]].refers.push(referId);
    FrontDoorStructs.Candidate memory candidate = candidateList[getAddressFromMail[candidateEMail]];
    FrontDoorStructs.Job memory job = jobList[jobId];
    if(!isAlreadyReferred(jobId,candidateEMail)) job.referredCandidates.push(candidate.address);

    FrontDoorStructs.Referral memory referral = FrontDoorStructs.Referral(
      referId,
      referralCounter,
      false,
      false,
      0,
      candidate,
      job,
      uint40(block.timestamp),
      0,
      msg.sender
    );
    recruiterList[msg.sender].refers.push(referId);
    emit RegisterReferral(candidateEMail, msg.sender, jobId, referralId);
    return referralId;
  }
  
  function confirmReferral(uint16 _referralCounter, uint16 _jobId) external nonReentrant {
    require(referralList[_referralCounter].isConfirmed == false, "Referral is already confirmed");
    require(referralList[_referralCounter].job.issucceed == false, "Job is already succeed");
    require(referralList[_referralCounter].job.timeOfJobCreated + 30 days > block.timestamp, "Job is expired");
    require(referralList[_referralCounter].candidate.isHired == false, "Candidate is already hired");
    require(referralList[_referralCounter].timeOfRefer + 7 days > block.timestamp, "Referral is expired");

    candidateList[msg.sender].referConfirmed = true;
    referralList[_referralCounter].isConfirmed = true;
    referralList[_referralCounter].candidate.wallet = msg.sender;    
    jobList[jobId].refers.push(referralList[_referralCounter].id);
    jobList[jobId].numberOfReferrals++;

    emit ReferralConfirmed(msg.sender, _referralCounter, _jobId);
  }


  function hireCandidate(
    address _candidateAddress,
    uint16 _jobId
  ) external nonReentrant checkIfItisACompany(msg.sender) {
    require(candidateList[_candidateAddress].isHired == false, "Candidate is already hired"); // check if candidate is already hired or not
    require(jobList[_jobId].issucceed == false, "Job is already succeed"); // check if job is already succeed or not

    candidateList[_candidateAddress].isHired = true;
    candidateList[_candidateAddress].timeOfHiring = uint40(block.timestamp);
    jobList[_jobId].hiredCandidate=_candidateAddress;

    emit CandidateHired(msg.sender, _candidateAddress, _jobId);
  }

  function getCandidate(address wallet) external view returns (FrontDoorStructs.Candidate memory) {
    return candidateList[wallet];
  }

  function getRecruiter(address wallet) external view returns (FrontDoorStructs.Referrer memory) {
    return recruiterList[wallet];
  }

  function getRecruiterScore(address wallet) public view returns (uint16) {
    return recruiterList[wallet].score.finalScore;
  }

  function getCompanyScore(address companyAddress) public view returns (uint16) {
    return companyList[companyAddress].score.finalScore;
  }

  function getAllJobsOfCompany(address companyWallet) external view returns (FrontDoorStructs.Job[] memory) {
    return companyList[companyWallet].jobs;
  }

  function getMyRefferals() public view returns ( uint16[] memory){
    return recuriterList[msg.sender].refers;
  }
  
  //TODO  validate if sender is the company that created the job
  function getCandidateListForJob (uint16 _jobId) public view returns(string[]){
    string[] candidates;
    for(uint i=0;i<jobList[_jobId].refers.length;i++)
      candidates.push(jobList[_jobId].refers.candidate.email);
    return candidates;
  }

  function candidateStatus(address _candidateAddress) public view returns(bool){
    return candidateList[_candidateAddress].isHired;
  }

  function getCandidateHiredJobId(uint16 _jobId) public view returns(string){
    return jobList[_jobId].hiredCandidate.email;
  }

  function getCurrentRefer(uint16 _jobId) internal returns(Referral)
  {
    for(uint i=0;i<jobList[_jobId].hiredCandidate.refers.length;i++)
      if(_jobId == jobList[_jobId].hiredCandidate.refers[i].job.id) return jobList[_jobId].hiredCandidate.refers[i];
    return 0;
  }
  
  function diburseBounty(uint16 _jobId) external nonReentrant checkIfItisACompany(msg.sender){
    require(jobList[_jobId].issucceed == true, "Job is not succeed yet");
    require(jobList[_jobId].numberOfCandidateHired > 0, "No candidate is hired yet");
    require(jobList[_jobId].isDibursed == false, "Bounty is already dibursed");
    require(jobList[_jobId].creator == msg.sender, "Only job creator can diburse");

    jobList[_jobId].isDibursed = true;
    uint256 bounty = jobList[_jobId].bounty;
    Referral currentRefer = getCurrentRefer();
    ERC20(acceptedTokenAddress).approve(currentRefer.owner, bounty * 6500 / 10_000);
    ERC20(acceptedTokenAddress).approve(jobList[_jobId].hiredCandidate, bounty * 1000 / 10_000);
    ERC20(acceptedTokenAddress).approve(frontDoorAddress, bounty * 2500 / 10_000);
    ERC20(acceptedTokenAddress).transfer(currentRefer.owner, bounty * 6500 / 10_000);
    ERC20(acceptedTokenAddress).transfer(jobList[_jobId].hiredCandidate, bounty * 1000 / 10_000);
    ERC20(acceptedTokenAddress).transfer(frontDoorAddress, bounty * 2500 / 10_000);
  }

  function updateFinalScore(address userAddress, uint kind) internal
  {
    switch(kind)
    {
      case 0: {
        int[] weight={10,8,7};
        int index=0,sum=0,div=0;
        while(companyList[userAddress].score.scores[index])
        {
          int w=index>2?5:weight[index];
          div+=w;
          sum+=companyList[userAddress].score.scores[index++]*w*20;
        }
        companyList[userAddress].score.finalScore=sum/div;
      }
      case 1: {
        int sum=0,count=0 ;
        for(uint i=0;i<recruiterList[userAddress].refers.length;i++)
        {
          if(recruiterList[userAddress].refers)
          sum+=recruiterList[userAddress].refers.scores[index++];
        }
        referrerList[userAddress].score.finalScore=(double)sum/div*;
      }
      case 2: {
        int index=0,sum=0,div=0;
        while(referrerList[userAddress].score.scores[index])
        {
          int w=index>2?5:weight[index];
          div+=w;
          sum+=referrerList[userAddress].score.scores[index++]*w*20;
        }
        referrerList[userAddress].score.finalScore=sum/div;
      }
    }
  }
  function setScore(Address userAddress, uint kind, uint score) {
    switch(kind)
    {
      case 0: {
        companyList[userAddress].score.scores.push(score);
        companyList[userAddress].score.finalScore=getFinalScore(userAddress,kind);
        break;
      }
      case 2: {
        candidateList[userAddress].score.scores.push(score);
        candidateList[userAddress].score.finalScore=getFinalScore(userAddress,kind);
        break;
      }
    }
  }
  event PercentagesCompleted(
    address indexed sender,
    uint8 month1RefundPct,
    uint8 month2RefundPct,
    uint8 month3RefundPct
  );
  event DepositCompleted(address indexed sender, uint256 amount, uint16 jobId);
  event ReferralScoreSubmitted(address senderAddress, address referrerWallet, uint16 score);
  event CompanyScoreSubmitted(address senderAddress, address companyAddress, uint16 score);
  event ReferCandidateSuccess(address indexed sender, address indexed candidateAddress, uint16 indexed jobId);
  event CandidateHired(address indexed companyAddress, address candidateAddress, uint16 jobId);
  event ReferralConfirmed(address indexed candidateAddress, uint16 indexed referralId, uint16 indexed jobId);
  event ReferralRejected(address indexed candidateAddress, uint16 indexed referralId, uint16 indexed jobId);
  event CandidateHiredSuccesfullyAfter90Days(address indexed companyAddress, address candidateAddress, uint16 jobId);
  event RegisterReferral(string indexed email, address indexed refferer, uint16 indexed jobId, uint16 referralId);
  event JobCreated(address indexed companyAddress, uint16 indexed jobId);

}