// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

library FrontDoorStructs {
    struct Candidate {
        address wallet;
        bytes32 email;
        address referrer; // address of the referrer
        uint40 timeOfHiring; // time at which candidate is hired
        uint16 score;
        bool isScoreGivenByCompany; // bool if company gives score to candidate
        bool isHired;
        bool jobConfirmed; // bool if candidate confirms the job
    }

    struct Referrer {
        address wallet;
        bytes32 email;
        uint16 score;
        uint16 numberOfSuccesfullReferrals; // number of referrals made by the referrer
    }

    struct Job {
        address creator;
        uint256 bounty;
        uint40 timeAtWhichJobCreated; // indicates time at which job is created job will only be listed for 30 days
        uint16 numberOfCandidateHired; // number of candidates hired by the company
        uint16 id;
        bool issucceed; // is comapny has succesfully hired the candidate
        bool isDisbursed;
        bool isRemoved;
    }

    struct Referral {
        Referrer referrer;
        Candidate candidate;
        Job job;
        uint40 timeAtWhichReferralStarted; // indicates time at which referral is made
        uint40 referralEnd; // indicates time at which referral is ending  ** Referral should end after 1 day
        uint16 id;
        bool isConfirmed; // set by candidate if we wants to confirm the referral
        bool confirmed;
    }

    struct Company {
        address wallet;
        uint256 jobsCreated;
        uint256 time_score;
        address[] candidates; // list of all candidates hired by the company
    }

    struct CompanyScore {
        uint256 score; //score given to the company
        address senderAddress; //address of the candidate
    }

    struct ReferralScore {
        uint256 score; //Score given by the hiring company to the candidate
        address senderAddress; // Wallet address of the hiring company
    }
}
