import { GraphQLClient } from 'graphql-request';
import { getSdk } from './generated/sdk';

async function main() {
  const client = new GraphQLClient('http://localhost:5000/graphql');
  const sdk = getSdk(client);

  // Generate a unique email by appending the current timestamp (or a random number).
  const uniqueEmail = `alice-${Date.now()}@example.com`;

  const newMemberResult = await sdk.CreateMember({
    firstName: 'Alice',
    lastName: 'Doe',
    email: uniqueEmail,
  });

  console.log('Created member:', newMemberResult.createMember?.member);
}

main().catch(console.error);
