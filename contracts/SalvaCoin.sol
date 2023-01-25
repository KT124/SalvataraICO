// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "./ERC20Dividend.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
// import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SalvaCoin is ERC20Dividend, ERC20Capped, ERC20Burnable, Ownable {
    constructor() ERC20("SalvaCoin", "STCX") ERC20Capped(10000000 * 10**18) {}

    function takesnapShot() external onlyOwner returns (uint256 _snapshotId) {
        return takeAShot();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        mintToken(to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Capped, ERC20Dividend)
    {
        super._mint(to, amount);
    }

    function banUser(address _banAddress) external onlyOwner returns (bool) {
        ban(_banAddress);
        return true;
    }

    function unBanUser(address _banAddress) external onlyOwner returns (bool) {
        unBan(_banAddress);
        return true;
    }

    function removeFromDivEligible(address _removeAddress)
        external
        onlyOwner
        returns (bool)
    {
        return excludeFromDiv(_removeAddress);
    }

    function addInDivEligible(address _addAddress)
        external
        onlyOwner
        returns (bool)
    {
        return includeForDiv(_addAddress);
    }

    // Only callable by contract ower. To withdraw salvacoin from this contract

    function withdrawContractERC20(address _erc20)
        external
        onlyOwner
        returns (bool)
    {
        address payable _to = payable(msg.sender);
        address _from = address(this);

        if (_erc20 == address(0)) {
            uint256 _amount = balanceOf(_from);
            _transfer(_from, _to, _amount);
        }
        // } else {
        //     uint256 _amount = IERC20(_erc20).balanceOf(_from);
        //     IERC20(_erc20).transfer(_to, _amount);
        // }
        return true;
    }

    /**************************overrides********************** */

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Dividend) {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Dividend) {
        super._afterTokenTransfer(from, to, amount);
    }

    function burn(uint256 amount)
        public
        override(ERC20Dividend, ERC20Burnable)
    {
        address _from = msg.sender;
        super._burn(_from, amount);
    }

    function transfer(address to, uint256 amount)
        public
        override(ERC20, ERC20Dividend)
        returns (bool)
    {
        super.transfer(to, amount);
        // address _from = msg.sender;
        // _transfer(_from, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override(ERC20, ERC20Dividend) returns (bool) {
        super.transferFrom(from, to, amount);

        return true;
    }

    function whoosh() external onlyOwner {
        address admin = owner();

        selfdestruct(payable(admin));
    }
}
