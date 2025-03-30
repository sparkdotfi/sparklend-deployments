#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
    export $(cat .env | grep -v '#' | xargs)
else
    echo "❌ .env file not found"
    exit 1
fi

# Verify API key is present
if [ -z "$PARSEC_API_KEY" ]; then
    echo "❌ PARSEC_API_KEY not found in .env file"
    exit 1
fi

# Configuration
RPC_URL="https://rpc.purroofgroup.com"
INITIAL_EOA="0x096f03ae4c33E9C9C0EC0dcbA29645382c38896b"  # Your deployer EOA
START_BLOCK="0"
END_BLOCK="latest"
FLAGGED_ADDRESSES_FILE="flagged-addresses.json"
SHOW_FULL_ADDRESSES=false  # Default to short addresses

# Process command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --full-addresses)
            SHOW_FULL_ADDRESSES=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--full-addresses]"
            exit 1
            ;;
    esac
done

# Known function signatures
TRANSFER_OWNERSHIP_SIG="0xf2fde38b"  # transferOwnership(address)
ADD_POOL_ADMIN_SIG="0x283d62ad"      # addPoolAdmin(address)
REMOVE_POOL_ADMIN_SIG="0x72a57b6b"    # removePoolAdmin(address)

# Address name mapping (example format)
declare -A ADDRESS_NAMES=(
    ["0x1234..."]="Deployer EOA"
    ["0x5678..."]="Pool Admin Multisig"
    ["0x9abc..."]="Emergency Admin"
    # Add more address mappings here
)

# Declare associative arrays for admin tracking
declare -A ADMIN_START_BLOCKS
declare -A ADMIN_END_BLOCKS
declare -A ACTIVE_ADMINS


