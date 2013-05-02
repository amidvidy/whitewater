# timeout.rb

## *module*: TimeoutProto

`TimeoutProto` defines an abstract interface for a variable-length timeout module. 


```ruby
interface input, :config, [] => [:min_timeout, :max_timeout]
interface input, :snooze, [:id]
interface output, :alarm, [:id]
```

### *input*: config

*Note: This collection must be inserted into once, and only once at bootstrap time.*

- `min_timeout`: The minimum duration of a timeout.
- `max_timeout`: The maximum duration of a timeout.

### *input*: snooze

An insertion on this collection will start a timeout.

- `id`: A unique identifier used for each request to the module. Anything works, as long
	as it is the same for the lifetime of the program.

### *output*: alarm

A tuple will be outputted to this interface when a timeout is triggered. 

*Note: After an `alarm` is triggered, a timeout will not occur until a subsequent insertion on the `snooze` interface.*

- `id`: Same unique identifier used for `snooze`.


## *module*: UniformlyDistributedTimeout

A concrete implementation of `TimeoutProto` that selects a timeout length by sampling on the
distribution U[`min_timeout`, `max_timeout`].

