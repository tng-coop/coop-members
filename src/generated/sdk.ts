import { GraphQLClient, RequestOptions } from 'graphql-request';
import gql from 'graphql-tag';
export type Maybe<T> = T | null;
export type InputMaybe<T> = Maybe<T>;
export type Exact<T extends { [key: string]: unknown }> = { [K in keyof T]: T[K] };
export type MakeOptional<T, K extends keyof T> = Omit<T, K> & { [SubKey in K]?: Maybe<T[SubKey]> };
export type MakeMaybe<T, K extends keyof T> = Omit<T, K> & { [SubKey in K]: Maybe<T[SubKey]> };
export type MakeEmpty<T extends { [key: string]: unknown }, K extends keyof T> = { [_ in K]?: never };
export type Incremental<T> = T | { [P in keyof T]?: P extends ' $fragmentName' | '__typename' ? T[P] : never };
type GraphQLClientRequestHeaders = RequestOptions['requestHeaders'];
/** All built-in and custom scalars, mapped to their actual values */
export type Scalars = {
  ID: { input: string; output: string; }
  String: { input: string; output: string; }
  Boolean: { input: boolean; output: boolean; }
  Int: { input: number; output: number; }
  Float: { input: number; output: number; }
  Cursor: { input: any; output: any; }
  JwtToken: { input: any; output: any; }
};

/** All input for the `loginMember` mutation. */
export type LoginMemberInput = {
  /**
   * An arbitrary string value with no semantic meaning. Will be included in the
   * payload verbatim. May be used to track mutations by the client.
   */
  clientMutationId?: InputMaybe<Scalars['String']['input']>;
  inEmail?: InputMaybe<Scalars['String']['input']>;
  inPassword?: InputMaybe<Scalars['String']['input']>;
};

/** The output of our `loginMember` mutation. */
export type LoginMemberPayload = {
  __typename?: 'LoginMemberPayload';
  /**
   * The exact same `clientMutationId` that was provided in the mutation input,
   * unchanged and unused. May be used by a client to track mutations.
   */
  clientMutationId?: Maybe<Scalars['String']['output']>;
  jwtToken?: Maybe<Scalars['JwtToken']['output']>;
  /** Our root query field type. Allows us to run any query from our mutation payload. */
  query?: Maybe<Query>;
};

export type Member = Node & {
  __typename?: 'Member';
  email: Scalars['String']['output'];
  firstName: Scalars['String']['output'];
  id: Scalars['Int']['output'];
  lastName: Scalars['String']['output'];
  /** A globally unique identifier. Can be used in various places throughout the system to identify this single value. */
  nodeId: Scalars['ID']['output'];
  passwordHash: Scalars['String']['output'];
};

/** A condition to be used against `Member` object types. All fields are tested for equality and combined with a logical ‘and.’ */
export type MemberCondition = {
  /** Checks for equality with the object’s `email` field. */
  email?: InputMaybe<Scalars['String']['input']>;
  /** Checks for equality with the object’s `firstName` field. */
  firstName?: InputMaybe<Scalars['String']['input']>;
  /** Checks for equality with the object’s `id` field. */
  id?: InputMaybe<Scalars['Int']['input']>;
  /** Checks for equality with the object’s `lastName` field. */
  lastName?: InputMaybe<Scalars['String']['input']>;
  /** Checks for equality with the object’s `passwordHash` field. */
  passwordHash?: InputMaybe<Scalars['String']['input']>;
};

/** A connection to a list of `Member` values. */
export type MembersConnection = {
  __typename?: 'MembersConnection';
  /** A list of edges which contains the `Member` and cursor to aid in pagination. */
  edges: Array<MembersEdge>;
  /** A list of `Member` objects. */
  nodes: Array<Maybe<Member>>;
  /** Information to aid in pagination. */
  pageInfo: PageInfo;
  /** The count of *all* `Member` you could get from the connection. */
  totalCount: Scalars['Int']['output'];
};

/** A `Member` edge in the connection. */
export type MembersEdge = {
  __typename?: 'MembersEdge';
  /** A cursor for use in pagination. */
  cursor?: Maybe<Scalars['Cursor']['output']>;
  /** The `Member` at the end of the edge. */
  node?: Maybe<Member>;
};

/** Methods to use when ordering `Member`. */
export enum MembersOrderBy {
  EmailAsc = 'EMAIL_ASC',
  EmailDesc = 'EMAIL_DESC',
  FirstNameAsc = 'FIRST_NAME_ASC',
  FirstNameDesc = 'FIRST_NAME_DESC',
  IdAsc = 'ID_ASC',
  IdDesc = 'ID_DESC',
  LastNameAsc = 'LAST_NAME_ASC',
  LastNameDesc = 'LAST_NAME_DESC',
  Natural = 'NATURAL',
  PasswordHashAsc = 'PASSWORD_HASH_ASC',
  PasswordHashDesc = 'PASSWORD_HASH_DESC',
  PrimaryKeyAsc = 'PRIMARY_KEY_ASC',
  PrimaryKeyDesc = 'PRIMARY_KEY_DESC'
}

/** The root mutation type which contains root level fields which mutate data. */
export type Mutation = {
  __typename?: 'Mutation';
  loginMember?: Maybe<LoginMemberPayload>;
  registerMember?: Maybe<RegisterMemberPayload>;
};


