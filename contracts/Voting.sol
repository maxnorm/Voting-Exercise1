// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

error InvalidWorkflowStatus(Voting.WorkflowStatus current, Voting.WorkflowStatus expected);
error VoterAlreadyRegistered();
error WorkflowAlreadyEnded();
error WorkflowNotEnded();
error VoterAddressNotAllowed();
error HasAlreadyVoted();
error InvalidProposalID();

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

    struct VotingState {
        mapping(address=> Voter) voters;
        Proposal[] proposals;
        WorkflowStatus status;
        Proposal[] winningProposals;
    }

    VotingState currentVoting;
    VotingState[] pastVote;

    constructor() Ownable(msg.sender) {
        currentVoting.status = WorkflowStatus.RegisteringVoters;
    }

    /**
    * Mofifier to allow certain functions only to registered voters
    */
    modifier allowedVoter() {
        require(
            currentVoting.voters[msg.sender].isRegistered, 
            VoterAddressNotAllowed()
        );
        _;
    }

    /**
    * This function is for registering voter 
    * Only available to the contract owner
    */
    function registerVoter(address _address) external onlyOwner {
        require(
            currentVoting.status == WorkflowStatus.RegisteringVoters, 
            InvalidWorkflowStatus(currentVoting.status, WorkflowStatus.RegisteringVoters)
        );
        require(
            !currentVoting.voters[_address].isRegistered,
            VoterAlreadyRegistered()
        );

        currentVoting.voters[_address].isRegistered = true;
        emit VoterRegistered(_address);
    }

    /**
    * This function is for updating the status of the voting workflow
    * Only available to the contract owner
    */
    function nextWorkflowStatus() external onlyOwner {
        require(
            uint(currentVoting.status) < uint(type(WorkflowStatus).max), 
            WorkflowAlreadyEnded()
        );
        WorkflowStatus previousStatus = currentVoting.status;
        currentVoting.status = WorkflowStatus(uint(currentVoting.status) + 1);
        emit WorkflowStatusChange(previousStatus, currentVoting.status);
    }

    /**
    * This function is to add voting proposal for the upcoming vote
    * Only available to registered voters
    */
    function registerProposal(string memory _description) external allowedVoter {
        require(
            currentVoting.status == WorkflowStatus.ProposalsRegistrationStarted,
            InvalidWorkflowStatus(currentVoting.status, WorkflowStatus.ProposalsRegistrationStarted)
        );
            
        currentVoting.proposals.push(
            Proposal({description: _description, voteCount: 0})
        );
    }

    /**
    * This function is to vote for a proposal
    * Only available to registered voters
    */
    function vote(uint256 _proposalId) external allowedVoter {
        require(
            currentVoting.status == WorkflowStatus.VotingSessionStarted,
            InvalidWorkflowStatus(currentVoting.status, WorkflowStatus.VotingSessionStarted)
        );
        require(
            !currentVoting.voters[msg.sender].hasVoted,
            HasAlreadyVoted()
        );
        require(
            _proposalId < currentVoting.proposals.length, 
            InvalidProposalID()
        );

        currentVoting.proposals[_proposalId].voteCount += 1;
        currentVoting.voters[msg.sender].votedProposalId = _proposalId;
        currentVoting.voters[msg.sender].hasVoted = true;
        emit Voted(msg.sender, _proposalId);
    }

    
} 
