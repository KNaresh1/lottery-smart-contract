// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/** Imports */
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title A sample Raffle Contract
 * @author Naresh Kakumani
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2 {
    /** Custom Errors */

    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 noOfPlayers,
        uint256 raffleState
    );

    /** State Variables */

    uint16 private constant REQ_CONFIRMATIONS = 3;

    uint32 private constant NUMBER_OF_WORDS = 1;

    uint256 private immutable i_entranceFee;
    // @dev Duration of the lottery in seconds to check for lottery pick
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gaseLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    // storage variable - as it is dynamic, payable - as we need to pay the winners
    address payable[] private s_players;
    address private s_recentWinner;
    uint256 private s_lastTimeStamp;
    RaffleState private s_raffleState;

    /** Type Declarations */

    enum RaffleState {
        OPEN, // or - 0
        CALCULATING // or - 1
    }

    /** Events */

    event EnteredRaffle(address indexed player);
    event PicketWinner(address indexed winner);
    event RequestRaffleWinner(uint256 indexed requestId);

    /** Constructor */
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);

        i_interval = interval;
        i_gaseLane = gasLane;
        i_entranceFee = entranceFee;
        s_lastTimeStamp = block.timestamp;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    /** Functions */

    /**
     * Allow user to enter raffle by paying entrance fee
     * external - gas efficient, not public as it not going to be called within code
     * payable - as who enters in the raffle has to pay for the ticket
     */
    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender)); // payable - to allow an address to get eth or any token.

        emit EnteredRaffle(msg.sender);
    }

    /** To automatically trigger lottery draw at given interval once it met following conditions:
     * 1. The timer interval has passed between raffle runs
     * 2. The raffle is in the OPEN state
     * 3. The contract has ETH (aka, players)
     * 4. (Implicit) The subscriptions is funded with LINK
     * Chainlink automation using keepers
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        // check if enough time has passed to pick winner
        bool hasTimePassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isRaffleOpen = RaffleState.OPEN == s_raffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;

        upkeepNeeded = (hasTimePassed &&
            isRaffleOpen &&
            hasBalance &&
            hasPlayers);
        return (upkeepNeeded, "0x0");
    }

    /**
     * 1. Get a random number
     * 2. Use the random number to pick a player
     * 3. Be automatically called
     *
     * external - allow anybody to call this function
     */
    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.CALCULATING;
        // Request chainlink node to give random number
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gaseLane,
            i_subscriptionId,
            REQ_CONFIRMATIONS,
            i_callbackGasLimit,
            NUMBER_OF_WORDS
        );
        // This redundant as vrf will emit, this is just to show testing this event
        emit RequestRaffleWinner(requestId);
    }

    /** This is the function that chainlink node is going to call to give us the random number
     * after requestRandomWords call is made in the pickWinner()
     *
     * CEI: Checks, Effects, Interactions - Design
     */
    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        // Checks
        // Effects (Our own contract)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;

        // Reset players after picking winner to start new
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit PicketWinner(winner);

        // Interactions (Other contracts)
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /**
     * Getter Functions
     */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 playerIndex) external view returns (address) {
        return s_players[playerIndex];
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getLengthOfPlayers() external view returns (uint256) {
        return s_players.length;
    }

    function getLastTimeStap() external view returns (uint256) {
        return s_lastTimeStamp;
    }
}
