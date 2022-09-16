pragma solidity =0.5.16;

import './interfaces/IUniswapV2Factory.sol';
import './UniswapV2Pair.sol';

contract UniswapV2Factory is IUniswapV2Factory {
    address public feeTo;
    address public feeToSetter;

    // getPair是用来维护pair合约以及token地址的
    // pair contract address =》 token0 =》 token1
    mapping(address => mapping(address => address)) public getPair;
    // allpairs里存放所有的pairs
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    // 创建交易对
    // 传入两个地址 tokenA 和token B
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        // 要求两个合约的地址不同
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
        // 排个序
        // 从小到大排序
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        // 要求合约地址不是0地址
        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        // 调用getPair函数查看这个pair是不是本来就存在的 如果存在的话就不用再创建一次了
        require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS'); // single check is sufficient
        // 创建交易对
        // 实际上创建交易对是部署一个新的合约
        // 创建的时候用了create2的方法，而不是直觉上最简单的pair = new UniswapV2Pair(tokenA, tokenB)，有什么好处？
        // create2是一个可以提前知道合约创建地址的方法，使用这个方法可以确定pair合约的地址
        // 因为uniswap使用的solidity版本比较低，这个版本还不支持直接调用create2的opcode
        // 所以uniswap用了assembly来调用
        // version 0.8之后就可以很方便了：https://stackoverflow.com/questions/71121396/how-is-uniswap-assembly-create2-function-working
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        // salt是用固定的方法计算的：
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        // 可以到geth源码里看看create2的规则是什么样的：https://github.com/ethereum/go-ethereum/blob/master/core/vm/evm.go
        // 知识点 create和create2的区别
        // 其实create2的功能就和他的名字一样：create2 创建一个合约到xxx地址
        // create的合约地址是：keccak256(rlp.encode(deployingAddress, nonce))[12:] 这里的nonce是随机的 所以地址随机、
        // create2的合约地址是： keccak256(0xff ++ deployingAddr ++ salt ++ keccak256(bytecode))[12:] 你可以自定义nonce ==》 可以确定合约地址
        assembly {
            // create2四个参数的意义: create new contract with code at memory p to p + n
            // 0是传入的value
            // bytecode是合约的hashcode
            // 因为bytecode类型为bytes，根据ABI规范，bytes为变长类型，在编码时前32个字节存储bytecode的长度，接着才是bytecode的真正内容，因此合约字节码的起始位置在bytecode+32字节
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IUniswapV2Pair(pair).initialize(token0, token1);
        // 把新建的pair合约写入map保存起来
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}
