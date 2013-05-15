whitewater
==========

An implementation of the [Raft consensus protocol][1] with static membership in the [Bloom][2] programming language.

We have implemented Leader Election and Log Replication as two separate
modules.

For the purpose of test driving the log replication module, we have also
implemented an ordered, consistent, and distributed simple calculator.

This was made as a final project for Joe Hellerstein and Peter Alvaro's Programming the Cloud course at UC Berkeley.

## Module Documentation

[Election](https://github.com/amidvidy/whitewater/blob/master/docs/election.md)

[Server State](https://github.com/amidvidy/whitewater/blob/master/docs/serverstate.md)

[Timeout](https://github.com/amidvidy/whitewater/blob/master/docs/timeout.md)

[Log](https://github.com/amidvidy/whitewater/blob/master/docs/log.md)

[Ordered State Machine](https://github.com/amidvidy/whitewater/blob/master/docs/orderedstatemachine.md)

[1: "Ongaro, D., and Ousterhout, J. In Search of an Understandable Consensus Algorithm"](https://ramcloud.stanford.edu/wiki/download/attachments/11370504/raft.pdf)  
[2: "Bloom"](http://www.bloom-lang.net/)

