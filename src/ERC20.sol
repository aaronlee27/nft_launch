// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20 } from "./interface/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";


contract ERC20 is IERC20, Ownable {
    error ERC20InvalidSender(address _sender);
    error ERC20InvalidReceiver(address _receiver);
    error ERC20CantMintMoreThanMaxSupply();
    error ERC20InsufficientAllowance(address _spender, uint256 _allowances, uint256 _value);
    error ERC20InsufficientBalance(address _owner, uint256 _currentBalance, uint256 _value);

    uint256 private constant MAX_SUPPLY = 1_000_000_000 ether; // 1 BILLION

    mapping (address _owner => uint256 _amount) private s_balances;
    mapping (address _owner => mapping(address _spender => uint256 _amount)) s_allowances;
    uint256 private s_totalSupply;

    string private s_name;
    string private s_symbol;


    constructor(string memory _name, string memory _symbol) Ownable (msg.sender) {
       s_name = _name;
       s_symbol = _symbol; 
       _mint(msg.sender, MAX_SUPPLY);
    }

    //////////////////////////////////////////////////////////////////////////
    //////////////////  EXTERNAL FUNCTION ////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////

    

    function mint(address _to, uint256 _value) external onlyOwner {
        _mint(_to, _value);
    }
    
    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        _transfer(msg.sender, _to, _value);
        success = true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        // check allowances (remember to check for reentrancy)
        uint256 _allowances = s_allowances[_from][msg.sender];
        if (_allowances < _value) revert ERC20InsufficientAllowance(msg.sender, _allowances, _value);
        s_allowances[_from][msg.sender] -= _value;

        _transfer(_from, _to, _value);
        success = true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        _approve(msg.sender, _spender, _value);
        success = true;
    }


    //////////////////////////////////////////////////////////////////////////
    //////////////////  INTERNAL FUNCTION ////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////

    function _transfer(address _from, address _to, uint256 _value) internal {
        if (_from == address(0)){
            revert ERC20InvalidSender(address(0));
        }
        if (_to == address(0)){
            revert ERC20InvalidReceiver(address(0));
        }

        _update(_from, _to, _value);
    }

    function _approve(address _owner, address _spender, uint256 _value) internal {
        s_allowances[_owner][_spender] = _value;
        emit Approval(_owner, _spender, _value);
    }

    function _mint(address _to, uint256 _value) internal {
        if (_to == address(0)){
            revert ERC20InvalidReceiver(address(0));
        }

        _update(address(0), _to, _value);
    }

    function _burn(address _from, uint256 _value) internal {
        _update(_from, address(0), _value);
    }

    function _update(address _from, address _to, uint256 _value) internal {
        // MINT NEW TOKEN
        if (_from == address(0)){
            s_totalSupply += _value;
            if (s_totalSupply > MAX_SUPPLY) revert ERC20CantMintMoreThanMaxSupply();
        } else{
            uint256 _balances = s_balances[_from];
            if (_balances < _value) {
                revert ERC20InsufficientBalance(_from, _balances, _value);
            }
            // save gas
            unchecked {
                s_balances[_from] -= _value;
            }
        }

        // BURN TOKEN
        if (_to == address(0)) {
            unchecked {
                s_totalSupply -= _value;
            }
        } else {
            unchecked {
                s_balances[_to] += _value;
            }
        }

        emit Transfer(_from, _to, _value);
    }


    //////////////////////////////////////////////////////////////////////////
    //////////////////  VIEW FUNCTION ////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////
    

    function name() public view returns (string memory) {
        return s_name;
    }

    function symbol() public view returns (string memory) {
        return s_symbol;
    }

    function decimals() public pure returns (uint8){
        return 18;
    }

    function totalSupply() public view returns (uint256) {
        return s_totalSupply;
    }

    function getMaxSupply() public pure returns (uint256){
        return MAX_SUPPLY;
    }

    function balanceOf(address _owner) public view returns (uint256) {
        return s_balances[_owner];
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return s_allowances[_owner][_spender];
    }
}