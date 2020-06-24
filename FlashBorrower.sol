pragma solidity 0.5.17;

import './UniswapV2Interfaces.sol';


contract UniswapV2FlashSwapper {
    
    enum SwapType {SimpleLoan, SimpleSwap, TriangularSwap}
    
    IUniswapV2Factory constant uniswapV2Factory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    
    // These addresses are for Rinkeby. For mainnet, use the correct mainnet addresses
    address constant WETH = 0xc778417E063141139Fce010982780140Aa0cD5Ab; // for mainnet use: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant DAI = 0xc7AD46e0b8a400Bb3C915120d284AafbA8fc4735; // for mainnet use: 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    
    address permissionedPairAddress = address(1); // access control
    
    // TESTING
    uint public lastAmount; // just for testing
    SwapType public lastType; // just for testing
    
    // @notice Flash-borrows _amount of _tokenBorrow from a Uniswap V2 pair and repays using _tokenPay
    // @param _tokenBorrow The address of the token you want to flash-borrow
    // @param _amount The amount of _tokenBorrow you will borrow
    // @param _tokenPay The address of the token you want to use to payback the flash-borrow
    function flashSwap(address _tokenBorrow, uint256 _amount, address _tokenPay) external {
        
        if (_tokenBorrow == _tokenPay) {
            simpleFlashLoan(_tokenBorrow, _amount);
            return;
        } else if (_tokenBorrow == WETH || _tokenPay == WETH) {
            simpleFlashSwap(_tokenBorrow, _amount, _tokenPay);
            return;
        } else {
            traingularFlashSwap(_tokenBorrow, _amount, _tokenPay);
            return;
        }

    }
    
    
    // @notice Function is called by the Uniswap V2 pair's `swap` function, passing in the `data` we defined above
    function uniswapV2Call(address _sender, uint _amount0, uint _amount1, bytes calldata _data) external {
        // access control
        require(msg.sender == permissionedPairAddress, "only permissioned UniswapV2 pair can call");
        require(_sender == address(this), "only this contract may initiate");
        
        // decode data
        (SwapType _swapType, address _tokenBorrow, uint _amount, address _tokenPay, bytes memory _triangleData) =
            abi.decode(_data, (SwapType, address, uint, address, bytes));
        
        lastType = _swapType; // FOR TESTING
        
        if (_swapType == SwapType.SimpleLoan) {
            simpleFlashLoanExecute(_tokenBorrow, _amount, msg.sender);
            return;
        } else if (_swapType == SwapType.SimpleSwap) {
            simpleFlashSwapExecute(_tokenBorrow, _amount, _tokenPay, msg.sender);
            return;
        } else {
            traingularFlashSwapExecute(_tokenBorrow, _amount, _tokenPay, _triangleData);
        }
    }
    
    // @notice This function is used when the user repays with the same token they borrowed
    // @dev This initiates the flash borrow. See `simpleFlashLoanExecute` for the code that executes after the borrow.
    function simpleFlashLoan(address _tokenBorrow, uint256 _amount) private {
        address tokenOther = _tokenBorrow == WETH ? DAI : WETH;
        permissionedPairAddress = uniswapV2Factory.getPair(_tokenBorrow, tokenOther); // is it cheaper to compute this locally?
        address pairAddress = permissionedPairAddress; // gas efficiency
        require(pairAddress != address(0), "Requested _token is not available.");
        address token0 = IUniswapV2Pair(pairAddress).token0();
        address token1 = IUniswapV2Pair(pairAddress).token1();
        uint amount0Out = _tokenBorrow == token0 ? _amount : 0;
        uint amount1Out = _tokenBorrow == token1 ? _amount : 0;
        bytes memory data = abi.encode(SwapType.SimpleLoan, _tokenBorrow, _amount, _tokenBorrow, bytes('')); // note _tokenBorrow == _tokenPay
        IUniswapV2Pair(pairAddress).swap(amount0Out, amount1Out, address(this), data);
    }
    
    // @notice This is the code that is executed after `simpleFlashLoan` initiated the flash-borrow 
    // @dev When this code executes, this contract will hold the flash-borrowed _amount of _tokenBorrow
    function simpleFlashLoanExecute(address _tokenBorrow, uint _amount, address _pairAddress) private {
        // do whatever the user wants
        execute(_amount); // when this line executes, this contract holds _amount of _tokenBorrow
        
        // payback loan
        uint256 fee = ((_amount * 3) / 997) + 1;
        IERC20(_tokenBorrow).transfer(_pairAddress, _amount + fee); 
    }
    
    // @notice This function is used when either the _tokenBorrow or _tokenPay is WETH
    // @dev Since ~all tokens trade against WETH (if they trade at all), we can use a single UniswapV2 pair to 
    //     flash-borrow and repay with the requested tokens.
    // @dev This initiates the flash borrow. See `simpleFlashSwapExecute` for the code that executes after the borrow.
    function simpleFlashSwap(address _tokenBorrow, uint _amount, address _tokenPay) private {
        permissionedPairAddress = uniswapV2Factory.getPair(_tokenBorrow, _tokenPay); // is it cheaper to compute this locally?
        address pairAddress = permissionedPairAddress; // gas efficiency
        require(pairAddress != address(0), "Requested pair is not available.");
        address token0 = IUniswapV2Pair(pairAddress).token0();
        address token1 = IUniswapV2Pair(pairAddress).token1();
        uint amount0Out = _tokenBorrow == token0 ? _amount : 0;
        uint amount1Out = _tokenBorrow == token1 ? _amount : 0;
        bytes memory data = abi.encode(SwapType.SimpleSwap, _tokenBorrow, _amount, _tokenPay, bytes(''));
        IUniswapV2Pair(pairAddress).swap(amount0Out, amount1Out, address(this), data);
    }
    
    // @notice This is the code that is executed after `simpleFlashSwap` initiated the flash-borrow 
    // @dev When this code executes, this contract will hold the flash-borrowed _amount of _tokenBorrow
    function simpleFlashSwapExecute(address _tokenBorrow, uint _amount, address _tokenPay, address _pairAddress) private {
        // do whatever the user wants
        execute(_amount); // when this line executes, this contract holds _amount of _tokenBorrow
        
        address pairAddress = permissionedPairAddress; // gas efficiency
        // payback loan
        uint pairBalanceTokenBorrow = IERC20(_tokenBorrow).balanceOf(pairAddress);
        uint pairBalanceTokenPay = IERC20(_tokenPay).balanceOf(pairAddress);
        uint amountToRepay = ((1000 * pairBalanceTokenPay * _amount) / (997 * pairBalanceTokenBorrow)) + 1;
        IERC20(_tokenPay).transfer(_pairAddress, amountToRepay); 
    }
    
    // @notice This function is used when neither the _tokenBorrow nor the _tokenPay is WETH
    // @dev Since it is unlikely that the _tokenBorrow/_tokenPay pair has more liquidaity than the _tokenBorrow/WETH and 
    //     _tokenPay/WETH pairs, we do a triangular swap here. That is, we flash borrow WETH from the _tokenPay/WETH pair,
    //     Then we swap that borrowed WETH for the desired _tokenBorrow via the _tokenBorrow/WETH pair. And finally, 
    //     we pay back the original flash-borrow using _tokenPay.
    // @dev This initiates the flash borrow. See `traingularFlashSwapExecute` for the code that executes after the borrow.
    function traingularFlashSwap(address _tokenBorrow, uint _amount, address _tokenPay) private {
        address borrowPairAddress = uniswapV2Factory.getPair(_tokenBorrow, WETH); // is it cheaper to compute this locally?
        require(borrowPairAddress != address(0), "Requested borrow token is not available.");
        
        permissionedPairAddress = uniswapV2Factory.getPair(_tokenPay, WETH); // is it cheaper to compute this locally?
        address payPairAddress = permissionedPairAddress; // gas efficiency
        require(payPairAddress != address(0), "Requested pay token is not available.");
        
        // STEP 1: Compute how much WETH will be needed to get _amount of _tokenBorrow out of the _tokenBorrow/WETH pool
        uint pairBalanceTokenBorrow = IERC20(_tokenBorrow).balanceOf(borrowPairAddress) - _amount; // TODO this one could be a bad underflow, maybe use SafeMath.
        uint pairBalanceWeth = IERC20(WETH).balanceOf(borrowPairAddress);
        uint amountOfWeth = ((1000 * pairBalanceWeth * _amount) / (997 * pairBalanceTokenBorrow)) + 1;
        
        // Step 2: Flash-borrow that much WETH from the _tokenPay/WETH pool
        address token0 = IUniswapV2Pair(payPairAddress).token0();
        address token1 = IUniswapV2Pair(payPairAddress).token1();
        uint amount0Out = WETH == token0 ? amountOfWeth : 0;
        uint amount1Out = WETH == token1 ? amountOfWeth : 0;
        bytes memory triangleData = abi.encode(borrowPairAddress, amountOfWeth);
        bytes memory data = abi.encode(SwapType.TriangularSwap, _tokenBorrow, _amount, _tokenPay, triangleData);
        IUniswapV2Pair(payPairAddress).swap(amount0Out, amount1Out, address(this), data);
    }
    
    // @notice This is the code that is executed after `traingularFlashSwap` initiated the flash-borrow 
    // @dev When this code executes, this contract will hold the amount of WETH we need in order to get _amount 
    //     _tokenBorrow from the _tokenBorrow/WETH pair.
    function traingularFlashSwapExecute(address _tokenBorrow, uint _amount, address _tokenPay,  bytes memory _triangleData) private {
        // decode _triangleData
        (address _borrowPairAddress, uint _amountOfWeth) = abi.decode(_triangleData, (address, uint));
        
        // Step 3: Using a normal swap, trade that WETH for _tokenBorrow
        address token0 = IUniswapV2Pair(_borrowPairAddress).token0();
        address token1 = IUniswapV2Pair(_borrowPairAddress).token1();
        uint amount0Out = _tokenBorrow == token0 ? _amount : 0;
        uint amount1Out = _tokenBorrow == token1 ? _amount : 0;
        IERC20(WETH).transfer(_borrowPairAddress, _amountOfWeth); // send our flash-borrowed WETH to the pair
        uint balanceBefore = IERC20(_tokenBorrow).balanceOf(address(this)); // FOR TESTING
        IUniswapV2Pair(_borrowPairAddress).swap(amount0Out, amount1Out, address(this), bytes(''));
        uint balanceAfter = IERC20(_tokenBorrow).balanceOf(address(this)); // FOR TESTING
        require(balanceAfter >= balanceBefore); // FOR TESTING
        require(balanceAfter - balanceBefore >= _amount, "didn't get as much as we expected"); // FOR TESTING
        require(balanceAfter - balanceBefore <= _amount + 1, "got more than we expected"); // FOR TESTING
        
        // Step 4: Do Whatever the user wants (arb, liqudiation, etc)
        execute(_amount); // when this line executes, this contract holds _amount of _tokenBorrow
        
        // Step 5: Pay back the flash-borrow to the _tokenPay/WETH pool
        address payPairAddress = permissionedPairAddress; // gas efficiency
        uint pairBalanceWETH = IERC20(WETH).balanceOf(payPairAddress);
        uint pairBalanceTokenPay = IERC20(_tokenPay).balanceOf(payPairAddress);
        uint amountToRepay = ((1000 * pairBalanceTokenPay * _amountOfWeth) / (997 * pairBalanceWETH)) + 1;
        IERC20(_tokenPay).transfer(payPairAddress, amountToRepay); 
        
    }
    
    // @notice This is where the user's custom logic goes
    // @dev When this function executes, this contract will hold _amount of _tokenBorrow
    // @dev It is important that, by the end of the execution of this function, this contract holds the necessary
    //     amount of _tokenPay needed to pay back the flash-loan.
    // @dev Paying back the flash-loan happens automatically by the calling function -- do not pay back the loan in this function
    function execute(uint _amount) internal {
        // do whatever you want here
        lastAmount = _amount; // FOR TESTING
    }
    
    // @notice Simple getter for convenience while testing
    function getBalanceOf(address _input) external view returns (uint) {
        return IERC20(_input).balanceOf(address(this));
    }
}
