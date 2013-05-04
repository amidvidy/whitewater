# election.rb

## *module*: LeaderElection

LeaderElection provides a high level interface to conduct elections, it uses the RequestVoteRPC behind the scenes to contact the other servers.

```ruby
interface input, :start_election, [:candidate_id, :term, :last_log_index, :last_log_term]
interface output, :election_outcome, [:term]
```

### *input*: start\_election

- `candidate_id`: The ip_host of the requesting candidate
- `term`: The current term of the candidate requesting the election.
- `last_log_index`: not implemented, currently: `nil`
- `last_log_term`: not implemented, currently: `nil`

### *output*: outcome

- `term`: The term for which, the requesting candidate won the election with a majority vote. This remains empty if there is a tie or another candidate wins.

### Additional Info:
### Things LeaderElection does:

- LeaderElection will start a RequestVoteRPC and count the responses. If a majority of the votes are for the Candidate requesting the election, the term number is returned in the outcome.

### Things LeaderElection does not do:

-  Term does **not** get incremented by LeaderElection, the Raft Server using the LeaderElection module is responsible for that.

- LeaderElection also does not implement timeouts. The Server is again responsible for that.
