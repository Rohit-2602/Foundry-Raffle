// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

error Raffle__UpkeepNotNeeded();
error Raffle__NotEnoughBalance();
error Raffle__RaffleNotOpen();
error Raffle__TransferFailed();
error Raffle__WithDrawFailed();

/**@title A Raffle Contract
 * @author 0xDemuth (Rohit Sharma)
 * @notice Smart Contract for creating and managing raffles
 * @dev Implements Chainlink VRFConsumerBaseV2 to generate random numbers
 * @dev Implements Chainlink Automation to perform upkeep on the contract
 * @dev Implements OpenZeppelin Ownable to restrict access to certain functions
 * @dev Implements OpenZeppelin IERC20 to allow the use of ERC20 tokens
 */
contract RaffleContract is Ownable, VRFConsumerBaseV2 {
    //  <-  Define Raffle State  ->  //
    enum RaffleState {
        Open,
        Close
    }

    //  <-  Raffle Structure  ->  //
    struct Raffle {
        uint256 id;
        uint256 endTime;
        uint256 entryFee;
        string title;
        RaffleState state;
        uint32 maxWinners;
        address[] winners;
    }

    //  <-  State Variables  ->  //
    VRFCoordinatorV2Interface public immutable i_vrfCoordinatorV2;
    IERC20 public immutable i_erc20Contract;

    bytes32 private immutable i_keyHash;
    uint64 public immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    mapping(uint256 => address[]) private s_entriesMapping;
    Raffle[] private s_raffles;

    mapping(uint256 => uint256) private s_requestIdToRaffleId;

    //  <-  Events  ->  //
    event RaffleCreated(
        uint256 indexed id,
        uint256 indexed endTime,
        uint256 entryFee,
        string indexed title,
        uint32 maxWinners
    );

    event RaffleEntered(
        uint256 indexed id,
        uint256 time,
        address indexed entrant,
        uint256 entryFee
    );

    event PerformedUpKeep(
        uint256 indexed id,
        uint256 indexed requestId,
        uint256 time
    );

    event FullFilledRandomWord(
        uint256 indexed id,
        uint256 indexed requestId,
        uint256[] numbers
    );

    constructor(
        bytes32 keyHash,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        address vrfCoordinatorV2Address,
        address erc20ContractAddress
    ) VRFConsumerBaseV2(vrfCoordinatorV2Address) {
        i_vrfCoordinatorV2 = VRFCoordinatorV2Interface(vrfCoordinatorV2Address);
        i_subscriptionId = subscriptionId;
        i_keyHash = keyHash;
        i_callbackGasLimit = callbackGasLimit;
        i_erc20Contract = IERC20(erc20ContractAddress);
    }

    /**
        @dev Function to create a new raffle with the specified parameters.
        @param timeInterval The duration of the raffle in seconds.
        @param entryFee The cost of entering the raffle.
        @param maxWinners The maximum number of winners allowed for the raffle.
        @param title The title or name of the raffle.
    */
    function createRaffle(
        uint256 timeInterval,
        uint256 entryFee,
        uint32 maxWinners,
        string memory title
    ) external onlyOwner {
        // Generate a unique ID for the new raffle
        uint256 id = s_raffles.length;

        // Create a new Raffle struct with the provided parameters
        Raffle memory raffle = Raffle({
            id: id,
            endTime: block.timestamp + timeInterval,
            entryFee: entryFee,
            title: title,
            state: RaffleState.Open,
            maxWinners: maxWinners,
            winners: new address[](maxWinners)
        });

        // Add the new raffle to the s_raffles array
        s_raffles.push(raffle);

        // Emit an event to indicate the creation of the new raffle
        emit RaffleCreated(
            id,
            block.timestamp + timeInterval,
            entryFee,
            title,
            maxWinners
        );
    }

    /**
        @dev Function for entering a specific raffle.
        @param _raffleId The ID of the raffle to enter.
    */
    function enterRaffle(uint256 _raffleId) external payable {
        // Retrieve the raffle information from the s_raffles array
        Raffle memory raffle = s_raffles[_raffleId];
        address sender = msg.sender;

        // Check if the raffle is in the "Open" state
        if (raffle.state != RaffleState.Open) {
            revert Raffle__RaffleNotOpen();
        }

        if (address(i_erc20Contract) == address(0)) {
            // Check if the sender has sent enough ETH to enter the raffle
            if (msg.value < raffle.entryFee) {
                revert Raffle__NotEnoughBalance();
            }
        } else {
            // Check if the sender has enough balance to enter the raffle
            if (i_erc20Contract.balanceOf(sender) < raffle.entryFee) {
                revert Raffle__NotEnoughBalance();
            }
            // Transfer the entry fee from the sender to this contract
            bool transfer = i_erc20Contract.transferFrom(
                sender,
                address(this),
                raffle.entryFee
            );

            if (!transfer) {
                revert Raffle__TransferFailed();
            }
        }

        // Add the sender's address to the entries mapping for the raffle
        s_entriesMapping[_raffleId].push(sender);

        // Emit an event to indicate the user has entered the raffle
        emit RaffleEntered(_raffleId, block.timestamp, sender, raffle.entryFee);
    }

    /**
        @dev Function to check if any raffle requires upkeep and perform the necessary actions.
        @param /checkData/ Unused parameter for additional check data (can be empty).
        @return upkeepNeeded A boolean indicating if upkeep is needed for any raffle.
        @return performData The perform data containing the ID of the raffle that requires upkeep.
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory performData) {
        for (uint256 i = 0; i < s_raffles.length; i++) {
            Raffle memory raffle = s_raffles[i];
            bool isOpen = raffle.state == RaffleState.Open;
            bool timePassed = block.timestamp > raffle.endTime;

            uint256 raffleEntries = s_entriesMapping[raffle.id].length;
            bool enoughtEntries = (raffleEntries > 0 &&
                raffleEntries >= raffle.maxWinners);

            if (timePassed && isOpen && enoughtEntries) {
                upkeepNeeded = (timePassed && isOpen && enoughtEntries);
                return (upkeepNeeded, abi.encodePacked(raffle.id));
            }
        }
    }

    /**
     * @dev Function to perform the necessary upkeep actions for a raffle.
     */
    function performUpkeep(bytes calldata /* performData */) external {
        // Check if any raffle requires upkeep
        (bool upkeepNeeded, bytes memory data) = checkUpkeep("");

        // Revert if no upkeep is needed
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded();
        }

        // Extract the raffle ID from the perform data
        uint256 raffleId = uint256(bytes32(data));

        // Closing the raffle by updating its state
        s_raffles[raffleId].state = RaffleState.Close;

        // Request random words from VRF Coordinator
        uint256 requestId = i_vrfCoordinatorV2.requestRandomWords(
            i_keyHash,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            s_raffles[0].maxWinners
        );

        // Map the request ID to the raffle ID for future reference
        s_requestIdToRaffleId[requestId] = raffleId;

        // Emit an event to indicate the performed upkeep
        emit PerformedUpKeep(raffleId, requestId, block.timestamp);
    }

    /**
        @dev Internal function to fulfill the requested random words for a raffle.
        @param requestId The ID of the request for random words.
        @param randomWords An array of random words generated for the raffle.
    */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        // Retrieve the raffle ID associated with the request ID
        uint256 raffleId = s_requestIdToRaffleId[requestId];

        // Get the raffle from the s_raffles array
        Raffle storage raffle = s_raffles[raffleId];

        // Iterate through the randomWords array
        for (uint256 i = 0; i < randomWords.length; i++) {
            // Calculate the index of the winner based on the random word and number of entries
            uint256 indexOfWinner = randomWords[i] %
                s_entriesMapping[raffleId].length;

            // Add the winner's address to the raffle's winners array
            raffle.winners.push(s_entriesMapping[raffleId][indexOfWinner]);
        }

        // Emit an event to indicate the fulfillment of the random words
        emit FullFilledRandomWord(raffleId, requestId, randomWords);
    }

    /**
        @dev Function to get the entries for a specific raffle.
        @param _raffleId The ID of the raffle.
        @return An array of addresses representing the entries for the raffle.
    */
    function getRaffleEntries(
        uint256 _raffleId
    ) external view returns (address[] memory) {
        return s_entriesMapping[_raffleId];
    }

    /**
        @dev Function to get the length of entries for a specific raffle.
        @param _raffleId The ID of the raffle.
        @return The number of entries for the raffle.
    */
    function getRaffleEntriesLength(
        uint256 _raffleId
    ) external view returns (uint256) {
        return s_entriesMapping[_raffleId].length;
    }

    /**
        @dev Function to get all the raffles.
        @return An array of Raffle structs representing all the raffles.
    */
    function getRaffles() external view returns (Raffle[] memory) {
        return s_raffles;
    }

    /**
        @dev Function to get a specific raffle by its ID.
        @param _raffleId The ID of the raffle.
        @return The Raffle struct representing the specified raffle.
    */
    function getRaffle(
        uint256 _raffleId
    ) external view returns (Raffle memory) {
        return s_raffles[_raffleId];
    }

    /**
        @dev Function to get the winners for a specific raffle.
        @param _raffleId The ID of the raffle.
        @return An array of addresses representing the winners of the raffle.
    */
    function getRaffleWinners(
        uint256 _raffleId
    ) external view returns (address[] memory) {
        return s_raffles[_raffleId].winners;
    }

    /**
        @dev Function to get the ERC20 token balance of a specific address.
        @param _address The address for which the ERC20 token balance is queried.
        @return The ERC20 token balance of the specified address.
    */
    function getERC20Balance(address _address) public view returns (uint256) {
        return i_erc20Contract.balanceOf(_address);
    }

    /**
        @dev Function to withdraw ETH and ERC20 tokens from the contract.
        Only the owner of the contract can call this function.
    */
    function withDraw() external onlyOwner {
        if (address(i_erc20Contract) == address(0)) {
            // Withdraw ETH from the contract
            (bool success, ) = payable(owner()).call{
                value: address(this).balance
            }("");
            if (!success) {
                revert Raffle__WithDrawFailed();
            }
        } else {
            // Withdraw ERC20 tokens from the contract
            bool transfer = i_erc20Contract.transfer(
                owner(),
                i_erc20Contract.balanceOf(address(this))
            );

            if (!transfer) {
                revert Raffle__WithDrawFailed();
            }
        }
    }
}
