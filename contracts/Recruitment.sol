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
    mapping(uint16 => FrontDoorStructs.Job) public jobList;
    mapping(uint16 => FrontDoorStructs.Referral) public referralList;
    mapping(bytes32 => FrontDoorStructs.ReferralCode) public referralCodeList;
    mapping(address => bool) public isCompany; // check if company is registered or not

    mapping(address => uint16[]) refersOfReferrer;
    mapping(uint16 => uint16[]) refersJobGot; //referrals job got
    mapping(uint16 => uint16[]) hiredRefers;  //referrals job hired
    mapping(address => uint16[]) companyJobs;
    mapping(address => uint16[]) refersCandidatesGot;
    mapping(bytes32 => uint16) referralCodeToJobId;
    

    mapping(address => uint256) public bountyClaim;
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
        if(candidateList[candidateAddress].company != companyAddress) {
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
            address(0),
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
     * @notice Register a Referrer
     */
    function registerReferrer() external {
        FrontDoorStructs.Referrer memory referrer = FrontDoorStructs.Referrer(
            msg.sender,
            0,
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
            jobId,
            msg.sender,
            bounty,
            uint40(block.timestamp),
            0,
            false,
            false,
            false
        );

        jobList[jobId] = job;
        jobIdCounter++;
        companyJobs[msg.sender].push(jobId);

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

        companyList[msg.sender].totalSpent += bounty;
        emit DepositCompleted(msg.sender, bounty, jobId);
        emit JobCreated(jobId);
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
            0
        );
        companyList[msg.sender] = company;
        isCompany[msg.sender] = true;
    }

    /**
     * @notice Registers a referral
     * @param jobId The job ID already registered with the contract.
     * @param candidate The email of the referee.
     * @param referralCode The referral code of the referee, it must be unique and hashed.
     */
    function registerReferral(
        uint16 jobId,
        address candidate,
        bytes32 referralCode
    ) external nonReentrant returns (uint256) {
        // Simple Checks Of Parameters
        require(jobId > 0, "Job Id should be greater than 0"); // check if job is registered or not
        require(candidateList[candidate].isHired == false, "Candidate is already hired."); // check if job is registered or not
        require(referralCode.length > 0, "Referral Code should not be empty"); // check if referral code is empty or not
        require(
            referralCodeToJobId[referralCode] == 0,
            "Referral Code should be unique"
        ); // check if referral code is unique or not
        
        uint16 referralId = referralCounter++;
        referralCodeToJobId[referralCode] = uint16(jobId);

        FrontDoorStructs.Referral memory referral = FrontDoorStructs.Referral(
            referralId,
            msg.sender,
            candidate,
            jobId,
            referralCode,
            uint40(block.timestamp),
            uint40(block.timestamp + 2 weeks),
            false,
            0,
            0
        );
        referralList[referralId] = referral;
        refersOfReferrer[msg.sender].push(referralId);

        emit RegisterReferral(msg.sender, jobId, referralId);
        return referralId;
    }

    /// @notice Allows the referral to confirm that accepts the referral to the job
    /// @param _referralId id of the referral
    /// @param _jobId job id that the candite is referred for
    /// @param _referralCode referral code of the referral
    function confirmReferral(
        uint16 _referralId,
        uint16 _jobId,
        bytes32 _referralCode
    ) external nonReentrant {
        // Some Checks
        require(
            referralList[_referralId].isConfirmed == false,
            "Referral is already confirmed"
        ); // check if referral is already confirmed or not
        require(
            jobList[referralList[_referralId].job].issucceed == false,
            "Job is already succeed"
        ); // check if job is already succeed or not
        require(
            jobList[referralList[_referralId].job].createdTime + 30 days >
                block.timestamp,
            "Job is expired"
        ); // check if job is expired or not
        require(
            candidateList[msg.sender].isHired == false,
            "Candidate is already hired"
        ); // check if candidate is hired
        require(
            referralList[_referralId].referTime + 2 weeks > block.timestamp,
            "Referral is expired"
        ); // check if referral is expired or not
        require(
            referralCodeToJobId[_referralCode] == _jobId,
            "Referral code is not valid for job id"
        );
        require(
            referralList[_referralId].referralCode == _referralCode,
            "Invalid Referral Code"
        ); // check if referral code is valid for referral

        // Code Logic
        referralCodeList[_referralCode].isUsed = true;
        referralList[_referralId].isConfirmed = true;
        candidateList[msg.sender].referrer = referralList[_referralId].referrer;
        candidateList[msg.sender].jobConfirmed = true;
        referrerList[referralList[_referralId].referrer].numberOfContactedReferrals++;
        refersJobGot[_jobId].push(_referralId);

        emit ReferralConfirmed(msg.sender, _referralId, _jobId); // emit event

        // push into a mapping jobsid => candidates
    }

    /**
     * @param _candidateAddress Candidate address
     * @param _jobId job id
     * @notice Simply sets isHired to true for the candidate , sets timestamp of hiring and incurease candidate count on that job
     */
    function hireCandidate(
        address _candidateAddress,
        uint16 _jobId
    ) external nonReentrant checkIfItisACompany(msg.sender) {
        // Some Checks
        require(
            candidateList[_candidateAddress].isHired == false,
            "Candidate is already hired"
        ); // check if candidate is already hired or not
        require(jobList[_jobId].issucceed == false, "Job is already succeed"); // check if job is already succeed or not

        // Code Logic
        candidateList[_candidateAddress].isHired = true;
        candidateList[_candidateAddress].company = msg.sender;
        candidateList[_candidateAddress].hiredTime = uint40(block.timestamp);
        companyList[jobList[_jobId].creator].totalHiredCandidates += 1;
        jobList[_jobId].issucceed = true;
        for(uint i = 0 ; i < refersJobGot[_jobId].length ; i++) {
            if(referralList[refersJobGot[_jobId][i]].candidate == _candidateAddress) {
                hiredRefers[_jobId].push(refersJobGot[_jobId][i]);
                refersCandidatesGot[_candidateAddress].push(refersJobGot[_jobId][i]);
            }
        }

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

    function getReferrerScore(
        address referrerWallet
    ) public view returns (uint16) {
        return referrerList[referrerWallet].score;
    }

    function getCompanyScore(
        address companyAddress
    ) public view returns (uint16 ) {
        return companyList[companyAddress].score;
    }

    function getAllJobsOfCompany(
        address companyWallet
    ) external view returns (uint16[] memory) {
        return companyJobs[companyWallet];
    }

    /// Returns the numbers of refferals that a refferer has made
    function getMyRefferals() public view returns (uint16[] memory) {
        return refersOfReferrer[msg.sender];
    }

    //TODO  validate if sender is the company that created the job
    function getCandidateListForJob(
        uint16 _jobId
    ) public view returns (address[] memory) {
        uint16[] storage refers = refersJobGot[_jobId];
        address[] memory res = new address[](refers.length);
        
        for (uint i = 0; i < refers.length; i++) {
            res[i] = referralList[refers[i]].candidate;
        }
        
        return res;
    }

    function candidateStatus(
        address _candidateAddress
    ) public view returns (bool) {
        return candidateList[_candidateAddress].isHired;
    }

    function getCandidatesHiredJobId(
        uint16 _jobId
    ) public view returns (address[] memory) {
        uint16[] storage refers = refersJobGot[_jobId];
        address[] memory res = new address[](refers.length);
        for(uint i = 0 ; i < hiredRefers[_jobId].length ; i++) res[i]=referralList[refers[i]].candidate;
        return res;
    }

    /// disburseBounty
    /// @param _jobId Job id
    /// @dev disburse bounty to referrer, candidate and frontDoorAddress using Pull over Push pattern
    function disburseBounty(
        uint16 _jobId
    ) external nonReentrant checkIfItisACompany(msg.sender) {
        require(jobList[_jobId].issucceed == true, "Job is not succeed yet");
        require(
            hiredRefers[_jobId].length > 0,
            "No candidate is hired yet"
        );
        require(
            jobList[_jobId].isDisbursed == false,
            "Bounty is already disbursed"
        );
        require(
            jobList[_jobId].createdTime + 90 days < block.timestamp,
            "90 days are not completed yet"
        );
        require(
            jobList[_jobId].creator == msg.sender,
            "Only job creator can disburse"
        );

        jobList[_jobId].isDisbursed = true;
        uint256 bounty = jobList[_jobId].bounty;

        uint hiredCounts = hiredRefers[_jobId].length;

        for(uint i=0;i<hiredCounts;i++)
        {
            FrontDoorStructs.Referral memory currentRefer = referralList[hiredRefers[_jobId][i]];
            IERC20(frontDoorToken).approve(currentRefer.referrer, bounty * 6500 / 10_000 / hiredCounts);
            IERC20(frontDoorToken).approve(currentRefer.candidate, bounty * 1000 / 10_000 / hiredCounts);
            IERC20(frontDoorToken).approve(frontDoorAddress, bounty * 2500 / 10_000 / hiredCounts);
            bool successOwner = IERC20(frontDoorToken).transfer(currentRefer.referrer, bounty * 6500 / 10_000 / hiredCounts);
            bool successCandidate = IERC20(frontDoorToken).transfer(currentRefer.candidate, bounty * 1000 / 10_000 / hiredCounts);
            bool successFrontDoor = IERC20(frontDoorToken).transfer(frontDoorAddress, bounty * 2500 / 10_000 / hiredCounts);
        
            if (successOwner) {
                bountyClaim[currentRefer.referrer] += (bounty * 6500) / 10_000 / hiredCounts;
            }

            if (successCandidate) {
                bountyClaim[currentRefer.candidate] += (bounty * 1000) / 10_000 / hiredCounts;
            }

            if (successFrontDoor) {
                bountyClaim[frontDoorAddress] += (bounty * 2500) / 10_000 / hiredCounts;
            }
        }

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

    function updateCompanyScore(address companyAddress) internal {
        uint16 sum=0;
        uint16 cnt = 0;
        for(uint i = 0 ; i < companyJobs[companyAddress].length ; i++)
            for(uint j = 0 ; j < hiredRefers[companyJobs[companyAddress][i]].length ; j++ ){
                sum += referralList[hiredRefers[companyJobs[companyAddress][i]][j]].companyScore;
                cnt++;
            }
        companyList[companyAddress].score = sum/cnt;
    }
    function updateReferrerScore(address userAddress) internal {
        uint16 sum = 0;
        uint i;
        for (i = 0; i < refersOfReferrer[userAddress].length; i++) {
            sum += referralList[refersOfReferrer[userAddress][i]].candidateScore;
        }
        if (i > 0) {
            referrerList[userAddress].score = uint16(sum / i);
        } else {
            referrerList[userAddress].score = 0; // You can change this to any suitable default value.
        }
    }
    
    function updateCandidateScore(address userAddress) internal {
        uint16 sum = 0;
        uint i;

        for (i = 0; i < refersCandidatesGot[userAddress].length; i++) {
            sum += referralList[refersCandidatesGot[userAddress][i]].candidateScore;
        }

        if (i > 0) {
            sum = uint16(sum / i);
        } else {
            // Handle the case when i is 0, e.g., set a default score.
            sum = 0; // You can change this to any suitable default value.
        }

        candidateList[userAddress].score = sum;
    }

    function getCandidateScore(address Address) external view returns (uint16) {
        return candidateList[Address].score;
    }
    function getCompanySpentAmount(address Address) external view returns (uint256) {
        return companyList[Address].totalSpent;
    }
    function getCompanyHiredCounts(address Address) external view returns (uint16) {
        return companyList[Address].totalHiredCandidates;
    }
    function setCanidateScoreFromCompany(uint16 referralId, uint16 score) public {
        require(isCompany[msg.sender] == true , "You can't give score to candidate");
        referrerList[referralList[referralId].referrer].numberOfSuccesfullReferrals++;
        referralList[referralId].candidateScore = score;
        updateCandidateScore(referralList[referralId].candidate);
        updateReferrerScore(referralList[referralId].referrer);
    }
    function setCompanyScoreFromCandidate(uint16 referralId, uint16 score) public {
        require(referralList[referralId].candidate == msg.sender , "You can't give score to the company");
        referralList[referralId].companyScore = score;
        updateCompanyScore(jobList[referralList[referralId].job].creator);
    }
    event BountyDisburse(uint16 _jobId);
    event PercentagesCompleted(
        address indexed sender,
        uint8 month1RefundPct,
        uint8 month2RefundPct,
        uint8 month3RefundPct
    );
    event DepositCompleted(
        address indexed sender,
        uint256 amount,
        uint16 jobId
    );
    event ReferralScoreSubmitted(
        address senderAddress,
        address referrerWallet,
        uint256 score
    );
    event CompanyScoreSubmitted(
        address senderAddress,
        address companyAddress,
        uint16 score
    );
    event ReferCandidateSuccess(
        address indexed sender,
        address indexed candidateAddress,
        uint16 indexed jobId
    );
    event CandidateHired(
        address indexed companyAddress,
        address candidateAddress,
        uint16 jobId
    );
    event ReferralConfirmed(
        address indexed candidateAddress,
        uint16 indexed referralId,
        uint16 indexed jobId
    );
    event ReferralRejected(
        address indexed candidateAddress,
        uint16 indexed referralId,
        uint16 indexed jobId
    );
    event CandidateHiredSuccesfullyAfter90Days(
        address indexed companyAddress,
        address candidateAddress,
        uint16 jobId
    );
    event RegisterReferral(
        address indexed refferer,
        uint16 indexed jobId,
        uint16 referralId
    );
    event JobCreated(uint16 indexed jobId);
}
