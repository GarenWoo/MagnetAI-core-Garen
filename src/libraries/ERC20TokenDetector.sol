// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

library ERC20TokenDetector {
    function isERC20BySig(address target) public returns (bool) {
        bytes memory payload;
        bool successOfCall;

        // Check {name}
        payload = abi.encodeWithSignature("name()");
        (successOfCall,) = target.staticcall(payload);

        // Check {symbol}
        payload = abi.encodeWithSignature("symbol()");
        (successOfCall,) = target.staticcall(payload);

        // Check {decimals}
        payload = abi.encodeWithSignature("decimals()");
        (successOfCall,) = target.staticcall(payload);

        // Check {totalSupply}
        payload = abi.encodeWithSignature("totalSupply()");
        (successOfCall,) = target.staticcall(payload);

        // Check {balanceOf}
        payload = abi.encodeWithSignature("balanceOf(address)", msg.sender);
        (successOfCall,) = target.staticcall(payload);
        
        // Check {transfer}
        payload = abi.encodeWithSignature("transfer(address,uint256)", address(this), 0);
        (successOfCall,) = target.call(payload);

        // Check {transferFrom}
        payload = abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), 0);
        (successOfCall,) = target.call(payload);

        // Check {approve}
        payload = abi.encodeWithSignature("approve(address,uint256)", address(this), 0);
        (successOfCall,) = target.call(payload);
        
        // Check {allowance}
        payload = abi.encodeWithSignature("allowance(address,address)", msg.sender, address(this));
        (successOfCall,) = target.staticcall(payload);

        return successOfCall;
    }
    function isERC20BySelector(address target) public returns (bool) {
        bytes memory payload;
        bool successOfCall;

        // Check {name}
        payload = abi.encodeWithSelector(0x06fdde03);       // "name()"
        (successOfCall,) = target.staticcall(payload);

        // Check {symbol}
        payload = abi.encodeWithSelector(0x95d89b41);      // "symbol()"
        (successOfCall,) = target.staticcall(payload);

        // Check {decimals}
        payload = abi.encodeWithSelector(0x313ce567);      // "decimals()"
        (successOfCall,) = target.staticcall(payload);

        // Check {totalSupply}
        payload = abi.encodeWithSelector(0x18160ddd);      // "totalSupply()"
        (successOfCall,) = target.staticcall(payload);

        // Check {balanceOf}
        payload = abi.encodeWithSelector(0x70a08231, msg.sender);    // "balanceOf(address)"
        (successOfCall,) = target.staticcall(payload);
        
        // Check {transfer}
        payload = abi.encodeWithSelector(0xa9059cbb, address(this), 0);       // "transfer(address,uint256)"
        (successOfCall,) = target.call(payload);

        // Check {transferFrom}
        payload = abi.encodeWithSelector(0x23b872dd, msg.sender, address(this), 0);       // "transferFrom(address,address,uint256)"
        (successOfCall,) = target.call(payload);

        // Check {approve}
        payload = abi.encodeWithSelector(0x095ea7b3, address(this), 0);       // "approve(address,uint256)"
        (successOfCall,) = target.call(payload);
        
        // Check {allowance}
        payload = abi.encodeWithSelector(0xdd62ed3e, msg.sender, address(this));      // "allowance(address,address)"
        (successOfCall,) = target.staticcall(payload);

        return successOfCall;
    }

    function isERC20UncheckMetadata(address target) public returns (bool) {
        bytes memory payload;
        bool successOfCall;

        // Check {totalSupply}
        payload = abi.encodeWithSignature("totalSupply()");
        (successOfCall,) = target.staticcall(payload);

        // Check {balanceOf}
        payload = abi.encodeWithSignature("balanceOf(address)", msg.sender);
        (successOfCall,) = target.staticcall(payload);
        
        // Check {transfer}
        payload = abi.encodeWithSignature("transfer(address,uint256)", address(this), 0);
        (successOfCall,) = target.call(payload);

        // Check {transferFrom}
        payload = abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), 0);
        (successOfCall,) = target.call(payload);

        // Check {approve}
        payload = abi.encodeWithSignature("approve(address,uint256)", address(this), 0);
        (successOfCall,) = target.call(payload);
        
        // Check {allowance}
        payload = abi.encodeWithSignature("allowance(address,address)", msg.sender, address(this));
        (successOfCall,) = target.staticcall(payload);

        return successOfCall;
    }

    // Here is an example to test
    function detectERC20ByStaticCall(address target) public view returns (string memory name, string memory symbol, uint256 totalSupply, uint256 decimals) {
        bytes memory data;
        string memory funcSig0 = "name()";
        (, data) = target.staticcall(abi.encodeWithSignature(funcSig0));
        name = abi.decode(data, (string));
        string memory funcSig1 = "symbol()";
        (, data) = target.staticcall(abi.encodeWithSignature(funcSig1));
        symbol = abi.decode(data, (string));
        string memory funcSig2 = "totalSupply()";
        (, data) = target.staticcall(abi.encodeWithSignature(funcSig2));
        totalSupply = abi.decode(data, (uint256));
        string memory funcSig3 = "decimals()";
        (, data) = target.staticcall(abi.encodeWithSignature(funcSig3));
        decimals = abi.decode(data, (uint256));
    }
}
