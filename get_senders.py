#!/usr/bin/env python3
"""
Get all unique sender addresses that sent ETH to the sale contract
You need a free Etherscan API key from: https://etherscan.io/myapikey
"""

import requests
import json

SALE_ADDRESS = '0xab02bf85a7a851b6a379ea3d5bd3b9b4f5dd8461'
ETHERSCAN_API_KEY = 'YOUR_API_KEY_HERE'  # Get free key from etherscan.io

def get_sender_addresses():
    print('Fetching transactions...')

    url = f'https://api.etherscan.io/api?module=account&action=txlist&address={SALE_ADDRESS}&startblock=0&endblock=99999999&sort=asc&apikey={ETHERSCAN_API_KEY}'

    try:
        response = requests.get(url)
        data = response.json()

        if data['status'] != '1':
            print(f"Error: {data['message']}")
            return

        # Filter for incoming transactions (where 'to' is our address)
        incoming_txs = [
            tx for tx in data['result']
            if tx['to'].lower() == SALE_ADDRESS.lower() and tx['value'] != '0'
        ]

        # Get unique sender addresses
        unique_senders = list(set(tx['from'] for tx in incoming_txs))
        unique_senders.sort()  # Sort alphabetically

        print(f"\nFound {len(incoming_txs)} transactions from {len(unique_senders)} unique addresses\n")

        # Print all unique sender addresses
        print('=== UNIQUE SENDER ADDRESSES ===')
        for i, address in enumerate(unique_senders, 1):
            print(f"{i}. {address}")

        # Save to file
        with open('sender_addresses.txt', 'w') as f:
            f.write('\n'.join(unique_senders))
        print('\n✓ Saved to sender_addresses.txt')

        # Create CSV with details
        csv_lines = ['Address,Transaction Count,Total ETH Sent']
        for sender in unique_senders:
            sender_txs = [tx for tx in incoming_txs if tx['from'].lower() == sender.lower()]
            total_eth = sum(float(tx['value']) for tx in sender_txs) / 1e18
            csv_lines.append(f"{sender},{len(sender_txs)},{total_eth:.6f}")

        with open('sender_addresses.csv', 'w') as f:
            f.write('\n'.join(csv_lines))
        print('✓ Saved details to sender_addresses.csv')

    except Exception as error:
        print(f'Error fetching data: {error}')

if __name__ == '__main__':
    get_sender_addresses()
