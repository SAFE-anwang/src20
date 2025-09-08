// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SRC20Lock {
    uint256 no;
    mapping(address => uint256[]) addr2ids;
    mapping(uint256 => LockRecord) id2record;
    mapping(uint256 => uint256) id2index;

    bool internal flag; // re-entrant lock
    modifier noReentrant() {
        require(!flag, "Error: reentrant call");
        flag = true;
        _;
        flag = false;
    }

    struct LockRecord {
        uint256 id;
        address addr;
        uint256 amount;
        uint256 lockDay;
        uint256 startHeight;
        uint256 unlockHeight;
    }

    event Lock(address _token, address _addr, uint256 _amount, uint256 _lockDay, uint256 _id);
    event Withdraw(address _token, address _addr, uint256 _amount, uint256[] _ids);

    function lock(address _token, address _to, uint256 _amount, uint256 _lockDay) public returns (uint256) {
        require(_token != address(0), "invalid token address");
        require(_amount > 0, "invalid amount");
        require(_lockDay > 0, "invalid lock day");

        (bool success, bytes memory data) = _token.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), _amount));
        if(!success) revert(getRevertMessage(data));

        uint256 id = addRecord(_to, _amount, _lockDay);
        emit Lock(_token, _to, _amount, _lockDay, id);
        return id;
    }

    function batchLock(address _token, address _to, uint256 _amount, uint256 _times, uint256 _spaceDay, uint256 _startDay) public returns (uint256[] memory) {
        require(_token != address(0), "invalid token address");
        require(_amount > 0, "invalid amount");
        require(_times > 0, "invalid times");
        require(_spaceDay + _startDay > 0, "_spaceDay + _startDay can't be 0");

        (bool success, bytes memory data) = _token.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), _amount));
        if(!success) revert(getRevertMessage(data));

        uint256[] memory ids = new uint256[](_times);
        uint256 batchAmount = _amount / _times;
        uint256 i;
        for(; i < _times - 1; i++) {
            ids[i] = addRecord(_to, batchAmount, _startDay + (i + 1) * _spaceDay);
            emit Lock(_token, _to, batchAmount, _startDay + (i + 1) * _spaceDay, ids[i]);
        }
        ids[i] = addRecord(_to, batchAmount + _amount % _times, _startDay + (i + 1) * _spaceDay);
        emit Lock(_token, _to, batchAmount + _amount % _times, _startDay + (i + 1) * _spaceDay, ids[i]);
        return ids;
    }

    function withdrawByID(address _token, uint256[] memory _ids) public noReentrant returns (uint256) {
        require(_ids.length > 0 && _ids.length <= 30, "invalid ids size, min: 1, max: 30");
        uint256 amount;
        LockRecord memory record;
        uint256[] memory temps = new uint256[](_ids.length);
        uint256 k;
        for(uint256 i; i < _ids.length; i++) {
            record = id2record[_ids[i]];
            if(record.amount == 0 || record.addr != tx.origin || block.number < record.unlockHeight) {
                continue;
            }
            amount += record.amount;
            delRecord(_ids[i]);
            temps[k++] = _ids[i];
        }
        if(amount != 0) {
            (bool success, bytes memory data) = _token.call(abi.encodeWithSignature("transfer(address,uint256)", tx.origin, amount));
            if(!success) revert(getRevertMessage(data));
            uint256[] memory retIDs = new uint256[](k);
            for(uint256 i; i < k; i++) {
                retIDs[i] = temps[i];
            }
            emit Withdraw(_token, tx.origin, amount, retIDs);
        }
        return amount;
    }

    function getTotalIDNum(address _addr) public view returns (uint256) {
        return addr2ids[_addr].length;
    }

    function getTotalIDs(address _addr, uint256 _start, uint256 _count) public view returns (uint256[] memory) {
        uint256 totalNum = getTotalIDNum(_addr);
        require(totalNum > 0, "insufficient quantity");
        require(_start < totalNum, "invalid _start, must be in [0, totalIDNum)");
        require(_count > 0 && _count <= 100, "max return 100 ids");

        uint256 num = _count;
        if(_start + _count >= totalNum) {
            num = totalNum - _start;
        }
        uint256[] memory ret = new uint256[](num);
        uint256[] memory ids = addr2ids[_addr];
        for(uint256 i; i < num; i++) {
            ret[i] = ids[i + _start];
        }
        return ret;
    }

    function getAvailableIDNum(address _addr) public view returns (uint256) {
        uint256 num;
        uint256[] memory ids = addr2ids[_addr];
        for(uint256 i; i < ids.length; i++) {
            if(block.number >= id2record[ids[i]].unlockHeight) {
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
            if(block.number >= id2record[ids[i]].unlockHeight) {
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
            if(block.number < id2record[ids[i]].unlockHeight) {
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
            if(block.number < id2record[ids[i]].unlockHeight) {
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

    function getRecordByID(uint256 _id) public view returns (LockRecord memory) {
        return id2record[_id];
    }

    // add record
    function addRecord(address _addr, uint256 _amount, uint256 _lockDay) internal returns (uint256) {
        require(_lockDay != 0, "invalid lock day");
        uint256 unlockHeight = block.number + _lockDay * getNumberInDay();
        uint256 id = ++no;
        addr2ids[_addr].push(id);
        id2record[id] = LockRecord(id, _addr, _amount, _lockDay, block.number, unlockHeight);
        id2index[id] = addr2ids[_addr].length - 1;
        return id;
    }

    // delete record
    function delRecord(uint256 _id) internal {
        require(id2record[_id].addr == tx.origin, "invalid record id");
        uint256[] storage ids = addr2ids[tx.origin];
        uint256 pos = id2index[_id];
        ids[pos] = ids[ids.length - 1];
        id2index[ids[pos]] = pos;
        ids.pop();
        delete id2record[_id];
        delete id2index[_id];
    }

    function getNumberInDay() internal view returns (uint256) {
        (bool success, bytes memory data) = 0x0000000000000000000000000000000000001000.staticcall(abi.encodeWithSignature("getValue(string)", "block_space"));
        if(!success) revert(getRevertMessage(data));
        return 86400 / abi.decode(data, (uint256));
    }

    function getRevertMessage(bytes memory _data) internal pure returns (string memory) {
        if (_data.length > 0) {
            assembly {
                let size := mload(_data)
                revert(add(32, _data), size)
            }
        } else {
            return "unknown error";
        }
    }
}