# Event signatures for Aave V3 admin functions
declare -A EVENT_SIGNATURES=(
    # Pool Admin Events
    ["0x8936e1f096bf0a8c9df862b3d1d5b82774cad78116200175f00b5b7ba3010b0e"]="PoolAdminAdded(address)"
    ["0x787a2e12f4a55b658b8f573c32432ee11a5e8b51677d1bdad8b2ec946f939ba8"]="PoolAdminRemoved(address)"
    
    # Ownership Events
    ["0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0"]="OwnershipTransferred(address,address)"
    
    # Risk Admin Events
    ["0x5c29179aba6942020a8a2d38f65de02fb6b7f784e7f049ed3a3cab97621859b7"]="RiskAdminChanged(address)"
    ["0x4c40659c10c63e725521d19e02459e8d5c116e6f1c9518fe7697afc23d5ba87c"]="RiskAdminAdminStatusChanged(address,bool)"
    
    # Asset Listing Events
    ["0x3a0ca721fc364424566385a1aa271ed508cc2c0949c2272575fb3013a163a45f"]="ReserveInitialized(address,address,address,address,address)"
    ["0x7596e9ad0f8c1522f5da22de3328d36735a758f00f01911ee208ce69c1e1d67a"]="ReserveDropped(address)"
    ["0x21778c2565e221074beeaff7e0f4f32db2f7baa7d8aa9866f4894a5692df9f8a"]="ATokenUpgraded(address,address,address)"
    ["0xf0cd54bd2a0c82ce0f97a0d010960c4c69d0723cf9c6a1ba935336cba0f56c52"]="StableDebtTokenUpgraded(address,address,address)"
    ["0x1140de0ca580c619c8e2800cc7b6bc3b5b44e49d6ee646046e2901e9da7c0c64"]="VariableDebtTokenUpgraded(address,address,address)"
    
    # Interest Rate Events
    ["0x804c9b842b2748a22bb64b345453a3de7ca54a6ca45ce00d415894979e22897a"]="ReserveInterestRateStrategyChanged(address,address)"
    ["0x44c58d81365b66dd4b1a7f36c25aa97b8c71c361ee4937adc1a00000227db5dd"]="ReserveStableBorrowingChanged(address,bool)"
    ["0x7c4717a4fb15fc91c25bd1cefd23afbf7aeef690a7c6bc7f28688f3c05f418af"]="CollateralConfigurationChanged(address,uint256,uint256,uint256)"
    
    # Oracle Events
    ["0xb5e6e01e79f91267dc17b4e6314d5d4d03593d2ceee0fbb452b97872e6790c32"]="PriceOracleUpdated(address)"
    ["0xece574603820d07bc9b91f2a932baadf4628aabcb8afba49776529c14a6104b2"]="AssetSourcesUpdated(address[],address[])"
    ["0x23fd8479a7666ad832524b342fc2de61c3ea57e15f6cd1e7b23fdc68a0d48c95"]="FallbackOracleUpdated(address)"
    
    # Bridge Events
    ["0xfb298d55d45046ac66fd3670e7038b38892544334d295f18ea19cc265cfcc17c"]="BridgeProtocolFeeUpdated(uint256)"
    ["0x5c37ab68009b2e3eac642626b5a755c12c86f7019e2bf0c1e86daa4f2fb62f56"]="FlashloanPremiumTotalUpdated(uint256)"
    ["0x973aa4ac1d3c0e4a36605d6958f10df54b1aa94ad83d5e04fa45e117f9619b54"]="FlashloanPremiumToProtocolUpdated(uint256)"
    
    # Fee Events
    ["0x9cd8e40c71ac7cfb11ea9c1b7c2d0ea25f46c8b895f062d0aed3e75ab897ca37"]="PoolPaused()"
    ["0x7aa1a54bf7d0ef6e800051dd2dd44ef081f1be55c040e965f33f17169b1855f3"]="FlashloanPremiumsUpdated(uint128,uint128)"
    
    # Emergency Admin Events
    ["0x282d3fdf67d7d409bb93f1605448dc624c3d08f66b5e5fd9cd782294d24954ba"]="EmergencyAdminChanged(address)"
    ["0xa82de37b1494f105507251375f1e97b7c5d27b11c7f9ed9d33e5911f2cd89cdd"]="ReservePaused(address)"
    ["0x9cd8e40c71ac7cfb11ea9c1b7c2d0ea25f46c8b895f062d0aed3e75ab897ca37"]="PoolPaused()"
    ["0xf7b9e556d3ce86f7c2def69b62842fc1c1f4c3c92b0902ab0f716581d32cf0f3"]="ReserveFrozen(address)"
    ["0x33af3a26c09774d0b04de97d7c56fd72f6f61a4a4bc3e9c01ae6c6512d2ef5bb"]="ReserveUnfrozen(address)"
    
    # Debt Ceiling Events
    ["0xe7f3a35c8ac8d9df0614e1f5d5e85ab455e7c29226c053aa782b893e0a0ff42a"]="DebtCeilingChanged(address,uint256)"
    ["0x377d0f645ca83af9e593e2c444cd22d3ee874e57f28e2ac1c62f2c9d4e5e9f08"]="BorrowableInIsolationChanged(address,bool)"
    ["0x0f08c2a8f456a6e747c2fd5c6c06d814f6c9545d131a7bb17ae9be42b5df8fe6"]="BorrowCapChanged(address,uint256)"
    ["0xd1e6e3b680a96f6c9c8e7c54df1c61d7c2593cc2bdf0c7c89a2a7831da8c1734"]="SupplyCapChanged(address,uint256)"
    ["0xf402011bd0f1fa047bbd7c1bb1fdc1f8d39eed103ae0fe96426f18ffdb6f5c7f"]="LiquidationProtocolFeeChanged(address,uint256)"
    ["0xc12b59ad5de0c1a57f5ca9940d3d16456d19df4ff1cf79859d19b8d2f08f0e32"]="EModeConfigured(uint8,DataTypes.EModeCategory)"
    ["0x22ac5cca01c44e998d456059ab4df64cc1e47e683b1d94435a72e6d1bf9e8708"]="ReserveEModeChanged(address,uint8)"
    ["0xbabe8ecd9307ef3007d97d9357c5c95b30e1142f41437998939ea3ac6212ec73"]="UnbackedMintCapChanged(address,uint256)"
    
    # Liquidation Events
    ["0x5548fb5e6c5aa4e3876cc8815e4874f85b82c8b4e2a8b0a4d2e6dc5b1e0c9e4e"]="LiquidationFeeChanged(uint256)"
    ["0x4d5c6f1745e85e013b09f314c55a54f4b5d4052dca45796a0570f15be8e2c118"]="LiquidationThresholdChanged(address,uint256)"
    ["0x648ccd8d881462d9d8e9c72e8b49f1eb9f75e1fd463fdc6a1e14a5b3a11b3ee0"]="LiquidationRatioChanged(uint256)"
    
    # Reserve Factor Events
    ["0x18037337d8a78008f752f7a441bc549c06eae9f2f803d5448f21843b875b7a8f"]="ReserveFactorChanged(address,uint256)"
    ["0x6fb68e476cf3531c74ab5ce7f303397a1f39ae3baf3c89d0a2d5e00c9ff85a58"]="ReserveFreezeChanged(address,bool)"
    
    # Treasury Events
    ["0xc890e9ad6431ca53be76ed57b3aaa5b37435a6dc76a33505e91d2531c4bf9c03"]="TreasuryChanged(address)"
    ["0x7757f7fb26f9c4ec0e11bc5e2e67358f69f3c3fe5dc42f2d66db8c39f4ec87fe"]="TreasuryFeeChanged(uint256)"
)

