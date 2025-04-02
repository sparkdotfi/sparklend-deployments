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
INITIAL_EOA="0xc2b3075fb1ac9f5ecc1e2c07da8bccc43e7083fb"  # Your deployer EOA
START_BLOCK="0"
END_BLOCK="latest"
FLAGGED_ADDRESSES_FILE="flagged-addresses.json"
SHOW_FULL_ADDRESSES=true  # Default to short addresses
FILTER_OWNERSHIP_EVENTS=false  # Default to showing all events
# TXN_LIMIT="65"
TXN_LIMIT="84"
# TXN_SKIP=13
TXN_SKIP=0
PURRSEC_URL="https://purrsec.com/tx"

# Helper function to convert date string to timestamp
convert_to_timestamp() {
    local date_str=$1
    
    # If input is already a Unix timestamp (all digits)
    if [[ "$date_str" =~ ^[0-9]+$ ]]; then
        echo "$date_str"
        return 0
    fi
    
    # Replace T with space if it exists
    date_str=${date_str/T/ }
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # For macOS
        local formatted_date=$(echo "$date_str" | sed 's/-/\//g')
        date -j -f "%Y/%m/%d %H:%M:%S" "$formatted_date" "+%s"
    else
        # For Linux
        date -d "$date_str" "+%s"
    fi
}

# Initialize timestamps
# DEFAULT_CUTOFF="2025-02-26T00:00:00"
TIMESTAMP_BEFORE="" # Default to no upper cutoff
TIMESTAMP_AFTER=""  # Default to no lower cutoff

# Helper function to format timestamp to human readable
format_timestamp_human() {
    local timestamp=$1
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS requires specific formatting
        date -j -f "%s" "$timestamp" "+%Y-%m-%d %H:%M:%S UTC" 2>/dev/null
    else
        # Linux
        date -d "@$timestamp" "+%Y-%m-%d %H:%M:%S UTC"
    fi
}

# Test the timestamp conversion immediately after setting it
if [ ! -z "$TIMESTAMP_BEFORE" ]; then
    converted_timestamp=$(convert_to_timestamp "$TIMESTAMP_BEFORE")
    if [ $? -eq 0 ]; then
        TIMESTAMP_BEFORE=$converted_timestamp
        echo "Converted before timestamp: $(format_timestamp_human "$TIMESTAMP_BEFORE")"
    else
        echo "Error converting before timestamp. Using default (no cutoff)."
        TIMESTAMP_BEFORE=""
    fi
fi

# Process command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --full-addresses)
            SHOW_FULL_ADDRESSES=true
            shift
            ;;
        --ownership-only)
            FILTER_OWNERSHIP_EVENTS=true
            shift
            ;;
        --limit)
            if [[ -z "$2" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
                echo "Error: --limit requires a positive number"
                exit 1
            fi
            TXN_LIMIT=$2
            shift 2
            ;;
        --skip)
            if [[ -z "$2" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
                echo "Error: --skip requires a positive number"
                exit 1
            fi
            TXN_SKIP=$2
            shift 2
            ;;
        --before)
            if [[ -z "$2" ]]; then
                echo "Error: --before requires a timestamp argument (YYYY-MM-DD HH:MM:SS)"
                exit 1
            fi
            TIMESTAMP_BEFORE=$(convert_to_timestamp "$2")
            if [ $? -ne 0 ] || [ -z "$TIMESTAMP_BEFORE" ]; then
                echo "Error: Invalid timestamp format for --before. Please use YYYY-MM-DD HH:MM:SS"
                exit 1
            fi
            shift 2
            ;;
        --after)
            if [[ -z "$2" ]]; then
                echo "Error: --after requires a timestamp argument (YYYY-MM-DD HH:MM:SS)"
                exit 1
            fi
            TIMESTAMP_AFTER=$(convert_to_timestamp "$2")
            if [ $? -ne 0 ] || [ -z "$TIMESTAMP_AFTER" ]; then
                echo "Error: Invalid timestamp format for --after. Please use YYYY-MM-DD HH:MM:SS"
                exit 1
            fi
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--full-addresses] [--ownership-only] [--before 'YYYY-MM-DD HH:MM:SS'] [--after 'YYYY-MM-DD HH:MM:SS'] [--limit N] [--skip N]"
            exit 1
            ;;
    esac
