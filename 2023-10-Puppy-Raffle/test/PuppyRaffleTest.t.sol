// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import {Test, console} from "forge-std/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";
import {DeployPuppyRaffle} from "../script/DeployPuppyRaffle.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract PuppyRaffleTest is Test {
    PuppyRaffle puppyRaffle;
    VRFCoordinatorV2Mock vrfCoordinatorV2Mock;
    uint256 entranceFee = 1e18;
    address playerOne = address(1);
    address playerTwo = address(2);
    address playerThree = address(3);
    address playerFour = address(4);
    address feeAddress;
    uint256 duration = 1 days;

    receive() external payable {}

    function setUp() public {
        DeployPuppyRaffle deployer = new DeployPuppyRaffle();

        (puppyRaffle, vrfCoordinatorV2Mock) = deployer.run();

        feeAddress = deployer.feeAddress();
    }

    //////////////////////
    /// EnterRaffle    ///
    /////////////////////

    function testCanEnterRaffle() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        assertEq(puppyRaffle.players(0), playerOne);
    }

    function testCantEnterWithoutPaying() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle(players);
    }

    function testCanEnterRaffleMany() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
        assertEq(puppyRaffle.players(0), playerOne);
        assertEq(puppyRaffle.players(1), playerTwo);
    }

    function testCantEnterWithoutPayingMultiple() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle{value: entranceFee}(players);
    }

    function testCantEnterWithDuplicatePlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
    }

    function testCantEnterWithDuplicatePlayersMany() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);
    }

    //////////////////////
    /// Refund         ///
    /////////////////////
    modifier playerEntered() {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        _;
    }

    function testCanGetRefund() public playerEntered {
        uint256 balanceBefore = address(playerOne).balance;
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        assertEq(address(playerOne).balance, balanceBefore + entranceFee);
    }

    function testGettingRefundRemovesThemFromArray() public playerEntered {
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        assertEq(puppyRaffle.players(0), address(0));
    }

    function testOnlyPlayerCanRefundThemself() public playerEntered {
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);
        vm.expectRevert("PuppyRaffle: Only the player can refund");
        vm.prank(playerTwo);
        puppyRaffle.refund(indexOfPlayer);
    }

    //////////////////////
    /// getActivePlayerIndex         ///
    /////////////////////
    function testGetActivePlayerIndexManyPlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);

        assertEq(puppyRaffle.getActivePlayerIndex(playerOne), 0);
        assertEq(puppyRaffle.getActivePlayerIndex(playerTwo), 1);
    }

    //////////////////////
    /// selectWinner         ///
    /////////////////////
    modifier playersEntered() {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);
        _;
    }

    function testCantSelectWinnerBeforeRaffleEnds() public playersEntered {
        vm.expectRevert("PuppyRaffle: Raffle not over");
        puppyRaffle.selectWinner();
    }

    function testCantSelectWinnerWithFewerThanFourPlayers() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = address(3);
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        vm.expectRevert("PuppyRaffle: Need at least 4 players");
        puppyRaffle.selectWinner();
    }

    function testSelectWinner() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 request_id = puppyRaffle.selectWinner();

        vrfCoordinatorV2Mock.fulfillRandomWords(request_id, address(puppyRaffle));

        address previous_winner = puppyRaffle.previousWinner();

        assertEq(
            (
                previous_winner == playerOne || previous_winner == playerTwo || previous_winner == playerThree
                    || previous_winner == playerFour
            ),
            true
        );
    }

    function testSelectWinnerGetsPaid() public playersEntered {
        uint256 balanceBefore1 = address(playerOne).balance;
        uint256 balanceBefore2 = address(playerTwo).balance;
        uint256 balanceBefore3 = address(playerThree).balance;
        uint256 balanceBefore4 = address(playerFour).balance;

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPayout = ((entranceFee * 4) * 80 / 100);

        uint256 request_id = puppyRaffle.selectWinner();

        vrfCoordinatorV2Mock.fulfillRandomWords(request_id, address(puppyRaffle));

        assertEq(
            (
                address(playerOne).balance == balanceBefore1 + expectedPayout
                    || address(playerTwo).balance == balanceBefore2 + expectedPayout
                    || address(playerThree).balance == balanceBefore3 + expectedPayout
                    || address(playerFour).balance == balanceBefore4 + expectedPayout
            ),
            true
        );
    }

    function testSelectWinnerGetsAPuppy() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 request_id = puppyRaffle.selectWinner();

        vrfCoordinatorV2Mock.fulfillRandomWords(request_id, address(puppyRaffle));

        address previous_winner = puppyRaffle.previousWinner();
        assertEq(puppyRaffle.balanceOf(previous_winner), 1);
    }

    // Don't know token uri in advance.
    // function testPuppyUriIsRight() public playersEntered {
    //     vm.warp(block.timestamp + duration + 1);
    //     vm.roll(block.number + 1);

    //     // Don't know token uri in advance.
    //     string memory expectedTokenUri =
    //         "data:application/json;base64,eyJuYW1lIjoiUHVwcHkgUmFmZmxlIiwgImRlc2NyaXB0aW9uIjoiQW4gYWRvcmFibGUgcHVwcHkhIiwgImF0dHJpYnV0ZXMiOiBbeyJ0cmFpdF90eXBlIjogInJhcml0eSIsICJ2YWx1ZSI6IGNvbW1vbn1dLCAiaW1hZ2UiOiJpcGZzOi8vUW1Tc1lSeDNMcERBYjFHWlFtN3paMUF1SFpqZmJQa0Q2SjdzOXI0MXh1MW1mOCJ9";

    //     uint256 request_id = puppyRaffle.selectWinner();

    //     vrfCoordinatorV2Mock.fulfillRandomWords(request_id, address(puppyRaffle));

    //     assertEq(puppyRaffle.tokenURI(0), expectedTokenUri);
    // }

    //////////////////////
    /// withdrawFees         ///
    /////////////////////
    function testCantWithdrawFeesIfPlayersActive() public playersEntered {
        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }

    function testWithdrawFees() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 puppyRaffleBalanceBefore = address(puppyRaffle).balance;

        uint256 expectedPrizeAmount = ((entranceFee * 4) * 20) / 100;

        uint256 request_id = puppyRaffle.selectWinner();

        vrfCoordinatorV2Mock.fulfillRandomWords(request_id, address(puppyRaffle));
        puppyRaffle.withdrawFees();
        // assertEq(feeAddress.balance, expectedPrizeAmount);
        assertEq(address(puppyRaffle).balance, puppyRaffleBalanceBefore - entranceFee * 4);
    }
}
