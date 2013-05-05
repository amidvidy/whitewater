# serverstate.rb

## *module*: ServerStateProto

`ServerStateProto` defines an abstract interface for storing global server state.

### API

```ruby
table            :members, [:host]
interface input, :update_term, [:term]
interface input, :update_max_term_voted, [:max_term]
interface input, :update_role, [:role]
```


```ruby
interface output, :current_term, [:term]
interface output, :max_term_voted, [:max_term]
interface output, :current_role, [:role]
interface output, :current_members, [:host]
```

### *table*: members

*Note: This collection must be inserted into once, and only once, at bootstrap time.*

- `host`: The `ip_port` pair of the given endpoint.

### *input*: update_term

- `term`: The new term.

### *input*: update_max_term_voted

- `max_term`: The new highest term voted so far.

### *input*: update_role

- `role`: The server's new role. One of `:LEADER`, `:FOLLOWER`, `:CANDIDATE`.

### *output*: current_term

*Note: This interface continually announces its state.*

- `term`: The current term.

### *output*: max_term_voted

*Note: This interface continually announces its state.*

- `max_term`: The current highest term voted so far.

### *output*: current_role

*Note: This interface continually announces its state.*

- `role`: The server's current role. One of `:LEADER`, `:FOLLOWER`, `:CANDIDATE`.

### *output*: current_members

*Note: This interface continually announces its state.*

- `host`: The `ip_port` pair of the given endpoint.

## *module*: ServerStateImpl

A concrete implementation of `ServerStateProto` that facilitates storing global server state in a single location.
