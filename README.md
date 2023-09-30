# Proveably Random Raffle Contracts

## About
This code is to create a proveably random smart contract lottery.

## What we want it to do?

1. Users can enter by paying for a ticket
   1. The ticket fees are going to go to the winner during the draw
2. After X period of time, the lottery will automatically draw a winner
   1. This will be done programatically
3. Using Chainlink VRF & Chainlink Automation
   1. Chainlink VRF -> Randomness
   2. Chainlink Automation -> Time based trigger

## Tests
    1. Write deploy scripts
    2. Write tests
       1. Works on local chain
       2. Forked Testnet
       3. Forked Mainnet

## Techinical
   1. Foundry tool kit 
   2. Events - brownie
   3. Chainlink Automation
   4. Chainlink VRF


## Me - Actual steps followed
1. forge init - To get initial project setup
2. Add README as what this smart contract does
3. Delete default .sol files
4. Create Raffle.sol and start writing the contract (forge build - with initial contract template)
5. Add contract doc at the top of the contract
6. Come up with basic fuctions that makes this contract
7. While adding any variable think of right dataType and storageType to make it gas efficient
8. Name the vairables that maps to storageType to easily identify
9. Come up with getters as required and use right types (external, view etc)
10. Think of solidity contract layout and place the code in a organized manner
11. Add Custom errors: gas efficient than using require(...) - eg. entranceFee check
12. Add contractName as prefix to custom errors for easy find
13. What data structure to use? To use to keep track of players in the contract - dynamic array
14. Events - Any update to storage emit event - makes migration and front end indexing easier
15. Use Chainlink VRF to get random number - Subscription method
16. forge install smartcontractkit/chainlink-brownie-contracts@0.6.1 --no-commit to get VRF interface
17. Update foundry.toml to map external libs to consider from lib directory
18. Using received random number pick the winner with Madulo calculation
19. Do not allow others to enter raffle while picking winner by using a local Enum with different states
20. After winner is picked, reset the players, timeStamp and emit an event
21. While implenting start with writing tests TDD
22. Follow design priniciple like CEI: Chekcs, Effects (our own contract) & Interactions (with other contracts) - gas efficient
23. Deploy and Helper config scripts
24. VRF mocks if need to run local blockchain (Anvil)
25. Write unit tests (forge test, forge coverage), Testing functionality, reverts, events
26. Write scripts to Deploy Raffle conntract that can run on any network based on the network config. Eg. Sepolia, local network - anvil
27. Write a HelperConfig that would return the active network config on which the Raffle contract can be run
28. The Ineractions.s.slo script can be used to create & fund subscription, add consumer whichi is required by VRF
29. Use forge install ChainAccelOrg/foundry-devops --no-commit - custom tool that can get most recently deployed Raffle contract, and as a consumer for VRF to receive random number
30. forge coverage --report debug > coverage
31. Write fuzz tests, test emitted events which can be required in some cases
32. Pass deployerKey to vm.startBroadcast() so that the tests pass when running with --fork-url
33. Create Makefile and add all required commands to make life easy to build, test, deploy on local/testnet blockchain
34. Need to create subscription and fund with link in chainlink and have the link balance in wallet as well in order to deploy this contract in sepolia/actual testnet