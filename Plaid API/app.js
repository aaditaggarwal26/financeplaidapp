// Step 1: Configuration
require('dotenv').config();
const axios = require('axios');
const { Configuration, PlaidApi } = require('plaid');
const { Parser } = require('json2csv');  
const fs = require('fs');

const PLAID_CLIENT_ID = process.env.PLAID_CLIENT_ID;
const PLAID_SECRET = process.env.PLAID_SECRET;
const PLAID_ENV = process.env.PLAID_ENV;
const ACCESS_TOKEN = process.env.ACCESS_TOKEN;

 
// Step 2: Fetch Transactions
async function fetchTransactions() {
  try {
    const response = await axios.post(
      `https://${PLAID_ENV}.plaid.com/transactions/get`,
      {
        client_id: PLAID_CLIENT_ID,
        secret: PLAID_SECRET,
        access_token: ACCESS_TOKEN,
        start_date: '2022-01-01',
        end_date: '2024-12-31',
        options: {
          count: 100,
          offset: 0,
        },
      }
    );
    //console.log(response.data.transactions);

    // Define the fields you want in the CSV
    const fields = ['transaction_id', 'date', 'name', 'amount', 'category', 'account_id'];
    const json2csvParser = new Parser({ fields });
    const csv = json2csvParser.parse(response.data.transactions);

    // Write to a CSV file
    fs.writeFileSync('transactions.csv', csv, 'utf-8');
    console.log('Transactions exported to transactions.csv');

  } catch (error) {
    console.error(error);
  }
}

// main
async function main() {
  await fetchTransactions();
}

main();