done

# Print time range if specified
if [ ! -z "$TIMESTAMP_AFTER" ] || [ ! -z "$TIMESTAMP_BEFORE" ]; then
    echo "🕒 Filtering transactions by time range:"
    if [ ! -z "$TIMESTAMP_AFTER" ]; then
        echo "   After: $(format_timestamp_human "$TIMESTAMP_AFTER")"
    fi
    if [ ! -z "$TIMESTAMP_BEFORE" ]; then
        echo "   Before: $(format_timestamp_human "$TIMESTAMP_BEFORE")"
    fi
fi

# Address name mapping
# Address name mapping
declare -A ADDRESS_NAMES=(
    ["0x0000000000000000000000000000000000000000"]="Burn Address"
    ["0x096f03ae4c33e9c9c0ec0dcba29645382c38896b"]="HypurrFi Deployer"
    ["0xc2b3075fb1ac9f5ecc1e2c07da8bccc43e7083fb"]="HypurrFi Team Multisig"
    ["0xafe1b6f29217fc917e3f9c725de07fdf4506f786"]="ReserveInitializer 1"
    ["0xa2d096e01b73048772c0fb3ad6a789af9788db08"]="ReserveInitializer 2"
    ["0x94e8396e0869c9f2200760af0621afd240e1cf38"]="wstHYPE"
    ["0x5555555555555555555555555555555555555555"]="WHYPE"
    # Add any other default mappings here
)

# Declare associative arrays for admin tracking
declare -A ADMIN_START_BLOCKS
declare -A ADMIN_END_BLOCKS
declare -A ACTIVE_ADMINS

