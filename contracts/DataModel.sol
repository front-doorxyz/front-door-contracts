pragma solidity 0.8.18;

library FrontDoorStructs {

    struct Candidate {
        address wallet;
        string email;
        Score score;
        uint40 timeOfHiring;
        bool isHired;
        bool referConfirmed;
        uint256 earnedMount;
        uint16[] refers;
    }

     struct Recruiter{
        address wallet;
        string email;
        Score score;
        uint16 numberOfSuccesfullReferrals;
        uint16 numberOfContactedCandidates;
        uint16[] refers;
    }

    struct Job {
        uint16 id;
        uint256 bounty;
        address creator;
        uint40 timeOfJobCreated;
        bool isDibursed;
        bool isRemoved;
        bool isSucceed;
        uint16[] refers;
        address hiredCandidate;
    }

    struct Referral{
        uint16 id;
        bool isConfirmed;
        bool isSucceed;
        uint16 score;
        Candidate candidate;
        Job job;
        uint40 timeOfRefer;
        uint40 timeOfConfirmed;
        address owner;
    }


    struct Company{
        address wallet;
        uint256 ballance;
        Score score;
        Job[] jobs;
    }

    struct Score {
        uint16[] scores;
        address[] senderAddress;
        uint256 finalScore;
    }
    
}