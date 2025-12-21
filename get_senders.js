// Get all unique sender addresses that sent ETH to the sale contract
// You need a free Etherscan API key from: https://etherscan.io/myapikey

const SALE_ADDRESS = '0xab02bf85a7a851b6a379ea3d5bd3b9b4f5dd8461';
const ETHERSCAN_API_KEY = 'YOUR_API_KEY_HERE'; // Get free key from etherscan.io

async function getSenderAddresses() {
  console.log('Fetching transactions...');

  const url = `https://api.etherscan.io/api?module=account&action=txlist&address=${SALE_ADDRESS}&startblock=0&endblock=99999999&sort=asc&apikey=${ETHERSCAN_API_KEY}`;

  try {
    const response = await fetch(url);
    const data = await response.json();

    if (data.status !== '1') {
      console.error('Error:', data.message);
      return;
    }

    // Filter for incoming transactions (where 'to' is our address)
    const incomingTxs = data.result.filter(tx =>
      tx.to.toLowerCase() === SALE_ADDRESS.toLowerCase() &&
      tx.value !== '0' // Only transactions that sent ETH
    );

    // Get unique sender addresses
    const uniqueSenders = [...new Set(incomingTxs.map(tx => tx.from))];

    console.log(`\nFound ${incomingTxs.length} transactions from ${uniqueSenders.length} unique addresses\n`);

    // Print all unique sender addresses
    console.log('=== UNIQUE SENDER ADDRESSES ===');
    uniqueSenders.forEach((address, i) => {
      console.log(`${i + 1}. ${address}`);
    });

    // Also save to file
    const fs = require('fs');
    fs.writeFileSync('sender_addresses.txt', uniqueSenders.join('\n'));
    console.log('\n✓ Saved to sender_addresses.txt');

    // Create CSV with details
    const csv = ['Address,Transaction Count,Total ETH Sent'];
    uniqueSenders.forEach(sender => {
      const senderTxs = incomingTxs.filter(tx => tx.from.toLowerCase() === sender.toLowerCase());
      const totalEth = senderTxs.reduce((sum, tx) => sum + parseFloat(tx.value), 0) / 1e18;
      csv.push(`${sender},${senderTxs.length},${totalEth.toFixed(6)}`);
    });

    fs.writeFileSync('sender_addresses.csv', csv.join('\n'));
    console.log('✓ Saved details to sender_addresses.csv');

  } catch (error) {
    console.error('Error fetching data:', error);
  }
}

getSenderAddresses();
