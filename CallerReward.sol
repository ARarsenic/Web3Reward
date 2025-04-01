// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Minimal ERC20 interface for USDT.
interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

// Minimal ERC721 interface for the whitelist NFT.
interface IERC721 {
    function balanceOf(address owner) external view returns (uint256);
}

contract FirstCallerReward {
    IERC20 public usdt;
    IERC721 public whitelistNFT;
    address public deployer;

    uint256 public totalPrizePool;
    uint256 public remainingPrizePool;
    bool public prizeDeposited;
    bool public activityEnded;
    mapping(address => bool) public hasClaimed;

    // Anti-reentrancy variable.
    uint256 private unlocked = 1;

    // Events for logging
    event RewardDeposited(uint256 amount);
    event RewardClaimed(address indexed claimant, uint256 amount);
    event ActivityEnded(uint256 remaining, address indexed deployer);

    // Modifier to restrict functions to the deployer.
    modifier onlyDeployer() {
        require(msg.sender == deployer, "Only deployer can call this function");
        _;
    }
    
    // Modifier to prevent reentrancy.
    modifier nonReentrant() {
        require(unlocked == 1, "Reentrant call");
        unlocked = 0;
        _;
        unlocked = 1;
    }
    
    // The constructor sets the USDT token address and the whitelist NFT address.
    constructor(address _usdtAddress, address _whitelistNFTAddress) {
        usdt = IERC20(_usdtAddress);
        whitelistNFT = IERC721(_whitelistNFTAddress);
        deployer = msg.sender;
    }
    
    // Deployer-only function to deposit the reward into the contract.
    // Ensure the deployer has approved the contract to transfer USDT on their behalf.
    function depositReward(uint256 _rewardAmount) external onlyDeployer {
        require(!prizeDeposited, "Prize already deposited");
        require(usdt.transferFrom(msg.sender, address(this), _rewardAmount), "USDT transfer failed");
        totalPrizePool = _rewardAmount;
        remainingPrizePool = _rewardAmount;
        prizeDeposited = true;
        emit RewardDeposited(_rewardAmount);
    }
    
    // Eligibility check: The caller must hold at least one whitelist NFT.
    function isEligible(address caller) internal view returns (bool) {
        return whitelistNFT.balanceOf(caller) > 0;
    }
    
    // Function to claim half of the remaining prize pool.
    // Each eligible caller can claim only once.
    function claimReward() external nonReentrant {
        require(prizeDeposited, "Prize not deposited yet");
        require(!activityEnded, "Activity ended");
        require(isEligible(msg.sender), "Caller does not hold a whitelist NFT");
        require(!hasClaimed[msg.sender], "Caller has already claimed their reward");

        uint256 rewardAmount = remainingPrizePool / 2;
        require(rewardAmount > 0, "No prize left to claim");

        // Update state before external call to avoid reentrancy.
        hasClaimed[msg.sender] = true;
        remainingPrizePool -= rewardAmount;

        require(usdt.transfer(msg.sender, rewardAmount), "USDT transfer failed");
        emit RewardClaimed(msg.sender, rewardAmount);
    }

    // Deployer-only function to end the activity and reclaim all remaining prize pool tokens.
    function endActivity() external onlyDeployer nonReentrant {
        require(prizeDeposited, "Prize not deposited yet");
        require(!activityEnded, "Activity already ended");
        activityEnded = true;

        uint256 remaining = remainingPrizePool;
        require(remaining > 0, "No prize left to claim back");
        remainingPrizePool = 0;

        require(usdt.transfer(deployer, remaining), "USDT transfer failed");
        emit ActivityEnded(remaining, deployer);
    }
}
