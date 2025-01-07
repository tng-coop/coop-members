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
};

/** All input for the create `Member` mutation. */
export type CreateMemberInput = {
  /**
   * An arbitrary string value with no semantic meaning. Will be included in the
   * payload verbatim. May be used to track mutations by the client.
   */
  clientMutationId?: InputMaybe<Scalars['String']['input']>;
  /** The `Member` to be created by this mutation. */
  member: MemberInput;
};

/** The output of our create `Member` mutation. */
export type CreateMemberPayload = {
  __typename?: 'CreateMemberPayload';
  /**
   * The exact same `clientMutationId` that was provided in the mutation input,
   * unchanged and unused. May be used by a client to track mutations.
   */
  clientMutationId?: Maybe<Scalars['String']['output']>;
  /** The `Member` that was created by this mutation. */
  member?: Maybe<Member>;
  /** An edge for our `Member`. May be used by Relay 1. */
  memberEdge?: Maybe<MembersEdge>;
  /** Our root query field type. Allows us to run any query from our mutation payload. */
  query?: Maybe<Query>;
};


/** The output of our create `Member` mutation. */
export type CreateMemberPayloadMemberEdgeArgs = {
  orderBy?: InputMaybe<Array<MembersOrderBy>>;
};

/** All input for the `deleteMemberByEmail` mutation. */
export type DeleteMemberByEmailInput = {
  /**
   * An arbitrary string value with no semantic meaning. Will be included in the
   * payload verbatim. May be used to track mutations by the client.
   */
  clientMutationId?: InputMaybe<Scalars['String']['input']>;
  email: Scalars['String']['input'];
};

/** All input for the `deleteMemberById` mutation. */
export type DeleteMemberByIdInput = {
  /**
   * An arbitrary string value with no semantic meaning. Will be included in the
   * payload verbatim. May be used to track mutations by the client.
   */
  clientMutationId?: InputMaybe<Scalars['String']['input']>;
  id: Scalars['Int']['input'];
};

/** All input for the `deleteMember` mutation. */
export type DeleteMemberInput = {
  /**
   * An arbitrary string value with no semantic meaning. Will be included in the
   * payload verbatim. May be used to track mutations by the client.
   */
  clientMutationId?: InputMaybe<Scalars['String']['input']>;
  /** The globally unique `ID` which will identify a single `Member` to be deleted. */
  nodeId: Scalars['ID']['input'];
};

/** The output of our delete `Member` mutation. */
export type DeleteMemberPayload = {
  __typename?: 'DeleteMemberPayload';
  /**
   * The exact same `clientMutationId` that was provided in the mutation input,
   * unchanged and unused. May be used by a client to track mutations.
   */
  clientMutationId?: Maybe<Scalars['String']['output']>;
  deletedMemberId?: Maybe<Scalars['ID']['output']>;
  /** The `Member` that was deleted by this mutation. */
  member?: Maybe<Member>;
  /** An edge for our `Member`. May be used by Relay 1. */
  memberEdge?: Maybe<MembersEdge>;
  /** Our root query field type. Allows us to run any query from our mutation payload. */
  query?: Maybe<Query>;
};


/** The output of our delete `Member` mutation. */
export type DeleteMemberPayloadMemberEdgeArgs = {
  orderBy?: InputMaybe<Array<MembersOrderBy>>;
};

export type JwtToken = {
  __typename?: 'JwtToken';
  memberId?: Maybe<Scalars['Int']['output']>;
  role?: Maybe<Scalars['String']['output']>;
};

/** All input for the `loginMember` mutation. */
export type LoginMemberInput = {
  /**
   * An arbitrary string value with no semantic meaning. Will be included in the
   * payload verbatim. May be used to track mutations by the client.
   */
  clientMutationId?: InputMaybe<Scalars['String']['input']>;
  inEmail?: InputMaybe<Scalars['String']['input']>;
};

/** The output of our `loginMember` mutation. */
export type LoginMemberPayload = {
  __typename?: 'LoginMemberPayload';
  /**
   * The exact same `clientMutationId` that was provided in the mutation input,
   * unchanged and unused. May be used by a client to track mutations.
   */
  clientMutationId?: Maybe<Scalars['String']['output']>;
  jwtToken?: Maybe<JwtToken>;
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
};

/** An input for mutations affecting `Member` */
export type MemberInput = {
  email: Scalars['String']['input'];
  firstName: Scalars['String']['input'];
  id?: InputMaybe<Scalars['Int']['input']>;
  lastName: Scalars['String']['input'];
};

/** Represents an update to a `Member`. Fields that are set will be updated. */
export type MemberPatch = {
  email?: InputMaybe<Scalars['String']['input']>;
  firstName?: InputMaybe<Scalars['String']['input']>;
  id?: InputMaybe<Scalars['Int']['input']>;
  lastName?: InputMaybe<Scalars['String']['input']>;
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
  PrimaryKeyAsc = 'PRIMARY_KEY_ASC',
  PrimaryKeyDesc = 'PRIMARY_KEY_DESC'
}

/** The root mutation type which contains root level fields which mutate data. */
export type Mutation = {
  __typename?: 'Mutation';
  /** Creates a single `Member`. */
  createMember?: Maybe<CreateMemberPayload>;
  /** Deletes a single `Member` using its globally unique id. */
  deleteMember?: Maybe<DeleteMemberPayload>;
  /** Deletes a single `Member` using a unique key. */
  deleteMemberByEmail?: Maybe<DeleteMemberPayload>;
  /** Deletes a single `Member` using a unique key. */
  deleteMemberById?: Maybe<DeleteMemberPayload>;
  loginMember?: Maybe<LoginMemberPayload>;
  /** Updates a single `Member` using its globally unique id and a patch. */
  updateMember?: Maybe<UpdateMemberPayload>;
  /** Updates a single `Member` using a unique key and a patch. */
  updateMemberByEmail?: Maybe<UpdateMemberPayload>;
  /** Updates a single `Member` using a unique key and a patch. */
  updateMemberById?: Maybe<UpdateMemberPayload>;
};


