// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Recruitment is Ownable {
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
        address candidate;
        bytes32 referralCode;
        uint256 timeCreatead;
        bool isHired;
        bool isRegistered;
    }

    struct Referrer {
        address wallet;
        bytes32 email;
        uint256 totalEarned;
        uint256 rewardsToClaim;
        uint8 score;
    }

    struct Candidate {
        address wallet;
        uint8 score;
    }

    mapping(address => Company) public companies;
    mapping(uint256 => Job) public jobs;
    mapping(uint256 => Referral) public referrals;
    mapping(address => Referrer) public referrers;

    mapping(address => uint256[]) public companyToJobs;
    mapping(address => uint256[]) public referrerToReferrals;

    uint256 public nextJobId;
    uint256 public nextReferralId;

    modifier onlyRegisteredCompany() {
        require(
            companies[msg.sender].isRegistered == true,
            "Not a registered company"
        );
        _;
    }

    modifier onlyExistingJob(uint256 jobId) {
        require(jobs[jobId].company != address(0), "Job does not exist");
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
        referrers[msg.sender] = Referrer(msg.sender, _email, 0, 0, 0);
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

    function referCandidate(uint256 jobId, address candidate) external {
        require(
            referrers[msg.sender].totalEarned >= 0,
            "Not a registered referrer"
        );
        require(candidate != address(0), "Invalid candidate address");

        uint256 referralId = nextReferralId++;
        Referral memory newReferral = Referral(
            msg.sender,
            jobId,
            candidate,
            false
        );
        referrals[referralId] = newReferral;
        referrerToReferrals[msg.sender].push(referralId);

        emit ReferralMade(msg.sender, referralId);
    }

    function hireCandidate(
        uint256 referralId
    )
        external
        onlyRegisteredCompany
        onlyExistingJob(referrals[referralId].jobId)
        onlyOpenJob(referrals[referralId].jobId)
    {
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

    function getCompanyJobs(
        address company
    ) public view returns (uint256[] memory) {
        return companyToJobs[company];
    }

    function getReferrerReferrals(
        address referrer
    ) public view returns (uint256[] memory) {
        return referrerToReferrals[referrer];
    }

    function updateJobBounty(
        uint256 jobId,
        uint256 newBounty
    ) external onlyRegisteredCompany onlyExistingJob(jobId) onlyOpenJob(jobId) {
        require(newBounty > 0, "Invalid bounty");
        Job storage job = jobs[jobId];
        require(
            msg.sender == job.company,
            "Only the company can update the bounty"
        );
        job.bounty = newBounty;
    }

    function closeJob(
        uint256 jobId
    ) external onlyRegisteredCompany onlyExistingJob(jobId) onlyOpenJob(jobId) {
        Job storage job = jobs[jobId];
        require(
            msg.sender == job.company,
            "Only the company can close the job"
        );
        job.isOpen = false;
    }

    function openJob(
        uint256 jobId
    ) external onlyRegisteredCompany onlyExistingJob(jobId) {
        Job storage job = jobs[jobId];
        require(msg.sender == job.company, "Only the company can open the job");
        job.isOpen = true;
    }

    event JobCreated(
        address indexed company,
        uint256 jobId,
        uint256 creationTime
    );
    event ReferrerRegistered(address indexed referrer, bytes32 email);
    event ReferralMade(address indexed referrer, uint256 referralId);
    event BountyDisbursed(address indexed candidate, uint256 amount);
    event CompanyRegistered(address indexed company);
}
