// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {Auxion} from "../src/Auxion.sol";
import "forge-std/console.sol";

contract AuxionTest is Test {
    Auxion public auxion;

    address owner = address(9);

    address user1 = address(1);
    address user2 = address(2);
    address user3 = address(3);

    function setUp() public {
        vm.prank(owner);
        auxion = new Auxion();
    }
    function helper_GivePenalties(address _user) public {
        vm.prank(owner);
        auxion.ownerGivePenalty(_user);
    }
    function helper_OpenAuction() public {
        auxion.openAuction(
            "Mutant Apes",
            "https://...",
            "Photos",
            100000000000000,
            100000000000000,
            block.timestamp,
            block.timestamp + 259200
        );
    }
}

contract AuxionOpenAuctionTest is AuxionTest {
    function test_OpenAuction() public {
        vm.prank(user1);
        auxion.openAuction(
            "Mutant Apes",
            "https://...",
            "Photos",
            100000000000000,
            100000000000000,
            block.timestamp,
            block.timestamp + 259200
        );

        (
            uint256 id,
            string memory name,
            string memory documents,
            string memory typeDocuments,
            address seller,
            address highestBidder,
            uint256 highestBid,
            bool isEnded,
            uint256 startBid,
            uint256 gapBid,
            uint256 startDate,
            uint256 endDate
        ) = auxion.listAuctions(1);

        assertEq(1, id);
        assertEq("Mutant Apes", name);
        assertEq("https://...", documents);
        assertEq("Photos", typeDocuments);
        assertEq(user1, seller);
        assertEq(address(0), highestBidder);
        assertEq(0, highestBid);
        assertEq(false, isEnded);
        assertEq(100000000000000, startBid);
        assertEq(100000000000000, gapBid);
        assertEq(block.timestamp, startDate);
        assertEq(block.timestamp + 259200, endDate);
    }

    function test_RevertWhenEndDateMoreStartDate_OpenAuction() public {
        vm.prank(user1);

        /**** */
        //Soon give theFeedback
        vm.expectRevert();
        /**** */

        auxion.openAuction(
            "Mutant Apes",
            "https://...",
            "Photos",
            100000000000000,
            100000000000000,
            block.timestamp,
            block.timestamp
        );
    }

    function test_RevertWhenUserGotPenalty_OpenAuction() public {
        helper_GivePenalties(user1);
        vm.prank(user1);
        vm.expectRevert("You got penalties");
        auxion.openAuction(
            "Mutant Apes",
            "https://...",
            "Photos",
            100000000000000,
            100000000000000,
            block.timestamp,
            block.timestamp + 259200
        );
    }
}

contract AuxionBidTest is AuxionTest {
    uint256 bidAmount = 1 ether;
    event highestBidIncreased(uint256 id, address bidder, uint256 amount);
    function test_1Bid() public {
        vm.prank(user1);
        helper_OpenAuction();

        vm.warp(block.timestamp + 1);
        vm.deal(user2, bidAmount);
        vm.prank(user2);
        auxion.bid{value: bidAmount}(1);

        (, , , , , address highestBidder, uint256 highestBid, , , , , ) = auxion
            .listAuctions(1);

        assertEq(user2, highestBidder);
        assertEq(bidAmount, highestBid);
    }

    function test_2Bid() public {
        vm.prank(user1);
        helper_OpenAuction();

        vm.warp(block.timestamp + 1);
        vm.deal(user2, bidAmount);
        vm.prank(user2);
        auxion.bid{value: bidAmount}(1);

        vm.warp(block.timestamp + 1);
        vm.deal(user3, bidAmount * 2);
        vm.prank(user3);
        vm.expectEmit(true, true, true, true);
        emit highestBidIncreased(1, user3, bidAmount * 2);
        auxion.bid{value: bidAmount * 2}(1);

        (, , , , , address highestBidder, uint256 highestBid, , , , , ) = auxion
            .listAuctions(1);

        assertEq(user3, highestBidder);
        assertEq(bidAmount * 2, highestBid);
    }

    function test_RevertWhenAuctionNotAvailable_Bid() public {
        vm.warp(block.timestamp + 1);
        vm.deal(user2, bidAmount);
        vm.prank(user2);
        vm.expectRevert("Auction not available");
        auxion.bid{value: bidAmount}(1);
    }

    function test_RevertWhenAuctionOwnerBid_Bid() public {
        vm.prank(user1);
        helper_OpenAuction();

        vm.warp(block.timestamp + 1);
        vm.deal(user1, bidAmount);
        vm.prank(user1);
        vm.expectRevert("You can't bid your auction");
        auxion.bid{value: bidAmount}(1);
    }

    function test_RevertWhenAuctionNotStarted_Bid() public {
        vm.prank(user1);
        helper_OpenAuction();

        vm.warp(block.timestamp);
        vm.deal(user2, bidAmount);
        vm.prank(user2);
        vm.expectRevert("Auction not started");
        auxion.bid{value: bidAmount}(1);
    }

    function test_RevertWhenAuctionFinished_Bid() public {
        vm.prank(user1);
        helper_OpenAuction();

        vm.warp(block.timestamp + 259300);
        vm.deal(user2, bidAmount);
        vm.prank(user2);
        vm.expectRevert("Auction has already ended.");
        auxion.bid{value: bidAmount}(1);
    }

    function test_RevertWhenAuctionBidLower_Bid() public {
        vm.prank(user1);
        helper_OpenAuction();

        vm.warp(block.timestamp + 1);
        vm.deal(user2, 10);
        vm.prank(user2);
        vm.expectRevert("There is already a higher or equal bid.");
        auxion.bid{value: 10}(1);
    }

    function test_RevertWhenAuctionBidNotMatch_Bid() public {
        vm.prank(user1);
        helper_OpenAuction();

        vm.warp(block.timestamp + 1);
        vm.deal(user2, bidAmount);
        vm.prank(user2);
        auxion.bid{value: bidAmount}(1);

        vm.warp(block.timestamp + 2);
        vm.deal(user3, bidAmount + 1);
        vm.prank(user3);
        vm.expectRevert("You should bid at least have gap ...");
        auxion.bid{value: bidAmount + 1}(1);
    }
}
