// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {Auxion} from "../src/Auxion.sol";

contract AuxionTest is Test {
    Auxion public auxion;

    address owner = address(9);

    address user1 = address(1);
    address user2 = address(2);
    address user3 = address(3);
    address user4 = address(4);
    uint256 bidAmount = 1 ether;

    event highestBidIncreased(uint256 id, address bidder, uint256 amount);
    event withdrawBalance(address user, uint256 amount);
    event auctionEnded(uint256 id, address highestBidder, uint256 highestBid);
    event refundToBuyer(address buyer, address seller, uint256 _amount);

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

    function helper_WithdrawBalance() public {
        vm.prank(user1);
        helper_OpenAuction();

        vm.warp(block.timestamp + 1);
        vm.deal(user2, bidAmount);
        vm.prank(user2);
        auxion.bid{value: bidAmount}(1);

        vm.warp(block.timestamp + 2);
        vm.deal(user3, bidAmount * 2);
        vm.prank(user3);
        auxion.bid{value: bidAmount * 2}(1);
    }

    function helper_EndAuction(address _user1, address _user2) public {
        vm.warp(block.timestamp + 1);
        vm.deal(_user1, bidAmount);
        vm.prank(_user1);
        auxion.bid{value: bidAmount}(1);

        uint256 tempBidAmount = bidAmount * 2;

        vm.warp(block.timestamp + 2);
        vm.deal(_user2, tempBidAmount);
        vm.prank(_user2);
        auxion.bid{value: tempBidAmount}(1);

        vm.warp(block.timestamp + 3);
        vm.deal(_user1, tempBidAmount);
        vm.prank(_user1);
        auxion.bidWithBalance{value: (tempBidAmount)}(1, 0.5 ether);
    }

    function helper_Approval(address _user) public {
        (,,,,,,,,,,, uint256 endDate) = auxion.listAuctions(1);
        vm.warp(endDate + 1);
        vm.prank(_user);
        auxion.endAuction(1);
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

        /**
         *
         */
        //Soon give theFeedback
        vm.expectRevert("Make sure your date is valid");
        /**
         *
         */
        auxion.openAuction(
            "Mutant Apes", "https://...", "Photos", 100000000000000, 100000000000000, block.timestamp, block.timestamp
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
    function test_1Bid() public {
        vm.prank(user1);
        helper_OpenAuction();

        vm.warp(block.timestamp + 1);
        vm.deal(user2, bidAmount);
        vm.prank(user2);
        auxion.bid{value: bidAmount}(1);

        (,,,,, address highestBidder, uint256 highestBid,,,,,) = auxion.listAuctions(1);

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

        (,,,,, address highestBidder, uint256 highestBid,,,,,) = auxion.listAuctions(1);

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

    // function test_RevertWhenAuctionNotStarted_Bid() public {
    //     vm.prank(user1);
    //     helper_OpenAuction();

    //     vm.warp(block.timestamp);
    //     vm.deal(user2, bidAmount);
    //     vm.prank(user2);
    //     vm.expectRevert("Auction not started");
    //     auxion.bid{value: bidAmount}(1);
    // }

    function test_RevertWhenAuctionFinished_Bid() public {
        vm.prank(user1);
        helper_OpenAuction();

        vm.warp(block.timestamp + 259300);
        vm.deal(user2, bidAmount);
        vm.prank(user2);
        vm.expectRevert("Auction has already ended.");
        auxion.bid{value: bidAmount}(1);
    }

    function test_RevertWhenAuctionBidNotMatch_Bid() public {
        vm.prank(user1);
        helper_OpenAuction();

        vm.warp(block.timestamp + 1);
        vm.deal(user2, bidAmount);
        vm.prank(user2);
        auxion.bid{value: bidAmount}(1);

        vm.warp(block.timestamp + 1);
        vm.deal(user3, bidAmount + 1);
        vm.prank(user3);
        vm.expectRevert("You should bid at least have gap ...");
        auxion.bid{value: bidAmount + 1}(1);
    }

    function test_RevertWhenAuctionBidLowerFromStart_Bid() public {
        vm.prank(user1);
        helper_OpenAuction();

        vm.warp(block.timestamp + 1);
        vm.deal(user2, 10);
        vm.prank(user2);
        vm.expectRevert("You should bid at least have gap ...");
        ///
        auxion.bid{value: 10}(1);
    }

    function test_RevertWhenAuctionBidUnderBidBefore_Bid() public {
        vm.prank(user1);
        helper_OpenAuction();

        vm.warp(block.timestamp + 1);
        vm.deal(user2, bidAmount);
        vm.prank(user2);
        auxion.bid{value: bidAmount}(1);

        vm.warp(block.timestamp + 1);
        vm.deal(user3, bidAmount - 1);
        vm.prank(user3);
        vm.expectRevert("There is already a higher or equal bid.");
        auxion.bid{value: bidAmount - 1}(1);
    }

    function test_RevertWhenUserGotPenalty_Bid() public {
        vm.prank(user1);
        helper_OpenAuction();

        helper_GivePenalties(user2);

        vm.warp(block.timestamp + 1);
        vm.deal(user2, bidAmount);
        vm.prank(user2);
        vm.expectRevert("You got penalties");
        auxion.bid{value: bidAmount}(1);
    }
}

contract AuxionBidWithBalanceTest is AuxionTest {
    function test_BidWithBalance() public {
        vm.prank(user1);
        helper_OpenAuction();

        vm.warp(block.timestamp + 1);
        vm.deal(user2, bidAmount);
        vm.prank(user2);
        auxion.bid{value: bidAmount}(1);

        vm.warp(block.timestamp + 2);
        vm.deal(user3, bidAmount * 2);
        vm.prank(user3);
        auxion.bid{value: bidAmount * 2}(1);

        vm.warp(block.timestamp + 3);
        vm.deal(user2, (bidAmount * 2));
        vm.prank(user2);
        auxion.bidWithBalance{value: (bidAmount * 2)}(1, bidAmount / 2);

        assertEq(auxion.balances(user2), bidAmount / 2);
        assertEq(auxion.balances(user3), bidAmount * 2);
    }
    // 1000000000000000000
    // 250000000000000000

    function test_RevertWhenInsufficientBalance_BidWithBalance() public {
        vm.prank(user1);
        helper_OpenAuction();

        vm.warp(block.timestamp + 1);
        vm.deal(user2, bidAmount);
        vm.prank(user2);
        auxion.bid{value: bidAmount}(1);

        vm.warp(block.timestamp + 2);
        vm.deal(user3, bidAmount * 2);
        vm.prank(user3);
        auxion.bid{value: bidAmount * 2}(1);

        vm.warp(block.timestamp + 3);
        vm.deal(user2, (bidAmount * 2));
        vm.prank(user2);
        vm.expectRevert("Insufficient Balance");
        auxion.bidWithBalance{value: (bidAmount * 2)}(1, bidAmount * 2);
    }

    function test_RevertWhenAuctionNotAvailable_BidWithBalance() public {
        vm.warp(block.timestamp + 1);
        vm.deal(user2, bidAmount);
        vm.prank(user2);
        vm.expectRevert("Auction not available");
        auxion.bidWithBalance{value: bidAmount}(1, bidAmount);
    }

    function test_RevertWhenAuctionOwnerBid_BidWithBalance() public {
        vm.prank(user1);
        helper_OpenAuction();

        vm.warp(block.timestamp + 1);
        vm.deal(user1, bidAmount);
        vm.prank(user1);
        vm.expectRevert("You can't bid your auction");
        auxion.bidWithBalance{value: bidAmount}(1, bidAmount);
    }

    // function test_RevertWhenAuctionNotStarted_BidWithBalance() public {
    //     vm.prank(user1);
    //     helper_OpenAuction();

    //     vm.warp(block.timestamp);
    //     vm.deal(user2, bidAmount);
    //     vm.prank(user2);
    //     vm.expectRevert("Auction not started");
    //     auxion.bidWithBalance{value: bidAmount}(1, bidAmount);
    // }

    function test_RevertWhenAuctionFinished_BidWithBalance() public {
        vm.prank(user1);
        helper_OpenAuction();

        vm.warp(block.timestamp + 259300);
        vm.deal(user2, bidAmount);
        vm.prank(user2);
        vm.expectRevert("Auction has already ended.");
        auxion.bidWithBalance{value: bidAmount}(1, bidAmount);
    }

    function test_RevertWhenAuctionBidNotMatch_BidWithBalance() public {
        vm.prank(user1);
        helper_OpenAuction();

        vm.warp(block.timestamp + 1);
        vm.deal(user2, bidAmount);
        vm.prank(user2);
        auxion.bidWithBalance{value: bidAmount}(1, 0);

        vm.warp(block.timestamp + 1);
        vm.deal(user3, bidAmount + 1);
        vm.prank(user3);
        vm.expectRevert("You should bid at least have gap ...");
        auxion.bidWithBalance{value: bidAmount + 1}(1, 0);
    }

    function test_RevertWhenAuctionBidLowerFromStart_BidWithBalance() public {
        vm.prank(user1);
        helper_OpenAuction();

        vm.warp(block.timestamp + 1);
        vm.deal(user2, 10);
        vm.prank(user2);
        vm.expectRevert("You should bid at least have gap ...");
        ///
        auxion.bidWithBalance{value: 10}(1, 0);
    }

    function test_RevertWhenAuctionBidUnderBidBefore_BidWithBalance() public {
        vm.prank(user1);
        helper_OpenAuction();

        vm.warp(block.timestamp + 1);
        vm.deal(user2, bidAmount);
        vm.prank(user2);
        auxion.bidWithBalance{value: bidAmount}(1, 0);

        vm.warp(block.timestamp + 1);
        vm.deal(user3, bidAmount - 1);
        vm.prank(user3);
        vm.expectRevert("There is already a higher or equal bid.");
        auxion.bidWithBalance{value: bidAmount - 1}(1, 0);
    }

    function test_RevertWhenUserGotPenalty_BidWithBalance() public {
        vm.prank(user1);
        helper_OpenAuction();

        helper_GivePenalties(user2);

        vm.warp(block.timestamp + 1);
        vm.deal(user2, bidAmount);
        vm.prank(user2);
        vm.expectRevert("You got penalties");
        auxion.bidWithBalance{value: bidAmount}(1, 0);
    }
}

contract AuxionWithdrawTest is AuxionTest {
    function test_Withdraw() public {
        helper_WithdrawBalance();
        uint256 withdrawAmount = 100;
        vm.prank(user2);
        auxion.withdraw(withdrawAmount);
        assertEq(user2.balance, withdrawAmount);
        assertEq(auxion.balances(user2), bidAmount - withdrawAmount);
    }

    function test_fullBalance_Withdraw() public {
        helper_WithdrawBalance();
        uint256 withdrawAmount = bidAmount;
        vm.prank(user2);
        auxion.withdraw(withdrawAmount);
        assertEq(user2.balance, withdrawAmount);
        assertEq(auxion.balances(user2), bidAmount - withdrawAmount);
    }

    function test_RevertWhenInsufficientBalance_Withdraw() public {
        helper_WithdrawBalance();
        vm.prank(user2);

        vm.expectRevert("Failed to send Ether");

        auxion.withdraw(bidAmount * 2);

        assertEq(auxion.balances(user2), bidAmount);
    }

    function test_RevertWhenZeroAmount_Withdraw() public {
        helper_WithdrawBalance();
        uint256 withdrawAmount = 0;
        vm.prank(user2);
        vm.expectRevert("Failed to send Ether");
        auxion.withdraw(withdrawAmount);
        assertEq(user2.balance, withdrawAmount);
        assertEq(auxion.balances(user2), bidAmount - withdrawAmount);
    }

    function test_RevertWhenUserGotPenalty_Withdraw() public {
        uint256 withdrawAmount = 100;
        helper_GivePenalties(user2);
        vm.prank(user2);
        vm.expectRevert("You got penalties");
        auxion.withdraw(withdrawAmount);
    }
}

contract AuxionEndAuctionTest is AuxionTest {
    function test_BuyerEndAuction() public {
        vm.prank(user1);
        helper_OpenAuction();
        helper_EndAuction(user2, user3);
        (,,,,,, uint256 highestBid,,,,, uint256 endDate) = auxion.listAuctions(1);
        vm.warp(endDate + 1);
        // Buyer
        vm.prank(user2);
        vm.expectEmit(true, true, true, true);
        emit auctionEnded(1, user2, highestBid);

        auxion.endAuction(1);
        (
            address buyer,
            address seller,
            bool buyerApproval,
            bool sellerApproval,
            bool isFinished,
            uint256 finalBid,
            uint256 pendingShip,
            uint256 approvalCreated
        ) = (auxion.winnerAuction(1));

        assertEq(buyer, user2);
        assertEq(seller, user1);
        assertEq(buyerApproval, false);
        assertEq(sellerApproval, false);
        assertEq(isFinished, false);
        assertEq(finalBid, highestBid);
        assertEq(pendingShip, 0);
        assertEq(approvalCreated, block.timestamp);
    }

    function test_SellerEndAuction() public {
        vm.prank(user1);
        helper_OpenAuction();
        helper_EndAuction(user2, user3);
        (,,,,,, uint256 highestBid,,,,, uint256 endDate) = auxion.listAuctions(1);
        vm.warp(endDate + 1);

        // Seller
        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit auctionEnded(1, user2, highestBid);

        auxion.endAuction(1);
        (
            address buyer,
            address seller,
            bool buyerApproval,
            bool sellerApproval,
            bool isFinished,
            uint256 finalBid,
            uint256 pendingShip,
            uint256 approvalCreated
        ) = (auxion.winnerAuction(1));

        assertEq(buyer, user2);
        assertEq(seller, user1);
        assertEq(buyerApproval, false);
        assertEq(sellerApproval, false);
        assertEq(isFinished, false);
        assertEq(finalBid, highestBid);
        assertEq(pendingShip, 0);
        assertEq(approvalCreated, block.timestamp);
    }

    function test_RevertWhenAuctionNotAvailable_EndAuction() public {
        vm.prank(user1);
        vm.expectRevert("Auction not available");
        auxion.endAuction(1);
    }

    function test_RevertWhenSomeoneEndAuction_EndAuction() public {
        vm.prank(user1);
        helper_OpenAuction();
        helper_EndAuction(user2, user3);
        (,,,,,,,,,,, uint256 endDate) = auxion.listAuctions(1);
        vm.warp(endDate + 1);
        vm.prank(user4);
        vm.expectRevert("Only the auction owner/highest bidder can end the auction.");
        auxion.endAuction(1);
    }

    function test_RevertWhenAuctionStillGoing_EndAuction() public {
        vm.prank(user1);
        helper_OpenAuction();
        helper_EndAuction(user2, user3);
        vm.prank(user1);
        vm.expectRevert("Auction is still ongoing.");
        auxion.endAuction(1);
    }

    function test_RevertWhenNobodyAuction_EndAuction() public {
        vm.prank(user1);
        helper_OpenAuction();
        (,,,,,,,,,,, uint256 endDate) = auxion.listAuctions(1);
        vm.warp(endDate + 1);
        vm.prank(user1);
        vm.expectRevert("Nobody bid here");
        auxion.endAuction(1);
    }

    function test_RevertWhenAuctionEnded_EndAuction() public {
        vm.prank(user1);
        helper_OpenAuction();
        helper_EndAuction(user2, user3);
        (,,,,,,,,,,, uint256 endDate) = auxion.listAuctions(1);
        vm.warp(endDate + 1);
        vm.prank(user2);
        auxion.endAuction(1);

        vm.prank(user1);
        vm.expectRevert("Auction end has already been called.");
        auxion.endAuction(1);
    }
}

contract AuxionBuyerApprovalTest is AuxionTest {
    function test_BuyerApproval() public {
        vm.prank(user1);
        helper_OpenAuction();
        helper_EndAuction(user2, user3);
        helper_Approval(user2);
        vm.prank(user2);
        auxion.buyerApproval(1);
        (,, bool buyerApproval,,,,,) = (auxion.winnerAuction(1));

        assertEq(buyerApproval, true);
    }

    function test_RevertWhenSomeoneAprrove_BuyerApproval() public {
        vm.prank(user1);
        helper_OpenAuction();
        helper_EndAuction(user2, user3);
        helper_Approval(user2);
        vm.prank(user1);
        vm.expectRevert("Not authorized");
        auxion.buyerApproval(1);
    }

    function test_RevertWhenAuctionNotEnded_BuyerApproval() public {
        vm.prank(user1);
        helper_OpenAuction();
        helper_EndAuction(user2, user3);
        vm.prank(user2);
        vm.expectRevert("Auction not ended");
        auxion.buyerApproval(1);
    }
}

contract AuxionSellerApprovalTest is AuxionTest {
    function test_Approval() public {
        vm.prank(user1);
        helper_OpenAuction();
        helper_EndAuction(user2, user3);
        helper_Approval(user2);
        vm.prank(user1);
        auxion.approval(1, block.timestamp + 1);
        (,,, bool sellerApproval,,, uint256 pendingShip,) = (auxion.winnerAuction(1));
        assertEq(sellerApproval, true);
        assertEq(pendingShip, block.timestamp + 1);
    }

    function test_EarlyApproval() public {
        vm.prank(user1);
        helper_OpenAuction();
        helper_EndAuction(user2, user3);
        helper_Approval(user2);
        vm.prank(user1);
        auxion.approval(1, 1);
        (,,, bool sellerApproval,,, uint256 pendingShip,) = (auxion.winnerAuction(1));
        assertEq(sellerApproval, true);
        assertEq(pendingShip, block.timestamp);
    }

    function test_MoreThreeMonthsApproval() public {
        uint256 threeMonths = 7889229;
        vm.prank(user1);
        helper_OpenAuction();
        helper_EndAuction(user2, user3);
        helper_Approval(user2);
        vm.prank(user1);
        auxion.approval(1, block.timestamp + threeMonths + 30);
        (,,, bool sellerApproval,,, uint256 pendingShip,) = (auxion.winnerAuction(1));
        assertEq(sellerApproval, true);
        assertEq(pendingShip, block.timestamp + threeMonths);
    }

    function test_RevertWhenSomeoneAprrove_Approval() public {
        vm.prank(user1);
        helper_OpenAuction();
        helper_EndAuction(user2, user3);
        helper_Approval(user2);
        vm.prank(user2);
        vm.expectRevert("Not authorized");
        auxion.approval(1, block.timestamp + 1);
    }

    function test_RevertWhenAuctionNotEnded_Approval() public {
        vm.prank(user1);
        helper_OpenAuction();
        helper_EndAuction(user2, user3);
        vm.prank(user1);
        vm.expectRevert("Auction not ended");
        auxion.approval(1, block.timestamp + 1);
    }
}

contract AuxionFinishAuctionTest is AuxionTest {
    function test_FinishAuction() public {
        vm.prank(user1);
        helper_OpenAuction();
        helper_EndAuction(user2, user3);
        helper_Approval(user2);

        vm.prank(user1);
        auxion.approval(1, block.timestamp + 1);

        vm.prank(user2);
        auxion.buyerApproval(1);

        (,,,,, uint256 tempFinalBid,,) = (auxion.winnerAuction(1));
        vm.warp(block.timestamp + 2);
        vm.prank(user1);
        auxion.finishAuction(1);

        (,,,, bool isFinished, uint256 finalBid,,) = (auxion.winnerAuction(1));
        assertEq(isFinished, true);
        assertEq(finalBid, 0);
        assertEq(auxion.balances(user1), tempFinalBid);
    }

    function test_RevertWhenAuctionNotFinished_FinishAuction() public {
        vm.prank(user1);
        helper_OpenAuction();
        helper_EndAuction(user2, user3);
        helper_Approval(user2);

        vm.prank(user1);
        auxion.approval(1, block.timestamp + 1);

        vm.prank(user2);
        auxion.buyerApproval(1);

        vm.prank(user1);
        vm.expectRevert("Auction not finished shipping");
        auxion.finishAuction(1);
    }

    function test_RevertWhenBothNoApprove_FinishAuction() public {
        vm.prank(user1);
        helper_OpenAuction();
        helper_EndAuction(user2, user3);
        helper_Approval(user2);

        vm.prank(user1);
        vm.expectRevert("Both of them must aprrove");
        auxion.finishAuction(1);
    }

    function test_RevertWhenHasFinished_FinishAuction() public {
        vm.prank(user1);
        helper_OpenAuction();
        helper_EndAuction(user2, user3);
        helper_Approval(user2);

        vm.prank(user1);
        auxion.approval(1, block.timestamp + 1);

        vm.prank(user2);
        auxion.buyerApproval(1);

        vm.warp(block.timestamp + 2);
        vm.prank(user1);
        auxion.finishAuction(1);

        vm.warp(block.timestamp + 3);
        vm.prank(user1);
        vm.expectRevert("Auction finished");
        auxion.finishAuction(1);
    }
}

contract AuxionRefundWhenSellerNoActionTest is AuxionTest {
    function test_RefundWhenSellerNoAction() public {
        vm.prank(user1);
        helper_OpenAuction();
        helper_EndAuction(user2, user3);
        helper_Approval(user2);

        vm.warp(block.timestamp + 6048000);
        vm.prank(user2);
        auxion.refundWhenSellerNoAction(1);

        (,,,, bool isFinished, uint256 finalBid,,) = (auxion.winnerAuction(1));

        assertEq(isFinished, true);
        assertEq(finalBid, 0);
        assertEq(auxion.balances(user2), 3 ether);
    }

    function test_RevertWhenNotBuyer_RefundWhenSellerNoAction() public {
        vm.prank(user1);
        helper_OpenAuction();
        helper_EndAuction(user2, user3);
        helper_Approval(user2);

        vm.warp(block.timestamp + 6048000);
        vm.prank(user3);
        vm.expectRevert("Not authorized");
        auxion.refundWhenSellerNoAction(1);
    }

    function test_RevertWhenNorReach1Week_RefundWhenSellerNoAction() public {
        vm.prank(user1);
        helper_OpenAuction();
        helper_EndAuction(user2, user3);
        helper_Approval(user2);

        vm.warp(block.timestamp);
        vm.prank(user2);
        vm.expectRevert("You can refund if theres no action more than a week");
        auxion.refundWhenSellerNoAction(1);
    }

    function test_RevertWhenSellerHasApprove_RefundWhenSellerNoAction() public {
        vm.prank(user1);
        helper_OpenAuction();
        helper_EndAuction(user2, user3);
        helper_Approval(user2);

        vm.prank(user1);
        auxion.approval(1, block.timestamp + 1);

        vm.warp(block.timestamp + 6048000);

        vm.prank(user2);

        vm.expectRevert("Seller has been approve");
        auxion.refundWhenSellerNoAction(1);
    }
}
