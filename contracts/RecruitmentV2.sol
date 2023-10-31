// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RecruitmentV2 is Ownable {
    IERC20 public token;

    struct Company {
        address wallet;
        uint8 score;
        bool isRegistered;
    }

    struct Job {
        address company;
        uint256 bounty;
        uint256 creationTime;
        bool isOpen;
    }

    struct Referral {
        address referrer;
        uint256 jobId;
        bytes32 candidateEmail;
        bytes32 referralCode;
        uint256 timeCreatead;
        uint256 id;
        bool isHired;
        bool isConfirmed;
    }

    struct Referrer {
        address wallet;
        bytes32 email;
        uint256 totalEarned;
        uint256 rewardsToClaim;
        uint8 score;
        bool isReferrer;
    }

    struct Candidate {
        address wallet;
        bytes32 email;
        uint8 score;
        bool isCandidate;
    }

    mapping(address => Company) public companies;
    mapping(uint256 => Job) public jobs;
    mapping(uint256 => Referral) public referrals;
    mapping(uint256 => uint256[]) public jobIdRefferals;
    mapping(address => Referrer) public referrers;
    mapping(address => uint256[]) public companyToJobs;
    mapping(address => uint256[]) public referrerToReferrals;
    mapping(bytes32 => Candidate) public candidates;

    uint256 public nextJobId;
    uint256 public nextReferralId;

    modifier onlyRegisteredCompany() {
        require(
            companies[msg.sender].isRegistered == true,
            "Not a registered company"
        );
        _;
    }

    modifier onlyOpenJob(uint256 jobId) {
        require(jobs[jobId].isOpen, "Job is not open");
        _;
    }

    constructor(address tokenAddress) {
        token = IERC20(tokenAddress);
    }

    /// Register a Company
    function registerCompany() external {
        require(
            companies[msg.sender].isRegistered == false,
            "Already registered"
        );
        companies[msg.sender] = Company(msg.sender, 0, true);
        emit CompanyRegistered(msg.sender);
    }

    /// Register a Referrer
    /// @param _email hashed email of the referrer in bytes32
    function registerReferrer(bytes32 _email) external {
        require(_email.length > 0, "Invalid email hash");
        require(
            referrers[msg.sender].wallet != address(0),
            "Already registered referrer"
        );
        referrers[msg.sender] = Referrer(msg.sender, _email, 0, 0, 0, true);
        emit ReferrerRegistered(msg.sender, _email);
    }

    /// Creates jobs for a company and stores them in the jobs mapping
    /// @param _bounty bounty for each job
    /// @param _vacants number of vacants for this position
    function createJob(
        uint256 _bounty,
        uint8 _vacants
    ) external onlyRegisteredCompany {
        require(_bounty > 0, "Invalid bounty");
        require(_vacants > 0, "Invalid vacants");
        for (uint8 i = 0; i < _vacants; i++) {
            uint256 jobId = nextJobId++;
            Job memory newJob = Job(
                msg.sender,
                _bounty / _vacants,
                block.timestamp,
                true
            );
            jobs[jobId] = newJob;
            companyToJobs[msg.sender].push(jobId);
            emit JobCreated(msg.sender, jobId, block.timestamp);
        }
    }

    /// Reffer a Candidate
    /// @param jobId Job id of the job for which the referral is made
    /// @param _candidateEmail hash of candidate email in bytes32
    /// @param _referralCode referral code of the referrer
    function referCandidate(
        uint256 jobId,
        bytes32 _candidateEmail,
        bytes32 _referralCode
    ) external {
        require(
            referrers[msg.sender].wallet != address(0),
            "Not a registered referrer"
        );
        require(_candidateEmail.length > 0, "Invalid candidate email");
        require(_referralCode.length > 0, "Invalid referral code");
        require(jobs[jobId].company != address(0), "Job does not exist");
        require(jobs[jobId].isOpen, "Job is not open");
        require(referrers[msg.sender].isReferrer, "Not a registered referrer");
        uint256 referralId = nextReferralId++;
        Candidate memory newCandidate = Candidate(
            address(0),
            _candidateEmail,
            0,
            true
        );

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
        require(jobs[_jobId].company != address(0), "Job does not exist");
        require(
            referrals[_referralId].timeCreatead + 2 weeks > block.timestamp,
            "Referral expired"
        );

        candidates[_candidateEmail] = Candidate(
            msg.sender,
            _candidateEmail,
            0,
            true
        );
        referrals[_referralId].isConfirmed = true;
        emit ReferralConfirm(_referralId, _jobId, _candidateEmail);
    }

    function hireCandidate(
        uint256 referralId
    ) external onlyRegisteredCompany onlyOpenJob(referrals[referralId].jobId) {
        Referral storage referral = referrals[referralId];
        Job storage job = jobs[referral.jobId];

        require(msg.sender == job.company, "Only the company can hire");
        require(!referral.isHired, "Candidate already hired");
        require(
            token.balanceOf(msg.sender) >= job.bounty,
            "Insufficient balance"
        );
        require(
            token.allowance(msg.sender, address(this)) >= job.bounty,
            "Insufficient allowance"
        );

        referral.isHired = true;
        job.isOpen = false;
        companies[job.company].totalSpent += job.bounty;
        referrers[referral.referrer].totalEarned += job.bounty;

        token.transferFrom(job.company, referral.referrer, job.bounty);
        emit BountyDisbursed(referral.candidate, job.bounty);
    }

    /// returns the jobs created by a company
    /// @param company address of the company
    function getCompanyJobs(
        address company
    ) public view returns (uint256[] memory) {
        require(companies[company].isRegistered, "Company is not registered");
        return companyToJobs[company];
    }

    /// returns the referrals made by a referrer
    /// @param referrer address of the referrer
    function getReferrerReferrals(
        address referrer
    ) public view returns (uint256[] memory) {
        require(referrers[referrer].isReferrer, "Referrer is not registered");
        return referrerToReferrals[referrer];
    }

    function closeJob(
        uint256 jobId
    ) external onlyRegisteredCompany onlyOpenJob(jobId) {
        Job storage job = jobs[jobId];
        require(
            msg.sender == job.company,
            "Only the company can close the job"
        );
        job.isOpen = false;
    }

    event JobCreated(
        address indexed company,
        uint256 jobId,
        uint256 creationTime
    );
    event ReferrerRegistered(address indexed referrer, bytes32 email);
    event ReferralMade(address indexed referrer, uint256 referralId);
    event ReferralConfirm(uint256 indexed referralId, uint256 indexed jobId, bytes32 indexed candidateEmail);
    event BountyDisbursed(address indexed candidate, uint256 amount);
    event CompanyRegistered(address indexed company);
}
