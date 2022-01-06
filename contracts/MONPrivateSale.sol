// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MONPrivateSale is Ownable, ReentrancyGuard {

    IERC20 public MON;
    IERC20 public buyingToken;

    uint256 public constant HARD_CAP = 1_400_000_000_000_000_000_000_000_000;      // hardcap 1,400,000,000 MON
    uint256 public constant DECIMAL_PRICE = 10000;

    uint256 public priceToken = 22; // 0.0022 BUSD
    uint256 public minSpend = 100_000_000_000_000_000_000; // min: 100 busd
    uint256 public maxSpend = 10_000_000_000_000_000_000_000;  // max: 10,000 busd
    uint256 public startTime;
    uint256 public endTime;

    // Whitelisting list
    mapping(address => bool) public whiteListed;
    // Total MON token user bought
    mapping(address => uint256) public userBought;
    // Total BUSD token user deposite
    mapping(address => uint256) public userDeposited;
    // Total MON token user claimed
    mapping(address => uint256) public userClaimned;
    // Total MON sold
    uint256 public totalTokenSold = 0;

    // Claim token
    uint256[] public claimableTimestamp;
    mapping(uint256 => uint256) public claimablePercents;
    mapping(address => uint256) public claimCounts;

    event TokenBuy(address user, uint256 tokens);
    event TokenClaim(address user, uint256 tokens);

    constructor(
        address _MON,
        address _buyingToken
    ) {
        MON = IERC20(_MON);
        buyingToken = IERC20(_buyingToken);
    }

    function buy(uint256 _amount) public nonReentrant {
        require(block.timestamp >= startTime, "Private sale has not started");
        require(block.timestamp <= endTime, "Private sale has ended");

        require(userDeposited[_msgSender()] + _amount >= minSpend, "Below minimum amount");
        require(userDeposited[_msgSender()] + _amount <= maxSpend, "You have reached maximum spend amount per user");

        uint256 tokenQuantity = _amount / priceToken * DECIMAL_PRICE;
        require(totalTokenSold + tokenQuantity <= HARD_CAP, "Token private sale hardcap reached");

        buyingToken.transferFrom(_msgSender(), address(this), _amount);

        userBought[_msgSender()] += tokenQuantity;
        userDeposited[_msgSender()] += _amount;
        totalTokenSold += tokenQuantity;

        emit TokenBuy(_msgSender(), tokenQuantity);
    }

    
    function claim() external nonReentrant {
        uint256 userBoughtAmount = userBought[_msgSender()];
        require(userBoughtAmount > 0, "Nothing to claim");
        require(claimableTimestamp.length > 0, "Can not claim at this time");
        require(block.timestamp >= claimableTimestamp[0], "Can not claim at this time");

        uint256 startIndex = claimCounts[_msgSender()];
        require(startIndex < claimableTimestamp.length, "You have claimed all token");

        uint256 tokenQuantity = 0;
        for(uint256 index = startIndex; index < claimableTimestamp.length; index++){
            uint256 timestamp = claimableTimestamp[index];
            if(block.timestamp >= timestamp){
                tokenQuantity += userBoughtAmount * claimablePercents[timestamp] / 100;
                claimCounts[_msgSender()]++;
            }else{
                break;
            }
        }

        require(tokenQuantity > 0, "Token quantity is not enough to claim");
        require(MON.transfer(_msgSender(), tokenQuantity), "Can not transfer MON token");

        userClaimned[_msgSender()] += tokenQuantity;

        emit TokenClaim(_msgSender(), tokenQuantity);
    }

    function getTokenBought(address _buyer) public view returns(uint256) {
        require(_buyer != address(0), "Zero address");
        return userBought[_buyer];
    }

    function setSaleInfo(
        uint256 _price,
        uint256 _minSpend,
        uint256 _maxSpend,
        uint256 _startTime,
        uint256 _endTime) external onlyOwner {
        require(_minSpend < _maxSpend, "Spend invalid");
        require(_startTime < _endTime, "Time invalid");

        priceToken = _price;
        minSpend = _minSpend;
        maxSpend = _maxSpend;
        startTime = _startTime;
        endTime = _endTime;
    }

    function setSaleTime(uint256 _startTime, uint256 _endTime) external onlyOwner {
        require(_startTime < _endTime, "Time invalid");
        startTime = _startTime;
        endTime = _endTime;
    }

    function getSaleInfo() public view returns(uint256, uint256, uint256, uint256, uint256){
        return (priceToken, minSpend, maxSpend, startTime, endTime);
    }

    function setClaimableTimes(uint256[] memory _timestamp) external onlyOwner {
        require(_timestamp.length > 0, "Empty input");
        claimableTimestamp = _timestamp;
    }

    function setClaimablePercents(uint256[] memory _timestamps, uint256[] memory _percents) external onlyOwner {
        require(_timestamps.length > 0, "Empty input");
        require(_timestamps.length == _percents.length, "Empty input");
        for(uint256 index = 0; index < _timestamps.length; index++){
            claimablePercents[_timestamps[index]] = _percents[index];
        }
    }

    function setBuyingToken(address _newAddress) external onlyOwner {
        require(_newAddress != address(0), "Zero address");
        buyingToken = IERC20(_newAddress);
    }

    function setMONToken(address _newAddress) external onlyOwner {
        require(_newAddress != address(0), "Zero address");
        MON = IERC20(_newAddress);
    }

    function addToWhiteList(address[] memory _accounts) external onlyOwner {
        require(_accounts.length > 0, "Invalid input");
        for (uint256 index; index < _accounts.length; index++) {
            whiteListed[_accounts[index]] = true;
        }
    }

    function removeFromWhiteList(address[] memory _accounts) external onlyOwner {
        require(_accounts.length > 0, "Invalid input");
        for(uint256 index = 0; index < _accounts.length; index++){
            whiteListed[_accounts[index]] = false;
        }
    }

    function withdrawFunds() external onlyOwner {
        buyingToken.transfer(_msgSender(), buyingToken.balanceOf(address(this)));
    }

    function withdrawUnsold() external onlyOwner {
        uint256 tokenQuantity = MON.balanceOf(address(this)) - totalTokenSold;
        MON.transfer(_msgSender(), tokenQuantity);
    }
}