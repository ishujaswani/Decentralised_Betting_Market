// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract Esports_Betting_W_Insurance {

    uint TeamA = 1;
    uint TeamB = 2;

    uint[] public bets;
    address payable public owner;
    uint public winningTeam;

    event BetPlaced(address indexed _bettor, uint _value);

    struct Bet {
        uint value;
        uint team;
        bool insurance;
        uint insuranceCost;
    }

    mapping(address => Bet) public betInfo;

    constructor() {
        owner = payable(msg.sender);
    }

    address[] public accounts;

    function placeABet(uint _bets, bool _insurance) public payable {
        require(msg.value > 0, "Bet amount must be greater than zero.");
        bets.push(_bets);
        accounts.push(msg.sender);
        betInfo[msg.sender] = Bet(msg.value, _bets, _insurance, 0); // Add 0 for insuranceCost
        emit BetPlaced(msg.sender, msg.value);
    }

    function getOdds() public view returns (uint, uint) {
        uint countA = 0;
        uint countB = 0;

        for (uint i = 0; i < bets.length; i++) {
            if (bets[i] == TeamA) {
                countA++;
            } else if (bets[i] == TeamB) {
                countB++;
            }
        }

        if (countA == 0 || countB == 0) {
            return (0, 0);
        }

        uint oddsA = (countA * 100 / countB);
        uint oddsB = (countB * 100 / countA);

        return (oddsA, oddsB);
    }

    function setWinningTeam(uint _winningTeam) public {
        require(msg.sender == owner, "Only the owner can set the winning team.");
        require(_winningTeam == TeamA || _winningTeam == TeamB, "Invalid winning team selected.");
        winningTeam = _winningTeam;
    }

    function distributeWinnings() public payable {
        require(msg.sender == owner, "Only the owner can distribute winnings.");
        require(winningTeam != 0, "Winning team has not been set yet.");

        (uint oddsA, uint oddsB) = getOdds();

        for (uint i = 0; i < accounts.length; i++) {
            address bettor = accounts[i];
            Bet memory bet = betInfo[bettor];

            uint winnings = 0;

            if (winningTeam == TeamA && bet.team == TeamA) {
                winnings = bet.value * (oddsB / 100 + 1);
            } else if (winningTeam == TeamB && bet.team == TeamB) {
                winnings = bet.value * (oddsA / 100 + 1);
            }

            if (winnings > 0) {
                payable(bettor).transfer(winnings);
            }
        }

        // Transfer the remaining balance to the contract owner
        payable(owner).transfer(address(this).balance);
    }

    function collectInsuranceFees() public {
        require(msg.sender == owner, "Only the owner can collect insurance fees.");
        require(winningTeam == 0, "Winning team must not be set yet.");

        for (uint i = 0; i < accounts.length; i++) {
            address bettor = accounts[i];
            uint selectedTeam = betInfo[bettor].team;

            bool hasInsurance = betInfo[bettor].insurance;

            if (hasInsurance) {
            uint insuranceCost = calculateInsurance(selectedTeam);

            require(address(this).balance >= insuranceCost, "Insufficient contract balance to collect insurance fee.");
            betInfo[bettor].insuranceCost = insuranceCost;
            payable(owner).transfer(insuranceCost);
            }
        }
    }

    function calculateInsurance(uint _bets) public view returns (uint) {
        require(_bets == TeamA || _bets == TeamB, "Invalid team selected.");

        (uint oddsA, uint oddsB) = getOdds();

        // Return 0 if there's only one bet placed
        if (oddsA == 0 || oddsB == 0) {
            return 0;
        }

        // Calculate implied probabilities
        uint impliedProbA = 1 ether / oddsA;
        uint impliedProbB = 1 ether / oddsB;

        uint insuranceCost;

        if (_bets == TeamA) {
            uint stakeOnTeamB = betInfo[msg.sender].value * 20 / 100; // Calculate 20% stake
            insuranceCost = (stakeOnTeamB * impliedProbB / impliedProbA) / 100;
        } else {
            uint stakeOnTeamA = betInfo[msg.sender].value * 20 / 100; // Calculate 20% stake
            insuranceCost = (stakeOnTeamA * impliedProbA / impliedProbB) / 100;
        }

        return insuranceCost;
    }

    function distributeInsurance() public payable {
        require(msg.sender == owner, "Only the owner can distribute insurance.");
        require(winningTeam != 0, "Winning team has not been set yet.");

        (uint oddsA, uint oddsB) = getOdds();

        for (uint i = 0; i < accounts.length; i++) {
            address bettor = accounts[i];
            uint selectedTeam = betInfo[bettor].team;
            bool hasInsurance = betInfo[bettor].insurance;

            if (hasInsurance) {
                uint insuranceCost = calculateInsurance(selectedTeam);

                uint moneyBack;
                if (selectedTeam == TeamA && winningTeam == TeamB) {
                    moneyBack = (insuranceCost * oddsB) / 100;
                } else if (selectedTeam == TeamB && winningTeam == TeamA) {
                    moneyBack = (insuranceCost * oddsA) / 100;
                }

                require(moneyBack <= address(this).balance, "Insufficient contract balance to send the insurance.");
                payable(bettor).transfer(moneyBack);
            }
        }
    }

    function getContractBalance() public view returns (uint) {
        return address(this).balance;
    }
}