# Function to format address display
format_address() {
    local address=$1
    local name="${ADDRESS_NAMES[$address]:-Unknown}"
    
    if [ "$SHOW_FULL_ADDRESSES" = true ]; then
        echo "$address ($name)"
    else
        # Show first 6 and last 4 characters
        echo "${address:0:6}...${address: -4} ($name)"
    fi
}

# Function to check if address is flagged
check_flag() {
    local address=$1
    local flag=$(jq -r ".[\"${address,,}\"]" "$FLAGGED_ADDRESSES_FILE")
    if [ "$flag" != "null" ]; then
        echo "⚠️  FLAGGED: $flag"
    fi
}

# Function to get UTC timestamp from block
get_timestamp() {
    local block_number=$1
    local timestamp=$(cast block $block_number --rpc-url $RPC_URL | grep "timestamp" | awk '{print $2}')
    echo "🕒 $(date -u -d @$timestamp '+%Y-%m-%d %H:%M:%S UTC')"
}

# Function to get function name from signature
get_function_name() {
    local signature=$1
    local name="${EVENT_SIGNATURES[$signature]}"
    if [ -z "$name" ]; then
        # If not found in our admin functions list, try cast 4byte
        name=$(cast 4byte "$signature" 2>/dev/null || echo "Unknown function")
    fi
    echo "$name"
}

# Function to decode transaction input data and track admin changes
decode_function() {
    local input=$1
    local to_addr=$2
    local block_number=$3
    
    if [ ${#input} -ge 10 ]; then
        local signature="${input:0:10}"
        local function_name=$(get_function_name "$signature")
        echo "📝 Function: $function_name"

        # Track admin changes based on signature
        case $signature in
            "0x283d62ad") # addPoolAdmin
                local new_admin=$(echo "$input" | cut -c 11- | cast --abi-decode "addPoolAdmin(address)" 2>/dev/null)
                echo "👤 New pool admin: $(format_address "$new_admin")"
                ADMIN_START_BLOCKS["$new_admin"]=$block_number
                ACTIVE_ADMINS["$new_admin"]=1
                ;;
            "0x72a57b6b") # removePoolAdmin
                local removed_admin=$(echo "$input" | cut -c 11- | cast --abi-decode "removePoolAdmin(address)" 2>/dev/null)
                echo "🚫 Removed pool admin: $(format_address "$removed_admin")"
                ADMIN_END_BLOCKS["$removed_admin"]=$block_number
                unset ACTIVE_ADMINS["$removed_admin"]
                ;;
            "0x0d428140") # setRiskAdmin
                local new_risk_admin=$(echo "$input" | cut -c 11- | cast --abi-decode "setRiskAdmin(address)" 2>/dev/null)
                echo "🔒 New risk admin: $(format_address "$new_risk_admin")"
                ;;
            "0x7f51bb1f") # setEmergencyAdmin
                local new_emergency_admin=$(echo "$input" | cut -c 11- | cast --abi-decode "setEmergencyAdmin(address)" 2>/dev/null)
                echo "🚨 New emergency admin: $(format_address "$new_emergency_admin")"
                ;;
        esac
    elif [ ${#input} -eq 0 ]; then
        echo "💰 ETH Transfer"
    fi
}

analyze_address_txns() {
    local ADDRESS=$1
    local START_BLOCK_NUM=$2
    local END_BLOCK_NUM=$3

    echo "🔍 Analyzing transactions for: $(format_address "$ADDRESS")"
    echo "📅 Period: Block $START_BLOCK_NUM to ${END_BLOCK_NUM:-latest}"

    # Call Parsec API to get transactions with logs
    local transactions=$(curl -s "https://api.parsec.finance/api/rest/transactions\
?addresses=$ADDRESS\
&chains=hyper_evm\
&apiKey=$PARSEC_API_KEY")

    # Process each transaction and its logs
    echo "$transactions" | jq -c '.[]' | while read -r tx; do
        local tx_hash=$(echo "$tx" | jq -r '.hash')
        local block_number=$(echo "$tx" | jq -r '.blockNumber')
        local timestamp=$(echo "$tx" | jq -r '.timestamp')
        
        # Get logs from the transaction
        local logs=$(echo "$tx" | jq -c '.logs[]?')
        
        # Check if any logs match our admin events
        if [ ! -z "$logs" ]; then
            local found_admin_event=false
            
            echo "$logs" | while read -r log; do
                local topics=$(echo "$log" | jq -r '.topics[]')
                local first_topic=$(echo "$topics" | head -n1)
                
                # Check if this is an admin event we're tracking
                if [ ! -z "${EVENT_SIGNATURES[$first_topic]}" ]; then
                    found_admin_event=true
                    
                    echo -e "\n---Admin Event Found---"
                    echo "Transaction: $tx_hash"
                    echo "Block: $block_number"
                    echo "🕒 $(date -u -d @$timestamp '+%Y-%m-%d %H:%M:%S UTC')"
                    
                    # Decode the event
                    decode_event "$log"
                fi
            done
        fi
    done
}

# Function to decode events and their parameters
decode_event() {
    local log=$1
    local topics=$(echo "$log" | jq -r '.topics[]')
    local first_topic=$(echo "$topics" | head -n1)
    local event_name="${EVENT_SIGNATURES[$first_topic]}"
    local data=$(echo "$log" | jq -r '.data')
    
    echo "🔔 Event: $event_name"
    
    # Decode based on event type
    case "$first_topic" in
        # Ownership events
        "0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0")
            local prev_owner=$(echo "$topics" | sed -n '2p' | cut -c 27-)
            local new_owner=$(echo "$topics" | sed -n '3p' | cut -c 27-)
            echo "   Previous Owner: 0x$prev_owner"
            echo "   New Owner: 0x$new_owner"
            ;;
            
        # Pool Admin events
        "0x8936e1f096bf0a8c9df862b3d1d5b82774cad78116200175f00b5b7ba3010b0e")
            local new_admin=$(echo "$topics" | sed -n '2p' | cut -c 27-)
            echo "   New Pool Admin: 0x$new_admin"
            ;;
            
        # Risk Admin events
        "0x5c29179aba6942020a8a2d38f65de02fb6b7f784e7f049ed3a3cab97621859b7")
            local new_risk_admin=$(echo "$topics" | sed -n '2p' | cut -c 27-)
            echo "   New Risk Admin: 0x$new_risk_admin"
            ;;
            
        # Reserve events
        "0x3a0ca721fc364424566385a1aa271ed508cc2c0949c2272575fb3013a163a45f")
            local reserve=$(echo "$topics" | sed -n '2p' | cut -c 27-)
            echo "   Reserve: 0x$reserve"
            # Decode additional parameters from data field
            ;;
            
        # Add more specific decodings for other events...
    esac
    
    # Show raw data for debugging
    echo "   Raw Data: $data"
}

