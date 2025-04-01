// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Minimal ERC20 interface for USDC.
interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

// Minimal ERC721 interface for the whitelist NFT.
// We assume the NFT contract implements the ownerOf function.
interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract FirstCallerReward {
    IERC20 public usdc;
    IERC721 public whitelistNFT;
    address public deployer;

    uint256 public totalPrizePool;
    uint256 public remainingPrizePool;
    bool public prizeDeposited;
    bool public activityEnded;
    
    // Tracks which NFT token IDs have been used to claim a reward.
    mapping(uint256 => bool) public tokenClaimed;

    // Anti-reentrancy variable.
    uint256 private unlocked = 1;

    // Events for logging
    event RewardDeposited(uint256 amount);
    event RewardClaimed(address indexed claimant, uint256 amount, uint256 tokenId);
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
    
    // Constructor sets the USDC token address and the whitelist NFT address.
    constructor(address _usdcAddress, address _whitelistNFTAddress) {
        usdc = IERC20(_usdcAddress);
        whitelistNFT = IERC721(_whitelistNFTAddress);
        deployer = msg.sender;
    }
    
    // Deployer-only function to deposit the reward into the contract.
    // Ensure the deployer has approved the contract to transfer USDC on their behalf.
    function depositReward(uint256 _rewardAmount) external onlyDeployer {
        require(!prizeDeposited, "Prize already deposited");
        require(usdc.transferFrom(msg.sender, address(this), _rewardAmount), "USDC transfer failed");
        totalPrizePool = _rewardAmount;
        remainingPrizePool = _rewardAmount;
        prizeDeposited = true;
        emit RewardDeposited(_rewardAmount);
    }
    
    // Claim the reward using a specific NFT token ID.
    // The caller must be the current owner of the NFT and the token must not have been used before.
    function claimReward(uint256 tokenId) external nonReentrant {
        require(prizeDeposited, "Prize not deposited yet");
        require(!activityEnded, "Activity ended");
        require(whitelistNFT.ownerOf(tokenId) == msg.sender, "Caller is not the owner of this NFT");
        require(!tokenClaimed[tokenId], "Reward for this NFT has already been claimed");

        uint256 rewardAmount = remainingPrizePool / 2;
        require(rewardAmount > 0, "No prize left to claim");

        // Mark this NFT as having claimed its reward.
        tokenClaimed[tokenId] = true;
        remainingPrizePool -= rewardAmount;

        require(usdc.transfer(msg.sender, rewardAmount), "USDC transfer failed");
        emit RewardClaimed(msg.sender, rewardAmount, tokenId);
    }

    // Deployer-only function to end the activity and reclaim all remaining prize pool tokens.
    function endActivity() external onlyDeployer nonReentrant {
        require(prizeDeposited, "Prize not deposited yet");
        require(!activityEnded, "Activity already ended");
        activityEnded = true;

        uint256 remaining = remainingPrizePool;
        require(remaining > 0, "No prize left to claim back");
        remainingPrizePool = 0;

        require(usdc.transfer(deployer, remaining), "USDC transfer failed");
        emit ActivityEnded(remaining, deployer);
    }
}
