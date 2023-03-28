const { ethers } = require('hardhat');
const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const { tokens, assertRoughlyEquals, deployContract } = require('./helpers.js');

const uniswapV2Factory = '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f';
const initcodeHashV2 = '0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f';
const oneInchLP1 = '0xbAF9A5d4b0052359326A6CDAb54BABAa3a3A9643';

describe('UniswapV3Oracle', function () {
    async function initContracts () {
        const UniswapV2LikeOracle = await ethers.getContractFactory('UniswapV2LikeOracle');
        const UniswapV3Oracle = await ethers.getContractFactory('UniswapV3Oracle');
        const uniswapV2LikeOracle = await UniswapV2LikeOracle.deploy(uniswapV2Factory, initcodeHashV2);
        await uniswapV2LikeOracle.deployed();
        const uniswapV3Oracle = await UniswapV3Oracle.deploy();
        await uniswapV3Oracle.deployed();
        return { uniswapV2LikeOracle, uniswapV3Oracle };
    }

    it('dai -> weth', async function () {
        const { uniswapV2LikeOracle, uniswapV3Oracle } = await loadFixture(initContracts);
        await testRate(tokens.DAI, tokens.WETH, tokens.NONE, uniswapV2LikeOracle, uniswapV3Oracle);
    });

    it('weth -> dai', async function () {
        const { uniswapV2LikeOracle, uniswapV3Oracle } = await loadFixture(initContracts);
        await testRate(tokens.WETH, tokens.DAI, tokens.NONE, uniswapV2LikeOracle, uniswapV3Oracle);
    });

    it('WETH -> USDT', async function () {
        const { uniswapV2LikeOracle, uniswapV3Oracle } = await loadFixture(initContracts);
        await testRate(tokens.WETH, tokens.USDT, tokens.NONE, uniswapV2LikeOracle, uniswapV3Oracle);
    });

    it('USDT -> WETH', async function () {
        const { uniswapV2LikeOracle, uniswapV3Oracle } = await loadFixture(initContracts);
        await testRate(tokens.USDT, tokens.WETH, tokens.NONE, uniswapV2LikeOracle, uniswapV3Oracle);
    });

    it('UNI -> WETH', async function () {
        const { uniswapV2LikeOracle, uniswapV3Oracle } = await loadFixture(initContracts);
        await testRate(tokens.UNI, tokens.WETH, tokens.NONE, uniswapV2LikeOracle, uniswapV3Oracle);
    });

    it('WETH -> UNI', async function () {
        const { uniswapV2LikeOracle, uniswapV3Oracle } = await loadFixture(initContracts);
        await testRate(tokens.WETH, tokens.UNI, tokens.NONE, uniswapV2LikeOracle, uniswapV3Oracle);
    });

    it('AAVE -> WETH', async function () {
        const { uniswapV2LikeOracle, uniswapV3Oracle } = await loadFixture(initContracts);
        await testRate(tokens.AAVE, tokens.WETH, tokens.NONE, uniswapV2LikeOracle, uniswapV3Oracle);
    });

    it('WETH -> AAVE', async function () {
        const { uniswapV2LikeOracle, uniswapV3Oracle } = await loadFixture(initContracts);
        await testRate(tokens.WETH, tokens.AAVE, tokens.NONE, uniswapV2LikeOracle, uniswapV3Oracle);
    });

    it('weth -> usdc -> dai', async function () {
        const { uniswapV2LikeOracle, uniswapV3Oracle } = await loadFixture(initContracts);
        await testRate(tokens.WETH, tokens.DAI, tokens.USDC, uniswapV2LikeOracle, uniswapV3Oracle);
    });

    it('dai -> usdc -> weth', async function () {
        const { uniswapV2LikeOracle, uniswapV3Oracle } = await loadFixture(initContracts);
        await testRate(tokens.DAI, tokens.WETH, tokens.USDC, uniswapV2LikeOracle, uniswapV3Oracle);
    });

    async function testRate (srcToken, dstToken, connector, uniswapV2LikeOracle, uniswapV3Oracle) {
        const v2Result = await uniswapV2LikeOracle.getRate(srcToken, dstToken, connector);
        const v3Result = await uniswapV3Oracle.getRate(srcToken, dstToken, connector);
        assertRoughlyEquals(v3Result.rate.toString(), v2Result.rate.toString(), 2);
    }
});

