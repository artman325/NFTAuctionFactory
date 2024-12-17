// SPDX-License-Identifier: UNLICENSED
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

    // struct offchainBid {
    //     address bidder;
    //     uint256 amount;
    // }
    //mapping(address => offchainBid[]) public offchainBidders;
    mapping(address => mapping(address => uint256)) public offchainBidders;
    mapping(address => mapping(address => address)) private _nextOffchainBidder;
    mapping(address => uint256) public offchainSizeList;
    
    address constant GUARD = address(1);
    
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

        _nextOffchainBidder[auction][GUARD] = GUARD;
    }

    /**
     * added offchain bid
     * there are simple logic "adding offchain bidder"
     * offchain and onchain bidder will intersect on auction
     * 
     * @param auctionAddress auction
     * @param winner winner 
     * @param amount bidamount
     */
    function addOffchainBid(
        address auctionAddress,
        address winner,
        uint256 amount
    ) 
        public 
        onlyOwner
    {
        _addOffchainBid(auctionAddress, winner, amount);
        //offchainWinners[auctionAddress].push(winner);
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
        view
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
        view
        returns(uint256 orderInClaim)
    {
        // check it is our auction
        requireExistsAuction(auctionAddress);

        orderInClaim = orderClaim(auctionAddress, sender);
        if (orderInClaim == 0) {
            revert NotAWinner(auctionAddress, sender);
        }

    }
    
    function findInOffchain(
        address auction,
        address addrIndex, 
        uint256 compareAmount
    )
        internal 
        view 
        returns(address nextAddrIndex)
    {

    }
    function findInOnchain(
        uint256 index, 
        uint256 compareAmount,
        IAuction.BidStruct[] memory result
    )
        internal 
        view 
        returns(uint256 nextIndex)
    {

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
        IAuction.BidStruct[] memory result = IAuction(auction).winning();

        uint256 orderInClaim = 0;

        address offchainIndex = _nextOffchainBidder[auction][GUARD];
        uint256 onchainIndex = 0;

        while (orderInClaim <= auctions[auction].maxWinners) {
            
            //get first item from offchain list
            uint256 amountFromOffchainList = offchainBidders[auction][offchainIndex];
            //get first item from onchain list
            uint256 amountFromOnchainList = onchainIndex >= result.length ? 0 : result[onchainIndex].amount;
            // compare which bigger
            // Keep in mind that indexes can exceed the bounds of the array size.  
            // We have removed these checks.  
            // In any cases, the variables `amountFromOffchainList` or `amountFromOnchainList` will set to zero.
            if (amountFromOffchainList == amountFromOnchainList && amountFromOffchainList == 0) {
                return 0;
            } else if (amountFromOffchainList >= amountFromOnchainList) {
                if (offchainIndex == sender) {
                    return orderInClaim;
                }
                offchainIndex = _nextOffchainBidder[auction][offchainIndex];
            } else {
                if (result[onchainIndex].bidder == sender) {
                    return orderInClaim;
                }
                onchainIndex++;
            }
            
            orderInClaim ++;
        }
        return 0;
        
        // uint256 totalOffchainWinners = offchainWinners[auction].length;
        // //find in offchain list. be sure then not exceed maxWinners
        // uint256 totalInOffchain = auctions[auction].maxWinners < totalOffchainWinners ? auctions[auction].maxWinners : totalOffchainWinners;
        // for (uint256 i = 0; i < totalInOffchain; i++) {
        //     if (offchainWinners[auction][i] == sender) {
        //         return i+1;
        //     }
        // }
        // // find in onchain list
        // if (auctions[auction].maxWinners > totalInOffchain) {
        //     // function winning() external view returns (BidStruct[] memory result);
        //     // struct BidStruct {
        //     //     address bidder;
        //     //     uint256 amount;
        //     // }
        //     IAuction.BidStruct[] memory result = IAuction(auction).winning();

        //     uint256 totalOnchainWinners = auctions[auction].maxWinners - totalInOffchain;
        //     uint256 totalInOnchain = result.length > totalOnchainWinners ? totalOnchainWinners : result.length;
        //     for (uint256 i = 0; i < totalInOnchain; i++) {
        //         if (result[i].bidder == sender) {
        //             return totalInOffchain+1+i;
        //         }
        //     }
        // }

        // return 0;
    }

    function requireOwnerNftContract(
        address nftcontract,
        address sender
    )
        internal
        view
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
        view
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
        view
    {
        // check it is our auction
        if (auctions[auction].exists == false) {
            revert UnknownAuction(auction);
        }
        
    }

    /**
     * function for verify that value is between left and right address.
     * @param auctionAddress auctionAddress
     * @param prev prev bidder
     * @param newAmount  new amount 
     * @param next next bidder
     * @return bool return true if left_value ≥ new_amount > right_value (here desc order)
     */
    function _verifyIndex(
        address auctionAddress,
        address prev, 
        uint256 newAmount, 
        address next
    ) 
        internal 
        view 
        returns(bool) 
    {
        return (prev == GUARD || offchainBidders[auctionAddress][prev] >= newAmount) &&
               (next == GUARD || newAmount > offchainBidders[auctionAddress][next]);
    }

    /**
     * helper function to find address that new value should insert after it.
     * @param newAmount new amount
     */
    function _findIndex(
        address auctionAddress,
        uint256 newAmount
    )
        internal
        view
        returns(address )
    {
        address newBidder = GUARD;
        while(true) {
            if (_verifyIndex(auctionAddress, newBidder, newAmount, _nextOffchainBidder[auctionAddress][newBidder])) {
                return newBidder;
            }
            newBidder = _nextOffchainBidder[auctionAddress][newBidder];
        }

        return newBidder;
    }

    function isPrev(
        address auctionAddress,
        address bidder, 
        address prevBidder
    )
        internal
        view
        returns(bool)
    {
        return _nextOffchainBidder[auctionAddress][prevBidder] == bidder;
    }

    function findPrevBidder(
        address auctionAddress,
        address bidder
    )
        internal
        view
        returns(address)
    {
        address currentBidder = GUARD;
        while(_nextOffchainBidder[auctionAddress][currentBidder] != GUARD) {
            if (isPrev(auctionAddress, bidder, currentBidder)) {
                return currentBidder;
            }
            currentBidder = _nextOffchainBidder[auctionAddress][currentBidder];
        }
        return address(0);
    }

    /**
     * insert new item after valid address, update amount and increase listSize.
     * @param auctionAddress auctionAddress
     * @param bidder bidder
     * @param amount amount
     */
    function _addOffchainBid(
        address auctionAddress,
        address bidder, 
        uint256 amount
    ) 
        internal
    {
        require(_nextOffchainBidder[auctionAddress][bidder] == address(0));
        address index = _findIndex(auctionAddress, amount);
        offchainBidders[auctionAddress][bidder] = amount;
        _nextOffchainBidder[auctionAddress][bidder] = _nextOffchainBidder[auctionAddress][index];
        _nextOffchainBidder[auctionAddress][index] = bidder;
        offchainSizeList[auctionAddress]++;
    }

    /**
     * remove item, clean amount and decrease listSize
     * @param auctionAddress auctionAddress
     * @param bidder bidder
     */
    function _removeOffchainBid(
        address auctionAddress,
        address bidder
    ) 
        internal
    {
        require(_nextOffchainBidder[auctionAddress][bidder] != address(0));
        address prevIndex = findPrevBidder(auctionAddress, bidder);
        _nextOffchainBidder[auctionAddress][prevIndex] = _nextOffchainBidder[auctionAddress][bidder];
        _nextOffchainBidder[auctionAddress][bidder] = address(0);
        offchainBidders[auctionAddress][bidder] = 0;
        offchainSizeList[auctionAddress]--;
    }

}