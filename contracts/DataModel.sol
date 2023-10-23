// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

library FrontDoorStructs {
    struct Candidate {
        address wallet;
        address referrer; // address of the referrer
        address company;
        uint40 hiredTime; // time at which candidate is hired
        uint16 score;
        bool isScored; // bool if company gives score to candidate
        bool isHired;
        bool jobConfirmed; // bool if candidate confirms the job
    }

    struct Referrer {
        address wallet;
        uint16 score;
        uint16 numberOfSuccesfullReferrals; // number of referrals made by the referrer
        uint16 numberOfContactedReferrals;
    }

    struct Job {
        uint16 id;
        address creator;
        uint256 bounty;
        uint40 createdTime; // indicates time at which job is created job will only be listed for 30 days
        uint16 score;
        bool issucceed; // is comapny has succesfully hired the candidate
        bool isDisbursed;
        bool isRemoved;
    }

    struct Referral {
        uint16 id;
        address referrer;
        address candidate;
        uint16 job;
        bytes32 referralCode;
        uint40 referTime; // indicates time at which referral is made
        uint40 confirmedTime; // indicates time at which referral is ending  ** Referral should end after 2 weeks
        bool isConfirmed; // set by candidate if we wants to confirm the referral
        uint16 companyScore;    // candidate gave score to company?
        uint16 candidateScore;    // company gave score to candidate?
    }

    struct Company {
        address wallet;
        uint256 totalSpent;
        uint16 totalHiredCandidates;
        uint16 score;
    }
    
    struct ReferralCode {
        bytes32 referralCode;
        uint40 createdTime;
        bool isUsed;
    }
}
