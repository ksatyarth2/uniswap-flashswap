#!/bin/bash

if [[ -z "${CHAIN_PROVIDER}" ]]; then
  echo "Environment variable CHAIN_PROVIDER must be set. E.g. CHAIN_PROVIDER=https://mainnet.infura.io/v3/<your_api_key>"
  exit 1
fi

npx ganache-cli \
--fork $CHAIN_PROVIDER \
--networkId 66 \
--unlock 0x742d35Cc6634C0532925a3b844Bc454e4438f44e \
--gasLimit 10000000