describe('UniswapV3Oracle doesn\'t ruin rates', function () {
    async function initContracts () {
        const tresholdFilter = 10;

        const MultiWrapper = await ethers.getContractFactory('MultiWrapper');
        const OffchainOracle = await ethers.getContractFactory('OffchainOracle');

        const uniswapV2LikeOracle = await deployContract('UniswapV2LikeOracle', [uniswapV2Factory, initcodeHashV2]);
        const uniswapV3Oracle = await deployContract('UniswapV3Oracle');
        const uniswapOracle = await deployContract('UniswapOracle', ['0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95']);
        const mooniswapOracle = await deployContract('MooniswapOracle', [oneInchLP1]);

        const wethWrapper = await deployContract('BaseCoinWrapper', [tokens.WETH]);
        const aaveWrapperV1 = await deployContract('AaveWrapperV1');
        const aaveWrapperV2 = await deployContract('AaveWrapperV2', ['0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9']);
        await aaveWrapperV1.addMarkets([tokens.DAI]);
        await aaveWrapperV2.addMarkets([tokens.DAI]);
        const multiWrapper = await MultiWrapper.deploy([
            wethWrapper.address,
            aaveWrapperV1.address,
            aaveWrapperV2.address,
        ]);
        await multiWrapper.deployed();

        const oldOffchainOracle = await OffchainOracle.deploy(
            multiWrapper.address,
            [
                uniswapV2LikeOracle.address,
                uniswapOracle.address,
                mooniswapOracle.address,
            ],
            [
                '0',
                '1',
                '2',
            ],
            [
                tokens.NONE,
                tokens.ETH,
                tokens.WETH,
                tokens.USDC,
                tokens.DAI,
            ],
            tokens.WETH,
        );
        await oldOffchainOracle.deployed();

        const deployOffchainOracle = await OffchainOracle.deploy(
            multiWrapper.address,
            [
                uniswapV2LikeOracle.address,
                uniswapOracle.address,
                mooniswapOracle.address,
                uniswapV3Oracle.address,
            ],
            [
                '0',
                '1',
                '2',
                '0',
            ],
            [
                tokens.NONE,
                tokens.ETH,
                tokens.WETH,
                tokens.USDC,
                tokens.DAI,
            ],
            tokens.WETH,
        );
        await deployOffchainOracle.deployed();
        return { tresholdFilter, oldOffchainOracle, deployOffchainOracle };
    }

    it('ETH DAI', async function () {
        const { tresholdFilter, oldOffchainOracle, deployOffchainOracle } = await loadFixture(initContracts);
        await testRate(tokens.ETH, tokens.DAI, tresholdFilter, oldOffchainOracle, deployOffchainOracle);
    });

    it('WETH DAI', async function () {
        const { tresholdFilter, oldOffchainOracle, deployOffchainOracle } = await loadFixture(initContracts);
        await testRate(tokens.WETH, tokens.DAI, tresholdFilter, oldOffchainOracle, deployOffchainOracle);
    });

    it('USDC DAI', async function () {
        const { tresholdFilter, oldOffchainOracle, deployOffchainOracle } = await loadFixture(initContracts);
        await testRate(tokens.USDC, tokens.DAI, tresholdFilter, oldOffchainOracle, deployOffchainOracle);
    });

    it('USDC WETH', async function () {
        const { tresholdFilter, oldOffchainOracle, deployOffchainOracle } = await loadFixture(initContracts);
        await testRate(tokens.USDC, tokens.WETH, tresholdFilter, oldOffchainOracle, deployOffchainOracle);
    });

    async function testRate (srcToken, dstToken, tresholdFilter, oldOffchainOracle, deployOffchainOracle) {
        const expectedRate = await oldOffchainOracle.getRate(srcToken, dstToken, true, tresholdFilter);
        const actualRate = await deployOffchainOracle.getRate(srcToken, dstToken, true, tresholdFilter);
        const expectedReverseRate = await oldOffchainOracle.getRate(srcToken, dstToken, true, tresholdFilter);
        const actualReverseRate = await deployOffchainOracle.getRate(srcToken, dstToken, true, tresholdFilter);
        assertRoughlyEquals(actualRate.toString(), expectedRate.toString(), 2);
        assertRoughlyEquals(actualReverseRate.toString(), expectedReverseRate.toString(), 2);
    }
});
