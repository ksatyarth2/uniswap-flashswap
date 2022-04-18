import { BigNumber, Contract, Signer } from 'ethers'
import getTokenContract from './getTokenContract'

export default async function transfer(contract: Contract, tokenSymbol: string, amount: BigNumber, signer: Signer, overrides: any): Promise<void> {
  if (tokenSymbol == 'ETH') {
    await signer.sendTransaction({
      to: contract.address,
      value: amount
    })
  } else {
    const token = await getTokenContract(tokenSymbol, signer)

const txn =     await token.transfer(
      contract.address,
      amount,
      overrides
    )
    const txnConfirmation = await txn.wait();
    console.log('txnConfirmation', txnConfirmation);
  }
}

