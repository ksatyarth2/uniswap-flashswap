pragma solidity 0.5.17;

import './UniswapV2Interfaces.sol';


contract UniswapV2FlashBorrower {
    
    IUniswapV2Factory constant uniswapV2Factory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    
    // These addresses are for Rinkeby. For mainnet, use the correct mainnet addresses
    address constant WETH = 0xc778417E063141139Fce010982780140Aa0cD5Ab; // for mainnet use: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant DAI = 0xc7AD46e0b8a400Bb3C915120d284AafbA8fc4735; // for mainnet use: 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    
    address pairAddress; // access control
    
    // TESTING
    uint public lastAmount; // just for testing
    
    // @notice Flash-borrows _amount of _token from the _token/_tokenB pool on Uniswap V2
    // @param _tokenA The address of the token you want to flash-borrow 
    // @param _tokenB The other token that defines the token pool from which you will flash-borrow
    // @param _amount The amount of _token you will borrow
    function flashLoan(address _token, uint256 _amount) external {
        address tokenB = _token == WETH ? DAI : WETH;
        pairAddress = uniswapV2Factory.getPair(_token, tokenB); // is it cheaper to compute this locally?
        require(pairAddress != address(0), "Requested _token is not available.");
        address token0 = IUniswapV2Pair(pairAddress).token0();
        address token1 = IUniswapV2Pair(pairAddress).token1();
        uint amount0Out = _token == token0 ? _amount : 0;
        uint amount1Out = _token == token1 ? _amount : 0;
        bytes memory data = abi.encode(_token, _amount);
        IUniswapV2Pair(pairAddress).swap(amount0Out, amount1Out, address(this), data);
    }
    
    
    // A FUNCTION OF THIS NAME MUST EXIST IN ORDER TO RECEIVE TOKENS FROM UNISWAP DURING A FLASH LOAN/SWAP
    // @notice Function is called by the Uniswap V2 pair's `swap` function, passing in the `data` we defined above
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external {
        // access control
        require(msg.sender == pairAddress, "only UniswapV2 pair can call");
        require(sender == address(this), "only this contract may initiate");
        
        // decode data
        (address _token, uint _amount) = abi.decode(data, (address, uint));
        
        // DO WHATEVER YOU WANT HERE
        lastAmount = _amount; // TESTING
        
        // payback loan
        uint256 fee = ((_amount * 3) / 997) + 1;
        IERC20(_token).transfer(msg.sender, _amount + fee);        
    }
}
