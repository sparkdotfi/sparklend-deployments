import argparse
from dotenv import load_dotenv
import eth_account
import os
import requests
import sys

from hyperliquid.utils.signing import (
    get_timestamp_ms,
    sign_l1_action,
)

load_dotenv()

def main(using_big_blocks):
    private_key = os.getenv("PRIVATE_KEY")
    print(f"Using private key: {private_key}")
    
    wallet = eth_account.Account.from_key(private_key)
    print(f"Using wallet: {wallet.address}")

    timestamp = get_timestamp_ms()
    print(f"Using timestamp: {timestamp}")

    action = {
        "type": "evmUserModify",
        "usingBigBlocks": using_big_blocks
    }
    print(f"Using useBigBlock: {action}")

    signature = sign_l1_action(
        wallet,
        action,
        None,
        timestamp,
        True,  # False=Testnet, True=Mainnet
    )

    payload = {
        "action": action,
        "nonce": timestamp,
        "signature": signature
    }
    print(f"Using payload: {payload}")

    # Send the POST request
    response = requests.post(
        "https://api.hyperliquid.xyz/exchange",
        headers={"Content-Type": "application/json"},
        json=payload
    )

    # Print the response
    sys.stderr.write(f"Response status code: {response.status_code}\n")
    sys.stderr.write(f"Response JSON: {response.json()}\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Script to modify usingBigBlocks value.")
    parser.add_argument("usingBigBlocks", type=str, choices=["true", "false"], help="Boolean value for usingBigBlocks")
    args = parser.parse_args()

    # Convert the string argument to a boolean
    using_big_blocks = args.usingBigBlocks.lower() == "true"

    main(using_big_blocks)