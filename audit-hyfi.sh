#!/bin/bash

# Configuration
RPC_URL="YOUR_RPC_URL"
INITIAL_EOA="YOUR_EOA_ADDRESS"  # Your deployer EOA
START_BLOCK="0"
END_BLOCK="latest"
FLAGGED_ADDRESSES_FILE="flagged_addresses.json"
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

# Admin function signatures from Aave V3
declare -A FUNCTION_SIGNATURES=(
    # Pool Admin Functions
    ["0x283d62ad"]="addPoolAdmin(address)"
    ["0x72a57b6b"]="removePoolAdmin(address)"
    ["0xf2fde38b"]="transferOwnership(address)"
    
    # Risk Admin Functions
    ["0x0d428140"]="setRiskAdmin(address)"
    ["0x2108375d"]="setRiskAdminAsAdmin(address,bool)"
    
    # Asset Listing Admin Functions
    ["0x7c4e560b"]="initReserves(ConfiguratorInputTypes.InitReserveInput[])"
    ["0xb888879f"]="dropReserve(address)"
    ["0x26a52521"]="updateAToken(ConfiguratorInputTypes.UpdateATokenInput)"
    ["0xd0ee0345"]="updateStableDebtToken(ConfiguratorInputTypes.UpdateDebtTokenInput)"
    ["0x28530a47"]="updateVariableDebtToken(ConfiguratorInputTypes.UpdateDebtTokenInput)"
    
    # Interest Rate Admin Functions
    ["0x8a751a60"]="setReserveInterestRateStrategyAddress(address,address)"
    ["0xc9cc5c52"]="setReserveStableRateBorrowing(address,bool)"
    ["0xe4dd8b74"]="configureReserveAsCollateral(address,uint256,uint256,uint256)"
    
    # Oracle Admin Functions
    ["0x56b49acd"]="setPriceOracle(address)"
    ["0x127af1c2"]="setAssetSources(address[],address[])"
    ["0x0c7fbb8c"]="setFallbackOracle(address)"
    
    # Bridge Admin Functions
    ["0x1437feaa"]="updateBridgeProtocolFee(uint256)"
    ["0xd1fd27b3"]="updateFlashloanPremiumTotal(uint256)"
    ["0xc9b4427f"]="updateFlashloanPremiumToProtocol(uint256)"
    
    # Fee Admin Functions
    ["0x1aa6cd37"]="setPoolPause(bool)"
    ["0xc6d67e71"]="updateFlashloanPremiums(uint128,uint128)"
    
    # Emergency Admin Functions
    ["0x7f51bb1f"]="setEmergencyAdmin(address)"
    ["0x4926a2c3"]="setPoolPaused(bool)"
    ["0x2c8e3b4c"]="freezeReserve(address)"
    ["0xb9a7b622"]="unfreezeReserve(address)"
    
    # Debt Ceiling Admin Functions
    ["0xd41b9f0d"]="setDebtCeiling(address,uint256)"
    ["0x4f279fb7"]="setBorrowableInIsolation(address,bool)"
    ["0xc04a8a10"]="setBorrowCap(address,uint256)"
    ["0xd9adda85"]="setSupplyCap(address,uint256)"
    ["0x4b519757"]="setLiquidationProtocolFee(address,uint256)"
    ["0x5ea74161"]="setEModeCategory(uint8,DataTypes.EModeCategory)"
    ["0xa8d61e8d"]="setAssetEModeCategory(address,uint8)"
    ["0x257e5c06"]="setUnbackedMintCap(address,uint256)"
    
    # Liquidation Admin Functions
    ["0x4efe9776"]="setLiquidationFee(uint256)"
    ["0x1aa3f283"]="setLiquidationThreshold(address,uint256)"
    ["0x1aa3a7f9"]="setLiquidationRatio(uint256)"
    
    # Reserve Factor Admin Functions
    ["0xb0fb6dd7"]="setReserveFactor(address,uint256)"
    ["0x474932a5"]="setReserveFreeze(address,bool)"
    
    # Token Implementation Admin Functions
    ["0x39928f6a"]="setReserveATokenImpl(address,address)"
    ["0x56459088"]="setReserveStableDebtImpl(address,address)"
    ["0x2a47b36b"]="setReserveVariableDebtImpl(address,address)"
    
    # Treasury Admin Functions
    ["0xf0bd2c0i"]="setTreasury(address)"
    ["0x89428b56"]="setTreasuryFee(uint256)"
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
    local name="${FUNCTION_SIGNATURES[$signature]}"
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

    # Get transactions where address is 'from'
    echo -e "\n📤 Outgoing transactions:"
    cast logs --rpc-url $RPC_URL --from-block $START_BLOCK_NUM --to-block ${END_BLOCK_NUM:-$END_BLOCK} --sender $ADDRESS | while read -r tx; do
        echo -e "\n---Transaction---"
        tx_hash=$(echo $tx | jq -r '.transactionHash')
        echo "Hash: $tx_hash"
        
        tx_details=$(cast tx $tx_hash --rpc-url $RPC_URL)
        
        # Get block number and timestamp
        block_number=$(echo "$tx_details" | grep "block" | awk '{print $2}')
        get_timestamp $block_number
        
        # Get from address
        from_addr=$(echo "$tx_details" | grep "from" | awk '{print $2}')
        echo "From: $(format_address "$from_addr")"
        
        # Get to address
        to_addr=$(echo "$tx_details" | grep "to" | awk '{print $2}')
        echo "To: $(format_address "$to_addr")"
        
        check_flag "$to_addr"
        
        # Get input data
        input_data=$(echo "$tx_details" | grep "input" | cut -d' ' -f2-)
        decode_function "$input_data" "$to_addr" "$block_number"
        
        # Get value
        value=$(echo "$tx_details" | grep "value" | awk '{print $2}')
        if [ ! -z "$value" ] && [ "$value" != "0" ]; then
            echo "💎 Value: $(cast --from-wei $value) ETH"
        fi
        
        # Get gas usage
        gas_used=$(cast receipt $tx_hash --rpc-url $RPC_URL | grep "gasUsed" | awk '{print $2}')
        gas_price=$(echo "$tx_details" | grep "gasPrice" | awk '{print $2}')
        if [ ! -z "$gas_used" ] && [ ! -z "$gas_price" ]; then
            gas_cost_wei=$((gas_used * gas_price))
            echo "⛽ Gas Used: $gas_used"
            echo "⛽ Gas Cost: $(cast --from-wei $gas_cost_wei) ETH"
        fi
    done
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
