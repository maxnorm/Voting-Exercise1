// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Voting System
 */
contract Voting is Ownable {
    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);
    
    struct Voter { 
        bool isRegistered; 
        bool hasVoted; 
        uint votedProposalId; 
    } 

    struct Proposal { 
        string description; 
        uint voteCount;
    }

    enum WorkflowStatus { 
        RegisteringVoters, 
        ProposalsRegistrationStarted, 
        ProposalsRegistrationEnded, 
        VotingSessionStarted, 
        VotingSessionEnded, 
        VotesTallied 
    }

    mapping(address=> Voter) voters;
    Proposal[] proposals;

    constructor() Ownable(msg.sender) {}

    function registerVoter(address _address) external {
        voters[_address] = Voter(true, false, 0);
        emit VoterRegistered(_address);
    }
} 
