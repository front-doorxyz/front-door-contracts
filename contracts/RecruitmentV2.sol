// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "hardhat/console.sol";

contract RecruitmentV2 is Ownable, ReentrancyGuard {
    IERC20 public frontDoorTkn;
    address frontDoorAddress;

    struct Company {
        address companyAddress;
        uint8 score;
    }

    struct Job {
        address companyAddress;
        uint256 bounty;
        uint256 creationTime;
        uint256 closedTime;
        uint256 hiredTime;
        uint256 hiredReferralId;
        uint256 jobId;
        bool isOpen;
        bool isDisbursed;
    }

    struct Referral {
        address referrerAddress;
        uint256 jobId;
        bytes32 candidateEmail;
        bytes32 referralCode;
        uint256 timeCreatead;
        uint256 id;
        bool isHired;
        bool isConfirmed;
    }

    struct Referrer {
        address reffererAddress;
        bytes32 email;
        uint8 score;
    }

    struct Candidate {
        address candidateAddress;
        bytes32 email;
        uint8 score;
    }

    mapping(address => uint256) public balances;
    mapping(address => Company) public companies;
    mapping(uint256 => Job) public jobs;
    mapping(uint256 => Referral) public referrals;
    mapping(uint256 => uint256[]) public jobIdToRefferals;
    mapping(address => Referrer) public referrers;
    mapping(bytes32 => address) public emailToReferrerAddress;
    mapping(address => uint256[]) public companyToJobs;
    mapping(address => uint256[]) public referrerToReferrals;
    mapping(bytes32 => Candidate) public candidates;
    mapping(address => mapping(bytes32 => bool)) public companyToHiredCandidate;
    mapping(address => mapping(address => bool)) public companyToReferred;
    mapping(address => bytes32) public candidateAddressToEmail;

    uint256 private nextJobId;
    uint256 private nextReferralId;

    modifier validScore(uint8 _score) {
        require(_score > 0 && _score <= 100, "Invalid score");
        _;
    }

    modifier onlyRegisteredCompany() {
        require(
            companies[msg.sender].companyAddress != address(0),
            "Not a registered company"
        );
        _;
    }

    modifier onlyOpenJob(uint256 jobId) {
        require(jobs[jobId].isOpen, "Job is not open");
        _;
    }

    constructor(address tokenAddress, address _frontDoorAddress) Ownable() {
        frontDoorTkn = IERC20(tokenAddress);
        frontDoorAddress = _frontDoorAddress;
    }

    /// Register a Company
    function registerCompany() external {
        require(
            companies[msg.sender].companyAddress == address(0),
            "Already registered"
        );
        companies[msg.sender] = Company(msg.sender, 0);
        emit CompanyRegistered(msg.sender);
    }

    /// Register a Referrer
    /// @param _email hashed email of the referrer in bytes32
    function registerReferrer(bytes32 _email) external {
        require(_email.length > 0, "Invalid email hash");
        require(
            referrers[msg.sender].reffererAddress == address(0),
            "Already registered referrer"
        );
        require(
            emailToReferrerAddress[_email] == address(0),
            "Email already registered"
        );
        referrers[msg.sender] = Referrer(msg.sender, _email, 0, 0);
        emailToReferrerAddress[_email] = msg.sender;
        emit ReferrerRegistered(msg.sender, _email);
    }

    /// Creates jobs for a company and stores them in the jobs mapping
    /// @param _bounty bounty for each job
    /// @param _vacants number of vacants for this position
    function registerJob(
        uint256 _bounty,
        uint8 _vacants
    ) external onlyRegisteredCompany {
        require(_bounty > 0, "Invalid bounty");
        require(_vacants > 0, "Invalid vacants");

        frontDoorTkn.transferFrom(msg.sender, address(this), _bounty * _vacants);
        balances[msg.sender] += _bounty * _vacants;
        for (uint8 i = 0; i < _vacants; i++) {
            uint256 jobId = nextJobId++;
            Job memory newJob = Job(
                msg.sender,
                _bounty,
                block.timestamp,
                0,
                0,
                0,
                true,
                false
            );
            jobs[jobId] = newJob;
            companyToJobs[msg.sender].push(jobId);
            emit JobCreated(msg.sender, jobId, block.timestamp);
        }
    }

    /// Refer a Candidate
    /// @param jobId Job id of the job for which the referral is made
    /// @param _candidateEmail hash of candidate email in bytes32
    /// @param _referralCode referral code of the referrer
    function referCandidate(
        uint256 jobId,
        bytes32 _candidateEmail,
        bytes32 _referralCode
    ) external {
        require(
            referrers[msg.sender].reffererAddress != address(0),
            "Not a registered referrer"
        );
        require(_candidateEmail.length > 0, "Invalid candidate email");
        require(_referralCode.length > 0, "Invalid referral code");
        require(jobs[jobId].companyAddress != address(0), "Job does not exist");
        require(jobs[jobId].isOpen, "Job is not open");
        uint256 referralId = nextReferralId++;

        Referral memory newReferral = Referral(
            msg.sender,
            jobId,
            _candidateEmail,
            _referralCode,
            block.timestamp,
            referralId,
            false,
            false
        );

        referrals[referralId] = newReferral;
        referrerToReferrals[msg.sender].push(referralId);
        jobIdToRefferals[jobId].push(referralId);
        companyToReferred[jobs[jobId].companyAddress][msg.sender] = true;
        emit ReferralMade(msg.sender, referralId);
    }

    /// Confirm Refferal by the candidate
    /// @param _referralId referral id of the referral
    /// @param _referralCode referral code of the referrer
    /// @param _candidateEmail hash of candidate email in bytes32
    function confirmReferral(
        uint256 _referralId,
        bytes32 _referralCode,
        bytes32 _candidateEmail
    ) external {
        uint256 _jobId = referrals[_referralId].jobId;
        require(
            referrals[_referralId].candidateEmail == _candidateEmail,
            "Not a candidate"
        );
        require(
            referrals[_referralId].isConfirmed == false,
            "Already confirmed"
        );
        require(referrals[_referralId].jobId == _jobId, "Invalid job id");
        require(
            referrals[_referralId].referralCode == _referralCode,
            "Invalid referral code"
        );
        require(jobs[_jobId].isOpen, "Job is not open");
        require(jobs[_jobId].companyAddress != address(0), "Job does not exist");
        require(
            referrals[_referralId].timeCreatead + 2 weeks > block.timestamp,
            "Referral expired"
        );
        if (candidates[_candidateEmail].candidateAddress == address(0)) {
            candidateAddressToEmail[msg.sender] = _candidateEmail;
            candidates[_candidateEmail] = Candidate(
                msg.sender,
                _candidateEmail,
                0
            );
        }

        referrals[_referralId].isConfirmed = true;
        emit ReferralConfirm(_referralId, _jobId, _candidateEmail);
    }

    /// Hire a candidate
    /// @param referralId referral id of the referral
    function hireCandidate(
        uint256 referralId
    ) external onlyRegisteredCompany onlyOpenJob(referrals[referralId].jobId) {
        Referral storage referral = referrals[referralId];
        Job storage job = jobs[referral.jobId];

        require(msg.sender == job.companyAddress, "Only the company can hire");
        require(!referral.isHired, "Candidate already hired");
        require(referral.isConfirmed, "Referral not confirmed");

        referral.isHired = true;
        job.isOpen = false;
        job.hiredReferralId = referralId;
        companyToHiredCandidate[msg.sender][referral.candidateEmail] = true;
    }

    /// returns the jobs created by a company
    /// @param _company address of the company to retrive the jobs
    function getCompanyJobs(
        address _company
    ) public view returns (uint256[] memory) {
        require(
            companies[_company].companyAddress != address(0),
            "Company is not registered"
        );
        return companyToJobs[_company];
    }

    /// returns the referrals made by a referrer
    /// @param referrer address of the referrer
    function getReferrerReferrals(
        address referrer
    ) public view returns (uint256[] memory) {
        require(
            referrers[referrer].reffererAddress != address(0),
            "Referrer is not registered"
        );
        return referrerToReferrals[referrer];
    }

    /// Close a Job without hiring
    /// @param jobId job id of the job
    function closeJob(
        uint256 jobId
    ) external onlyRegisteredCompany onlyOpenJob(jobId) {
        Job storage job = jobs[jobId];
        require(
            msg.sender == job.companyAddress,
            "Only the company can close the job"
        );
        job.isOpen = false;
        frontDoorTkn.transfer(job.companyAddress, job.bounty); // transfer the bounty back to the company
    }

    /// Dirburse Job bounty after 90 days
    /// @param _jobId job id of the job for which the bounty is to be disbursed
    function disburseBounty(
        uint256 _jobId
    ) external nonReentrant onlyRegisteredCompany {
        require(
            jobs[_jobId].companyAddress == msg.sender,
            "Only the company can disburse bounty"
        );
        require(jobs[_jobId].isOpen == false, "Job is still open");
        require(jobs[_jobId].isDisbursed == false, "Bounty already disbursed");
        require(
            jobs[_jobId].creationTime + 90 days < block.timestamp,
            "90 days are not completed yet"
        );
        uint256 bounty = jobs[_jobId].bounty;
        uint256 referralId = jobs[_jobId].hiredReferralId;
        bytes32 candidateEmail = referrals[referralId].candidateEmail;
        address referrer = referrals[referralId].referrerAddress;
        address candidate = candidates[candidateEmail].candidateAddress;
        balances[msg.sender] -= bounty;
        balances[referrer] += (bounty * 6500) / 10_000;
        balances[candidate] += (bounty * 1000) / 10_000;
        balances[frontDoorAddress] = (bounty * 2500) / 10_000;
        jobs[_jobId].isDisbursed = true;
        emit BountyDisbursed(_jobId);
    }

    /// Claim rewards using Pull over Push pattern
    function claimRewards() external nonReentrant {
        uint256 balance = balances[msg.sender];
        require(balance > 0, "No rewards to claim");
        balances[msg.sender] = 0;
        frontDoorTkn.transfer(msg.sender, balance);

        emit ClaimedRewards(msg.sender, balance);
    }

    /// Get referrals of a job
    /// @param _jobId job id of the job
    function getReferralsOfJobId(
        uint256 _jobId
    ) external view returns (uint256[] memory) {
        return jobIdToRefferals[_jobId];
    }

    /// Provide Feedback to a candidate by the company
    /// @param _candidateEmail candidate email to provide feedback
    /// @param _score assigned score to the candidate
    function provideCandidateFeedback(
        bytes32 _candidateEmail,
        uint8 _score
    ) external onlyRegisteredCompany validScore(_score) {
        require(
            candidates[_candidateEmail].candidateAddress != address(0),
            "Candidate does not exist"
        );
        require(
            companies[msg.sender].companyAddress != address(0),
            "Company does not exist"
        );
        require(
            companyToHiredCandidate[msg.sender][_candidateEmail],
            "Candidate not hired by the company"
        );
        if (candidates[_candidateEmail].score == 0) {
            candidates[_candidateEmail].score = _score;
        }
        if (candidates[_candidateEmail].score != 0) {
            candidates[_candidateEmail].score =
                (candidates[_candidateEmail].score + _score) /
                2;
        }
        emit FeedbackProvided(
            candidates[_candidateEmail].candidateAddress,
            _score
        );
    }

    /// Provide Feedback to a company by the candidate
    /// @param _company company address to provide feedback
    /// @param _score score to be assigned to the company
    function provideCompanyFeedback(
        address _company,
        uint8 _score
    ) external validScore(_score) {
        require(_score > 0 && _score <= 100, "Invalid score");
        require(
            companies[_company].companyAddress != address(0),
            "Company does not exist"
        );
        require(
            candidateAddressToEmail[msg.sender].length > 0,
            "Not a candidate"
        );
        bytes32 candidateEmail = candidateAddressToEmail[msg.sender];
        require(
            companyToHiredCandidate[_company][candidateEmail],
            "Candidate not hired by the company"
        );
        if (companies[_company].score == 0) {
            companies[_company].score = _score;
        }
        if (companies[_company].score != 0) {
            companies[_company].score =
                (companies[_company].score + _score) /
                2;
        }
        emit FeedbackProvided(_company, _score);
    }

    /// Provide Feedback to a referrer by the company
    /// @param _referrer referrer address to provide feedback
    /// @param _score score to be assigned to the referrer
    function provideReferrerFeedback(
        address _referrer,
        uint8 _score
    ) external onlyRegisteredCompany validScore(_score) {
        require(
            referrers[_referrer].reffererAddress != address(0),
            "Referrer does not exist"
        );
        require(
            companyToReferred[msg.sender][_referrer],
            "Referrer not referred by the company"
        );
        if (referrers[_referrer].score == 0) {
            referrers[_referrer].score = _score;
        }
        if (referrers[_referrer].score != 0) {
            referrers[_referrer].score =
                (referrers[_referrer].score + _score) /
                2;
        }
        emit FeedbackProvided(_referrer, _score);
    }

    event JobCreated(
        address indexed company,
        uint256 jobId,
        uint256 creationTime
    );
    event FeedbackProvided(address indexed company, uint8 score);
    event ReferrerRegistered(address indexed referrer, bytes32 email);
    event ReferralMade(address indexed referrer, uint256 referralId);
    event ReferralConfirm(
        uint256 indexed referralId,
        uint256 indexed jobId,
        bytes32 indexed candidateEmail
    );
    event BountyDisbursed(uint256 indexed _jobId);
    event CompanyRegistered(address indexed company);
    event ClaimedRewards(address indexed user, uint256 amount);
}
