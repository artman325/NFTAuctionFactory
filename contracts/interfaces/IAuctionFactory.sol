pragma solidity >=0.8.0 <0.9.0;
import "@intercoin/auction/contracts/interfaces/IAuction.sol";

interface IAuctionFactory {

    function produceAuction(
        address token,
        bool cancelable,
        uint64 startTime,
        uint64 endTime,
        uint64 claimPeriod,
        uint256 startingPrice,
        IAuction.Increase memory increase,
        uint32 maxWinners
    ) external returns (address);

}