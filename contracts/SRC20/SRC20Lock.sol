
// File: contracts/utils/common.sol


pragma solidity ^0.8.0;

library Common {
    address internal constant PROPERTY_ADDR = 0x0000000000000000000000000000000000001000;

    function getMinLockAmount() public returns (uint256) {
        (bool success, bytes memory data) = PROPERTY_ADDR.call(abi.encodeWithSignature("getValue(string)", "deposit_min_amount"));
        require(success, "get deposit_min_amount failed");
        return abi.decode(data, (uint256));
    }

    function getLogoPayAmount() public returns (uint256) {
        (bool success, bytes memory data) = PROPERTY_ADDR.call(abi.encodeWithSignature("getValue(string)", "logo_payamount"));
        require(success, "get logo_payamount failed");
        return abi.decode(data, (uint256));
    }

    function getNumberInDay() public returns (uint256) {
        (bool success, bytes memory data) = PROPERTY_ADDR.call(abi.encodeWithSignature("getValue(string)", "block_space"));
        require(success, "get block_space failed");
        return 86400 / abi.decode(data, (uint256));
    }
}
// File: contracts/SRC20/SRC20Lock.sol


pragma solidity ^0.8.0;

contract SRC20Lock {
    uint256 no;

    mapping(address => uint256) addr2amount;
    mapping(address => mapping(uint256 => LockRecord)) addr2locks;
    mapping(address => uint256[]) addr2ids;
    mapping(uint256 => uint256) id2index;
    mapping(uint256 => address) id2addr;

    struct LockRecord {
        uint256 id;
        address addr;
        uint256 amount;
        uint256 lockDay;
        uint256 startHeight;
        uint256 unlockHeight;
    }

    bool internal lock; // re-entrant lock
    modifier noReentrant() {
        require(!lock, "Error: reentrant call");
        lock = true;
        _;
        lock = false;
    }

    event SRC20Deposit(address _addr, uint256 _id, uint256 _amount, uint256 _lockDay, uint256 _unlockHeight);
    event SRC20Withdraw(address _addr, uint256 _amount, uint256[] _ids);

    function deposit(address _to, uint256 _lockDay) public payable returns (uint256) {
        require(_lockDay > 0, "invalid lock day");
        require(msg.value >= Common.getMinLockAmount(), "invalid lock amount");
        LockRecord memory record = addRecord(_to, msg.value, _lockDay);
        emit SRC20Deposit(_to, record.id, msg.value, _lockDay, record.unlockHeight);
        return record.id;
    }

    function withdrawByID(uint256[] memory _ids) public noReentrant returns (uint256) {
        require(_ids.length > 0 && _ids.length <= 30, "invalid ids size, min: 1, max: 30");
        uint256 amount;
        LockRecord memory record;
        uint256[] memory temps = new uint256[](_ids.length);
        uint256 k;
        for(uint256 i; i < _ids.length; i++) {
            record = addr2locks[msg.sender][_ids[i]];
            if(record.amount == 0 || block.number < record.unlockHeight) {
                continue;
            }
            amount += record.amount;
            delRecord(_ids[i]);
            temps[k++] = _ids[i];
        }
        if(amount != 0) {
            payable(msg.sender).transfer(amount);
            uint256[] memory retIDs = new uint256[](k);
            for(uint256 i; i < k; i++) {
                retIDs[i] = temps[i];
            }
            emit SRC20Withdraw(msg.sender, amount, retIDs);
        }
        return amount;
    }

    function getTotalIDNum(address _addr) public view returns (uint256) {
        return addr2ids[_addr].length;
    }

    function getTotalIDs(address _addr, uint256 _start, uint256 _count) public view returns (uint256[] memory) {
        uint256 num = getTotalIDNum(_addr);
        require(num > 0, "insufficient quantity");
        require(_start < num, "invalid _start, must be in [0, totalNum)");
        require(_count > 0 && _count <= 100, "max return 100 ids");

        uint256[] memory ret = new uint256[](_count);
        uint256[] memory ids = addr2ids[_addr];
        for(uint256 i; i < _count; i++) {
            if(i + _start >= ids.length) {
                break;
            }
            ret[i++] = ids[i + _start];
        }
        return ret;
    }

    function getAvailableIDNum(address _addr) public view returns (uint256) {
        uint256 num;
        uint256[] memory ids = addr2ids[_addr];
        for(uint256 i; i < ids.length; i++) {
            if(block.number >= addr2locks[_addr][ids[i]].unlockHeight) {
                num++;
            }
        }
        return num;
    }

    function getAvailableIDs(address _addr, uint256 _start, uint256 _count) public view returns (uint256[] memory) {
        uint256 availableNum = getAvailableIDNum(_addr);
        require(availableNum > 0, "insufficient quantity");
        require(_start < availableNum, "invalid _start, must be in [0, availableIDNum)");
        require(_count > 0 && _count <= 100, "max return 100 ids");

        uint256[] memory temp = new uint256[](availableNum);
        uint256 index;
        uint256[] memory ids = addr2ids[_addr];
        for(uint256 i; i < ids.length; i++) {
            if(block.number >= addr2locks[_addr][ids[i]].unlockHeight) {
                temp[index++] = ids[i];
            }
        }

        uint256 num = _count;
        if(_start + _count >= availableNum) {
            num = availableNum - _start;
        }
        uint256[] memory ret = new uint256[](num);
        for(uint256 i; i < num; i++) {
            ret[i] = temp[i + _start];
        }
        return ret;
    }

    function getLockedIDNum(address _addr) public view returns (uint256) {
        uint256 num;
        uint256[] memory ids = addr2ids[_addr];
        for(uint256 i; i < ids.length; i++) {
            if(block.number < addr2locks[_addr][ids[i]].unlockHeight) {
                num++;
            }
        }
        return num;
    }

    function getLockedIDs(address _addr, uint256 _start, uint256 _count) public view returns (uint256[] memory) {
        uint256 lockedNum = getLockedIDNum(_addr);
        require(lockedNum > 0, "insufficient quantity");
        require(_start < lockedNum, "invalid _start, must be in [0, lockedIDNum)");
        require(_count > 0 && _count <= 100, "max return 100 ids");

        uint256[] memory temp = new uint256[](lockedNum);
        uint256 index;
        uint256[] memory ids = addr2ids[_addr];
        for(uint256 i; i < ids.length; i++) {
            if(block.number < addr2locks[_addr][ids[i]].unlockHeight) {
                temp[index++] = ids[i];
            }
        }

        uint256 num = _count;
        if(_start + _count >= lockedNum) {
            num = lockedNum - _start;
        }
        uint256[] memory ret = new uint256[](num);
        for(uint256 i; i < num; i++) {
            ret[i] = temp[i + _start];
        }
        return ret;
    }

    function getRecordByID(uint256 _id) public view returns (LockRecord memory ret) {
        return addr2locks[id2addr[_id]][_id];
    }

    // add record
    function addRecord(address _addr, uint256 _amount, uint256 _lockDay) internal returns (LockRecord memory) {
        uint256 startHeight = block.number;
        uint256 unlockHeight = startHeight + _lockDay * Common.getNumberInDay();
        uint256 id = ++no;
        LockRecord memory record = LockRecord(id, _addr, _amount, _lockDay, startHeight, unlockHeight);
        addr2amount[_addr] += _amount;
        addr2locks[_addr][id] = record;
        addr2ids[_addr].push(id);
        id2index[id] = addr2ids[_addr].length - 1;
        id2addr[id] = _addr;
        return record;
    }

    // delete record
    function delRecord(uint256 _id) internal {
        uint256 pos = id2index[_id];
        address addr = id2addr[_id];
        uint256 amount = addr2locks[addr][_id].amount;

        if(addr2amount[addr] < amount) {
            addr2amount[addr] = 0;
        } else {
            addr2amount[addr] -= amount;
        }

        delete addr2locks[addr][_id];

        uint256[] storage ids = addr2ids[addr];
        if(ids.length > 0) {
            ids[pos] = ids[ids.length - 1];
            ids.pop();
            if(ids.length > 0) {
                id2index[ids[pos]] = pos;
            }
        }

        delete id2index[_id];
        delete id2addr[_id];
    }
}