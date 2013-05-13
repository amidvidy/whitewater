whitewater
==========

An implementation of the Raft consensus protocol with static membership in the Bloom programming language.

We have implemented Leader Election and Log Replication as two separate
modules.

For the purpose of test driving the log replication module, we have also
implemented an ordered, consistent, and distributed simple calculator
(lol).

## Docs

Election: <https://github.com/amidvidy/whitewater/blob/master/docs/election.md>

Server State: <https://github.com/amidvidy/whitewater/blob/master/docs/serverstate.md>

Timeout: <https://github.com/amidvidy/whitewater/blob/master/docs/timeout.md>

