// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Erc20Vault is ERC20("Principal", "PRPL") {

    uint256 public totalPoints;
    uint256 public totalPointsUsed;
    uint256 public lastUpdatedAt;
    address public principalAsset;
    address public yieldAsset;

    mapping (address => uint256) public lastClaimBlock;

    constructor(address _principalAsset, address _yieldAsset) {
        principalAsset = _principalAsset;
        yieldAsset = _yieldAsset;
    }

    function getAssetBalance() public view returns(uint256) {
        return IERC20(principalAsset).balanceOf(address(this));
    }

    // NOTE: User should not be able to claim in the same block as the deposit
    function deposit(uint256 amount) external {
        // claim yield if any
        claimYield();

        // accept the supplied asset
        // NOTE: USDT does not return bool value for transferFrom()
        require(
            IERC20(principalAsset).transferFrom(
                msg.sender,
                address(this),
                amount
            ),
            "deposit failed"
        );

        // mint vault token to represent liquidity provided
        _mint(msg.sender, amount);
    }

    // NOTE: User should not be able to claim in the same block as the deposit
    // NOTE: We can have a small cliff to prevent malicious users trying to 
    // leech profits from other depositors 
    function withdraw(uint256 amount) external {
        // claim yield if any
        claimYield();

        // return the deposited assets back
        IERC20(principalAsset).transfer(msg.sender, amount);

        // burn the user's vault token
        _burn(msg.sender, amount);
    }

    function getClaimablePoints(address account) public view returns(uint256) {
        if (lastClaimBlock[account] == 0) {
            return 0;
        }
        else {
            return balanceOf(account)*(block.number-lastClaimBlock[account]);
        }
    }

    // NOTE: User should not be able to claim in the same block as the deposit
    // NOTE: We can have a small cliff to prevent malicious users trying to 
    // leech profits from other depositors 
    function claimYield() public {
        // update total points
        totalPoints += (block.number-lastUpdatedAt)*getAssetBalance();

        // calculate claimable yield for the user
        uint256 claimablePoints = getClaimablePoints(msg.sender);
        uint256 claimableYield = (totalPoints-totalPointsUsed) == 0
            ? 0
            : (claimablePoints/(totalPoints-totalPointsUsed))*getAvailableYield();
        
        // update claimed points
        totalPointsUsed += claimablePoints;
        
        // mark the user claim block
        lastClaimBlock[msg.sender] = block.number;
        
        // mark the latest update block
        lastUpdatedAt = block.number;

        // claim if any
        if(claimableYield > 0) {
            _sendYieldToUser(claimableYield);
        }
    }

    // NOTE: Example of a pool of reward asset 
    // (this can also be an external contract like a Treasury for which the amount of liquidity keeps changing)
    function getAvailableYield() public view returns(uint256) {
        // calculate the total available yield
        return IERC20(yieldAsset).balanceOf(address(this));
    }

    // NOTE: Example of a yield distribution 
    function _sendYieldToUser(uint256 amount) internal {
        // send yield
        IERC20(yieldAsset).transfer(msg.sender, amount);
    }
}
