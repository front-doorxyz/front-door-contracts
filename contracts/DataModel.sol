// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

library FrontDoorStructs {
    struct Candidate {
        address wallet;
        address referrer; // address of the referrer
        uint40 hiredTime; // time at which candidate is hired
        uint16 score;
        bool isScored; // bool if company gives score to candidate
        bool isHired;
        bool jobConfirmed; // bool if candidate confirms the job
        uint16[] refers;
    }

    struct Referrer {
        address wallet;
        uint16 score;
        uint16[] refers;
        uint16 numberOfSuccesfullReferrals; // number of referrals made by the referrer
        uint numberOfContactedReferrals;
    }

    struct Job {
        uint16 id;
        address creator;
        uint256 bounty;
        uint40 createdTime; // indicates time at which job is created job will only be listed for 30 days
        uint16[] gotRefers;
        uint16[] hiredRefers; // number of candidates hired by the company
        bool issucceed; // is comapny has succesfully hired the candidate
        bool isDisbursed;
        bool isRemoved;
    }

    struct Referral {
        uint16 id;
        Referrer referrer;
        Candidate candidate;
        Job job;
        bytes32 referralCode;
        uint40 referTime; // indicates time at which referral is made
        uint40 confirmedTime; // indicates time at which referral is ending  ** Referral should end after 2 weeks
        bool isConfirmed; // set by candidate if we wants to confirm the referral
        bool companyToCandidate;    // candidate gave score to company?
        bool candidateToCompany;    // company gave score to candidate?
    }

    struct Company {
        address wallet;
        uint16[] job;
        uint256 totalSpent;
        uint16 totalHiredCandidates;
        uint16 score;
        bool hasScore;      //Has score from any job?
    }
}
