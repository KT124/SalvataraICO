// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

// // import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
// // import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";

abstract contract ERC20Dividend is ERC20Snapshot {
    // Add the library methods
    //   using EnumerableMap for EnumerableMap.UintToAddressMap;
    //   using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for EnumerableSet.AddressSet;

    // Declare a set state variable
    //  EnumerableSet.UintSet private holdingAmount;
    // storing coin holders in array using EnumerableMap library
    EnumerableSet.AddressSet private holder;

    // storing holders excluded from dividend distribution in array using EnumerableMap library
    EnumerableSet.AddressSet private _excluded;

    // Storing addresses not eligible for dividend
    // Used in calcDiv function later
    address[] public _excludedAddr;

    // storing address which are allowed to intract with the contract

    EnumerableSet.AddressSet private allowed;

    // storing address which are not allowed to intract with the contract
    EnumerableSet.AddressSet private banned;

    // Couting total number of holders eligible for dividend
    uint256 public currentHolderCount;

    // Counting total number of holders not eligible for dividend
    uint256 public excludedCount;

    // Claimed points
    // mapping(address => bool) private hasClaimed;

    mapping(address => uint256) private holderTokens;
    // mapping(address => bool) private isHolder;

    // timeStamp => Dividend stored

    // Dividend[] public dividends;

    // Dividend receiver to snapshotId
    mapping(address => mapping(uint256 => bool)) public addressToClaimedIds;

    // SnapshotId to Dividend

    // mapping(uint256 => Dividend) internal timeStampToDividend;

    // snap to total dividend amount to be distributed
    mapping(uint256 => uint256) public snapIdToTotalDividend;

    // To store all the snapShots taken.
    uint256[] public snapShots;

    // To capture last tranch of profit sent(SalvaCoin) to treasury(this contract)
    uint256 public lastestDividend;

    // To capture total dividens claimed.
    uint256 public totalDivs;

    uint256 public multiplier = 10**18;

    constructor() {
        treasuryAdd = address(this);

        _excluded.add(msg.sender);
        _excludedAddr.push(msg.sender);
        excludedCount = 1;
        // currentHolderCount = 2;
        // holder.add(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2);
        // holder.add(0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db);
        // holder.add(0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB);
        // startingBalAdmin();
    }

    // function startingBalAdmin() internal returns(uint256 _shotId){
    //     require(_admintStartingBal == 0, "Starting bal must be zero");
    //     _mint(msg.sender, 1000);
    //     _shotId = _snapshot();
    //     _admintStartingBal = balanceOfAt(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, 1);
    // }

    event SnapShotTaken(uint256 indexed SnapShotId);

    function takeAShot() internal returns (uint256 _shotId) {
        // Taking next snapshot
        _shotId = _snapshot();

        snapIdToTotalDividend[_shotId] = lastestDividend;

        totalDivWithdrawn[_shotId] += totalDivs;

        currentSnapId = _shotId;
        //  uint256 _divPerToken = lastestDividend * 10**18 / totalSupplyAt(_shotId) - balanceOfAt(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, _shotId);
        //  snapIdToDivPerToken[_shotId] = _divPerToken;

        snapShots.push(_shotId);

        emit SnapShotTaken(_shotId);

        // everytime take a snapshot, call setRewards. endtime is set to when the snapshot is  taked and start time is time of last snapthot
        // When we take the very first snapshot, we need to provided starttime and it is hardcoded.
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20Snapshot) {
        super._beforeTokenTransfer(from, to, amount);
    }

    address public treasuryAdd;
    mapping(address => uint256) public balExclDiv;

    function getPureBalanceOf(address account)
        public
        view
        override
        returns (uint256)
    {
        return balExclDiv[account];
    }

    function _updatePureBal(
        address from,
        address to,
        uint256 amount
    ) private {
        // to avoid any bugs it's imperative to ensure trasuryAddr is only used for dividend transfer
        if (from != treasuryAdd) {
            if (from != address(0)) {
                //burn

                balExclDiv[from] -= amount;
            }

            if (to != address(0)) {
                //mint

                balExclDiv[to] += amount;
            }
        } else if (from == treasuryAdd) {
            balExclDiv[from] -= amount;
        }
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20) {
        super._afterTokenTransfer(from, to, amount);

        if (to == treasuryAdd) {
            lastestDividend = amount;
            dividens.push(amount);
        }

        _updatePureBal(from, to, amount);
    }

    function mintToken(address to, uint256 amount) internal virtual {
        require(!banned.contains(msg.sender), "Banned address not allowed");

        updateReceiver(to);
        _mint(to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        virtual
        override(ERC20)
    {
        super._mint(to, amount);
    }

    function transfer(address to, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        require(!banned.contains(msg.sender), "Banned address not allowed");

        address _from = msg.sender;
        updateReceiver(to);
        updateSender(_from);
        _transfer(_from, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        require(!banned.contains(msg.sender), "Banned address not allowed");

        super.transferFrom(from, to, amount);

        updateReceiver(to);

        updateSender(from);
        return true;
    }

    function burn(uint256 amount) external virtual {
        require(!banned.contains(msg.sender), "Banned address not allowed");

        address _from = msg.sender;
        super._burn(_from, amount);
        require(updateSender(_from), "updateSender failed!");
    }

    mapping(address => mapping(uint256 => uint256)) public divClaimed;
    mapping(address => uint256) public addrToDivClaimed;

    mapping(address => mapping(uint256 => bool)) public hasClaimed;
    // mapping(uint256 => uint256) public snapIdToDivPerToken;
    // caller  => callerBal;
    // mapping(address => uint256) public balExclDiv;

    uint256[] public dividens;

    uint256 public currentSnapId;

    event DivClaimed(address indexed DivClaimer, uint256 indexed amount);

    // function to  claim dividiend
    function claimDiv() public {
        require(!banned.contains(msg.sender), "Banned!");
        require(!_excluded.contains(msg.sender), "Not allowed!");
        require(holder.contains(msg.sender), "Only coin holders!");

        // Fetching unclaimed snapshots by the caller and amounts

        uint256 _dividend;

        for (uint256 i; i < snapShots.length; i++) {
            uint256 _snapId = snapShots[i];
            // uint256 _previousDivClaimed;
            uint256 _holdingAmount;

            // if caller address is not in already claimed mapping, below code execute
            // otherwise, reverts with zero dividend message for the caller

            if (!addressToClaimedIds[msg.sender][_snapId]) {
                // _previousDivClaimed = addrToDivClaimed[msg.sender];

                // fetching dividend eligible balance of caller at _snapId

                _holdingAmount = this.balanceOfAt(msg.sender, _snapId);

                // _holdingAmount = balanceOfAt(msg.sender, _snapId)  - _previousDivClaimed;

                //    address _treasuryAdd = _excludedAddr[0];
                //    uint256 _totalAmountToDistribute = dividens[i]; // This should be the balance of escrow contract
                //    uint256 _totalAmountToDistribute = balanceOfAt(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4, snapShots[i]); // This should be the balance of escrow contract
                //    uint256 _totalAmountToDistribute = snapIdToTotalDividend[snapShots[i]]; // This should be the balance of escrow contract
                uint256 _totalAmountToDistribute = snapIdToTotalDividend[
                    _snapId
                ]; // This should be the balance of escrow contract

                // total amount of dividend till now for the  caller
                uint256 _div = calcDividend(
                    _holdingAmount,
                    _totalAmountToDistribute,
                    _snapId
                );

                if (_div > 0) {
                    _dividend += _div;
                }

                addressToClaimedIds[msg.sender][_snapId] = true;
                divClaimed[msg.sender][snapShots[i]] = _dividend;
            }
        }

        // asserting total divdidend for user is not zero.

        require(_dividend > 0, "zero dividend");

        // checking if this contract(treasury) has dividend ERC20 tokens to send dividend
        // if zero balance, revert

        if (balanceOf(address(this)) == 0) {
            revert("SalvaCoin: zero ERC20 bal for treasury.");
        }

        emit DivClaimed(msg.sender, _dividend);

        // Transferring dividend.

        this.transfer(msg.sender, _dividend);
    }

    // mapping to store snapshot => totalDividend withdrawn at the time of taking snapshot.

    mapping(uint256 => uint256) public totalDivWithdrawn;

    // Private function to calculate dividend.
    // Called by claimDiv function above.

    function calcDividend(
        uint256 _holdingAmount,
        uint256 _totalAmountToDistribute,
        uint256 _shotId
    ) private returns (uint256) {
        uint256 _excludedAddressAmount;
        for (uint256 i; i < _excludedAddr.length; i++) {
            // _excludedAddressAmount += balanceOfAt(_excludedAddr[i], _shotId);
            _excludedAddressAmount += balanceOfAt(_excludedAddr[i], _shotId);
        }
        uint256 _totalDivWithdrawn = totalDivWithdrawn[_shotId];
        uint256 _totalDivEligibleCoins = totalSupplyAt(_shotId) -
            (_totalDivWithdrawn + _excludedAddressAmount); // total dividend eligible coins held by all holders

        uint256 _divPerToken = (_totalAmountToDistribute * multiplier) /
            _totalDivEligibleCoins; // deriving the multiplier

        uint256 _div = (_holdingAmount * _divPerToken) / multiplier; // calculating dividend

        divClaimed[msg.sender][_shotId] = _div;
        addrToDivClaimed[msg.sender] += _div;
        hasClaimed[msg.sender][_shotId] = true;
        totalDivs += _div;

        return _div;
    }

    // To fetch total pending divs of an address

    function getMyTotalDivs() external returns (uint256 _totalDivs) {
        for (uint256 i; i < snapShots.length; i++) {
            uint256 _snapId = snapShots[i];
            uint256 _holdingAmount = this.balanceOfAt(msg.sender, _snapId);
            uint256 _totalAmountToDistribute = snapIdToTotalDividend[_snapId];

            // calculating total divs
            _totalDivs += calcDividend(
                _holdingAmount,
                _totalAmountToDistribute,
                _snapId
            );
        }
    }

    //  To fetch total supply which is eligible for dividend.

    function getNetSupplyHeld(uint256 _shotId) public view returns (uint256) {
        uint256 _excludedAddressAmount;
        for (uint256 i; i < _excludedAddr.length; i++) {
            // _excludedAddressAmount += balanceOfAt(_excludedAddr[i], _shotId);
            _excludedAddressAmount += balanceOfAt(_excludedAddr[i], _shotId);
        }
        uint256 _totalDivWithdrawn = totalDivWithdrawn[_shotId];
        uint256 _totalCoinsHeldAt = totalSupplyAt(_shotId) -
            _totalDivWithdrawn -
            (_excludedAddressAmount); // total coins held by all holders

        return _totalCoinsHeldAt;
    }

    // Private function called by _afterTransfer hook of ERC20

    function updateReceiver(address _to) private {
        if (!_excluded.contains(_to) && !holder.contains(_to)) {
            holder.add(_to);

            currentHolderCount++;
        }
    }

    // Private function called by _afterTransfer hook of ERC20

    function updateSender(address _from) private returns (bool) {
        if (this.balanceOf(_from) == 0) {
            holder.remove(_from);
        }
        return true;
    }

    // To check if a user if caller is dividend eligible.

    function isHolder(address _holder) public view returns (bool) {
        return holder.contains(_holder);
    }

    // To ban a user from interacting with import functions of this contract
    // Only contract owner can call this function.

    event BannedUser(address indexed _bannedAddress);

    function ban(address _banAddress) internal virtual returns (bool) {
        if (banned.contains(_banAddress)) {
            revert("SalvaCoin: already banned.");
        } else {
            banned.add(_banAddress);
        }
        emit BannedUser(_banAddress);
        return true;
    }

    // To unban the user and allow interaction with the contract.
    // Only contract owner can call this function.

    event UnBannedUser(address indexed _unbannedAddress);

    function unBan(address _unBanAddress) internal returns (bool) {
        if (!banned.contains(_unBanAddress)) {
            revert("SalvaCoin: already not banned.");
        } else {
            banned.remove(_unBanAddress);
        }

        emit UnBannedUser(_unBanAddress);

        return true;
    }

    /// To exclude an account from dividend benefit.

    function excludeFromDiv(address _excludedAddress)
        internal
        virtual
        returns (bool)
    {
        require(
            !_excluded.contains(_excludedAddress),
            "SalvaCoin: already excluded."
        );

        _excludedAddr.push(_excludedAddress);
        _excluded.add(_excludedAddress);
        excludedCount++;
        if (holder.contains(_excludedAddress)) {
            holder.remove(_excludedAddress);
            currentHolderCount--;
        }
        return true;
    }

    // To include an account for dividend.

    function includeForDiv(address _excludedAddress)
        internal
        virtual
        returns (bool)
    {
        for (uint256 i; i < _excludedAddr.length; i++) {
            if (_excludedAddress == _excludedAddr[i]) {
                delete _excludedAddr[i];
            }
        }
        _excluded.remove(_excludedAddress);
        excludedCount--;
        if (!holder.contains(_excludedAddress)) {
            holder.add(_excludedAddress);
            currentHolderCount++;
        }
        return true;
    }
}
