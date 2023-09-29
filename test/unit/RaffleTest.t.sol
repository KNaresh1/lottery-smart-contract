// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    /** Events */
    event EnteredRaffle(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address linkToken;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();

        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            linkToken,

        ) = helperConfig.activeNetworkConfig();

        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffledInitializedWithOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /**
     * Tests for enterRaffle()
     */

    function testRevertsWhenNotEnoughEntranceFeePaidByPlayer() public {
        // Arrange
        vm.prank(PLAYER);

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle(); // Send value is 0
    }

    function testRevertsWhenPlayerEntersWhileRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // Shoulg call checkUpkeep() which updates the RaffleState to CALCULATING.
        // In order to do that set the reqired data for checkUpkeep
        vm.warp(block.timestamp + interval + 1); // To set block timestamp to pass the raffle run
        vm.roll(block.number + 1); // to set the block number
        raffle.performUpkeep("");

        // Now it is in calculating state

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        vm.prank(PLAYER);

        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEmitsEventOnPlayerEntrance() public {
        vm.prank(PLAYER);

        vm.expectEmit(true, false, false, false, address(raffle));
        // This test should emit that event and expect the same
        emit EnteredRaffle(PLAYER);

        raffle.enterRaffle{value: entranceFee}();
    }

    /** Tests for checkUpkeep() */

    function testcheckUpkeepReturnsFalseIfItHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1); // To set block timestamp to pass the raffle run
        vm.roll(block.number + 1); // to set the block number

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1); // To set block timestamp to pass the raffle run
        vm.roll(block.number + 1); // to set the block number
        _;
    }

    function testcheckUpkeepReturnsFalseIfRaffleNotOpen()
        public
        raffleEnteredAndTimePassed
    {
        raffle.performUpkeep("");

        // Now it is in calculating state

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded == false);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasNotPassed() public view {
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded == false);
    }

    function testCheckUpkeepReturnsTrueWhenParametersAreGood()
        public
        raffleEnteredAndTimePassed
    {
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded == true);
    }

    /** Tests for performUpkeep() */

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue()
        public
        raffleEnteredAndTimePassed
    {
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 numberOfPlayers = 0;
        uint256 raffleState = 0; // RaffleState.OPEN

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numberOfPlayers,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    // How to test the output of an event, useful in some cases?
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEnteredAndTimePassed
    {
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // entries[0] is emmited by VRFCoordinatorV2Mock, topics[0] = RequestRaffleWinner event, so topics[1] is requestId
        bytes32 requestId = entries[1].topics[1];

        assert(uint256(requestId) > 0);
        assert(uint256(raffle.getRaffleState()) == 1);
    }

    /** Tests for fulfillRandomWords()
     *
     * Fuzz Tests - testing method that injects invalid, malformed, or unexpected inputs into a system to reveal software defects and vulnerabilities.
     */

    modifier skipFork() {
        // If Anvil, then return which does not effect if this modifier is used
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    // When we run this test, foundry generates random requestIds and pass to this test
    // Actual VRFCoordinator and mock VRFCoordinator has different fulfillRandomWords() method signature.
    // We made mock method easier for testing (i.e on Anvil chain). So when it is fork-url skip this test
    // So this test will only run on Anvil and not on forking i.e --fork-url ...
    function testFulfillRandomWordsCanOnlyBeCalledAfeterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEnteredAndTimePassed skipFork {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicsAWinnerResetsAndSendsMoney()
        public
        raffleEnteredAndTimePassed
        skipFork
    {
        uint256 additionalEntrants = 5; // add 5 more players, the modifier already add 1 player
        uint256 startingIndex = 1;

        for (uint256 i = startingIndex; i <= additionalEntrants; i++) {
            address player = address(uint160(i)); // create a player eg. address(1)
            hoax(player, STARTING_USER_BALANCE); // prank the player and send to have intial balance

            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 prizeMoney = entranceFee * (additionalEntrants + 1); // +1 because the modifier added a player

        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // entries[0] is emmited by VRFCoordinatorV2Mock, topics[0] = RequestRaffleWinner event, so topics[1] is requestId
        bytes32 requestId = entries[1].topics[1];
        uint256 previousTimeStamp = raffle.getLastTimeStap();

        // Pretend to be chainlink vrf to get random number & pick winner
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        assert(uint256(raffle.getRaffleState()) == 0); // RaffleState.OPEN
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getLengthOfPlayers() == 0);
        assert(previousTimeStamp < raffle.getLastTimeStap());
        // Can also assert PickWinner event
        assert(
            raffle.getRecentWinner().balance ==
                STARTING_USER_BALANCE + prizeMoney - entranceFee
        ); // -entranceFee: as the winner might have paid it
    }
}
