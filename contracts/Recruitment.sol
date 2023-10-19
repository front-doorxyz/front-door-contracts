
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
  mapping(address => FrontDoorStructs.Recruiter) public recruiterList;
  mapping(address => FrontDoorStructs.Company) public companyList;
  mapping(uint16 => FrontDoorStructs.Job) public jobList;
  mapping(uint16 => FrontDoorStructs.Referral) public referralList;
  mapping(address => FrontDoorStructs.ReferralCode) private referralCodes;

  address[] public companies;
  address[] public candidates;
  address[] public recruiters;

  address acceptedTokenAddress;
  address frontDoorAddress;
  uint16 private jobIdCounter = 1;
  uint16 private referralCounter = 1;

  mapping(address => uint256) public bountyClaim;
  mapping(uint16 => bytes32) public JobIdtoTeferralCodeList;
  mapping(bytes32 => uint16) public referralCodeToJobId;
  mapping(bytes32 => FrontDoorStructs.ReferralCode) public referralCodeList;

  constructor(address _acceptedTokenAddress, address _frontDoorAddress) {
    acceptedTokenAddress = _acceptedTokenAddress;
    frontDoorAddress = _frontDoorAddress;
  }

  modifier checkIfCandidateHiredByCompany(address candidateAddress, address companyAddress) 
  {
    require(candidateList[candidateAddress].isHired, 'Candidate is not hired yet');
    _;
  }

  function isAlreadyReferred(uint16 jobId, address userAddress) public view returns (bool) {
    for(uint i=0;i<jobList[jobId].refers.length;i++)
      if(referralList[jobList[jobId].refers[i]].candidate == userAddress) return true;
    return false;
  }
  function registerAsRecruiter() external {
    FrontDoorStructs.Recruiter memory recruiter = FrontDoorStructs.Recruiter({
      wallet: msg.sender, 
      score: FrontDoorStructs.Score({
          scores: new uint16[](0),
          senderAddress: new address[](0),
          timeOfGetScore: new uint40[](0),
          finalScore: 0
      }),
      numberOfSuccesfullReferrals: 0,
      numberOfContactedCandidates: 0,
      refers: new uint16[](0),
      timeOfRegist: uint40(block.timestamp)
    });
    recruiterList[msg.sender] = recruiter;
    recruiters.push(msg.sender);
  }

  function registerJob(uint256 bounty) external payable nonReentrant returns (uint16) {
    require(bounty > 0, "Bounty should be greater than 0");
    uint16 jobId = jobIdCounter;
    FrontDoorStructs.Job memory job = FrontDoorStructs.Job({
      id: jobId,
      bounty: bounty,
      creator: msg.sender,
      timeOfJobCreated: uint40(block.timestamp),
      isDibursed: false,
      isRemoved: false,
      isSucceed: false,
      refers: new uint16[](0),
      hiredRefers: new uint16[](0),
      timeOfCandidateHire: new uint40[](0)
    });
    jobList[jobId] = job;
    jobIdCounter++;
    companyList[msg.sender].jobIds.push(jobId);
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

  function registerAsCompany() external {
    FrontDoorStructs.Company memory company = FrontDoorStructs.Company({
      wallet: msg.sender,
      ballance: 0, 
      score: FrontDoorStructs.Score({
          scores: new uint16[](0),
          senderAddress: new address[](0),
          timeOfGetScore: new uint40[](0),
          finalScore: 0
      }),
      jobIds: new uint16[](0),
      timeOfRegist: uint40(block.timestamp)
    });
    companyList[msg.sender] = company;
    companies.push(msg.sender);
  }

  function registerAsCandidate() external  {
    FrontDoorStructs.Candidate memory candidate = FrontDoorStructs.Candidate({
      wallet: msg.sender,
      score: FrontDoorStructs.Score({
        scores: new uint16[](0),
        senderAddress: new address[](0),
        timeOfGetScore: new uint40[](0),
        finalScore: 0
      }),
      isHired: false,
      earnedMount: 0,
      refers: new uint16[](0),
      timeOfRegist: uint40(block.timestamp)
    });
    candidateList[msg.sender] = candidate;
    candidates.push(msg.sender);
  }
  function registerReferral(uint16 jobId, address candidateAddress) external nonReentrant returns (uint16){
    require(jobId > 0, "Job Id should be greater than 0");
    
    if(!isAlreadyReferred(jobId,candidateAddress))
    {
      uint16 referId = referralCounter++;
      
      candidateList[candidateAddress].refers.push(referId);
      jobList[jobId].refers.push(referId);


      FrontDoorStructs.Referral memory referral = FrontDoorStructs.Referral({
        id: referId,
        isConfirmed: false,
        isSucceed: false,
        score: 0,
        candidate: candidateAddress,
        job: jobId,
        owner: msg.sender,
        timeAtWhichReferralStarted: uint40(block.timestamp),
        timeReferralEnd: 0
      });
      referralList[referId] = referral;
      recruiterList[msg.sender].refers.push(referId);
      emit RegisterReferral(msg.sender, jobId, referId);
      return referId;
    }
    return 0;
  }
  
  function confirmReferral(uint16 _referralCounter, uint16 _jobId) external nonReentrant {
    require(referralList[_referralCounter].isConfirmed == false, "Referral is already confirmed");
    require(referralList[_referralCounter].isSucceed == false, "Job is already succeed");
    require(jobList[referralList[_referralCounter].job].timeOfJobCreated + 30 days > block.timestamp, "Job is expired");
    require(candidateList[referralList[_referralCounter].candidate].isHired == false, "Candidate is already hired");
    require(referralList[_referralCounter].timeAtWhichReferralStarted + 2 weeks > block.timestamp, "Referral is expired");

    referralList[_referralCounter].isConfirmed = true;
    recruiterList[referralList[_referralCounter].owner].numberOfContactedCandidates++;
    referralList[_referralCounter].candidate = msg.sender;    
    jobList[_jobId].refers.push(referralList[_referralCounter].id);

    emit ReferralConfirmed(msg.sender, _referralCounter, _jobId);
  }


  function hireCandidate(
    address _candidateAddress,
    uint16 _jobId
  ) external nonReentrant {
    require(candidateList[_candidateAddress].isHired == false, "Candidate is already hired"); // check if candidate is already hired or not
    require(jobList[_jobId].isSucceed == false, "Job is already succeed"); // check if job is already succeed or not

    candidateList[_candidateAddress].isHired = true;
    jobList[_jobId].timeOfCandidateHire.push(uint40(block.timestamp));
    for(uint i=0; i<jobList[_jobId].refers.length;i++)
      if(referralList[jobList[_jobId].refers[i]].candidate == _candidateAddress)  jobList[_jobId].hiredRefers.push(jobList[_jobId].refers[i]);
    
    emit CandidateHired(msg.sender, _candidateAddress, _jobId);
  }

  function getCandidate(address wallet) external view returns (FrontDoorStructs.Candidate memory) {
    return candidateList[wallet];
  }

  function getRecruiter(address wallet) external view returns (FrontDoorStructs.Recruiter memory) {
    return recruiterList[wallet];
  }

  function getRecruiterScore(address wallet) public view returns (uint256) {
    return recruiterList[wallet].score.finalScore;
  }

  function getCompanyScore(address companyAddress) public view returns (uint256) {
    return companyList[companyAddress].score.finalScore;
  }
  function getCandidateScore(address candidateAddress) public view returns (uint256) {
    return candidateList[candidateAddress].score.finalScore;
  }

  function getMyRefferals() public view returns ( uint16[] memory){
    return recruiterList[msg.sender].refers;
  }
  
  function getCandidateListForJob(uint16 _jobId) public view returns (address[] memory) {
    address[] memory hiredCandidates = new address[](jobList[_jobId].refers.length);
    for (uint i = 0; i < jobList[_jobId].refers.length; i++) {
        hiredCandidates[i] = referralList[jobList[_jobId].refers[i]].candidate;
    }
    return hiredCandidates;
  }

  function candidateStatus(address _candidateAddress) public view returns(bool) {
    return candidateList[_candidateAddress].isHired;
  }

  function getHiredCandidatesByJobId(uint16 _jobId) public view returns (address[] memory) {
    address[] memory hiredCandidates = new address[](jobList[_jobId].hiredRefers.length); // Initialize the array with the correct size
    for (uint i = 0; i < jobList[_jobId].hiredRefers.length; i++) {
        hiredCandidates[i] = referralList[jobList[_jobId].hiredRefers[i]].candidate;
    }
    return hiredCandidates;
  }

  function getCompanyJobs(address _companyAddress) public view returns (uint16[] memory) {
    return companyList[_companyAddress].jobIds;
  }

  function diburseBounty(uint16 _jobId) external nonReentrant {
    require(jobList[_jobId].isSucceed == true, "Job is not succeed yet");
    require(jobList[_jobId].refers.length > 0, "No candidate is hired yet");
    require(jobList[_jobId].isDibursed == false, "Bounty is already dibursed");
    require(jobList[_jobId].creator == msg.sender, "Only job creator can diburse");
    require(jobList[_jobId].timeOfJobCreated + 90 days < block.timestamp,"90 days are not completed yet");
    jobList[_jobId].isDibursed = true;
    uint256 bounty = jobList[_jobId].bounty;


    uint hiredCounts = jobList[_jobId].hiredRefers.length;
    for(uint i=0;i<hiredCounts;i++)
    {
      FrontDoorStructs.Referral memory currentRefer = referralList[jobList[_jobId].hiredRefers[i]];
      ERC20(acceptedTokenAddress).approve(currentRefer.owner, bounty * 6500 / 10_000 / hiredCounts);
      ERC20(acceptedTokenAddress).approve(currentRefer.candidate, bounty * 1000 / 10_000 / hiredCounts);
      ERC20(acceptedTokenAddress).approve(frontDoorAddress, bounty * 2500 / 10_000 / hiredCounts);
      bool successOwner = ERC20(acceptedTokenAddress).transfer(currentRefer.owner, bounty * 6500 / 10_000 / hiredCounts);
      bool successCandidate = ERC20(acceptedTokenAddress).transfer(currentRefer.candidate, bounty * 1000 / 10_000 / hiredCounts);
      bool successFrontDoor = ERC20(acceptedTokenAddress).transfer(frontDoorAddress, bounty * 2500 / 10_000 / hiredCounts);
 
      if (successOwner) {
        bountyClaim[currentRefer.owner] += (bounty * 6500) / 10_000 / hiredCounts;
      }

      if (successCandidate) {
        bountyClaim[currentRefer.candidate] += (bounty * 1000) / 10_000 / hiredCounts;
      }

      if (successFrontDoor) {
        bountyClaim[frontDoorAddress] += (bounty * 2500) / 10_000 / hiredCounts;
      }
    }
  }
  function updateFinalScore(address userAddress, uint kind) private returns (uint256) {
    if(kind == 0) {
      uint8[3] memory weight=[10,8,7];
      uint16 sum=0;
      uint8 div=0;
      for(uint8 i=0;i<companyList[userAddress].score.scores.length;i++)
      {
        uint8 w=i>2?5:weight[i];
        div+=w;
        sum+=companyList[userAddress].score.scores[i]*w*20;
      }
      return sum/div;
    }
    else if (kind == 1) {
      uint16 sum=0;
      uint i;
      for(i=0;i<recruiterList[userAddress].refers.length;i++)
        sum+=referralList[recruiterList[userAddress].refers[i]].score;
      return sum*recruiterList[userAddress].numberOfContactedCandidates * recruiterList[userAddress].numberOfSuccesfullReferrals/(recruiterList[userAddress].refers.length*i);
    }
    else {
      uint16 sum=0;
      uint i;
      for(i=0;i<companyList[userAddress].score.scores.length;i++)
        sum+=companyList[userAddress].score.scores[i];
      sum=uint16(sum/i);
      return sum;
    }
  }
  function setScore(uint16 referralId, uint kind, uint16 score) internal {
    if(kind == 2) {
      address userAddress = jobList[referralList[referralId].job].creator;
      companyList[userAddress].score.scores.push(score);
      companyList[userAddress].score.senderAddress.push(msg.sender);
      companyList[userAddress].score.finalScore= updateFinalScore(userAddress,kind);
    }
    else if(kind == 0) {
      address userAddress = referralList[referralId].candidate;
      candidateList[userAddress].score.scores.push(score);
      candidateList[userAddress].score.senderAddress.push(msg.sender);
      candidateList[userAddress].score.finalScore= updateFinalScore(userAddress,kind);

      userAddress = referralList[referralId].owner;
      recruiterList[userAddress].score.scores.push(score);
      recruiterList[userAddress].score.senderAddress.push(referralList[referralId].candidate);
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
  event RegisterReferral(address indexed refferer, uint16 indexed jobId, uint16 referralId);
  event JobCreated(address indexed companyAddress, uint16 indexed jobId);
}