# First analyze initial EOA transactions
echo "Starting transaction analysis..."
analyze_address_txns "$INITIAL_EOA" "$START_BLOCK"

# Process any discovered admin changes
for admin in "${!ACTIVE_ADMINS[@]}"; do
    echo -e "\n\n====================================="
    echo "Analyzing temporary pool admin: $(format_address "$admin")"
    echo "====================================="
    
    start_block="${ADMIN_START_BLOCKS[$admin]}"
    end_block="${ADMIN_END_BLOCKS[$admin]:-latest}"
    
    analyze_address_txns "$admin" "$start_block" "$end_block"
done

# Print summary
echo -e "\n📊 Admin Activity Summary:"
for admin in "${!ADMIN_START_BLOCKS[@]}"; do
    echo "Address: $(format_address "$admin")"
    echo "Active from block: ${ADMIN_START_BLOCKS[$admin]}"
    if [ ! -z "${ADMIN_END_BLOCKS[$admin]}" ]; then
        echo "Removed at block: ${ADMIN_END_BLOCKS[$admin]}"
    else
        echo "Still active"
    fi
    echo "-------------------"
done

get_all_transactions() {
    local ADDRESS=$1
    local START_BLOCK=$2
    local END_BLOCK=$3

    echo "Getting all transactions for: $(format_address "$ADDRESS")"
    
    # Get transactions where address is 'from'
    echo -e "\n📤 Outgoing transactions:"
    cast rpc eth_getLogs "{\"fromBlock\":\"0x$(printf '%x' $START_BLOCK)\",\"toBlock\":\"0x$(printf '%x' $END_BLOCK)\",\"address\":\"$ADDRESS\"}" --rpc-url $RPC_URL

    # Alternative: If you have an Etherscan API key
    # ETHERSCAN_API_KEY="your-api-key"
    # curl "https://api.etherscan.io/api?module=account&action=txlist&address=$ADDRESS&startblock=$START_BLOCK&endblock=$END_BLOCK&sort=asc&apikey=$ETHERSCAN_API_KEY"
}

