import * as assert from 'assert'
import { Signer } from 'ethers'

import bre from '@nomiclabs/buidler'

import { ExampleContract } from '../typechain/ExampleContract'
import { ExampleContractFactory } from '../typechain/ExampleContractFactory'

const SIGNER_ADDRESS = '0x742d35Cc6634C0532925a3b844Bc454e4438f44e'
const OVERRIDES = {
  gasLimit: 9e6,
  gasPrice: 60e9
}

describe('Example', () => {
  let signer: Signer
  let contract: ExampleContract

  before('set up signer account', async () => {
    signer = bre.ethers.provider.getSigner(SIGNER_ADDRESS)
  })

  before('deploy example contract', async () => {
    const factory = new ExampleContractFactory(signer)

    contract = await factory.deploy(OVERRIDES)
  })

  it('deploys', async () => {
    assert.strictEqual(contract.address.length, 42)
  })
})