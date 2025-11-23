#!/bin/bash

source .env

if [ -z "$1" ]; then
  echo "Usage: $0 <positionManagerAddress>"
  exit 1
fi

forge script ./script/Deploy.s.sol:DeployScript --sig "deploy(address)" $1 --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --broadcast
