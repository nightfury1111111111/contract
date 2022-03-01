pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract NFTAuction {
    mapping(uint256 => Auction) public nftContractAuctions;
    mapping(address => uint256) failedTransferCredits; //return the money to bidders

    struct Auction {
        //map token ID to
        uint32 bidIncreasePercentage;
        uint32 auctionBidPeriod; //Increments the length of time the auction is open in which a new bid can be made after each bid.
        uint64 auctionEnd;
        uint128 minPrice;
        uint128 buyNowPrice;
        uint128 nftHighestBid;
        address nftHighestBidder;
        address nftSeller;
        address nftRecipient; //The bidder can specify a recipient for the NFT if their bid is successful.
        address ERC20Token; // The seller can specify an ERC20 token that can be used to bid or purchase the NFT.
        address[] feeRecipients;
        uint32[] feePercentages;
    }

    //Default values that are used if not specified by the NFT seller.
    uint32 public defaultBidIncreasePercentage;
    uint32 public minimumSettableIncreasePercentage;
    uint32 public defaultAuctionBidPeriod;

    //NFT token contract address
    address public _nftContractAddress;

    /*╔═════════════════════════════╗
      ║           EVENTS            ║
      ╚═════════════════════════════╝*/
    event NftAuctionCreated(
        uint256 tokenId,
        address nftSeller,
        address erc20Token,
        uint128 minPrice,
        uint128 buyNowPrice,
        uint32 auctionBidPeriod,
        uint32 bidIncreasePercentage,
        address[] feeRecipients,
        uint32[] feePercentages
    );

    event NFTTransferredAndSellerPaid(
        uint256 tokenId,
        address nftSeller,
        uint128 nftHighestBid,
        address nftHighestBidder,
        address nftRecipient
    );

    event AuctionPeriodUpdated(uint256 tokenId, uint64 auctionEndPeriod);

    event SaleCreated(
        uint256 tokenId,
        address nftSeller,
        address erc20Token,
        uint128 buyNowPrice,
        address whitelistedBuyer,
        address[] feeRecipients,
        uint32[] feePercentages
    );

    event BidMade(
        uint256 tokenId,
        address bidder,
        uint256 ethAmount,
        address erc20Token,
        uint256 tokenAmount
    );

    event AuctionSettled(uint256 tokenId, address auctionSettler);

    event AuctionWithdrawn(uint256 tokenId, address nftOwner);

    event BidWithdrawn(uint256 tokenId, address highestBidder);

    event HighestBidTaken(uint256 tokenId);

    /**********************************/
    /*╔═════════════════════════════╗
      ║             END             ║
      ║            EVENTS           ║
      ╚═════════════════════════════╝*/
    /**********************************/

    /*╔═════════════════════════════╗
      ║          MODIFIERS          ║
      ╚═════════════════════════════╝*/
    modifier isAuctionNotStartedByOwner(uint256 _tokenId) {
        require(
            nftContractAuctions[_tokenId].nftSeller != msg.sender,
            "Auction already started by owner"
        );

        if (nftContractAuctions[_tokenId].nftSeller != address(0)) {
            require(
                msg.sender == IERC721(_nftContractAddress).ownerOf(_tokenId),
                "Sender doesn't own NFT"
            );

            _resetAuction(_tokenId);
        }
        _;
    }

    modifier auctionOngoing(uint256 _tokenId) {
        require(_isAuctionOngoing(_tokenId), "Auction has ended");
        _;
    }

    modifier priceGreaterThanZero(uint256 _price) {
        require(_price > 0, "Price cannot be 0");
        _;
    }

    modifier notNftSeller(uint256 _tokenId) {
        require(
            msg.sender != nftContractAuctions[_tokenId].nftSeller,
            "Owner cannot bid on own NFT"
        );
        _;
    }

    modifier onlyNftSeller(uint256 _tokenId) {
        require(
            msg.sender == nftContractAuctions[_tokenId].nftSeller,
            "Only nft seller"
        );
        _;
    }

    modifier bidAmountMeetsBidRequirements(
        uint256 _tokenId,
        uint128 _tokenAmount
    ) {
        require(
            _doesBidMeetBidRequirements(_tokenId, _tokenAmount),
            "Not enough funds to bid on NFT"
        );
        _;
    }

    /*
     * Payment is accepted if the payment is made in the ERC20 token or ETH specified by the seller.
     * Early bids on NFTs not yet up for auction must be made in ETH.
     */
    modifier paymentAccepted(
        uint256 _tokenId,
        address _erc20Token,
        uint128 _tokenAmount
    ) {
        require(
            _isPaymentAccepted(_tokenId, _erc20Token, _tokenAmount),
            "Bid to be in specified ERC20/Eth"
        );
        _;
    }

    modifier isAuctionOver(uint256 _tokenId) {
        require(!_isAuctionOngoing(_tokenId), "Auction is not yet over");
        _;
    }

    modifier notZeroAddress(address _address) {
        require(_address != address(0), "Cannot specify 0 address");
        _;
    }

    modifier isFeePercentagesLessThanMaximum(uint32[] memory _feePercentages) {
        uint32 totalPercent;
        for (uint256 i = 0; i < _feePercentages.length; i++) {
            totalPercent = totalPercent + _feePercentages[i];
        }
        require(totalPercent <= 10000, "Fee percentages exceed maximum");
        _;
    }

    modifier correctFeeRecipientsAndPercentages(
        uint256 _recipientsLength,
        uint256 _percentagesLength
    ) {
        require(
            _recipientsLength == _percentagesLength,
            "Recipients != percentages"
        );
        _;
    }

    modifier isNotASale(uint256 _tokenId) {
        require(!_isASale(_tokenId), "Not applicable for a sale");
        _;
    }

    modifier minimumBidNotMade(uint256 _tokenId) {
        require(
            !_isMinimumBidMade(_tokenId),
            "The auction has a valid bid made"
        );
        _;
    }

    // constructor
    constructor(address nftContractAddress) {
        defaultBidIncreasePercentage = 100;
        defaultAuctionBidPeriod = 86400; //1 day
        minimumSettableIncreasePercentage = 100;
        _nftContractAddress = nftContractAddress;
    }

    /*╔══════════════════════════════╗
      ║    AUCTION CHECK FUNCTIONS   ║
      ╚══════════════════════════════╝*/
    function _isAuctionOngoing(uint256 _tokenId) internal view returns (bool) {
        uint64 auctionEndTimestamp = nftContractAuctions[_tokenId].auctionEnd;
        //if the auctionEnd is set to 0, the auction is technically on-going, however
        //the minimum bid price (minPrice) has not yet been met.
        return (auctionEndTimestamp == 0 ||
            block.timestamp < auctionEndTimestamp);
    }

    /*
     * Check that a bid is applicable for the purchase of the NFT.
     * In the case of a sale: the bid needs to meet the buyNowPrice.
     * In the case of an auction: the bid needs to be a % higher than the previous bid.
     */
    function _doesBidMeetBidRequirements(uint256 _tokenId, uint128 _tokenAmount)
        internal
        view
        returns (bool)
    {
        uint128 buyNowPrice = nftContractAuctions[_tokenId].buyNowPrice;
        //if buyNowPrice is met, ignore increase percentage
        if (
            buyNowPrice > 0 &&
            (msg.value >= buyNowPrice || _tokenAmount >= buyNowPrice)
        ) {
            return true;
        }
        //if the NFT is up for auction, the bid needs to be a % higher than the previous bid
        uint256 bidIncreaseAmount = (nftContractAuctions[_tokenId]
            .nftHighestBid * (10000 + _getBidIncreasePercentage(_tokenId))) /
            10000;
        return (msg.value >= bidIncreaseAmount ||
            _tokenAmount >= bidIncreaseAmount);
    }

    /**
     * Payment is accepted in the following scenarios:
     * (1) Auction already created - can accept ETH or Specified Token
     *  --------> Cannot bid with ETH & an ERC20 Token together in any circumstance<------
     * (2) Auction not created - only ETH accepted (cannot early bid with an ERC20 Token
     * (3) Cannot make a zero bid (no ETH or Token amount)
     */
    function _isPaymentAccepted(
        uint256 _tokenId,
        address _bidERC20Token,
        uint128 _tokenAmount
    ) internal view returns (bool) {
        address auctionERC20Token = nftContractAuctions[_tokenId].ERC20Token;
        if (_isERC20Auction(auctionERC20Token)) {
            return
                msg.value == 0 &&
                auctionERC20Token == _bidERC20Token &&
                _tokenAmount > 0;
        } else {
            return
                msg.value != 0 &&
                _bidERC20Token == address(0) &&
                _tokenAmount == 0;
        }
    }

    function _isERC20Auction(address _auctionERC20Token)
        internal
        pure
        returns (bool)
    {
        return _auctionERC20Token != address(0);
    }

    /*
     * An NFT is up for sale if the buyNowPrice is set, but the minPrice is not set.
     * Therefore the only way to conclude the NFT sale is to meet the buyNowPrice.
     */
    function _isASale(uint256 _tokenId) internal view returns (bool) {
        return (nftContractAuctions[_tokenId].buyNowPrice > 0 &&
            nftContractAuctions[_tokenId].minPrice == 0);
    }

    /*
     * If the buy now price is set by the seller, check that the highest bid meets that price.
     */
    function _isBuyNowPriceMet(uint256 _tokenId) internal view returns (bool) {
        uint128 buyNowPrice = nftContractAuctions[_tokenId].buyNowPrice;
        return
            buyNowPrice > 0 &&
            nftContractAuctions[_tokenId].nftHighestBid >= buyNowPrice;
    }

    /*
     * Returns the percentage of the total bid (used to calculate fee payments)
     */
    function _getPortionOfBid(uint256 _totalBid, uint256 _percentage)
        internal
        pure
        returns (uint256)
    {
        return (_totalBid * (_percentage)) / 10000;
    }

    /*
     *if the minPrice is set by the seller, check that the highest bid meets or exceeds that price.
     */
    function _isMinimumBidMade(uint256 _tokenId) internal view returns (bool) {
        uint128 minPrice = nftContractAuctions[_tokenId].minPrice;
        return
            minPrice > 0 &&
            (nftContractAuctions[_tokenId].nftHighestBid >= minPrice);
    }

    /*
     * Check if a bid has been made. This is applicable in the early bid scenario
     * to ensure that if an auction is created after an early bid, the auction
     * begins appropriately or is settled if the buy now price is met.
     */
    function _isABidMade(uint256 _tokenId) internal view returns (bool) {
        return (nftContractAuctions[_tokenId].nftHighestBid > 0);
    }

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║    AUCTION CHECK FUNCTIONS   ║
      ╚══════════════════════════════╝*/
    /**********************************/
    /*╔══════════════════════════════╗
      ║    DEFAULT GETTER FUNCTIONS  ║
      ╚══════════════════════════════╝*/
    /*****************************************************************
     * These functions check if the applicable auction parameter has *
     * been set by the NFT seller. If not, return the default value. *
     *****************************************************************/

    function _getBidIncreasePercentage(uint256 _tokenId)
        internal
        view
        returns (uint32)
    {
        uint32 bidIncreasePercentage = nftContractAuctions[_tokenId]
            .bidIncreasePercentage;

        if (bidIncreasePercentage == 0) {
            return defaultBidIncreasePercentage;
        } else {
            return bidIncreasePercentage;
        }
    }

    function _getAuctionBidPeriod(uint256 _tokenId)
        internal
        view
        returns (uint32)
    {
        uint32 auctionBidPeriod = nftContractAuctions[_tokenId]
            .auctionBidPeriod;

        if (auctionBidPeriod == 0) {
            return defaultAuctionBidPeriod;
        } else {
            return auctionBidPeriod;
        }
    }

    /*
     * The default value for the NFT recipient is the highest bidder
     */
    function _getNftRecipient(uint256 _tokenId)
        internal
        view
        returns (address)
    {
        address nftRecipient = nftContractAuctions[_tokenId].nftRecipient;

        if (nftRecipient == address(0)) {
            return nftContractAuctions[_tokenId].nftHighestBidder;
        } else {
            return nftRecipient;
        }
    }

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║    DEFAULT GETTER FUNCTIONS  ║
      ╚══════════════════════════════╝*/
    /**********************************/

    /*╔══════════════════════════════╗
      ║  TRANSFER NFTS TO CONTRACT   ║
      ╚══════════════════════════════╝*/

    function _transferNftToAuctionContract(uint256 _tokenId) internal {
        address _nftSeller = nftContractAuctions[_tokenId].nftSeller;
        if (IERC721(_nftContractAddress).ownerOf(_tokenId) == _nftSeller) {
            IERC721(_nftContractAddress).transferFrom(
                _nftSeller,
                address(this),
                _tokenId
            );
            require(
                IERC721(_nftContractAddress).ownerOf(_tokenId) == address(this),
                "nft transfer failed"
            );
        } else {
            require(
                IERC721(_nftContractAddress).ownerOf(_tokenId) == address(this),
                "Seller doesn't own NFT"
            );
        }
    }

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║  TRANSFER NFTS TO CONTRACT   ║
      ╚══════════════════════════════╝*/
    /**********************************/

    /*╔══════════════════════════════╗
      ║       AUCTION CREATION       ║
      ╚══════════════════════════════╝*/

    /**
     * Setup parameters applicable to all auctions and whitelised sales:
     * -> ERC20 Token for payment (if specified by the seller) : _erc20Token
     * -> minimum price : _minPrice
     * -> buy now price : _buyNowPrice
     * -> the nft seller: msg.sender
     * -> The fee recipients & their respective percentages for a sucessful auction/sale
     */
    function _setupAuction(
        uint256 _tokenId,
        address _erc20Token,
        uint128 _minPrice,
        uint128 _buyNowPrice,
        address[] memory _feeRecipients,
        uint32[] memory _feePercentages
    )
        internal
        correctFeeRecipientsAndPercentages(
            _feeRecipients.length,
            _feePercentages.length
        )
        isFeePercentagesLessThanMaximum(_feePercentages)
    {
        if (_erc20Token != address(0)) {
            nftContractAuctions[_tokenId].ERC20Token = _erc20Token;
        }
        nftContractAuctions[_tokenId].feeRecipients = _feeRecipients;
        nftContractAuctions[_tokenId].feePercentages = _feePercentages;
        nftContractAuctions[_tokenId].buyNowPrice = _buyNowPrice;
        nftContractAuctions[_tokenId].minPrice = _minPrice;
        nftContractAuctions[_tokenId].nftSeller = msg.sender;
    }

    function _createNewNftAuction(
        uint256 _tokenId,
        address _erc20Token,
        uint128 _minPrice,
        uint128 _buyNowPrice,
        address[] memory _feeRecipients,
        uint32[] memory _feePercentages
    ) internal {
        // Sending the NFT to this contract
        _setupAuction(
            _tokenId,
            _erc20Token,
            _minPrice,
            _buyNowPrice,
            _feeRecipients,
            _feePercentages
        );
        emit NftAuctionCreated(
            _tokenId,
            msg.sender,
            _erc20Token,
            _minPrice,
            _buyNowPrice,
            _getAuctionBidPeriod(_tokenId),
            _getBidIncreasePercentage(_tokenId),
            _feeRecipients,
            _feePercentages
        );
        _updateOngoingAuction(_tokenId);
    }

    function createNewNftAuction(
        uint256 _tokenId,
        address _erc20Token,
        uint128 _minPrice,
        uint128 _buyNowPrice,
        uint32 _auctionBidPeriod, //this is the time that the auction lasts until another bid occurs
        uint32 _bidIncreasePercentage,
        address[] memory _feeRecipients,
        uint32[] memory _feePercentages
    )
        external
        isAuctionNotStartedByOwner(_tokenId)
        priceGreaterThanZero(_minPrice)
    {
        nftContractAuctions[_tokenId].auctionBidPeriod = _auctionBidPeriod;
        nftContractAuctions[_tokenId]
            .bidIncreasePercentage = _bidIncreasePercentage;
        _createNewNftAuction(
            _tokenId,
            _erc20Token,
            _minPrice,
            _buyNowPrice,
            _feeRecipients,
            _feePercentages
        );
    }

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║       AUCTION CREATION       ║
      ╚══════════════════════════════╝*/
    /**********************************/

    /*╔══════════════════════════════╗
      ║            SALES             ║
      ╚══════════════════════════════╝*/

    /********************************************************************
     * Allows for a standard sale mechanism where the NFT seller can    *
     * can select an address to be whitelisted. This address is then    *
     * allowed to make a bid on the NFT. No other address can bid on    *
     * the NFT.                                                         *
     ********************************************************************/
    function _setupSale(
        uint256 _tokenId,
        address _erc20Token,
        uint128 _buyNowPrice,
        address _whitelistedBuyer,
        address[] memory _feeRecipients,
        uint32[] memory _feePercentages
    )
        internal
        correctFeeRecipientsAndPercentages(
            _feeRecipients.length,
            _feePercentages.length
        )
        isFeePercentagesLessThanMaximum(_feePercentages)
    {
        if (_erc20Token != address(0)) {
            nftContractAuctions[_tokenId].ERC20Token = _erc20Token;
        }
        nftContractAuctions[_tokenId].feeRecipients = _feeRecipients;
        nftContractAuctions[_tokenId].feePercentages = _feePercentages;
        nftContractAuctions[_tokenId].buyNowPrice = _buyNowPrice;
        nftContractAuctions[_tokenId].nftSeller = msg.sender;
    }

    function createSale(
        uint256 _tokenId,
        address _erc20Token,
        uint128 _buyNowPrice,
        address _whitelistedBuyer,
        address[] memory _feeRecipients,
        uint32[] memory _feePercentages
    )
        external
        isAuctionNotStartedByOwner(_tokenId)
        priceGreaterThanZero(_buyNowPrice)
    {
        //min price = 0
        _setupSale(
            _tokenId,
            _erc20Token,
            _buyNowPrice,
            _whitelistedBuyer,
            _feeRecipients,
            _feePercentages
        );

        emit SaleCreated(
            _tokenId,
            msg.sender,
            _erc20Token,
            _buyNowPrice,
            _whitelistedBuyer,
            _feeRecipients,
            _feePercentages
        );
        //check if buyNowPrice is meet and conclude sale, otherwise reverse the early bid
        if (_isABidMade(_tokenId)) {
            if (_isBuyNowPriceMet(_tokenId)) {
                _transferNftToAuctionContract(_tokenId);
                _transferNftAndPaySeller(_tokenId);
            }
        }
    }

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║            SALES             ║
      ╚══════════════════════════════╝*/
    /**********************************/

    /*╔═════════════════════════════╗
      ║        BID FUNCTIONS        ║
      ╚═════════════════════════════╝*/

    /********************************************************************
     * Make bids with ETH or an ERC20 Token specified by the NFT seller.*
     * Additionally, a buyer can pay the asking price to conclude a sale*
     * of an NFT.                                                      *
     ********************************************************************/

    function _makeBid(
        uint256 _tokenId,
        address _erc20Token,
        uint128 _tokenAmount
    )
        internal
        notNftSeller(_tokenId)
        paymentAccepted(_tokenId, _erc20Token, _tokenAmount)
        bidAmountMeetsBidRequirements(_tokenId, _tokenAmount)
    {
        _reversePreviousBidAndUpdateHighestBid(_tokenId, _tokenAmount);
        emit BidMade(
            _tokenId,
            msg.sender,
            msg.value,
            _erc20Token,
            _tokenAmount
        );
        _updateOngoingAuction(_tokenId);
    }

    function makeCustomBid(
        uint256 _tokenId,
        address _erc20Token,
        uint128 _tokenAmount,
        address _nftRecipient
    ) external payable auctionOngoing(_tokenId) notZeroAddress(_nftRecipient) {
        nftContractAuctions[_tokenId].nftRecipient = _nftRecipient;
        _makeBid(_tokenId, _erc20Token, _tokenAmount);
    }

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║        BID FUNCTIONS         ║
      ╚══════════════════════════════╝*/
    /**********************************/

    /*╔══════════════════════════════╗
      ║       UPDATE AUCTION         ║
      ╚══════════════════════════════╝*/

    /***************************************************************
     * Settle an auction or sale if the buyNowPrice is met or set  *
     *  auction period to begin if the minimum price has been met. *
     ***************************************************************/
    function _updateOngoingAuction(uint256 _tokenId) internal {
        if (_isBuyNowPriceMet(_tokenId)) {
            _transferNftToAuctionContract(_tokenId);
            _transferNftAndPaySeller(_tokenId);
            return;
        }
        //min price not set, nft not up for auction yet
        if (_isMinimumBidMade(_tokenId)) {
            _transferNftToAuctionContract(_tokenId);
            _updateAuctionEnd(_tokenId);
        }
    }

    function _updateAuctionEnd(uint256 _tokenId) internal {
        //the auction end is always set to now + the bid period
        nftContractAuctions[_tokenId].auctionEnd =
            _getAuctionBidPeriod(_tokenId) +
            uint64(block.timestamp);
        emit AuctionPeriodUpdated(
            _tokenId,
            nftContractAuctions[_tokenId].auctionEnd
        );
    }

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║       UPDATE AUCTION         ║
      ╚══════════════════════════════╝*/
    /**********************************/

    /*╔══════════════════════════════╗
      ║       RESET FUNCTIONS        ║
      ╚══════════════════════════════╝*/

    /*
     * Reset all auction related parameters for an NFT.
     * This effectively removes an EFT as an item up for auction
     */
    function _resetAuction(uint256 _tokenId) internal {
        nftContractAuctions[_tokenId].minPrice = 0;
        nftContractAuctions[_tokenId].buyNowPrice = 0;
        nftContractAuctions[_tokenId].auctionEnd = 0;
        nftContractAuctions[_tokenId].auctionBidPeriod = 0;
        nftContractAuctions[_tokenId].bidIncreasePercentage = 0;
        nftContractAuctions[_tokenId].nftSeller = address(0);
        nftContractAuctions[_tokenId].ERC20Token = address(0);
    }

    function _resetBids(uint256 _tokenId) internal {
        nftContractAuctions[_tokenId].nftHighestBidder = address(0);
        nftContractAuctions[_tokenId].nftHighestBid = 0;
        nftContractAuctions[_tokenId].nftRecipient = address(0);
    }

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║       RESET FUNCTIONS        ║
      ╚══════════════════════════════╝*/
    /**********************************/

    /*╔══════════════════════════════╗
      ║         UPDATE BIDS          ║
      ╚══════════════════════════════╝*/
    /******************************************************************
     * Internal functions that update bid parameters and reverse bids *
     * to ensure contract only holds the highest bid.                 *
     ******************************************************************/
    function _updateHighestBid(uint256 _tokenId, uint128 _tokenAmount)
        internal
    {
        address auctionERC20Token = nftContractAuctions[_tokenId].ERC20Token;
        if (_isERC20Auction(auctionERC20Token)) {
            IERC20(auctionERC20Token).transferFrom(
                msg.sender,
                address(this),
                _tokenAmount
            );
            nftContractAuctions[_tokenId].nftHighestBid = _tokenAmount;
        } else {
            nftContractAuctions[_tokenId].nftHighestBid = uint128(msg.value);
        }
        nftContractAuctions[_tokenId].nftHighestBidder = msg.sender;
    }

    function _reversePreviousBidAndUpdateHighestBid(
        uint256 _tokenId,
        uint128 _tokenAmount
    ) internal {
        address prevNftHighestBidder = nftContractAuctions[_tokenId]
            .nftHighestBidder;

        uint256 prevNftHighestBid = nftContractAuctions[_tokenId].nftHighestBid;
        _updateHighestBid(_tokenId, _tokenAmount);

        if (prevNftHighestBidder != address(0)) {
            _payout(_tokenId, prevNftHighestBidder, prevNftHighestBid);
        }
    }

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║         UPDATE BIDS          ║
      ╚══════════════════════════════╝*/
    /**********************************/

    /*╔══════════════════════════════╗
      ║  TRANSFER NFT & PAY SELLER   ║
      ╚══════════════════════════════╝*/
    function _transferNftAndPaySeller(uint256 _tokenId) internal {
        address _nftSeller = nftContractAuctions[_tokenId].nftSeller;
        address _nftHighestBidder = nftContractAuctions[_tokenId]
            .nftHighestBidder;
        address _nftRecipient = _getNftRecipient(_tokenId);
        uint128 _nftHighestBid = nftContractAuctions[_tokenId].nftHighestBid;
        _resetBids(_tokenId);

        _payFeesAndSeller(_tokenId, _nftSeller, _nftHighestBid);
        IERC721(_nftContractAddress).transferFrom(
            address(this),
            _nftRecipient,
            _tokenId
        );

        _resetAuction(_tokenId);
        emit NFTTransferredAndSellerPaid(
            _tokenId,
            _nftSeller,
            _nftHighestBid,
            _nftHighestBidder,
            _nftRecipient
        );
    }

    function _payFeesAndSeller(
        uint256 _tokenId,
        address _nftSeller,
        uint256 _highestBid
    ) internal {
        uint256 feesPaid;
        for (
            uint256 i = 0;
            i < nftContractAuctions[_tokenId].feeRecipients.length;
            i++
        ) {
            uint256 fee = _getPortionOfBid(
                _highestBid,
                nftContractAuctions[_tokenId].feePercentages[i]
            );
            feesPaid = feesPaid + fee;
            _payout(
                _tokenId,
                nftContractAuctions[_tokenId].feeRecipients[i],
                fee
            );
        }
        _payout(_tokenId, _nftSeller, (_highestBid - feesPaid));
    }

    function _payout(
        uint256 _tokenId,
        address _recipient,
        uint256 _amount
    ) internal {
        address auctionERC20Token = nftContractAuctions[_tokenId].ERC20Token;
        if (_isERC20Auction(auctionERC20Token)) {
            IERC20(auctionERC20Token).transfer(_recipient, _amount);
        } else {
            // attempt to send the funds to the recipient
            (bool success, ) = payable(_recipient).call{
                value: _amount,
                gas: 20000
            }("");
            // if it failed, update their credit balance so they can pull it later
            if (!success) {
                failedTransferCredits[_recipient] =
                    failedTransferCredits[_recipient] +
                    _amount;
            }
        }
    }

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║  TRANSFER NFT & PAY SELLER   ║
      ╚══════════════════════════════╝*/
    /**********************************/

    /*╔══════════════════════════════╗
      ║      SETTLE & WITHDRAW       ║
      ╚══════════════════════════════╝*/

    function settleAuction(uint256 _tokenId) external isAuctionOver(_tokenId) {
        _transferNftAndPaySeller(_tokenId);
        emit AuctionSettled(_tokenId, msg.sender);
    }

    function withdrawAuction(uint256 _tokenId) external {
        //only the NFT owner can prematurely close and auction
        require(
            IERC721(_nftContractAddress).ownerOf(_tokenId) == msg.sender,
            "Not NFT owner"
        );
        _resetAuction(_tokenId);
        emit AuctionWithdrawn(_tokenId, msg.sender);
    }

    function withdrawBid(uint256 _tokenId)
        external
        minimumBidNotMade(_tokenId)
    {
        address nftHighestBidder = nftContractAuctions[_tokenId]
            .nftHighestBidder;
        require(msg.sender == nftHighestBidder, "Cannot withdraw funds");

        uint128 nftHighestBid = nftContractAuctions[_tokenId].nftHighestBid;
        _resetBids(_tokenId);

        _payout(_tokenId, nftHighestBidder, nftHighestBid);

        emit BidWithdrawn(_tokenId, msg.sender);
    }

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║      SETTLE & WITHDRAW       ║
      ╚══════════════════════════════╝*/
    /**********************************/

    /*╔══════════════════════════════╗
      ║       UPDATE AUCTION         ║
      ╚══════════════════════════════╝*/

    /*
     * The NFT seller can opt to end an auction by taking the current highest bid.
     */
    function takeHighestBid(uint256 _tokenId) external onlyNftSeller(_tokenId) {
        require(_isABidMade(_tokenId), "cannot payout 0 bid");
        _transferNftToAuctionContract(_tokenId);
        _transferNftAndPaySeller(_tokenId);
        emit HighestBidTaken(_tokenId);
    }

    /*
     * Query the owner of an NFT deposited for auction
     */
    function ownerOfNFT(uint256 _tokenId) external view returns (address) {
        address nftSeller = nftContractAuctions[_tokenId].nftSeller;
        require(nftSeller != address(0), "NFT not deposited");

        return nftSeller;
    }

    /*
     * If the transfer of a bid has failed, allow the recipient to reclaim their amount later.
     */
    function withdrawAllFailedCredits() external {
        uint256 amount = failedTransferCredits[msg.sender];

        require(amount != 0, "no credits to withdraw");

        failedTransferCredits[msg.sender] = 0;

        (bool successfulWithdraw, ) = msg.sender.call{
            value: amount,
            gas: 20000
        }("");
        require(successfulWithdraw, "withdraw failed");
    }

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║       UPDATE AUCTION         ║
      ╚══════════════════════════════╝*/
    /**********************************/
}
