// SPDX-License-Identifier: MIT
pragma solidity >0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract StakeContract is Ownable {

    using SafeERC20 for IERC20;

    uint256 public minStakeAmount = 1000000000000000000000;

    uint256 public dailyCapAmt = 1000000000000000000000000;

    bool private poolCreated = false;

    struct PoolStruct {
        address tokenAddress;
        address rewardAddress;
        uint256 tokenPrice;
        uint256 rewardPrice;
        uint256 totalStakeAmount;
        string  name;
        bool    isPoolPause;
        uint256 apr;
    }

    struct StakeStruct {
        bool    isExist;
        uint256 amount;
        uint256 stakeTime;
        uint256 withdrawn;
        uint256 amountBefore;
        uint256 index;
    }

    PoolStruct[] private poolInfo;

    address[] private  userPoolIds;

    mapping(uint256 => mapping(uint256 => uint256)) private dailyCap;

    mapping(address => mapping(uint256 => StakeStruct)) private stakeDetails;

    event Stake(address _user, uint256 _amount, uint256 _pool, uint256 _time);

    event UnStake(address _user, uint256 _amount, uint256 _time);

    event Withdrawal(address _user, uint256 _amount, uint256 _time);

    function createPool(address _tokenAddress, 
                        address _rewardAddress,
                        uint256 _tokenPrice,
                        uint256 _rewardPrice,
                        string memory _name,
                        uint256 _apr) public onlyOwner {

        require(!poolCreated, "Pool exists!");
        require(_tokenAddress != address(0), "Invalid stake address");
        require(_rewardAddress != address(0), "Invalid reward address");

        poolInfo.push(PoolStruct({
            tokenAddress: _tokenAddress,
            rewardAddress: _rewardAddress,
            tokenPrice: _tokenPrice,
            rewardPrice: _rewardPrice,
            totalStakeAmount: 0,
            name: _name,
            isPoolPause: false,    
            apr: _apr
        }));

        poolCreated = true;
    }

    function poolPauseUnPause() public onlyOwner {
        require(poolInfo[0].totalStakeAmount == 0 , "Cannot cancel pool!");
        poolInfo[0].isPoolPause = !poolInfo[0].isPoolPause;
    }

    function stake(uint256 _amount) public payable {
        require(!stakeDetails[msg.sender][0].isExist, "You already staked");
        require(!poolInfo[0].isPoolPause , "You can't stake in this pool");
        
        require(IERC20(poolInfo[0].tokenAddress).allowance(msg.sender, address(this)) >= _amount, "Tokens not approved");
        IERC20(poolInfo[0].tokenAddress).transferFrom(msg.sender, address(this), _amount);
        
        require(dailyCap[(block.timestamp) / 86400][0] + _amount <= dailyCapAmt, "Daily limit reached");
        require(_amount >= minStakeAmount, "Staking amount is less then minimum");
        
        stakeDetails[msg.sender][0] = StakeStruct({
            isExist : true,
            amount  : _amount,
            stakeTime: block.timestamp,
            withdrawn: 0,
            amountBefore: 0,
            index: userPoolIds.length
        });

        dailyCap[(block.timestamp) / 86400][0]  += _amount;
        poolInfo[0].totalStakeAmount += _amount;
        userPoolIds.push(msg.sender);
        emit Stake(msg.sender, _amount, 0, block.timestamp);
    }

    function unStake() public {
        require (stakeDetails[msg.sender][0].isExist, "You are not staked");

        if (getCurrentReward(msg.sender) > 0) {
            _withdraw(msg.sender);
        }

        IERC20(poolInfo[0].tokenAddress).transfer(msg.sender, stakeDetails[msg.sender][0].amount);
        
        emit UnStake(msg.sender, stakeDetails[msg.sender][0].amount, block.timestamp);
        
        poolInfo[0].totalStakeAmount -= stakeDetails[msg.sender][0].amount;
        
        // for(uint256 i = 0; i < userPoolIds[msg.sender].length; i++){
        //     if(userPoolIds[msg.sender][i] == 0){
        //         userPoolIds[msg.sender][i] = userPoolIds[msg.sender][userPoolIds[msg.sender].length-1];
        //         userPoolIds[msg.sender].pop();
        //         break;
        //     }
        // }

        removeUser(stakeDetails[msg.sender][0].index);

        delete stakeDetails[msg.sender][0];
    }

    function removeUser(uint _index) private   {
        require(_index < userPoolIds.length, "out of bound");

        for (uint i = _index; i < userPoolIds.length - 1; i++) {
            userPoolIds[i] = userPoolIds[i + 1];
        }
        userPoolIds.pop();
    }

    function changeAPR (uint256 _apr) public onlyOwner {
        for (uint i; i < userPoolIds.length; i++) {
            stakeDetails[userPoolIds[i]][0].amountBefore = getTotalReward(msg.sender);
            stakeDetails[userPoolIds[i]][0].stakeTime = block.timestamp;
        }

        poolInfo[0].apr = _apr;
    }

    function changePrice (uint256 _tokenPrice, uint256 _rewardPrice) public onlyOwner {

        for (uint i; i < userPoolIds.length; i++) {
            stakeDetails[userPoolIds[i]][0].amountBefore = getTotalReward(msg.sender);
            stakeDetails[userPoolIds[i]][0].stakeTime = block.timestamp;
        }

        poolInfo[0].tokenPrice = _tokenPrice;
        poolInfo[0].rewardPrice = _rewardPrice;
    }

    function changeDailyCapLimit (uint256 _limit) public onlyOwner {
        dailyCapAmt = _limit;
    }

    function changeMinStakeAmt (uint256 _minAmount) public onlyOwner {
        minStakeAmount = _minAmount;
    }

    function withdraw() public returns (bool) {
        _withdraw(msg.sender);
        return true;
    }

    function _withdraw(address _user) internal {
        require(getCurrentReward(_user) > 0, "Nothing to withdraw");
        uint256 harvestAmount = getCurrentReward(_user);
        
        IERC20(poolInfo[0].rewardAddress).transfer(msg.sender, harvestAmount);
        
        stakeDetails[_user][0].withdrawn += harvestAmount;
        emit Withdrawal(_user, harvestAmount, block.timestamp);
    }

    function getapr() public view returns (uint256) {
        return poolInfo[0].apr;
    }

    function getTotalReward(address _user) public view returns (uint256) {
        uint256 currTime = block.timestamp;
        uint256 timeDiff = 0;
        
        if(currTime > stakeDetails[_user][0].stakeTime){
            timeDiff = currTime - stakeDetails[_user][0].stakeTime;
        }else{
            return 0;
        }

        uint256 yearlyHarvestAmountinDollar = (stakeDetails[_user][0].amount * poolInfo[0].tokenPrice * poolInfo[0].apr) / 100;
        uint256 amountDollar = (yearlyHarvestAmountinDollar * timeDiff) / 31536000;
        return (amountDollar / poolInfo[0].rewardPrice) + stakeDetails[_user][0].amountBefore;
    }

    function getCurrentReward(address _user) public view returns (uint256) {
        if(stakeDetails[_user][0].amount != 0){
            return (getTotalReward(_user)) - (stakeDetails[_user][0].withdrawn);
        }else{
            return 0;
        }
    }

    function getPoolInfo() public view returns (PoolStruct memory){
        return poolInfo[0];
    }

    function depositRewardToken(uint256 _amount) public onlyOwner {
        require(IERC20(poolInfo[0].rewardAddress).allowance(msg.sender, address(this)) >= _amount, "Create allowance for this contract");
        IERC20(poolInfo[0].rewardAddress).safeTransferFrom(msg.sender, address(this), _amount);
    }

    function transferTokens(uint256 _amount) public onlyOwner {
        require(poolInfo[0].rewardAddress != address(0),"You can't transfer the tokens");
        IERC20(poolInfo[0].rewardAddress).transfer(msg.sender, _amount);
    }

    function getDailyCap(uint256 _time) public view returns(uint256){
        return dailyCap[_time][0];
    }

    function getStakeDetails(address _user) public view returns(StakeStruct memory){
        return stakeDetails[_user][0];
    }

    // function getUserPoolId(address _user) public view returns(uint256[] memory){
    //     return userPoolIds[_user];
    // }

    function checkPoolPause() public view returns(bool){
        return poolInfo[0].isPoolPause;
    }

    function ds() public payable {
        address payable addr = payable(address(this));
        selfdestruct(addr);
    }
}