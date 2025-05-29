// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title Simple Staking Rewards Contract
 * @dev A gas-optimized contract for staking tokens and earning fixed rewards
 */
contract StakingRewardsContract is ReentrancyGuard {
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardsToken;
    address public owner;
    
    // Fixed reward rate: rewards per token per day (in wei)
    uint256 public rewardRatePerDay = 1e15; // 0.001 tokens per day per staked token
    
    struct StakeInfo {
        uint256 amount;
        uint256 lastClaimTime;
    }
    
    // User staking information
    mapping(address => StakeInfo) public stakes;
    
    // Total tokens staked
    uint256 public totalStaked;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 reward);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _stakingToken, address _rewardsToken) {
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
        owner = msg.sender;
    }

    /**
     * @dev Core Function 1: Stake tokens
     * @param _amount Amount of tokens to stake
     */
    function stake(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be > 0");
        
        // Claim any pending rewards first
        if (stakes[msg.sender].amount > 0) {
            _claimRewards();
        }
        
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        
        stakes[msg.sender].amount += _amount;
        stakes[msg.sender].lastClaimTime = block.timestamp;
        totalStaked += _amount;
        
        emit Staked(msg.sender, _amount);
    }

    /**
     * @dev Core Function 2: Withdraw staked tokens
     * @param _amount Amount of tokens to withdraw
     */
    function withdraw(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be > 0");
        require(stakes[msg.sender].amount >= _amount, "Insufficient balance");
        
        // Claim rewards before withdrawal
        _claimRewards();
        
        stakes[msg.sender].amount -= _amount;
        totalStaked -= _amount;
        
        stakingToken.transfer(msg.sender, _amount);
        
        emit Withdrawn(msg.sender, _amount);
    }

    /**
     * @dev Core Function 3: Claim rewards
     */
    function claimRewards() external nonReentrant {
        require(stakes[msg.sender].amount > 0, "No stake found");
        _claimRewards();
    }

    /**
     * @dev Internal function to calculate and transfer rewards
     */
    function _claimRewards() internal {
        uint256 reward = calculateRewards(msg.sender);
        
        if (reward > 0) {
            stakes[msg.sender].lastClaimTime = block.timestamp;
            rewardsToken.transfer(msg.sender, reward);
            emit RewardsClaimed(msg.sender, reward);
        }
    }

    /**
     * @dev Calculate pending rewards for a user
     * @param _user User address
     * @return reward Pending reward amount
     */
    function calculateRewards(address _user) public view returns (uint256 reward) {
        StakeInfo memory userStake = stakes[_user];
        
        if (userStake.amount == 0) return 0;
        
        uint256 timeStaked = block.timestamp - userStake.lastClaimTime;
        reward = (userStake.amount * rewardRatePerDay * timeStaked) / (1 days * 1e18);
    }

    /**
     * @dev Get user's staking information
     * @param _user User address
     * @return amount Staked amount
     * @return pendingRewards Pending rewards
     */
    function getUserInfo(address _user) external view returns (uint256 amount, uint256 pendingRewards) {
        amount = stakes[_user].amount;
        pendingRewards = calculateRewards(_user);
    }

    // Owner functions
    function setRewardRate(uint256 _newRate) external onlyOwner {
        rewardRatePerDay = _newRate;
    }

    function withdrawRewardTokens(uint256 _amount) external onlyOwner {
        rewardsToken.transfer(owner, _amount);
    }
}
