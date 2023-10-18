pragma solidity 0.8.18;

library FrontDoorStructs {

    struct Candidate {
        address wallet;
        Score score;
        bool isHired;
        uint256 earnedMount;
        uint16[] refers;
        uint40 timeOfRegist;
    }

     struct Recruiter{
        address wallet;
        Score score;
        uint16 numberOfSuccesfullReferrals;
        uint16 numberOfContactedCandidates;
        uint16[] refers;
        uint40 timeOfRegist;
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
        uint16[] hiredRefers;
        uint40[] timeOfCandidateHire;
    }

    struct Referral{
        uint16 id;
        bool isConfirmed;
        bool isSucceed;
        uint16 score;
        address candidate;
        uint16 job;
        address owner;
        uint40 timeAtWhichReferralStarted;
        uint40 timeReferralEnd;
    }


    struct Company{
        address wallet;
        uint256 ballance;
        Score score;
        uint16[] jobIds;
        uint40 timeOfRegist;
    }

    struct Score {
        uint16[] scores;
        address[] senderAddress;
        uint40[] timeOfGetScore;
        uint256 finalScore;
    }
    struct ReferralCode {
        bytes32 code;
        uint16 expirationDate;
        bool isUsed;
    }
}