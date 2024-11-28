const { ethers} = require('hardhat');
const { expect } = require('chai');
const { time, loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

require("@nomicfoundation/hardhat-chai-matchers");

const { 
  deploy
} = require("./fixtures/deploy.js");

describe("Tests", function () {
  
  it("stub", async() => {
    const nftAuctionF = await ethers.getContractFactory("NFTAuctionFactory");

    const res = await loadFixture(deploy);
    const {
        alice,
        seriesId,
        ZERO_ADDRESS,
        price,
        now,
        baseURI,
        nft,
        mockUsefulContract,
        erc20,
        auctionFactory
    } = res;

    const nftAuction = await nftAuctionF.deploy(auctionFactory.target);
    let currentTime = await mockUsefulContract.currentBlockTimestamp();
    const NO_CLAIM_PERIOD = 0n;
    const CLAIM_PERIOD = 3600n; //1hour

    await nftAuction.produceAuction(
      erc20.target,// address token,
      true,// bool cancelable,
      currentTime,// uint64 startTime,
      currentTime + (86400n),// uint64 endTime,
      CLAIM_PERIOD, // uint64 claimPeriod,
      ethers.parseEther('1'), // uint256 startingPrice,
      // IAuction.Increase memory increase,
      // struct Increase {
      //     uint128 amount; // can't increase by over half the range
      //     uint32 numBids; // increase after this many bids
      //     bool canBidAboveIncrease;
      // }
      [
        ethers.parseEther('0.1'),
        10n,
        false
      ],
      3n,// uint32 maxWinners

      //----
      nft.target,// address nftcontract,
      600, //10min // uint64 winnerClaimInterval,
      seriesId, // uint64 seriesId,
      []// uint256[] memory tokensPerWinners
    );


    expect(1n).to.be.equal(1n);
    
  });

});