# Or using cast directly with trace calls
get_transactions_alternative() {
    local ADDRESS=$1
    local START_BLOCK=$2
    local END_BLOCK=$3

    # Get normal transactions
    cast block-number --rpc-url $RPC_URL > /dev/null # ensure RPC is working
    
    # Get all blocks in range and filter for our address
    for ((block=$START_BLOCK; block<=$END_BLOCK; block++)); do
        cast block $block --rpc-url $RPC_URL --json | \
        jq --arg addr "${ADDRESS,,}" '.transactions[] | select(.from == $addr or .to == $addr)'
    done
}

# Get the deployer EOA address
DEPLOYER=$(jq -r '.accounts.deployer' "$FLAGGED_ADDRESSES_FILE")

# Function to get event logs for contract interactions
get_contract_interactions() {
    local from_address=$1
    local contract_address=$2
    local contract_name=$3
    local start_block=$4
    local end_block=$5

    echo "🔍 Analyzing interactions between $from_address and $contract_name ($contract_address)"
    
    # Get all events where the EOA interacted with this contract
    cast rpc eth_getLogs "{
        \"fromBlock\": \"0x$(printf '%x' $start_block)\",
        \"toBlock\": \"0x$(printf '%x' $end_block)\",
        \"address\": \"$contract_address\",
        \"topics\": [[null], [\"0x000000000000000000000000${from_address#0x}\"]],
        \"fromAddress\": \"$from_address\"
    }" --rpc-url $RPC_URL | jq -r '.[]' | while read -r event; do
        process_event "$event" "$contract_name"
    done
}

process_event() {
    local event=$1
    local contract_name=$2
    
    # Extract event details
    local tx_hash=$(echo "$event" | jq -r '.transactionHash')
    local block_number=$(echo "$event" | jq -r '.blockNumber')
    local topics=$(echo "$event" | jq -r '.topics[]')
    
    echo -e "\n---Event in $contract_name---"
    echo "Transaction: $tx_hash"
    echo "Block: $block_number"
    
    # Get transaction details
    local tx_details=$(cast tx "$tx_hash" --rpc-url $RPC_URL)
    
    # Get timestamp
    local timestamp=$(cast block "$block_number" --rpc-url $RPC_URL | grep "timestamp" | awk '{print $2}')
    echo "🕒 $(date -u -d @$timestamp '+%Y-%m-%d %H:%M:%S UTC')"
    
    # Get function signature
    local input_data=$(echo "$tx_details" | grep "input" | cut -d' ' -f2-)
    if [ ${#input_data} -ge 10 ]; then
        local signature="${input_data:0:10}"
        local function_name=$(get_function_name "$signature")
        echo "📝 Function: $function_name"
    fi
    
    # Get event signature and try to decode it
    local event_sig=$(echo "$topics" | head -n1)
    echo "Event signature: $event_sig"
    decode_event "$topics"
}

# Function to fetch all transactions from Parsec API
get_transactions() {
    local address=$1
    echo "Fetching transactions for $address..."
    
    curl -s "https://api.parsec.finance/api/rest/transactions\
?addresses=$address\
&chains=hyper_evm\
&apiKey=$PARSEC_API_KEY" | jq '.'
}

# Function to analyze a contract deployment transaction
analyze_deployment() {
    local tx_hash=$1
    echo -e "\n---Analyzing Transaction---"
    echo "Transaction: $tx_hash"
    
    # Get transaction details
    local tx_details=$(cast tx "$tx_hash" --rpc-url "$RPC_URL")
    
    # Get receipt to check if it's a contract deployment
    local receipt=$(cast receipt "$tx_hash" --rpc-url "$RPC_URL")
    local contract_address=$(echo "$receipt" | grep "contractAddress" | awk '{print $2}')
    
    # Get block number and timestamp
    local block_number=$(echo "$tx_details" | grep "block" | awk '{print $2}')
    local timestamp=$(cast block "$block_number" --rpc-url "$RPC_URL" | grep "timestamp" | awk '{print $2}')
    
    echo "🕒 $(date -u -d @$timestamp '+%Y-%m-%d %H:%M:%S UTC')"
    
    if [ ! -z "$contract_address" ]; then
        echo "📍 Contract Deployment at: $contract_address"
        # Get contract code
        local code=$(cast code "$contract_address" --rpc-url "$RPC_URL")
    else
        echo "🔄 Regular transaction"
        local to_address=$(echo "$tx_details" | grep "to" | awk '{print $2}')
        echo "To: $to_address"
    fi
}
