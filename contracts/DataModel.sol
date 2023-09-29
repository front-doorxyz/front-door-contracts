// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

library FrontDoorStructs {

    struct Candidate {
        address wallet;
        string email;
        uint16 score;
        bool isScoreGivenByCompany ; // bool if company gives score to candidate
        uint40 timeOfHiring; // time at which candidate is hired
        bool isHired;
        bool jobConfirmed; // bool if candidate confirms the job
        address referrer; // address of the referrer
    }

     struct Referrer{
        address wallet;
        string email;
        uint16 score;
        uint16 numberOfSuccesfullReferrals; // number of referrals made by the referrer
    }

    struct Job {
        uint16 id;
        uint256 bounty;
        bool isRemoved;
        address creator;
        bool issucceed; // is comapny has succesfully hired the candidate
        uint16 numberOfCandidateHired; // number of candidates hired by the company
        uint40 timeAtWhichJobCreated; // indicates time at which job is created job will only be listed for 30 days
        bool isDibursed;
    }
    

    struct Referral{
        uint16 id;
        bool confirmed;
        Referrer referrer;
        Candidate candidate;
        Job job;
        uint40 timeAtWhichReferralStarted; // indicates time at which referral is made 
        uint40 timeAtWhichReferralEnded; // indicates time at which referral is end 
        bool isConfirmed; // set by candidate if we wants to confirm the referral
        uint40 referralEnd; // indicates time at which referral is ending  ** Referral should end after 1 day
    }


    struct Company{
        address wallet;
        uint40 jobsCreated;
        uint16 time_score;
        address[] candidates; // list of all candidates hired by the company
    }

    struct CompanyScore{
      uint16 score; //score given to the company
      address senderAddress; //address of the candidate
    }

    struct ReferralScore {
        uint16 score;  //Score given by the hiring company to the candidate 
        address senderAddress; // Wallet address of the hiring company
  }
}