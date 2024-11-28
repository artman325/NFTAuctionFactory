pragma solidity >=0.8.0 <0.9.0;

//import "@intercoin/auction/contracts/interfaces/IAuction.sol";
import "./interfaces/IAuctionFactory.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@intercoin/nonfungibletokencontract/contracts/interfaces/INFTState.sol";

contract NFTAuctionFactory is Ownable {

    uint8 internal constant SERIES_SHIFT_BITS = 192; // 256 - 64

    error AuctionCreateFailed();
    error UnknownAuction(address auction);
    error WrongAuctionOwner(address auction, address owner);
    error WrongNftContractOwner(address nftContract, address owner);
    error NotAWinner(address auction, address owner);
    error WrongSeriesId(uint64 seriesId, uint256 tokenId);
    error WrongClaimInterval(address auction);

    address public auctionFactoryAddress;

    struct auctionInfo {
        address token;
        bool cancelable;
        uint64 startTime;
        uint64 endTime;
        uint64 claimPeriod;
        uint256 startingPrice;
        IAuction.Increase increase;
        uint32 maxWinners;
        //---------------------
        address nftcontract;
        uint64 winnerClaimInterval;
        uint64 seriesId;
        uint256[] tokensPerWinners;
        //-------
        bool exists;
    }

    mapping(address => auctionInfo) public auctions;
    mapping(address => address[]) public offchainWinners;
    
    /**
     * 
     * @param auctionFactoryAddressF auction factory address  for example 0x090101003c69e3E3D777Db1EAb500BDC74469fA6 on 1.0.0
     * used to produce auction
     */
    constructor(
        address auctionFactoryAddressF
    ) 
    {
        auctionFactoryAddress = auctionFactoryAddressF;
    }

    /**
     * 
     * @param token address of erc20 token which using when user bid and charged by factory.
     * @param cancelable can Auction be cancelled or no
     * @param startTime auction start time
     * @param endTime auction end time
     * @param startingPrice starting price 
     * @param increase incresetuple [amount, bidsCount, canBidAbove] how much will the price increase `amount` after `bidsCount` bids happens
     * @param maxWinners maximum winners
     * -----------------------
     * @param nftcontract nft contract which supports Series, for example from nonefungibletokencontract repo
     * @param winnerClaimInterval winners can choose tokenid in claim method. 
     * Mean after endTime 1st winner can claim and choose token from series, after `winnerClaimInterval` 2nd winner can choose and so on
     * @param seriesId seriesId specify seriesId to prevent claim tokens between auction
     * @param tokensPerWinners optional parameter specifying how much tokens winners can claim.
     * Can be empty - when 1 token per winner, or like this [3,2,1,1,1,1,1]. be sure length should be equal `maxWinners`
     */
    function produceAuction(
        address token,
        bool cancelable,
        uint64 startTime,
        uint64 endTime,
        uint64 claimPeriod,
        uint256 startingPrice,
        IAuction.Increase memory increase,
        uint32 maxWinners,
        //---------------------
        address nftcontract,
        uint64 winnerClaimInterval,
        uint64 seriesId,
        uint256[] memory tokensPerWinners
    ) 
        public
    {
        requireOwnerNftContract(nftcontract, _msgSender()); 

        address auction = IAuctionFactory(auctionFactoryAddress).produceAuction(
            token,
            cancelable,
            startTime,
            endTime,
            claimPeriod,
            startingPrice,
            increase,
            maxWinners
        );

        if (auction == address(0)) {
            revert AuctionCreateFailed();
        }
        
        auctions[auction] = auctionInfo({
            //foo:1, fighter:2
            token: token,
            cancelable: cancelable,
            startTime: startTime,
            endTime: endTime,
            claimPeriod: claimPeriod,
            startingPrice: startingPrice,
            increase: increase,
            maxWinners: maxWinners,
            //---------------------
            nftcontract: nftcontract,
            winnerClaimInterval: winnerClaimInterval,
            seriesId: seriesId,
            tokensPerWinners: tokensPerWinners,
            exists: true
        });

        Ownable(auction).transferOwnership(msg.sender);

    }

    /**
     * added offchain winner
     * there are simple logic "last added offchainwinner go first"
     * after offchain winners takes from auction
     * 
     * @param auctionAddress auction
     * @param winner winner 
     */
    function addOffchainWinner(
        address auctionAddress,
        address winner
    ) 
        public 
        onlyOwner
    {
        offchainWinners[auctionAddress].push(winner);
    }

    function claim(
        address auctionAddress, 
        uint256 tokenId
    ) 
        public
    {
        address sender = _msgSender();
        
        uint256[] memory tokenIds = new uint256[](1);
        address[] memory addresses = new address[](1);

        tokenIds[0] = tokenId;
        addresses[0] = _msgSender();

        claimValidate(auctionAddress, sender, tokenIds);

        INFTState(auctions[auctionAddress].nftcontract).mintAndDistribute(tokenIds, addresses);

    }

    function claim(
        address auctionAddress, 
        uint256[] memory tokenIds
    )
        public
    {
        address sender = _msgSender();
        
        address[] memory addresses = new address[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            addresses[i] = sender;
        }

        claimValidate(auctionAddress, sender, tokenIds);

        INFTState(auctions[auctionAddress].nftcontract).mintAndDistribute(tokenIds, addresses);
    }

    
    /// internal section

    function claimValidate(
        address auctionAddress, 
        address sender,
        uint256[] memory tokenIds

    )
        internal 
    {
        uint256 orderInClaim = requireWinner(auctionAddress, sender);

        if (auctions[auctionAddress].endTime + orderInClaim*auctions[auctionAddress].winnerClaimInterval < block.timestamp) {
            revert WrongClaimInterval(auctionAddress);
        }

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint64 seriesId = getSeriesId(tokenIds[i]);
            if (seriesId != auctions[auctionAddress].seriesId) {
                revert WrongSeriesId(seriesId, tokenIds[i]);
            }
        }

    }

    function getSeriesId(uint256 tokenId) internal pure returns (uint64) {
        return uint64(tokenId >> SERIES_SHIFT_BITS);
    }

    function requireWinner(
        address auctionAddress,
        address sender
    )
        internal
        returns(uint256 orderInClaim)
    {
        // check it is our auction
        requireExistsAuction(auctionAddress);

        orderInClaim = orderClaim(auctionAddress, sender);
        if (orderInClaim == 0) {
            revert NotAWinner(auctionAddress, sender);
        }

    }
    

    /**
     * @dev it's not index in auction winning 
     * 
     * @param auction auction address
     * @param sender sender
     * 
     * @return number in order. zero mean it is not in order
     */
    function orderClaim(
        address auction,
        address sender
    )
        internal 
        view
        returns(uint256)
    {

        uint256 totalOffchainWinners = offchainWinners[auction].length;
        //find in offchain list. be sure then not exceed maxWinners
        uint256 totalInOffchain = auctions[auction].maxWinners < totalOffchainWinners ? auctions[auction].maxWinners : totalOffchainWinners;
        for (uint256 i = 0; i < totalInOffchain; i++) {
            if (offchainWinners[auction][i] == sender) {
                return i+1;
            }
        }
        // find in onchain list
        if (auctions[auction].maxWinners > totalInOffchain) {
            // function winning() external view returns (BidStruct[] memory result);
            // struct BidStruct {
            //     address bidder;
            //     uint256 amount;
            // }
            IAuction.BidStruct[] memory result = IAuction(auction).winning();

            uint256 totalOnchainWinners = auctions[auction].maxWinners - totalInOffchain;
            uint256 totalInOnchain = result.length > totalOnchainWinners ? totalOnchainWinners : result.length;
            for (uint256 i = 0; i < totalInOnchain; i++) {
                if (result[i].bidder == sender) {
                    return totalInOffchain+1+i;
                }
            }
        }

        return 0;
    }

    function requireOwnerNftContract(
        address nftcontract,
        address sender
    )
        internal
    {
        
        address auctionOwner = Ownable(nftcontract).owner();
        if (auctionOwner != sender) {
          revert WrongNftContractOwner(nftcontract, sender);
        }
    }

    function requireOwnerAuction(
        address auction,
        address sender
    )
        internal
    {
        // check it is our auction
        requireExistsAuction(auction);
        
        address auctionOwner = Ownable(auction).owner();
        if (auctionOwner != sender) {
          revert WrongAuctionOwner(auction, sender);
        }
    }

    function requireExistsAuction(
        address auction
    )
        internal
    {
        // check it is our auction
        if (auctions[auction].exists == false) {
            revert UnknownAuction(auction);
        }
        
    }

}