export function getSignerAddress(): string {
  const envSignerAddress = process.env.SIGNER_ADDRESS

  if (!envSignerAddress) {
    throw new Error('Environment variable SIGNER_ADDRESS must be set. E.g. SIGNER_ADDRESS=0xD3E52099a6a48F132Cb23b1364B7dEE212d862F6')
  }

  return envSignerAddress
}

export function getUniswapFactoryAddress(): string {
  return '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f'
}

export function getTokenAddress(tokenSymbol: string): string {
  switch (tokenSymbol) {
    case 'DAI':
      return '0x6B175474E89094C44Da98b954EedeAC495271d0F'
    case 'WETH':
      return '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'
    case 'ETH':
      return '0x0000000000000000000000000000000000000000'
    default:
      throw new Error(`Unrecognized token symbol ${tokenSymbol}`)
  }
}
