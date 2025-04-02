// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts@4.9.6/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts-upgradeable@4.9.6/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable@4.9.6/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable@4.9.6/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable@4.9.6/proxy/utils/UUPSUpgradeable.sol";

contract SRC20Upgradable is 
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    string _orgName;
    string _logoUrl;
    string _description;
    string _officialUrl;
    string _whitePaperUrl;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply_
    ) public initializer {
        __ERC20_init(name_, symbol_);
        __Ownable_init();
        __UUPSUpgradeable_init();

        _mint(msg.sender, initialSupply_);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    function orgName() public view returns (string memory) {
        return _orgName;
    }

    function setOrgName(string memory orgName_) public onlyOwner {
        _orgName = orgName_;
    }

    function logoUrl() public view returns (string memory) {
        return _logoUrl;
    }

    function setLogoUrl(string memory logoUrl_) public onlyOwner {
        _logoUrl = logoUrl_;
    }

    function description() public view returns (string memory) {
        return _description;
    }

    function setDescription(string memory description_) public onlyOwner {
        _description = description_;
    }

    function officialUrl() public view returns (string memory) {
        return _officialUrl;
    }

    function setOfficialUrl(string memory officialUrl_) public onlyOwner {
        _officialUrl = officialUrl_;
    }

    function whitePaperUrl() public view returns (string memory) {
        return _whitePaperUrl;
    }

    function setWhitePaperUrl(string memory whitePaperUrl_) public onlyOwner {
        _whitePaperUrl = whitePaperUrl_;
    }

    function version() public pure returns (string memory) {
        return "SRC20-0.0.1";
    }
}