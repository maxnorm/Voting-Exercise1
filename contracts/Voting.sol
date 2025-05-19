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
error InvalidPastVoteID();


/**
 * @title Voting System
 */
contract Voting is Ownable {
    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);
    event VotesTallied(uint maxVotes, uint winningProposalsCount);
    event VotingReset(uint indexed roundIndex, uint totalVotes, uint winningProposalsCount);
    
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
        uint totalVotesCount;
        Proposal[] proposals;
        WorkflowStatus status;
        Proposal[] winningProposals;
    }

    struct VotingSummary {
        uint totalVotesCount;
        Proposal[] proposals;
        Proposal[] winningProposals;
    }

    VotingState currentVote;
    VotingSummary[] pastVotes;

    constructor() Ownable(msg.sender) {
        currentVote.status = WorkflowStatus.RegisteringVoters;
    }

    /**
    * Mofifier to allow certain functions only to registered voters
    */
    modifier allowedVoter() {
        require(
            currentVote.voters[msg.sender].isRegistered, 
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
            currentVote.status == WorkflowStatus.RegisteringVoters, 
            InvalidWorkflowStatus(currentVote.status, WorkflowStatus.RegisteringVoters)
        );
        require(
            !currentVote.voters[_address].isRegistered,
            VoterAlreadyRegistered()
        );

        currentVote.voters[_address].isRegistered = true;
        emit VoterRegistered(_address);
    }

    /**
    * This function is for updating the status of the voting workflow
    * Only available to the contract owner
    */
    function nextWorkflowStatus() external onlyOwner {
        require(
            uint(currentVote.status) < (uint(type(WorkflowStatus).max)) , 
            WorkflowAlreadyEnded()
        );
        WorkflowStatus previousStatus = currentVote.status;
        currentVote.status = WorkflowStatus(uint(currentVote.status) + 1);
        emit WorkflowStatusChange(previousStatus, currentVote.status);

        if (currentVote.status == WorkflowStatus.VotesTallied) {
            tallyVotes();
        }
    }

    /**
    * This internal function is to end the voting workflow and tallies votes
    * Only available to the contract owner
    */
    function tallyVotes() internal onlyOwner {
        uint maxVotes = 0;
        delete currentVote.winningProposals;

        for (uint i = 0; i < currentVote.proposals.length; ++i) {
            uint votesCount = currentVote.proposals[i].voteCount;

            if(votesCount > maxVotes){
                maxVotes = votesCount;
                delete currentVote.winningProposals;
                currentVote.winningProposals.push(currentVote.proposals[i]);
            } else if (votesCount == maxVotes && maxVotes != 0){
                currentVote.winningProposals.push(currentVote.proposals[i]);
            }
        }

        emit VotesTallied(maxVotes, currentVote.winningProposals.length);
    }

    function resetVotingState() external onlyOwner {
        require(
            currentVote.status == WorkflowStatus.VotesTallied ,
            InvalidWorkflowStatus(currentVote.status, WorkflowStatus.VotesTallied)
        );

        pastVotes.push(); // Allocate a new empty slot
        VotingSummary storage summary = pastVotes[pastVotes.length - 1];

        summary.totalVotesCount = currentVote.totalVotesCount;

        for (uint i = 0; i < currentVote.proposals.length; i++) {
            summary.proposals.push(currentVote.proposals[i]);
        }

        for (uint i = 0; i < currentVote.winningProposals.length; i++) {
            summary.winningProposals.push(currentVote.winningProposals[i]);
        }

        delete currentVote;
        currentVote.status = WorkflowStatus.RegisteringVoters;

        emit VotingReset(pastVotes.length - 1, summary.totalVotesCount, summary.winningProposals.length);
    }

    /**
    * This function is to add voting proposal for the upcoming vote
    * Only available to registered voters
    */
    function registerProposal(string memory _description) external allowedVoter {
        require(
            currentVote.status == WorkflowStatus.ProposalsRegistrationStarted,
            InvalidWorkflowStatus(currentVote.status, WorkflowStatus.ProposalsRegistrationStarted)
        );
            
        currentVote.proposals.push(Proposal(_description, 0));
        emit ProposalRegistered(currentVote.proposals.length - 1);
    }

    /**
    * This function is to vote for a proposal
    * Only available to registered voters
    */
    function vote(uint256 _proposalId) external allowedVoter {
        require(
            currentVote.status == WorkflowStatus.VotingSessionStarted,
            InvalidWorkflowStatus(currentVote.status, WorkflowStatus.VotingSessionStarted)
        );
        require(
            !currentVote.voters[msg.sender].hasVoted,
            HasAlreadyVoted()
        );
        require(
            _proposalId < currentVote.proposals.length, 
            InvalidProposalID()
        );

        currentVote.proposals[_proposalId].voteCount += 1;
        currentVote.voters[msg.sender].votedProposalId = _proposalId;
        currentVote.voters[msg.sender].hasVoted = true;
        currentVote.totalVotesCount += 1;
        emit Voted(msg.sender, _proposalId);
    }

    /**
    * This function is to access the vote results
    * Only available to registered voters
    */
    function getVoteResults() external view allowedVoter returns (Proposal[] memory winningProposals) {
        require(
            currentVote.status == WorkflowStatus.VotesTallied,
            InvalidWorkflowStatus(currentVote.status, WorkflowStatus.VotesTallied)
        );
        return currentVote.winningProposals;
    }


    function getPastVote(uint index) external view returns (VotingSummary memory) {
        require(index < pastVotes.length, InvalidPastVoteID());
        return pastVotes[index];
    }
}
