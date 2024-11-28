// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

contract MockUsefulContract {
    // constructor(address _implementation) ReleaseManagerFactory(_implementation) {
        
    // }
    function currentBlockTimestamp() public view returns (uint64) {
        return uint64(block.timestamp);
    }
}
 
