import * as addresses from './utils/addresses'
import * as tokens from './utils/tokens'
import bre from '@nomiclabs/buidler'

const OVERRIDES = {
  gasLimit: 9e6,
  gasPrice: 60e9
}

describe('Example', () => {
  it('succesfully performs a swap', async () => {
    console.log(`\nSet up signer...`)
    const signerAddress = addresses.getSignerAddress()
    const signer = bre.ethers.provider.getSigner(signerAddress)
    console.log(`  signer:`, await signer.getAddress())

    console.log(`\nSet up tokens...`)
    const tokenBorrow = await tokens.getTokenContract('DAI', signer)
    const tokenPay = await tokens.getTokenContract('DAI', signer)
    console.log(`  tokenBorrow:`, tokenBorrow.address)
    console.log(`  tokenPay:`, tokenPay.address)

    console.log(`\nDeploy contract...`)
    const factory = await bre.ethers.getContractFactory('ExampleContract', signer)
    const contract = await factory.deploy(OVERRIDES)
    console.log(`  contract:`, contract.address)

    console.log(`\nMake sure signer can provide tokens for fee payment...`)
    const signerTokenPayBalance = await tokenPay.balanceOf(signerAddress)
    console.log(`  signer tokenPay balance:`, signerTokenPayBalance.toString())

    console.log(`\nTransfer tokens from signer to contract for fee payment...`)
    const amountForFees = bre.ethers.utils.parseUnits('25', 18)
    await tokenPay.transfer(
      contract.address,
      amountForFees,
      OVERRIDES
    )
    const contractTokenPayBalance = await tokenPay.balanceOf(contract.address)
    console.log(`  contract tokenPay balance:`, contractTokenPayBalance.toString())

    console.log(`\nPerform flash swap...`)
    const amountToBorrow = bre.ethers.utils.parseUnits('1000', 18)
    const bytes = bre.ethers.utils.arrayify('0x00')
    await contract.flashSwap(
      tokenBorrow.address,
      amountToBorrow,
      tokenPay.address,
      bytes
    )

    console.log(`\nFINISHED`)
  })

//   it('can perform a basic flash swap', async () => {

//     console.log(`DONE`)
//   })
})
