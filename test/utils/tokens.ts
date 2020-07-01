import * as addresses from './addresses'
import bre from '@nomiclabs/buidler'
import { Signer, Contract } from 'ethers'

export function getTokenContract(tokenSymbol: string, signer: Signer): Promise<Contract> {
  const tokenAddress = addresses.getTokenAddress(tokenSymbol)

  const tokenContract = bre.ethers.getContractAt(
    'IERC20',
    tokenAddress,
    signer
  )

  return tokenContract
}

