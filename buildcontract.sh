#!/bin/bash

#Build Flag
PARAM=$1
####################################    Constants    ##################################################

#depends on mainnet or testnet
# NODE="--node https://rpc.junomint.com:443"
# CHAIN_ID=juno-1
# DENOM="ujuno"
# CONTRACT_VMARBLE="juno18cpnn3cnrr9xq7r0cqp7shl7slasf27nrmskw4rrw8c6hyp8u7rqe2nulg"

NODE="--node https://rpc.juno.giansalex.dev:443"
#NODE="--node https://rpc.uni.junomint.com:443"
CHAIN_ID=uni-2
DENOM="ujunox"
CONTRACT_VMARBLE="juno1j5rl5sy40nmlqyugphgh5hnyrmj2cc5h7swy9x8rm0jkxy566nlqcx0jmv"

#not depends
NODECHAIN=" $NODE --chain-id $CHAIN_ID"
TXFLAG=" $NODECHAIN --gas-prices 0.03$DENOM --gas auto --gas-adjustment 1.3"
WALLET="--from workshop"
WASMFILE="artifacts/sale.wasm"

FILE_UPLOADHASH="uploadtx.txt"
FILE_SALE_CONTRACT_ADDR="contractaddr.txt"
FILE_CODE_ID="code.txt"

ADDR_WORKSHOP="juno1htjut8n7jv736dhuqnad5mcydk6tf4ydeaan4s"
ADDR_ACHILLES="juno15fg4zvl8xgj3txslr56ztnyspf3jc7n9j44vhz"
ADDR_ARBITER="juno1m0snhthwl80hweae54fwre97y47urlxjf5ua6j"

###################################################################################################
###################################################################################################
###################################################################################################
###################################################################################################
#Environment Functions
CreateEnv() {
    sudo apt-get update && sudo apt upgrade -y
    sudo apt-get install make build-essential gcc git jq chrony -y
    wget https://golang.org/dl/go1.17.3.linux-amd64.tar.gz
    sudo tar -C /usr/local -xzf go1.17.3.linux-amd64.tar.gz
    rm -rf go1.17.3.linux-amd64.tar.gz

    export GOROOT=/usr/local/go
    export GOPATH=$HOME/go
    export GO111MODULE=on
    export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
    
    rustup default stable
    rustup target add wasm32-unknown-unknown

    git clone https://github.com/CosmosContracts/juno
    cd juno
    git fetch
    git checkout v2.1.0
    make install

    rm -rf juno

    junod keys import workshop workshop.key

}

#Contract Functions

#Build Optimized Contracts
OptimizeBuild() {

    echo "================================================="
    echo "Optimize Build Start"
    
    docker run --rm -v "$(pwd)":/code \
        --mount type=volume,source="$(basename "$(pwd)")_cache",target=/code/target \
        --mount type=volume,source=registry_cache,target=/usr/local/cargo/registry \
        cosmwasm/rust-optimizer:0.12.4
}

RustBuild() {

    echo "================================================="
    echo "Rust Optimize Build Start"

    RUSTFLAGS='-C link-arg=-s' cargo wasm

    mkdir artifacts
    cp target/wasm32-unknown-unknown/release/sale.wasm $WASMFILE
}

#Writing to FILE_UPLOADHASH
Upload() {
    echo "================================================="
    echo "Upload $WASMFILE"
    
    UPLOADTX=$(junod tx wasm store $WASMFILE $WALLET $TXFLAG --output json -y | jq -r '.txhash')
    echo "Upload txHash:"$UPLOADTX
    
    #save to FILE_UPLOADHASH
    echo $UPLOADTX > $FILE_UPLOADHASH
    echo "wrote last transaction hash to $FILE_UPLOADHASH"
}

UploadTest() {
    echo "================================================="
    echo "Upload $WASMFILE"
    
    junod tx wasm store $WASMFILE $WALLET $TXFLAG --output json -y
    
}

#Read code from FILE_UPLOADHASH
GetCode() {
    echo "================================================="
    echo "Get code from transaction hash written on $FILE_UPLOADHASH"
    
    #read from FILE_UPLOADHASH
    TXHASH=$(cat $FILE_UPLOADHASH)
    echo "read last transaction hash from $FILE_UPLOADHASH"
    echo $TXHASH
    
    QUERYTX="junod query tx $TXHASH $NODECHAIN --output json"
	CODE_ID=$(junod query tx $TXHASH $NODECHAIN --output json | jq -r '.logs[0].events[-1].attributes[0].value')
	echo "Contract Code_id:"$CODE_ID

    #save to FILE_CODE_ID
    echo $CODE_ID > $FILE_CODE_ID
}

#Instantiate Contract
Instantiate() {
    echo "================================================="
    echo "Instantiate Contract"
    
    #read from FILE_CODE_ID
    CODE_ID=$(cat $FILE_CODE_ID)
    junod tx wasm instantiate $CODE_ID '{"cw20_address":"'$CONTRACT_VMARBLE'", "denom":"ujunox", "price":"100", "maxamount":"10"}' --label "vMarbleSale" $WALLET $TXFLAG -y
}

#Get Instantiated Contract Address
GetContractAddress() {
    echo "================================================="
    echo "Get contract address by code"
    
    #read from FILE_CODE_ID
    CODE_ID=$(cat $FILE_CODE_ID)
    CONTRACT_ADDR=$(junod query wasm list-contract-by-code $CODE_ID $NODECHAIN --output json | jq -r '.contracts[0]')
    
    echo "Contract Address : "$CONTRACT_ADDR

    #save to FILE_SALE_CONTRACT_ADDR
    echo $CONTRACT_ADDR > $FILE_SALE_CONTRACT_ADDR
}


###################################################################################################
###################################################################################################
###################################################################################################
###################################################################################################
#Send initial tokens
SendInitialFund() {
    CONTRACT_SALE=$(cat $FILE_SALE_CONTRACT_ADDR)
    junod tx wasm execute $CONTRACT_VMARBLE '{"send":{"amount":"1000000000","contract":"'$CONTRACT_SALE'","msg":""}}' $WALLET $TXFLAG
}

SetPrice() {
    CONTRACT_SALE=$(cat $FILE_SALE_CONTRACT_ADDR)
    junod tx wasm execute $CONTRACT_SALE '{"set_price":{"denom":"ujunox", "price":"100"}}' $WALLET $TXFLAG
}

WithdrawAll() {
    CONTRACT_SALE=$(cat $FILE_SALE_CONTRACT_ADDR)
    junod tx wasm execute $CONTRACT_SALE '{"withdraw_all":{}}' $WALLET $TXFLAG
}

PrintGetInfo() {
    CONTRACT_SALE=$(cat $FILE_SALE_CONTRACT_ADDR)
    junod query wasm contract-state smart $CONTRACT_SALE '{"get_info":{}}' $NODECHAIN
}

PrintPoolContractState() {
    junod query wasm list-code $NODECHAIN --output json
    junod query wasm list-contract-by-code 16 $NODECHAIN
    
}

#################################### End of Function ###################################################
if [[ $PARAM == "" ]]; then
    RustBuild
    Upload
sleep 5
    GetCode
sleep 5
    Instantiate
sleep 8
    GetContractAddress
sleep 5
    SendInitialFund
sleep 5
    SetPrice
sleep 5
    PrintGetInfo
else
    $PARAM
fi

# OptimizeBuild
# Upload
# GetCode
# Instantiate
# GetContractAddress
# CreateEscrow
# TopUp