# Event signatures for Aave V3 admin functions
declare -A EVENT_SIGNATURES=(
    # ACL Events
    ["0xe9cf53972264dc95304fd424458745019ddfca0e37ae8f703d74772c41ad115b"]="ACLAdminUpdated(address,address)"
    ["0x2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d"]="RoleGranted(bytes32,address,address)"
    ["0xf6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b"]="RoleRevoked(bytes32,address,address)"
    
    # PoolAddressesProvider Events
    ["0xb30efa04327bb8a537d61cc1e5c48095345ad18ef7cc04e6bacf7dfb6caaf507"]="ACLManagerUpdated(address,address)"
    ["0x9ef0e8c8e52743bb38b83b17d9429141d494b8041ca6d616a6c77cebae9cd8b7"]="AddressSet(bytes32,address,address)"
    ["0x3bbd45b5429b385e3fb37ad5cd1cd1435a3c8ec32196c7937597365a3fd3e99c"]="AddressSetAsProxy(bytes32,address,address,address)"
    ["0xe685c8cdecc6030c45030fd54778812cb84ed8e4467c38294403d68ba7860823"]="MarketIdSet(string,string)"
    ["0x8932892569eba59c8382a089d9b732d1f49272878775235761a2a6b0309cd465"]="PoolConfiguratorUpdated(address,address)"
    ["0xc853974cfbf81487a14a23565917bee63f527853bcb5fa54f2ae1cdf8a38356d"]="PoolDataProviderUpdated(address,address)"
    ["0x90affc163f1a2dfedcd36aa02ed992eeeba8100a4014f0b4cdc20ea265a66627"]="PoolUpdated(address,address)"
    ["0x5326514eeca90494a14bedabcff812a0e683029ee85d1e23824d44fd14cd6ae7"]="PriceOracleSentinelUpdated(address,address)"
    ["0x56b5f80d8cac1479698aa7d01605fd6111e90b15fc4d2b377417f46034876cbd"]="PriceOracleUpdated(address,address)"
    ["0x4a465a9bd819d9662563c1e11ae958f8109e437e7f4bf1c6ef0b9a7b3f35d478"]="ProxyCreated(bytes32,address,address)"
    
    # PoolAddressesProviderRegistry Events
    ["0xc2e7cc813550ef0e7126cc0571281850ce5df2e9c400acf3589c38e4627f85f1"]="AddressesProviderRegistered(address,uint256)"
    ["0x254723080701bde71d562cad0e967cef23d86bb27ee842c190a2596820f3b241"]="AddressesProviderUnregistered(address,uint256)"
    
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

    # Pool Configurator Events
    ["0xa76f65411ec66a7fb6bc467432eb14767900449ae4469fa295e4441fe5e1cb73"]="ATokenUpgraded(address,address,address)"
    ["0xc51aca575985d521c5072ad11549bad77013bb786d57f30f94b40ed8f8dc9bc4"]="BorrowCapChanged(address,uint256,uint256)"
    ["0x74adf6aaf58c08bc4f993640385e136522375ea3d1589a10d02adbb906c67d1c"]="BorrowableInIsolationChanged(address,bool)"
    ["0x30b17cb587a89089d003457c432f73e22aeee93de425e92224ba01080260ecd9"]="BridgeProtocolFeeUpdated(uint256,uint256)"
    ["0x637febbda9275aea2e85c0ff690444c8d87eb2e8339bbede9715abcc89cb0995"]="CollateralConfigurationChanged(address,uint256,uint256,uint256)"
    ["0x6824a6c7fbc10d2979b1f1ccf2dd4ed0436541679a661dedb5c10bd4be830682"]="DebtCeilingChanged(address,uint256,uint256)"
    ["0x5bb69795b6a2ea222d73a5f8939c23471a1f85a99c7ca43c207f1b71f10c6264"]="EModeAssetCategoryChanged(address,uint8,uint8)"
    ["0x0acf8b4a3cace10779798a89a206a0ae73a71b63acdd3be2801d39c2ef7ab3cb"]="EModeCategoryAdded(uint8,uint256,uint256,uint256,address,string)"
    ["0xe7e0c75e1fc2d0bd83dc85d59f085b3e763107c392fb368e85572b292f1f5576"]="FlashloanPremiumToProtocolUpdated(uint128,uint128)"
    ["0x71aba182c9d0529b516de7a78bed74d49c207ef7e152f52f7ea5d8730138f643"]="FlashloanPremiumTotalUpdated(uint128,uint128)"
    ["0xb5b0a963825337808b6e3154de8e98027595a5cad4219bb3a9bc55b192f4b391"]="LiquidationProtocolFeeChanged(address,uint256,uint256)"
    ["0xc36c7d11ba01a5869d52aa4a3781939dab851cbc9ee6e7fdcedc7d58898a3f1e"]="ReserveActive(address,bool)"
    ["0x2443ba28e8d1d88d531a3d90b981816a4f3b3c7f1fd4085c6029e81d1b7a570d"]="ReserveBorrowing(address,bool)"
    ["0xeeec4c06f7adad215cbdb4d2960896c83c26aedce02dde76d36fa28588d62da4"]="ReserveDropped(address)"
    ["0xb46e2b82b0c2cf3d7d9dece53635e165c53e0eaa7a44f904d61a2b7174826aef"]="ReserveFactorChanged(address,uint256,uint256)"
    ["0xc8ff3cc5b0fddaa3e6ebbbd7438f43393e4ea30e88b80ad016c1bc094655034d"]="ReserveFlashLoaning(address,bool)"
    ["0x0c4443d258a350d27dc50c378b2ebf165e6469725f786d21b30cab16823f5587"]="ReserveFrozen(address,bool)"
    ["0x3a0ca721fc364424566385a1aa271ed508cc2c0949c2272575fb3013a163a45f"]="ReserveInitialized(address,address,address,address,address)"
    ["0xdb8dada53709ce4988154324196790c2e4a60c377e1256790946f83b87db3c33"]="ReserveInterestRateStrategyChanged(address,address,address)"
    ["0xe188d542a5f11925d3a3af33703cdd30a43cb3e8066a3cf68b1b57f61a5a94b5"]="ReservePaused(address,bool)"
    ["0x0b64d0941719acd363f1a6be3d8525d8ec9d71738f7445aabcd88d7939b472e7"]="ReserveStableRateBorrowing(address,bool)"
    ["0x842a280b07e8e502a9101f32a3b768ebaba3655556dd674f0831900861fc674b"]="SiloedBorrowingChanged(address,bool,bool)"
    ["0x7a943a5b6c214bf7726c069a878b1e2a8e7371981d516048b84e03743e67bc28"]="StableDebtTokenUpgraded(address,address,address)"
    ["0x0263602682188540a2d633561c0b4453b7d8566285e99f9f6018b8ef2facef49"]="SupplyCapChanged(address,uint256,uint256)"
    ["0x09808b1fc5abde94edf02fdde393bea0d2e4795999ba31695472848638b5c29f"]="UnbackedMintCapChanged(address,uint256,uint256)"
    ["0x9439658a562a5c46b1173589df89cf001483d685bad28aedaff4a88656292d81"]="VariableDebtTokenUpgraded(address,address,address)"
)

