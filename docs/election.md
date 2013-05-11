# election.rb

## *module*: LeaderElectionImpl

LeaderElection provides a high level interface to conduct elections. The logic for request vote RPCs are embedded within.

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
### Things LeaderElectionImpl does for Candidate:
-	Send out Request Vote RPC to all existing members
-	Updates its own term number if it receives a response with a higher term
-	Start a vote to count all "yes" votes returned by other members and output the current term if the candidate won the election

### Things LeaderElectionImpl does for Followers/Receivers:
-	Receives Request Vote RPCs from other candidates
-	Update its own current term number if the incoming request vote rpc contains a greater term number
-	Deterministically cast vote for a candidate once per term


### Things LeaderElection does not do:

- LeaderElection also does not implement timeouts. The Server is responsible for that.

