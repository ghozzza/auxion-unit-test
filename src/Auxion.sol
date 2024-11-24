// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

contract Auxion {
    uint256 id;

    struct AuctionData {
        uint256 id;
        string name;
        string documents;
        string typeDocuments;
        address seller;
        address highestBidder;
        uint256 highestBid;
        bool isEnded;
        uint256 startBid;
        uint256 gapBid;
        uint256 startDate;
        uint256 endDate;
    }

    struct WinnerApproval {
        address buyer;
        address seller;
        bool buyerApproval;
        bool sellerApproval;
        bool isFinished;
        uint256 finalBid;
        uint256 pendingShip;
        uint256 approvalCreated;
    }

    mapping(uint256 => AuctionData) public listAuctions;
    mapping(address => uint256) public balances;
    mapping(uint256 => WinnerApproval) public winnerAuction;
    mapping(address => bool) public penalty;
    mapping(address => bool) public admin;

    address owner;

    event highestBidIncreased(uint256 id, address bidder, uint256 amount);
    event auctionEnded(uint256 id, address highestBidder, uint256 highestBid);
    event withdrawBalance(address user, uint256 amount);
    event refundToBuyer(address buyer, address seller, uint256 _amount);

    constructor() {
        owner = msg.sender;
    }

    modifier auctionAvailable(uint256 _id) {
        require(listAuctions[_id].id != 0, "Auction not available");
        _;
    }

    modifier notAuctionOwner(uint256 _id) {
        require(listAuctions[_id].seller != msg.sender, "You can't bid your auction");
        _;
    }

    modifier timeSchedule(uint256 _id) {
        require(block.timestamp > listAuctions[_id].startDate, "Auction not started");
        require(block.timestamp < listAuctions[_id].endDate && !listAuctions[_id].isEnded, "Auction has already ended.");
        _;
    }

    modifier bidLower(uint256 _id, uint256 _amount) {
        require(msg.value + _amount > listAuctions[_id].highestBid, "There is already a higher or equal bid.");
        _;
    }

    modifier bidGapHigh(uint256 _id, uint256 _amount) {
        require(
            msg.value + _amount > (listAuctions[_id].highestBid + listAuctions[_id].gapBid),
            "You should bid at least have gap ..."
        );
        _;
    }

    modifier startBidding(uint256 _id, uint256 _amount) {
        require(msg.value + _amount >= listAuctions[_id].startBid, "Bid at least higher than start bid");
        _;
    }

    modifier penaltyProtect() {
        require(!penalty[msg.sender], "You got penalties");
        _;
    }

    modifier onlyOwner() {
        require((owner == msg.sender) || (admin[msg.sender]), "You're not Owner");
        _;
    }

    function openAuction(
        string memory _name,
        string memory _documents,
        string memory _typeDocuments,
        uint256 _price,
        uint256 _gapBid,
        uint256 _startDate,
        uint256 _endDate
    ) external penaltyProtect {
        uint256 tempStartDate = (block.timestamp > _startDate ? block.timestamp : _startDate);
        require(tempStartDate < _endDate);
        ++id;
        listAuctions[id] = AuctionData({
            id: id,
            name: _name,
            documents: _documents,
            typeDocuments: _typeDocuments, // photos, nft, etc
            seller: msg.sender,
            highestBidder: address(0), // changeable
            highestBid: 0, // changeable
            isEnded: false, // changeable
            startBid: _price,
            gapBid: _gapBid,
            startDate: tempStartDate,
            endDate: _endDate
        });
    }
    // Bid using external balances

    function bid(uint256 _id)
        external
        payable
        auctionAvailable(_id)
        notAuctionOwner(_id)
        timeSchedule(_id)
        bidLower(_id, 0)
        bidGapHigh(_id, 0)
        startBidding(_id, 0)
        penaltyProtect
    {
        //Refund the bid to balances, if there are higher bid use the function
        if (listAuctions[_id].highestBid < msg.value && listAuctions[_id].highestBid != 0) {
            balances[listAuctions[_id].highestBidder] += listAuctions[_id].highestBid;
        }

        listAuctions[_id].highestBidder = msg.sender;
        listAuctions[_id].highestBid = msg.value;
        emit highestBidIncreased(_id, msg.sender, msg.value);
    }
    // Bid using external balances and internal balances

    function bidWithBalance(uint256 _id, uint256 _amount)
        external
        payable
        auctionAvailable(_id)
        notAuctionOwner(_id)
        timeSchedule(_id)
        bidLower(_id, _amount)
        bidGapHigh(_id, _amount)
        startBidding(_id, _amount)
        penaltyProtect
    {
        require(_amount <= balances[msg.sender], "Insufficient Balance");

        balances[msg.sender] -= _amount;

        if ((listAuctions[_id].highestBid < (msg.value + _amount)) && (listAuctions[_id].highestBid != 0)) {
            balances[listAuctions[_id].highestBidder] += listAuctions[_id].highestBid;
        }
        listAuctions[_id].highestBidder = msg.sender;
        listAuctions[_id].highestBid = msg.value + _amount;
        emit highestBidIncreased(_id, msg.sender, msg.value + _amount);
    }
    // Withdraw balance from contract with protected user from penalty

    function withdraw(uint256 _amount) external penaltyProtect {
        if (_amount > 0 && _amount <= balances[msg.sender]) {
            balances[msg.sender] -= _amount;
            (bool sent,) = (msg.sender).call{value: _amount}("");
            require(sent, "Failed to send Ether");
            // emit
            emit withdrawBalance(msg.sender, _amount);
        } else {
            revert("Failed to send Ether");
        }
    }
    // End auction can happen when seller/buyer do this

    function endAuction(uint256 _id) external auctionAvailable(_id) {
        require(
            msg.sender == listAuctions[_id].seller || msg.sender == listAuctions[_id].highestBidder,
            "Only the auction owner/highest bidder can end the auction."
        );
        require(block.timestamp > listAuctions[_id].endDate, "Auction is still ongoing.");
        require(listAuctions[_id].highestBidder != address(0), "Nobody bid here");
        require(!listAuctions[_id].isEnded, "Auction end has already been called.");

        listAuctions[_id].isEnded = true;
        uint256 highestBid = listAuctions[_id].highestBid;
        listAuctions[_id].highestBid = 0;

        winnerAuction[_id] = WinnerApproval({
            buyer: listAuctions[_id].highestBidder,
            seller: listAuctions[_id].seller,
            buyerApproval: false,
            sellerApproval: false,
            isFinished: false,
            finalBid: highestBid,
            pendingShip: 0,
            approvalCreated: block.timestamp
        });
        // move to winnerAuction[id].finalBid
        emit auctionEnded(_id, listAuctions[_id].highestBidder, highestBid);
    }
    // Buyer approve winnerAuction

    function buyerApproval(uint256 _id) external {
        require(listAuctions[_id].isEnded, "Auction not ended");
        require(winnerAuction[_id].buyer == msg.sender, "Not authorized");

        winnerAuction[_id].buyerApproval = true;
    }
    // Seller approve winnerAuction

    function approval(uint256 _id, uint256 _pendingShip) external {
        require(listAuctions[_id].isEnded, "Auction not ended");
        require(winnerAuction[_id].seller == msg.sender, "Not authorized");
        /*
         *
         * Exact 91,32 days, most tolerate whether cross maritime shipping order,
         * sources by journal https://www.inderscienceonline.com/doi/pdf/10.1504/IJSTL.2018.088322
         *
         */
        uint256 threeMonths = 7889229;

        winnerAuction[_id].sellerApproval = true;

        // Checking pending shipping less than nowadays, too keep secure the transaction
        uint256 tempPendingShip = _pendingShip < block.timestamp ? block.timestamp : _pendingShip;
        // Checking pending shipping more than 3 months, too keep secure the transaction
        uint256 finalPendingShip =
            tempPendingShip > (block.timestamp + threeMonths) ? (block.timestamp + threeMonths) : tempPendingShip;
        // Default, if seller approving more than
        winnerAuction[_id].pendingShip = finalPendingShip;
    }
    //Both of seller and buyer, approve, then between user or buyer can do this function to transfer auction's balance to seller

    function finishAuction(uint256 _id) external {
        require(winnerAuction[_id].pendingShip < block.timestamp, "Auction not finished shipping");
        require(winnerAuction[_id].sellerApproval && winnerAuction[_id].buyerApproval, "Both of them must aprrove");
        require(!winnerAuction[_id].isFinished, "Auction finished");

        winnerAuction[_id].isFinished = true;
        uint256 sendBalance = winnerAuction[_id].finalBid;
        winnerAuction[_id].finalBid = 0;
        balances[winnerAuction[id].seller] += sendBalance;
    }
    //if seller no verify the transaction, bid refund to user

    function refundWhenSellerNoAction(uint256 _id) external {
        require(winnerAuction[_id].buyer == msg.sender, "Not authorized");
        require(
            (block.timestamp > (winnerAuction[_id].approvalCreated + 604800))
                && (winnerAuction[_id].approvalCreated != 0),
            "You can refund if theres no action more than a week"
        );
        require(!winnerAuction[_id].sellerApproval, "Seller has been approve");

        winnerAuction[_id].isFinished = true;
        uint256 sendBalance = winnerAuction[_id].finalBid;
        winnerAuction[_id].finalBid = 0;
        balances[winnerAuction[id].buyer] += sendBalance;

        emit refundToBuyer(winnerAuction[_id].buyer, winnerAuction[_id].seller, sendBalance);
    }

    // Owner & Admin area
    function ownerForceApprove(uint256 _id, address _user, bool _approve) external onlyOwner {
        if (winnerAuction[_id].buyer == _user) {
            winnerAuction[_id].buyerApproval = _approve;
        } else if (winnerAuction[_id].seller == _user) {
            winnerAuction[_id].sellerApproval = _approve;
        }
    }

    function ownerGivePenalty(address _user) external onlyOwner {
        penalty[_user] = true;
    }

    function ownerRemovePenalty(address _user) external onlyOwner {
        penalty[_user] = false;
    }

    // Owner Area
    function ownerAddAdmin(address _admin) external {
        require(owner == msg.sender, "Not Authorized");
        admin[_admin] = true;
    }

    function ownerRemoveAdmin(address _admin) external {
        require(owner == msg.sender, "Not Authorized");
        admin[_admin] = false;
    }
}
