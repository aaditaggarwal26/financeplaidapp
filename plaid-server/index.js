const express = require('express');
const bodyParser = require('body-parser');
const plaid = require('plaid');
require('dotenv').config();

const app = express();
const PORT = 3003;

app.use(bodyParser.json());

const client = new plaid.Client({
  clientID: process.env.PLAID_CLIENT_ID,
  secret: process.env.PLAID_SECRET,
  env: plaid.environments.sandbox,
});

let ACCESS_TOKEN = null;

// Create Link Token
app.post('/api/create_link_token', async (req, res) => {
  try {
    const response = await client.linkTokenCreate({
      user: {
        client_user_id: 'user-id',
      },
      client_name: 'FBLA Coding Programming App',
      products: ['auth', 'transactions'],
      country_codes: ['US'],
      language: 'en',
    });
    res.json(response);
  } catch (error) {
    res.status(500).send(error);
  }
});

// Exchange Public Token for Access Token
app.post('/api/exchange_public_token', async (req, res) => {
  const publicToken = req.body.public_token;
  try {
    const response = await client.itemPublicTokenExchange({
      public_token: publicToken,
    });
    ACCESS_TOKEN = response.access_token;
    res.json(response);
  } catch (error) {
    res.status(500).send(error);
  }
});

// Retrieve Transactions
app.get('/api/transactions', async (req, res) => {
  try {
    const response = await client.transactionsGet({
      access_token: ACCESS_TOKEN,
      start_date: '2023-01-01',
      end_date: '2024-01-01',
    });
    res.json(response);
  } catch (error) {
    res.status(500).send(error);
  }
});

// Get Item Info
app.get('/api/item', async (req, res) => {
  try {
    const response = await client.itemGet({
      access_token: ACCESS_TOKEN,
    });
    res.json(response);
  } catch (error) {
    res.status(500).send(error);
  }
});

// Remove Item
app.post('/api/item/remove', async (req, res) => {
  try {
    const response = await client.itemRemove({
      access_token: ACCESS_TOKEN,
    });
    res.json(response);
  } catch (error) {
    res.status(500).send(error);
  }
});

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
