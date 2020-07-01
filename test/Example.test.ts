import * as assert from 'assert'
import * as addresses from './utils/addresses'
import * as tokens from './utils/tokens'
import bre from '@nomiclabs/buidler'
import { Signer, BigNumber, Contract } from 'ethers'

const OVERRIDES = {
  gasLimit: 9.5e6,
  gasPrice: 60e9
}

let signer: Signer
let exampleContract: Contract

async function ensureFeeCanBePaid(tokenPay: Contract, minBalance: BigNumber): Promise<void> {
  let contractTokenPayBalance = await tokenPay.balanceOf(exampleContract.address) as BigNumber
  console.log('Example contract tokenPay balance', contractTokenPayBalance.toString())
  if (contractTokenPayBalance.lt(minBalance)) {
    const signerAddress = await signer.getAddress()
    const signerTokenPayBalance = await tokenPay.balanceOf(signerAddress) as BigNumber
    console.log('Signer tokenPay balance', signerTokenPayBalance.toString())

    if (signerTokenPayBalance.lt(minBalance)) {
      throw new Error(`Will not be able to cover transaction fee: ${minBalance.toString()}`)
    }

    await tokenPay.transfer(
      exampleContract.address,
      minBalance,
      OVERRIDES
    )

    contractTokenPayBalance = await tokenPay.balanceOf(exampleContract.address) as BigNumber
    console.log('Example contract tokenPay balance', contractTokenPayBalance.toString())
  }
}

function itSuccesfullyFlashSwaps(
  tokenBorrowSymbol: string,
  tokenPaySymbol: string,
  borrowAmount: string,
  feeCushionAmount: string
): void {
  it(`succesfully performs a swap with token ${tokenBorrowSymbol}, paying with token ${tokenPaySymbol}`, async () => {
    console.log(`\nPerforming flash swap for ${tokenBorrowSymbol}, paying with ${tokenPaySymbol}`)

    const tokenBorrow = await tokens.getTokenContract(tokenBorrowSymbol, signer)
    const tokenPay = await tokens.getTokenContract(tokenPaySymbol, signer)

    const amountToBorrow = bre.ethers.utils.parseUnits(borrowAmount, 18)
    const minBalance = bre.ethers.utils.parseUnits(feeCushionAmount, 18)
    await ensureFeeCanBePaid(tokenPay, minBalance)

    console.log('\nPerforming flash swap...')
    const bytes = bre.ethers.utils.arrayify('0x00')
    await exampleContract.flashSwap(
      tokenBorrow.address,
      amountToBorrow,
      tokenPay.address,
      bytes
    )

    assert.ok(true)
  })
}

describe('Example', () => {
  before('set up signer', () => {
    console.log('\nSetting up signer...')
    signer = bre.ethers.provider.getSigner(
      addresses.getSignerAddress()
    )
  })

  before('deploy example contract', async () => {
    console.log('\nDeploying example contract...')
    const factory = await bre.ethers.getContractFactory('ExampleContract', signer)
    exampleContract = await factory.deploy(OVERRIDES)
  })

  itSuccesfullyFlashSwaps('TUSD', 'TUSD', '100', '5')
  // itSuccesfullyFlashSwaps('DAI', 'DAI', '1000', '25')
  // itSuccesfullyFlashSwaps('WETH', 'WETH', '10', '1')
})
