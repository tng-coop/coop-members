import { GraphQLClient } from 'graphql-request';
import { getSdk } from './generated/sdk';

async function main() {
  // 1. Create the GraphQL client
  const client = new GraphQLClient('http://localhost:5000/graphql');

  // 2. Get your strongly-typed SDK
  const sdk = getSdk(client);

  // 3. Call your queries/mutations
  const result = await sdk.GetAllMembers(); // auto-generated from GetAllMembers.graphql

  console.log(result.allMembers?.nodes);
}

main().catch(console.error);
