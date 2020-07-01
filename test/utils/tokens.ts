import * as addresses from './addresses'
import bre from '@nomiclabs/buidler'
import * as ethers from "ethers";
import { Signer } from 'ethers'

export function getTokenContract(tokenSymbol: string, signer: Signer): Promise<ethers.Contract> {
  const tokenAddress = addresses.getTokenAddress(tokenSymbol)

  const tokenContract = bre.ethers.getContractAt(
    'IERC20',
    tokenAddress,
    signer
  )

  return tokenContract
}

