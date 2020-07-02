import * as assert from 'assert'
import * as addresses from './addresses'
import bre from '@nomiclabs/buidler'
import { Signer, BigNumber, Contract } from 'ethers'

const OVERRIDES = {
  gasLimit: 9.5e6,
  gasPrice: 60e9
}

let signer: Signer
let exampleContract: Contract

function getTokenContract(tokenSymbol: string, signer: Signer): Promise<Contract> {
  const tokenAddress = addresses.getTokenAddress(tokenSymbol)

  const tokenContract = bre.ethers.getContractAt(
    'IERC20',
    tokenAddress,
    signer
  )

  return tokenContract
}

async function getBalance(tokenSymbol: string, address: string): Promise<BigNumber> {
  if (tokenSymbol == 'ETH') {
    return await bre.ethers.provider.getBalance(address)
  } else {
    const token = await getTokenContract(tokenSymbol, signer)

    return await token.balanceOf(address)
  }
}

async function transfer(tokenSymbol: string, amount: BigNumber): Promise<void> {
  if (tokenSymbol == 'ETH') {
    signer.sendTransaction({
      to: exampleContract.address,
      value: amount
    })
  } else {
    const token = await getTokenContract(tokenSymbol, signer)

    await token.transfer(
      exampleContract.address,
      amount,
      OVERRIDES
    )
  }
}

async function ensureMinBalance(tokenSymbol: string, minBalance: BigNumber): Promise<void> {
  console.log(`\nEnsuring that contract can cover fees...`)

  let contractTokenPayBalance = await getBalance(tokenSymbol, exampleContract.address)
  console.log(`  contract ${tokenSymbol} balance`, contractTokenPayBalance.toString())

  if (contractTokenPayBalance.lt(minBalance)) {
    console.log(`  contract will not be able to cover fee, sending from signer...`)

    const signerAddress = await signer.getAddress()
    const signerTokenPayBalance = await getBalance(tokenSymbol, signerAddress)
    console.log(`  signer ${tokenSymbol} balance`, signerTokenPayBalance.toString())

    if (signerTokenPayBalance.lt(minBalance)) {
      throw new Error(`Signer does not have ${minBalance.toString()} ${tokenSymbol}`)
    }

    await transfer(tokenSymbol, minBalance)

    contractTokenPayBalance = await getBalance(tokenSymbol, exampleContract.address)
    console.log(`  new contract ${tokenSymbol} balance`, contractTokenPayBalance.toString())
  }
}

async function getDecimals(tokenSymbol: string): Promise<number> {
  if (tokenSymbol == 'ETH') {
    return 18
  } else {
    const token = await getTokenContract(tokenSymbol, signer)

    return await token.decimals()
  }
}

function itSuccessfullyFlashSwaps(
  tokenBorrowSymbol: string,
  tokenPaySymbol: string,
  borrowAmount: string,
  feeCushionAmount: string
): void {
  it('successfully flash swaps', async () => {
    console.log(`\nTesting swap - borrows ${borrowAmount} ${tokenBorrowSymbol}, paying with ${tokenPaySymbol}`)

    const amountToBorrow = bre.ethers.utils.parseUnits(borrowAmount, await getDecimals(tokenBorrowSymbol))
    const minBalance = bre.ethers.utils.parseUnits(feeCushionAmount, await getDecimals(tokenPaySymbol))
    await ensureMinBalance(tokenPaySymbol, minBalance)

    console.log(`\nPerforming flash swap...`)
    const bytes = bre.ethers.utils.arrayify('0x00')
    await exampleContract.flashSwap(
      addresses.getTokenAddress(tokenBorrowSymbol),
      amountToBorrow,
      addresses.getTokenAddress(tokenPaySymbol),
      bytes
    )

    assert.ok(true)
  })
}

describe('Example', () => {
  before('set up signer', () => {
    console.log('\nSetting up signer...')

    const signerAddress = addresses.getSignerAddress()
    signer = bre.ethers.provider.getSigner(signerAddress)
    console.log(`  signer: ${signerAddress}`)
  })

  before('deploy example contract', async () => {
    console.log('\nDeploying example contract...')
    const factory = await bre.ethers.getContractFactory('ExampleContract', signer)
    exampleContract = await factory.deploy(
      addresses.getTokenAddress('WETH'),
      addresses.getTokenAddress('DAI'),
      OVERRIDES
    )
    console.log(`  example contract: ${exampleContract.address}`)
  })

  // traditional "flash loans" (these incur a 0.3% fee)
  itSuccessfullyFlashSwaps('ETH', 'ETH', '1', '2')
  itSuccessfullyFlashSwaps('WETH', 'WETH', '1', '2')
  itSuccessfullyFlashSwaps('DAI', 'DAI', '100', '4')
  // ETH/WETH unwrapping during traditional "flash loans" (these incur a 0.3% fee)
  itSuccessfullyFlashSwaps('WETH', 'ETH', '1', '2')
  itSuccessfullyFlashSwaps('ETH', 'WETH', '1', '2')
  // simple flash swaps (these incur a 0.3% fee)
  itSuccessfullyFlashSwaps('DAI', 'WETH', '100', '0.05')
  itSuccessfullyFlashSwaps('WETH', 'DAI', '1', '10')
  // ETH/WETH unwrapping with simple flash swaps (these incur a 0.3% fee)
  itSuccessfullyFlashSwaps('DAI', 'ETH', '100', '0.05')
  itSuccessfullyFlashSwaps('ETH', 'DAI', '1', '10')
  // triangular swaps (these incur a 0.6% fee)
  itSuccessfullyFlashSwaps('USDC', 'DAI', '100', '6')

  // itSuccessfullyFlashSwaps('USDC', 'USDC', '100', '5')
  // itSuccessfullyFlashSwaps('TUSD', 'TUSD', '100', '5')
  // itSuccessfullyFlashSwaps('DAI', 'DAI', '1000', '25')
  // itSuccessfullyFlashSwaps('KNC', 'KNC', '1000', '25')
  // itSuccessfullyFlashSwaps('KNC', 'DAI', '100', '25')
  // itSuccessfullyFlashSwaps('ETH', 'ETH', '1', '1')
  // itSuccessfullyFlashSwaps('ETH', 'DAI', '10', '100')
  // itSuccessfullyFlashSwaps('WETH', 'WETH', '10', '1')
})
