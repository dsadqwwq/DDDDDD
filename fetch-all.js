// Simple script to get all 109k sender addresses
// Run: node fetch-all.js

const https = require('https');
const fs = require('fs');

const SALE_ADDRESS = '0xab02bf85a7a851b6a379ea3d5bd3b9b4f5dd8461';
const API_KEY = 'JQ85MFQSS25595CMJXDQ274DRNRC2FXKE3';
const START_BLOCK = 23669434;
const CURRENT_BLOCK = 24750000;
const CHUNK_SIZE = 100000;

const allAddresses = new Set();
let totalTxs = 0;

function fetchRange(startBlock, endBlock) {
  return new Promise((resolve, reject) => {
    const url = `https://api.etherscan.io/v2/api?chainid=1&module=account&action=txlist&address=${SALE_ADDRESS}&startblock=${startBlock}&endblock=${endBlock}&page=1&offset=10000&sort=asc&apikey=${API_KEY}`;

    https.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          if (json.status === '1' && json.result) {
            const incomingTxs = json.result.filter(tx =>
              tx.to && tx.to.toLowerCase() === SALE_ADDRESS.toLowerCase() && tx.value !== '0'
            );
            incomingTxs.forEach(tx => allAddresses.add(tx.from));
            totalTxs += incomingTxs.length;
            resolve(incomingTxs.length);
          } else {
            resolve(0);
          }
        } catch (e) {
          reject(e);
        }
      });
    }).on('error', reject);
  });
}

async function fetchAll() {
  console.log('Starting to fetch all transactions...');
  console.log(`Block range: ${START_BLOCK} to ${CURRENT_BLOCK}\n`);

  const ranges = [];
  for (let start = START_BLOCK; start < CURRENT_BLOCK; start += CHUNK_SIZE) {
    ranges.push({
      start,
      end: Math.min(start + CHUNK_SIZE - 1, CURRENT_BLOCK)
    });
  }

  console.log(`Will fetch ${ranges.length} ranges...\n`);

  for (let i = 0; i < ranges.length; i++) {
    const range = ranges[i];
    process.stdout.write(`\rFetching range ${i + 1}/${ranges.length} (${range.start}-${range.end})... `);

    try {
      const count = await fetchRange(range.start, range.end);
      process.stdout.write(`Found ${count} txs. Total addresses: ${allAddresses.size}`);
      await new Promise(resolve => setTimeout(resolve, 300)); // Rate limit
    } catch (e) {
      console.error(`\nError: ${e.message}`);
    }
  }

  console.log(`\n\n✓ DONE!`);
  console.log(`Total transactions: ${totalTxs}`);
  console.log(`Unique sender addresses: ${allAddresses.size}\n`);

  // Save to file
  const addresses = Array.from(allAddresses).sort();
  fs.writeFileSync('sender_addresses.txt', addresses.join('\n'));
  console.log('✓ Saved to sender_addresses.txt\n');

  // Print first 10 addresses
  console.log('First 10 addresses:');
  addresses.slice(0, 10).forEach((addr, i) => console.log(`${i + 1}. ${addr}`));

  console.log(`\n... and ${allAddresses.size - 10} more in sender_addresses.txt`);
}

fetchAll().catch(console.error);
