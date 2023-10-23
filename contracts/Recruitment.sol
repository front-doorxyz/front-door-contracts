// SPDX-License-Identifier: UNLICENSED
//Enable the optimizer
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "hardhat/console.sol";

import {FrontDoorStructs} from "./DataModel.sol";

error OnlyRefererAllowed();
error SenderIsNotReferee();
error OnlyJobCreatorAllowedToDelete();
error JobAlreadyDeleted();
error JobListingLimitExceed();
error CompanyNotListed();
error BountyNotPaid();
error CandidateNotHiredByCompany();
error SameCandidateCannotBeReferredTwice();
error NotEnoughFundDepositedByCompany();
error InvalidMonth();

// Register a company, publish a job
// Register a a cadidate
// Register a a referrer
// referrer can refer a candidate
// company can hire a candidate
// company can pay bounty to hire a candidate

contract Recruitment is Ownable, ReentrancyGuard {
    // =============    Defining Mapping        ==================
    mapping(address => uint256) public companyaccountBalances;
    mapping(address => FrontDoorStructs.Candidate) public candidateList;
    mapping(address => FrontDoorStructs.Referrer) public referrerList;
    mapping(address => FrontDoorStructs.Company) public companyList;
    mapping(uint256 => FrontDoorStructs.Job) public jobList;
    mapping(address => uint256[]) public referralIndex;
    mapping(address => uint256) public confirmedReferralCount;
    mapping(uint256 => FrontDoorStructs.Referral) public referralList;
    address[] public companiesAddressList; // list of address of company

    mapping(address => FrontDoorStructs.UserScore[]) public referralScores;
    mapping(address => FrontDoorStructs.UserScore[]) public companyScores;
    mapping(address => FrontDoorStructs.UserScore[]) public candidateScores;

    mapping(address => mapping(address => bool)) public hasScoredCompany; //allows only to score once
    mapping(address => bool) public isCompany; // check if company is registered or not

    mapping(uint256 => FrontDoorStructs.Candidate[]) public candidateListForJob; // list of candidates for a job
    mapping(uint256 => FrontDoorStructs.Candidate[]) public hiredCpandidateListForJob;

    mapping(address => uint256) public bountyClaim;

    mapping(uint16 => bytes32) public JobIdtoTeferralCodeList;
    mapping(bytes32 => uint16) public referralCodeToJobId;
    mapping(bytes32 => FrontDoorStructs.ReferralCode) public referralCodeList;

    // Company address  to candidate address  hired by company
    mapping(address => address[]) public companyAddressToHiredCandidateAddress;

    //  Counters
    uint16 private jobIdCounter = 1;
    uint16 private referralCounter = 1;

    address frontDoorAddress;

    IERC20 public frontDoorToken;

    // Constructor
    constructor(address _acceptedTokenAddress, address _frontDoorAddress) {
        frontDoorToken = IERC20(_acceptedTokenAddress);
        frontDoorAddress = _frontDoorAddress;
    }

    /**
     * @param _address company address
     * @dev Checks whether the address of Company is in CompanyList or not
     */
    modifier checkIfItisACompany(address _address) {
        require(isCompanyRegistered(_address), "Company is not registered yet");
        _;
    }

    modifier checkIfCandidateHiredByCompany(
        address candidateAddress,
        address companyAddress
    ) {
        bool isCandidateHired = false;
        address[]
            memory hiredCandidates = companyAddressToHiredCandidateAddress[
                companyAddress
            ];
        for (uint256 i = 0; i < hiredCandidates.length; i++) {
            if (hiredCandidates[i] == candidateAddress) {
                isCandidateHired = true;
                break;
            }
        }

        if (isCandidateHired == false) {
            revert CandidateNotHiredByCompany();
        }
        _;
    }

    //   Register Functions

    function isCompanyRegistered(address _company) public view returns (bool) {
        return isCompany[_company];
    }
    function registerCandidate() external {
      FrontDoorStructs.Candidate memory newCandidate = FrontDoorStructs.Candidate(
          msg.sender,
          0,
          address(0),
          0,
          0,
          false,
          false,
          false
      );
      candidateList[msg.sender] = newCandidate;
    }
    /**
     * @notice Register a Referrer with email
     * @param email email of the referee
     */
    function registerReferrer(bytes32 email) external {
        FrontDoorStructs.Referrer memory referrer = FrontDoorStructs.Referrer(
            msg.sender,
            email,
            0,
            0
        );
        referrerList[msg.sender] = referrer;
    }

    /**
     * @param bounty amount paid by company to hire candidate
     */
    function registerJob(
        uint256 bounty
    )
        external
        payable
        nonReentrant
        checkIfItisACompany(msg.sender)
        returns (uint16)
    {
        uint16 jobId = jobIdCounter;
        require(bounty > 0, "Bounty should be greater than 0"); // check if company is giving bounty or not
        FrontDoorStructs.Job memory job = FrontDoorStructs.Job(
            msg.sender,
            bounty,
            uint40(block.timestamp),
            0,
            jobId,
            false,
            false,
            false
        );

        jobList[jobId] = job;
        jobIdCounter++;
        companyList[msg.sender].jobsCreated++;

        // implement  company to pay the bounty upfront
        frontDoorToken.approve(address(this), bounty); // asking user for approval to transfer bounty

        bool success = frontDoorToken.transferFrom(
            msg.sender,
            address(this),
            bounty
        );

        if (!success) {
            revert BountyNotPaid();
        }

        companyaccountBalances[msg.sender] += bounty;
        emit DepositCompleted(msg.sender, bounty, jobId);
        emit JobCreated(msg.sender, jobId);
        return jobId;
    }

    /**
     * @notice Registers a Company
     */
    function registerCompany() external {
        FrontDoorStructs.Company memory company = FrontDoorStructs.Company(
            msg.sender,
            0,
            0,
            new address[](0)
        );
        companyList[msg.sender] = company;
        companiesAddressList.push(msg.sender);
        isCompany[msg.sender] = true;
    }

    /**
     * @notice Registers a referral
     * @param jobId The job ID already registered with the contract.
     * @param refereeMail The email of the referee.
     * @param referralCode The referral code of the referee, it must be unique and hashed.
     */
    function registerReferral(
        uint256 jobId,
        bytes32 refereeMail,
        bytes32 referralCode
    ) external nonReentrant returns (uint256) {
        // Simple Checks Of Parameters
        require(jobId > 0, "Job Id should be greater than 0"); // check if job is registered or not
        require(refereeMail.length > 0, "Referee Mail should not be empty"); // check if referee mail is empty or not
        require(referralCode.length > 0, "Referral Code should not be empty"); // check if referral code is empty or not
        require(
            referralCodeToJobId[referralCode] == 0,
            "Referral Code should be unique"
        ); // check if referral code is unique or not

        FrontDoorStructs.Candidate memory candidate;
        FrontDoorStructs.Referrer memory referrer = referrerList[msg.sender];
        FrontDoorStructs.Job memory job = jobList[jobId];

        candidate.email = refereeMail;
        candidate.referrer = msg.sender;
        referralCodeToJobId[referralCode] = uint16(jobId);

        FrontDoorStructs.Referral memory referral = FrontDoorStructs.Referral(
            referrer,
            candidate,
            job,
            referralCode,
            uint40(block.timestamp),
            uint40(block.timestamp + 2 weeks),
            referralCounter,
            false
        );
        referralIndex[msg.sender].push(referralCounter);
        referralList[referralCounter] = referral;
        uint256 referralId = referralCounter;
        referralCounter++;
        emit RegisterReferral(refereeMail, msg.sender, jobId, referralId);
        return referralId;
    }

    /// @notice Allows the referral to confirm that accepts the referral to the job
    /// @param _referralCounter id of the referral
    /// @param _jobId job id that the candite is referred for
    /// @param _referralCode referral code of the referral
    function confirmReferral(
        uint256 _referralCounter,
        uint256 _jobId,
        bytes32 _referralCode
    ) external nonReentrant {
        // Some Checks
        require(
            referralList[_referralCounter].isConfirmed == false,
            "Referral is already confirmed"
        ); // check if referral is already confirmed or not
        require(
            referralList[_referralCounter].job.issucceed == false,
            "Job is already succeed"
        ); // check if job is already succeed or not
        require(
            referralList[_referralCounter].job.timeAtWhichJobCreated + 30 days >
                block.timestamp,
            "Job is expired"
        ); // check if job is expired or not
        require(
            referralList[_referralCounter].candidate.isHired == false,
            "Candidate is already hired"
        ); // check if candidate is hired
        require(
            referralList[_referralCounter].referralEnd > block.timestamp,
            "Referral is expired"
        ); // check if referral is expired or not
        require(
            referralCodeToJobId[_referralCode] == _jobId,
            "Referral code is not valid for job id"
        );
        require(
            referralList[_referralCounter].referralCode == _referralCode,
            "Invalid Referral Code"
        ); // check if referral code is valid for referral
        confirmedReferralCount[candidateList[msg.sender].referrer]++;
        // Code Logic
        referralList[_referralCounter].isConfirmed = true;
        referralList[_referralCounter].candidate.wallet = msg.sender;
        candidateList[msg.sender] = referralList[_referralCounter].candidate;

        emit ReferralConfirmed(msg.sender, _referralCounter, _jobId); // emit event

        // push into a mapping jobsid => candidates

        candidateListForJob[_jobId].push(
            referralList[_referralCounter].candidate
        );
    }

    /**
     * @param _candidateAddress Candidate address
     * @param _jobId job id
     * @notice Simply sets isHired to true for the candidate , sets timestamp of hiring and incurease candidate count on that job
     */
    function hireCandidate(
        address _candidateAddress,
        uint256 _jobId
    ) external nonReentrant checkIfItisACompany(msg.sender) {
        // Some Checks
        require(
            candidateList[_candidateAddress].isHired == false,
            "Candidate is already hired"
        ); // check if candidate is already hired or not
        require(jobList[_jobId].issucceed == false, "Job is already succeed"); // check if job is already succeed or not

        // Code Logic
        candidateList[_candidateAddress].isHired = true;
        candidateList[_candidateAddress].timeOfHiring = uint40(block.timestamp);
        jobList[_jobId].numberOfCandidateHired += 1;
        jobList[_jobId].issucceed = true;
        hiredCpandidateListForJob[_jobId].push(candidateList[_candidateAddress]);
        companyAddressToHiredCandidateAddress[msg.sender].push(_candidateAddress);
        // if ((companyaccountBalances[msg.sender]) >= (jobList[_jobId].bounty * jobList[_jobId].numberOfCandidateHired)) {
        //   revert Errors.NotEnoughFundDepositedByCompany();
        // }

        emit CandidateHired(msg.sender, _candidateAddress, _jobId); // emit event
    }

    function getCandidate(
        address wallet
    ) external view returns (FrontDoorStructs.Candidate memory) {
        return candidateList[wallet];
    }

    function getReferrer(
        address wallet
    ) external view returns (FrontDoorStructs.Referrer memory) {
        return referrerList[wallet];
    }

    function getReferralScores(
        address referrerWallet
    ) public view returns (FrontDoorStructs.UserScore[] memory) {
        return referralScores[referrerWallet];
    }

    function getCompanyScores(
        address companyAddress
    ) public view returns (FrontDoorStructs.UserScore[] memory) {
        return companyScores[companyAddress];
    }

    function getAllJobsOfCompany(
        address companyWallet
    ) external view returns (FrontDoorStructs.Job[] memory) {
        uint256 jobsFetched = 0;

        // Count the number of jobs for the company
        for (uint256 i = 1; i < jobIdCounter; i++) {
            if (jobList[i].creator == companyWallet && !jobList[i].isRemoved) {
                jobsFetched++;
            }
        }

        // Initialize the memory array
        FrontDoorStructs.Job[] memory jobArray = new FrontDoorStructs.Job[](
            jobsFetched
        );
        uint256 index = 0;

        // Populate the memory array with jobs
        for (uint256 i = 1; i < jobIdCounter; i++) {
            if (jobList[i].creator == companyWallet && !jobList[i].isRemoved) {
                FrontDoorStructs.Job storage currentJob = jobList[i];
                jobArray[index] = currentJob;
                index++;
            }
        }

        return jobArray;
    }

    /// Returns the numbers of refferals that a refferer has made
    function getMyRefferals() public view returns (uint256[] memory) {
        return referralIndex[msg.sender];
    }

    //TODO  validate if sender is the company that created the job
    function getCandidateListForJob(
        uint256 _jobId
    ) public view returns (FrontDoorStructs.Candidate[] memory) {
        return candidateListForJob[_jobId];
    }

    function candidateStatus(
        address _candidateAddress
    ) public view returns (bool) {
        return candidateList[_candidateAddress].isHired;
    }

    function getCandidateHiredJobId(
        uint256 _jobId
    ) public view returns (FrontDoorStructs.Candidate[] memory) {
        return hiredCpandidateListForJob[_jobId];
    }

    /// disburseBounty
    /// @param _jobId Job id
    /// @dev disburse bounty to referrer, candidate and frontDoorAddress using Pull over Push pattern
    function disburseBounty(
        uint256 _jobId
    ) external nonReentrant checkIfItisACompany(msg.sender) {
        require(jobList[_jobId].issucceed == true, "Job is not succeed yet");
        require(
            jobList[_jobId].numberOfCandidateHired > 0,
            "No candidate is hired yet"
        );
        require(
            jobList[_jobId].isDisbursed == false,
            "Bounty is already disbursed"
        );
        require(
            jobList[_jobId].timeAtWhichJobCreated + 90 days < block.timestamp,
            "90 days are not completed yet"
        );
        require(
            jobList[_jobId].creator == msg.sender,
            "Only job creator can disburse"
        );

        jobList[_jobId].isDisbursed = true;
        uint256 bounty = jobList[_jobId].bounty;

        uint hiredCount = hiredCpandidateListForJob[_jobId].length;
        for(uint i = 0 ; i < hiredCount ; i++) {
          bountyClaim[hiredCpandidateListForJob[_jobId][i].referrer] =
              bountyClaim[hiredCpandidateListForJob[_jobId][i].referrer] +
              (bounty * 6500) / hiredCount / 
              10_000;
          bountyClaim[hiredCpandidateListForJob[_jobId][i].wallet] =
              bountyClaim[hiredCpandidateListForJob[_jobId][i].wallet] +
              (bounty * 1000) / hiredCount / 
              10_000;
        }
        bountyClaim[frontDoorAddress] =
          bountyClaim[frontDoorAddress] +
          (bounty * 2500) /
          10_000;

        emit BountyDisburse(_jobId);
    }

    /// claimBounty
    /// @dev claim disbursed bounty
    function claimBounty() external nonReentrant {
        uint256 bounty = bountyClaim[msg.sender];
        require(bounty > 0, "No bounty to claim");
        bountyClaim[msg.sender] = 0;
        frontDoorToken.transfer(msg.sender, bounty);
    }

    function setCanidateScoreFromCompany(address candidateAddress, uint256 score) public {
        require(isCompany[msg.sender] == true , "You can't give score to candidate");
        FrontDoorStructs.UserScore memory newScore = FrontDoorStructs.UserScore (
          score,
          msg.sender
        );
        candidateScores[candidateAddress].push(newScore);
        referralScores[candidateList[candidateAddress].referrer].push(newScore);
        updateCandidateScore(candidateAddress);
        updateReferrerScore(candidateList[candidateAddress].referrer);
    }
    function setCompanyScoreFromCandidate(address companyAddress, uint256 score) public checkIfCandidateHiredByCompany(msg.sender , companyAddress) {
       FrontDoorStructs.UserScore memory newScore = FrontDoorStructs.UserScore (
          score,
          msg.sender
        );
        companyScores[companyAddress].push(newScore);
        updateCompanyScore(companyAddress);
    }
    function updateCompanyScore(address companyAddress) internal {
      uint256 finalScore = 0 ;
      uint256 count = companyScores[companyAddress].length;
      for(uint i = 0 ; i < count ; i++)
        finalScore += companyScores[companyAddress][i].score;
      companyList[companyAddress].score = uint256(finalScore / count);
    }
    function updateReferrerScore(address referrerAddress) internal {
      uint256 finalScore = 0 ;
      uint256 count = referralScores[referrerAddress].length;
      for(uint i = 0 ; i < count ; i++)
        finalScore += referralScores[referrerAddress][i].score;
      referrerList[referrerAddress].score = (finalScore * confirmedReferralCount[referrerAddress]) / referralIndex[referrerAddress].length;
    }
    function updateCandidateScore(address candidateAddress) internal {
      uint finalScore = 0 ;
      uint count = candidateScores[candidateAddress].length;
      if(count == 1) finalScore = candidateScores[candidateAddress][0].score;
      else if(count == 2) finalScore = (candidateScores[candidateAddress][0].score*2 + candidateScores[candidateAddress][1].score*3 ) /5;
      else {
        for(uint i = 0 ; i < count-2 ; i++)
          finalScore += candidateScores[candidateAddress][i].score;
        finalScore += candidateScores[candidateAddress][count-2].score * 2;
        finalScore += candidateScores[candidateAddress][count-1].score * 3;
        finalScore = finalScore / (count + 3);
      }
      candidateList[candidateAddress].score = finalScore;
    }
    function getCandidateScore(address Address) external view returns (uint256) {
      return candidateList[Address].score;
    }
    function getReferrerScore(address Address) external view returns (uint256) {
      return referrerList[Address].score;
    }
    function getCompanyScore(address Address) external view returns (uint256) {
      return companyList[Address].score;
    }

    event BountyDisburse(uint256 _jobId);
    event PercentagesCompleted(
        address indexed sender,
        uint8 month1RefundPct,
        uint8 month2RefundPct,
        uint8 month3RefundPct
    );
    event DepositCompleted(
        address indexed sender,
        uint256 amount,
        uint256 jobId
    );
    event ReferralScoreSubmitted(
        address senderAddress,
        address referrerWallet,
        uint256 score
    );
    event CompanyScoreSubmitted(
        address senderAddress,
        address companyAddress,
        uint256 score
    );
    event ReferCandidateSuccess(
        address indexed sender,
        address indexed candidateAddress,
        uint256 indexed jobId
    );
    event CandidateHired(
        address indexed companyAddress,
        address candidateAddress,
        uint256 jobId
    );
    event ReferralConfirmed(
        address indexed candidateAddress,
        uint256 indexed referralId,
        uint256 indexed jobId
    );
    event ReferralRejected(
        address indexed candidateAddress,
        uint256 indexed referralId,
        uint256 indexed jobId
    );
    event CandidateHiredSuccesfullyAfter90Days(
        address indexed companyAddress,
        address candidateAddress,
        uint256 jobId
    );
    event RegisterReferral(
        bytes32 indexed email,
        address indexed refferer,
        uint256 indexed jobId,
        uint256 referralId
    );
    event JobCreated(address indexed companyAddress, uint256 indexed jobId);
}