/** The root mutation type which contains root level fields which mutate data. */
export type MutationLoginMemberArgs = {
  input: LoginMemberInput;
};


/** The root mutation type which contains root level fields which mutate data. */
export type MutationRegisterMemberArgs = {
  input: RegisterMemberInput;
};

/** An object with a globally unique `ID`. */
export type Node = {
  /** A globally unique identifier. Can be used in various places throughout the system to identify this single value. */
  nodeId: Scalars['ID']['output'];
};

/** Information about pagination in a connection. */
export type PageInfo = {
  __typename?: 'PageInfo';
  /** When paginating forwards, the cursor to continue. */
  endCursor?: Maybe<Scalars['Cursor']['output']>;
  /** When paginating forwards, are there more items? */
  hasNextPage: Scalars['Boolean']['output'];
  /** When paginating backwards, are there more items? */
  hasPreviousPage: Scalars['Boolean']['output'];
  /** When paginating backwards, the cursor to continue. */
  startCursor?: Maybe<Scalars['Cursor']['output']>;
};

/** The root query type which gives access points into the data universe. */
export type Query = Node & {
  __typename?: 'Query';
  /** Reads and enables pagination through a set of `Member`. */
  allMembers?: Maybe<MembersConnection>;
  currentDbUser?: Maybe<Scalars['String']['output']>;
  /** Reads a single `Member` using its globally unique `ID`. */
  member?: Maybe<Member>;
  memberByEmail?: Maybe<Member>;
  memberById?: Maybe<Member>;
  /** Fetches an object given its globally unique `ID`. */
  node?: Maybe<Node>;
  /** The root query type must be a `Node` to work well with Relay 1 mutations. This just resolves to `query`. */
  nodeId: Scalars['ID']['output'];
  /**
   * Exposes the root query type nested one level down. This is helpful for Relay 1
   * which can only query top level fields if they are in a particular form.
   */
  query: Query;
};


/** The root query type which gives access points into the data universe. */
export type QueryAllMembersArgs = {
  after?: InputMaybe<Scalars['Cursor']['input']>;
  before?: InputMaybe<Scalars['Cursor']['input']>;
  condition?: InputMaybe<MemberCondition>;
  first?: InputMaybe<Scalars['Int']['input']>;
  last?: InputMaybe<Scalars['Int']['input']>;
  offset?: InputMaybe<Scalars['Int']['input']>;
  orderBy?: InputMaybe<Array<MembersOrderBy>>;
};


/** The root query type which gives access points into the data universe. */
export type QueryMemberArgs = {
  nodeId: Scalars['ID']['input'];
};


/** The root query type which gives access points into the data universe. */
export type QueryMemberByEmailArgs = {
  email: Scalars['String']['input'];
};


/** The root query type which gives access points into the data universe. */
export type QueryMemberByIdArgs = {
  id: Scalars['Int']['input'];
};


/** The root query type which gives access points into the data universe. */
export type QueryNodeArgs = {
  nodeId: Scalars['ID']['input'];
};

/** All input for the `registerMember` mutation. */
export type RegisterMemberInput = {
  /**
   * An arbitrary string value with no semantic meaning. Will be included in the
   * payload verbatim. May be used to track mutations by the client.
   */
  clientMutationId?: InputMaybe<Scalars['String']['input']>;
  inEmail?: InputMaybe<Scalars['String']['input']>;
  inFirstName?: InputMaybe<Scalars['String']['input']>;
  inLastName?: InputMaybe<Scalars['String']['input']>;
  inPassword?: InputMaybe<Scalars['String']['input']>;
};

/** The output of our `registerMember` mutation. */
export type RegisterMemberPayload = {
  __typename?: 'RegisterMemberPayload';
  /**
   * The exact same `clientMutationId` that was provided in the mutation input,
   * unchanged and unused. May be used by a client to track mutations.
   */
  clientMutationId?: Maybe<Scalars['String']['output']>;
  jwtToken?: Maybe<Scalars['JwtToken']['output']>;
  /** Our root query field type. Allows us to run any query from our mutation payload. */
  query?: Maybe<Query>;
};

export type GetAllMembersQueryVariables = Exact<{ [key: string]: never; }>;


export type GetAllMembersQuery = { __typename?: 'Query', allMembers?: { __typename?: 'MembersConnection', nodes: Array<{ __typename?: 'Member', id: number, firstName: string, lastName: string } | null> } | null };


export const GetAllMembersDocument = gql`
    query GetAllMembers {
  allMembers {
    nodes {
      id
      firstName
      lastName
    }
  }
}
    `;

export type SdkFunctionWrapper = <T>(action: (requestHeaders?:Record<string, string>) => Promise<T>, operationName: string, operationType?: string, variables?: any) => Promise<T>;


const defaultWrapper: SdkFunctionWrapper = (action, _operationName, _operationType, _variables) => action();

export function getSdk(client: GraphQLClient, withWrapper: SdkFunctionWrapper = defaultWrapper) {
  return {
    GetAllMembers(variables?: GetAllMembersQueryVariables, requestHeaders?: GraphQLClientRequestHeaders): Promise<GetAllMembersQuery> {
      return withWrapper((wrappedRequestHeaders) => client.request<GetAllMembersQuery>(GetAllMembersDocument, variables, {...requestHeaders, ...wrappedRequestHeaders}), 'GetAllMembers', 'query', variables);
    }
  };
}
export type Sdk = ReturnType<typeof getSdk>;