/** The root mutation type which contains root level fields which mutate data. */
export type MutationCreateMemberArgs = {
  input: CreateMemberInput;
};


/** The root mutation type which contains root level fields which mutate data. */
export type MutationDeleteMemberArgs = {
  input: DeleteMemberInput;
};


/** The root mutation type which contains root level fields which mutate data. */
export type MutationDeleteMemberByEmailArgs = {
  input: DeleteMemberByEmailInput;
};


/** The root mutation type which contains root level fields which mutate data. */
export type MutationDeleteMemberByIdArgs = {
  input: DeleteMemberByIdInput;
};


/** The root mutation type which contains root level fields which mutate data. */
export type MutationLoginMemberArgs = {
  input: LoginMemberInput;
};


/** The root mutation type which contains root level fields which mutate data. */
export type MutationUpdateMemberArgs = {
  input: UpdateMemberInput;
};


/** The root mutation type which contains root level fields which mutate data. */
export type MutationUpdateMemberByEmailArgs = {
  input: UpdateMemberByEmailInput;
};


/** The root mutation type which contains root level fields which mutate data. */
export type MutationUpdateMemberByIdArgs = {
  input: UpdateMemberByIdInput;
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

/** All input for the `updateMemberByEmail` mutation. */
export type UpdateMemberByEmailInput = {
  /**
   * An arbitrary string value with no semantic meaning. Will be included in the
   * payload verbatim. May be used to track mutations by the client.
   */
  clientMutationId?: InputMaybe<Scalars['String']['input']>;
  email: Scalars['String']['input'];
  /** An object where the defined keys will be set on the `Member` being updated. */
  memberPatch: MemberPatch;
};

/** All input for the `updateMemberById` mutation. */
export type UpdateMemberByIdInput = {
  /**
   * An arbitrary string value with no semantic meaning. Will be included in the
   * payload verbatim. May be used to track mutations by the client.
   */
  clientMutationId?: InputMaybe<Scalars['String']['input']>;
  id: Scalars['Int']['input'];
  /** An object where the defined keys will be set on the `Member` being updated. */
  memberPatch: MemberPatch;
};

/** All input for the `updateMember` mutation. */
export type UpdateMemberInput = {
  /**
   * An arbitrary string value with no semantic meaning. Will be included in the
   * payload verbatim. May be used to track mutations by the client.
   */
  clientMutationId?: InputMaybe<Scalars['String']['input']>;
  /** An object where the defined keys will be set on the `Member` being updated. */
  memberPatch: MemberPatch;
  /** The globally unique `ID` which will identify a single `Member` to be updated. */
  nodeId: Scalars['ID']['input'];
};

/** The output of our update `Member` mutation. */
export type UpdateMemberPayload = {
  __typename?: 'UpdateMemberPayload';
  /**
   * The exact same `clientMutationId` that was provided in the mutation input,
   * unchanged and unused. May be used by a client to track mutations.
   */
  clientMutationId?: Maybe<Scalars['String']['output']>;
  /** The `Member` that was updated by this mutation. */
  member?: Maybe<Member>;
  /** An edge for our `Member`. May be used by Relay 1. */
  memberEdge?: Maybe<MembersEdge>;
  /** Our root query field type. Allows us to run any query from our mutation payload. */
  query?: Maybe<Query>;
};


/** The output of our update `Member` mutation. */
export type UpdateMemberPayloadMemberEdgeArgs = {
  orderBy?: InputMaybe<Array<MembersOrderBy>>;
};

export type CreateMemberMutationVariables = Exact<{
  firstName: Scalars['String']['input'];
  lastName: Scalars['String']['input'];
  email: Scalars['String']['input'];
}>;


export type CreateMemberMutation = { __typename?: 'Mutation', createMember?: { __typename?: 'CreateMemberPayload', member?: { __typename?: 'Member', id: number, firstName: string, lastName: string, email: string } | null } | null };

export type GetAllMembersQueryVariables = Exact<{ [key: string]: never; }>;


export type GetAllMembersQuery = { __typename?: 'Query', allMembers?: { __typename?: 'MembersConnection', nodes: Array<{ __typename?: 'Member', id: number, firstName: string, lastName: string } | null> } | null };


export const CreateMemberDocument = gql`
    mutation CreateMember($firstName: String!, $lastName: String!, $email: String!) {
  createMember(
    input: {member: {firstName: $firstName, lastName: $lastName, email: $email}}
  ) {
    member {
      id
      firstName
      lastName
      email
    }
  }
}
    `;
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
    CreateMember(variables: CreateMemberMutationVariables, requestHeaders?: GraphQLClientRequestHeaders): Promise<CreateMemberMutation> {
      return withWrapper((wrappedRequestHeaders) => client.request<CreateMemberMutation>(CreateMemberDocument, variables, {...requestHeaders, ...wrappedRequestHeaders}), 'CreateMember', 'mutation', variables);
    },
    GetAllMembers(variables?: GetAllMembersQueryVariables, requestHeaders?: GraphQLClientRequestHeaders): Promise<GetAllMembersQuery> {
      return withWrapper((wrappedRequestHeaders) => client.request<GetAllMembersQuery>(GetAllMembersDocument, variables, {...requestHeaders, ...wrappedRequestHeaders}), 'GetAllMembers', 'query', variables);
    }
  };
}
export type Sdk = ReturnType<typeof getSdk>;