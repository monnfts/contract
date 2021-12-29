// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenTimelock is Ownable {

    // ERC20 basic token contract being held
    IERC20 private _token;

    struct ReleaseInfo {
        bool isReleased;
        uint256 releaseTime;
        uint256 releasePercent;
    }

    // beneficiary of tokens to lock info
    mapping(address => uint256) internal _beneficiaryLocks;

    // beneficiary to release info
    mapping(address => ReleaseInfo[]) internal _releases;

    constructor (address tokenAddress) {
        _token = IERC20(tokenAddress);
    }

    /**
     * @notice Set new beneficiary lock.
     */
    function setLock(
        uint amount,
        uint256[] memory releaseTimes,
        uint256[] memory releasePercents
    ) public {
        require(releaseTimes.length ==  releasePercents.length, "Invalid argument releaseTimes");

        require(_token.transferFrom(_msgSender(), address(this), amount));
        _beneficiaryLocks[_msgSender()] = amount;
        
        for(uint256 index = 0; index < releaseTimes.length; index++){
            uint256 releaseTime = releaseTimes[index];
            require(releaseTime > block.timestamp, "Invalid release time");
            _releases[_msgSender()].push(ReleaseInfo({
                isReleased: false,
                releaseTime: releaseTime,
                releasePercent: releasePercents[index]
            }));
        }
    }

    /**
     * @notice Transfers tokens held by timelock to beneficiary.
     */
    function release() public virtual returns (bool){
        uint256 amount = 0;
        ReleaseInfo[] storage releases = _releases[_msgSender()];
        for(uint256 releaseIndex = 0; releaseIndex < releases.length; releaseIndex++){
            ReleaseInfo storage releaseDetail = releases[releaseIndex];
            if(releaseDetail.releaseTime <= block.timestamp && !releaseDetail.isReleased){
                amount += (_beneficiaryLocks[_msgSender()] * releaseDetail.releasePercent / 100);
                releaseDetail.isReleased = true;
            }
        }
        if (amount > 0) {
            require(token().transfer(_msgSender(), amount));
        }
        return true;
    }

    /**
     * @return the amount token lock by specific `account`.
     */
    function getLockAmount(address account) public view virtual returns (uint256) {
        return _beneficiaryLocks[account];
    }

    /**
    * @return quantity of token can be claimed by specific `account` 
    */
    function getReleasableAmount(address account) public view virtual returns(uint256){
        uint256 result = 0;
        ReleaseInfo[] storage releases = _releases[account];
        for(uint256 releaseIndex = 0; releaseIndex < releases.length; releaseIndex++){
            ReleaseInfo storage releaseDetail = releases[releaseIndex];
            if(releaseDetail.releaseTime <= block.timestamp && !releaseDetail.isReleased){
                result += (_beneficiaryLocks[account] * releaseDetail.releasePercent / 100);
            }
        }
        return result;
    }

    /**
    * @return quantity of token released by specific `account` 
    */
    function getReleasedAmount(address account) public view virtual returns(uint256){
        uint256 result = 0;
        ReleaseInfo[] storage releases = _releases[account];
        for(uint256 releaseIndex = 0; releaseIndex < releases.length; releaseIndex++){
            ReleaseInfo storage releaseDetail = releases[releaseIndex];
            if(releaseDetail.isReleased){
                result += (_beneficiaryLocks[account] * releaseDetail.releasePercent / 100);
            }
        }
        return result;
    }

    /**
    * @return list release info by specific `account` 
    */
    function getReleaseInfo(address account) public view virtual returns(ReleaseInfo[] memory){
        ReleaseInfo[] storage releases = _releases[account];
        return releases;
    }

    /**
     * @return the token being held.
     */
    function token() public view virtual returns (IERC20) {
        return _token;
    }

    /**
     * @notice Set new address for token.
     */
    function setToken(address newAddress) public onlyOwner{
        require(newAddress != address(0), "Zero address");
        _token = IERC20(newAddress);
    }
}