# Add function signatures mapping
declare -A FUNCTION_SIGNATURES=(
    ["0x4dd18bf5"]="setACLAdmin(address)"
    # Add other known function signatures here
)

# First, let's add debug logging to load_address_names
load_address_names() {
    # Reset the associative array
    declare -g -A ADDRESS_NAMES
    
    while IFS='=' read -r address name; do
        # Convert address to lowercase and store
        local lower_address="${address,,}"
        ADDRESS_NAMES["$lower_address"]="$name"
    done < "$FLAGGED_ADDRESSES_FILE"
}

# And in format_address, let's add debug
format_address() {
    local address="${1,,}" # Convert to lowercase
    local name="${ADDRESS_NAMES[$address]}"
    if [ ! -z "$name" ]; then
        echo "$address ($name)"
    else
        echo "$address (Unknown)"
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

# Function to format timestamp for macOS
format_timestamp() {
    local timestamp=$1
    # macOS date command format
    date -r "$timestamp" "+%Y-%m-%d %H:%M:%S UTC"
}

# Function to get UTC timestamp from block
get_timestamp() {
    local block_number=$1
    local timestamp=$(cast block $block_number --rpc-url $RPC_URL | grep "timestamp" | awk '{print $2}')
    echo "🕒 $(format_timestamp "$timestamp")"
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

# Function to analyze transactions for an address
analyze_address_txns() {
    load_address_names
    
    local ADDRESS=$1
    local START_BLOCK_NUM=$2
    local END_BLOCK_NUM=$3

    echo "🔍 Analyzing transactions for: $(format_address "$ADDRESS")"
    echo "📅 Period: Block $START_BLOCK_NUM to ${END_BLOCK_NUM:-latest}"

    local apiUrl="https://api.parsec.finance/api/rest/transactions?addresses=$ADDRESS&chains=hyper_evm&apiKey=$PARSEC_API_KEY&limit=200&includeLogs=true&includeInput=true"

    # Call Parsec API to get transactions and sort by timestamp
    local transactions=$(curl -s "$apiUrl" | jq '.txs |= sort_by(.timestamp)')

    # Print total number of transactions found
    echo "$transactions" | jq -r '.txs | length' | xargs -I {} echo "Total transactions: {}"

    # Process each transaction (now sorted by timestamp)
    txn_count=0
    processed_count=0
    echo "$transactions" | jq -c '.txs[]?' 2>/dev/null | while read -r tx; do
        if [ -z "$tx" ] || [ "$tx" = "null" ]; then
            continue
        fi

        # Skip transactions if needed
        if [ "$txn_count" -lt "$TXN_SKIP" ]; then
            ((txn_count++))
            continue
        fi

        # Check transaction limit
        if [ ! -z "$TXN_LIMIT" ]; then
            if [ "$processed_count" -ge "$TXN_LIMIT" ]; then
                processed_count=$TXN_LIMIT
                echo -e "\n════════════════════════════════════════"
                echo -e "\n🛑 Reached transaction limit ($TXN_LIMIT)"
                break
            fi
        fi
        
        # Increment counters
        ((txn_count++))
        ((processed_count++))

        # Extract transaction details
        local tx_hash=$(echo "$tx" | jq -r '.hash // empty')
        local block_number=$(echo "$tx" | jq -r '.block // empty')
        local timestamp=$(echo "$tx" | jq -r '.timestamp // empty')
        
        # Check timestamp cutoffs if specified
        if [ ! -z "$timestamp" ]; then
            # Convert timestamp to integer for comparison
            timestamp_int=$(echo "$timestamp" | cut -d. -f1)  # Remove any decimal part
            
            # Skip if before the after timestamp
            if [ ! -z "$TIMESTAMP_AFTER" ] && [ "$timestamp_int" -lt "$TIMESTAMP_AFTER" ]; then
                continue
            fi
            # Break if after the before timestamp
            if [ ! -z "$TIMESTAMP_BEFORE" ] && [ "$timestamp_int" -gt "$TIMESTAMP_BEFORE" ]; then
                echo "🕒 Reached timestamp cutoff"
                break
            fi
        fi

        local contract_creation=$(echo "$tx" | jq -r '.contract_creation // empty')
        local to_address=$(echo "$tx" | jq -r '.to // empty')
        local value=$(echo "$tx" | jq -r '.value // "0.0"')
        local status=$(echo "$tx" | jq -r '.status // false')
        local input_data=$(echo "$tx" | jq -r '.input // empty')

        echo -e "\n════════════════════════════════════════"
        if [ ! -z "$contract_creation" ] && [ "$contract_creation" != "null" ]; then
            echo "CONTRACT CREATION"
        else
            echo "TRANSACTION"
        fi
        echo "════════════════════════════════════════"
        
        if [ ! -z "$timestamp" ]; then
            echo "🕒 $(format_timestamp "$timestamp")"
        fi
        
        # Show function call if available
        local input_decoded=$(echo "$tx" | jq -r '.inputDecoded // empty')
        if [ ! -z "$input_decoded" ]; then
            local function_name=$(echo "$input_decoded" | jq -r '.function // empty')
            local args=$(echo "$input_decoded" | jq -r '.args // empty')
            
            if [ ! -z "$function_name" ]; then
                echo "📝 Function: $function_name"
                if [ ! -z "$args" ] && [ "$args" != "null" ]; then
                    echo "📋 Arguments: $args"
                fi
            fi
        fi

        # Handle contract creation transactions
        if [ ! -z "$contract_creation" ] && [ "$contract_creation" != "null" ]; then
            echo "📝 Contract Created"
            echo "🏠 Address: $contract_creation ($(get_contract_details "$contract_creation"))"
        else
            if [ ! -z "$to_address" ]; then
                echo "To: $to_address ($(get_contract_details "$to_address"))"
            fi
            if [ "$value" != "0.0" ]; then
                echo "Value: $value ETH"
            fi
        fi

        # Process status
        if [ "$status" = "true" ]; then
            echo "✅ Status: Success"
        else
            echo "❌ Status: Failed"
        fi

        echo "📦 Block: $block_number"

        # Show link at the end
        if [ ! -z "$tx_hash" ]; then
            echo "🔗 $PURRSEC_URL/$tx_hash"
        fi
        
        # Process logs if they exist
        echo "$tx" | jq -c '.logs[]?' 2>/dev/null | while read -r log; do
            if [ -z "$log" ] || [ "$log" = "null" ]; then
                continue
            fi

            local topic=$(echo "$log" | jq -r '.topic // empty')
            if [ -z "$topic" ]; then
                continue
            fi

            # Skip non-OwnershipTransferred events if filter is enabled
            if [ "$FILTER_OWNERSHIP_EVENTS" = true ] && [ "$topic" != "0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0" ]; then
                continue
            fi

            local name=$(echo "$log" | jq -r '.name // empty')
            local address=$(echo "$log" | jq -r '.address // empty')
            local address_label=$(echo "$log" | jq -r '.addressLabel.label // empty')
            local data=$(echo "$log" | jq -r '.data // "{}"')
            
            # Update ADDRESS_NAMES if we have a contract name in the logs
            if [ ! -z "$address" ] && [ ! -z "$address_label" ] && [ "$address_label" != "null" ]; then
                ADDRESS_NAMES["${address,,}"]="$address_label"
            fi
            
            # Check if this is a tracked event
            if [ ! -z "${EVENT_SIGNATURES[$topic]}" ]; then
                echo -e "\n    ▓▓▓▓▓▓▓▓▓▓ EVENT ▓▓▓▓▓▓▓▓▓▓"
                if [ ! -z "$address" ]; then
                    # Convert to lowercase for consistent lookup
                    address="${address,,}"
                    
                    # Check if we already have a name for this address
                    if [ -z "${ADDRESS_NAMES[$address]}" ]; then
                        # If not, try to get it from Parsec API
                        local contract_name=$(get_contract_details "$address")
                        if [ "$contract_name" != "Unknown" ]; then
                            ADDRESS_NAMES["$address"]="$contract_name"
                        fi
                    fi
                    
                    echo -e "\n    Contract: $(format_address "$address")"
                fi
                
                if [ ! -z "$name" ] && [ "$name" != "null" ]; then
                    echo "    Event: $name"
                else
                    echo "    Event: ${EVENT_SIGNATURES[$topic]}"
                fi
                
                # Parse raw data parameters
                echo "$log" | jq -c '.rawData[]?' 2>/dev/null | while read -r param; do
                    if [ -z "$param" ] || [ "$param" = "null" ]; then
                        continue
                    fi
                    
                    if [[ $param == *"0x000000000000000000000000"* ]]; then
                        # This is likely an address parameter
                        # Remove quotes and extract the address part
                        param=$(echo "$param" | tr -d '"')
                        local addr="0x${param:26:40}"  # Take exactly 40 chars after prefix
                        # Convert to lowercase for consistent lookup
                        addr="${addr,,}"
                        local contract_name=$(get_contract_details "$addr")
                        echo "    Parameter: $addr ($contract_name)"
                    else
                        echo "    Parameter: $param"
                    fi
                done
                
                # Show decoded data if available
                if [ "$data" != "{}" ] && [ "$data" != "null" ]; then
                    echo "    Decoded Data:"
                    echo "$data" | jq '.' 2>/dev/null | sed 's/^/        /'
                fi
            fi


        done
    done

    # Print final stats if we didn't hit the limit
    if [ -z "$TXN_LIMIT" ]; then
        echo "📊 Processed $processed_count transaction(s) (skipped first $TXN_SKIP)"
    else
        echo "📊 Processed $TXN_LIMIT transaction(s) (skipped first $TXN_SKIP)"
    fi
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
    local timestamp=$(cast block "$block_number" --rpc-url "$RPC_URL" | grep "timestamp" | awk '{print $2}')
    echo "🕒 $(format_timestamp "$timestamp")"
    
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
    echo -e "\n════════════════════════════════════════"
    echo "TRANSACTION"
    echo "════════════════════════════════════════"
    echo "Transaction: $tx_hash"
    
    # Get transaction details
    local tx_details=$(cast tx "$tx_hash" --rpc-url "$RPC_URL")
    
    # Get receipt to check if it's a contract deployment
    local receipt=$(cast receipt "$tx_hash" --rpc-url "$RPC_URL")
    local contract_address=$(echo "$receipt" | grep "contractAddress" | awk '{print $2}')
    
    # Get block number and timestamp
    local block_number=$(echo "$tx_details" | grep "block" | awk '{print $2}')
    local timestamp=$(cast block "$block_number" --rpc-url "$RPC_URL" | grep "timestamp" | awk '{print $2}')
    
    echo "🕒 $(format_timestamp "$timestamp")"
    
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

# Function to get contract details from Parsec API and update address names
get_contract_details() {
    local contract_address="${1,,}"  # Convert to lowercase
    
    # Check if we already know this contract's name
    if [ ! -z "${ADDRESS_NAMES[$contract_address]}" ]; then
        echo "${ADDRESS_NAMES[$contract_address]}"
        return 0
    fi
    
    # If not in our mapping, fetch from API
    local api_response=$(curl -s "https://api.parsec.finance/api/rest/contract?address=$contract_address&chain=hyper_evm&apiKey=$PARSEC_API_KEY")
    local contract_name=$(echo "$api_response" | jq -r '.contract.sourceCode.name // "Unknown"')
    
    # Update ADDRESS_NAMES mapping with the contract name if found
    if [ "$contract_name" != "Unknown" ] && [ "$contract_name" != "null" ]; then
        ADDRESS_NAMES["$contract_address"]="$contract_name"
        echo "$contract_name"
    else
        echo "Unknown"
    fi
}

# Main execution flow (move this to the end of the file)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Starting transaction analysis..."
    analyze_address_txns "$INITIAL_EOA" "$START_BLOCK"
fi

