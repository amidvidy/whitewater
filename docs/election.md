# election.rb

## *module*: LeaderElection

LeaderElection provides a high level interface to conduct elections, it uses the RequestVoteRPC behind the scenes to contact the other servers.

```ruby
interface input, :start_election, [:term]
interface output, :outcome, [:term]
```

### *input*: start\_election

- `term`: The current term of the Candidate requesting the election.

### *output*: outcome

- `term`: The term for which, the requesting candidate won the election with a majority vote. This remains empty if there is a tie or another candidate wins.

### Additional Info:
### Things LeaderElection does:

- LeaderElection will start a RequestVoteRPC and count the responses. If a majority of the votes are for the Candidate requesting the election, the term number is returned in the outcome.

### Things LeaderElection does not do:

-  Term does **not** get incremented by LeaderElection, the Raft Server using the LeaderElection module is responsible for that.

- LeaderElection also does not implement timeouts. The Server is again responsible for that.

## *module*: RequestVoteRPC

RequestVoteRPC implements the request and response end of the RPC as outlined in RAFT. One call to RequestVoteRPC will send a RPC to all servers in StaticMembership as well as collect their responses

```ruby
interface input, :request_vote, [:term]
interface output, :vote_response, [:host, :term, :voteGranted]
```

### *input*: request\_vote

- `term`: The current term of the Candidate requesting the election.

### *output*: vote\_response

- `host`: The `ip_port` of the voter casting the vote.
- `term`: The current term of the voter casting the vote.
- `voteGranted`: a boolean `true` or `false` indicating if the requesting Candidate is voted for or not.
