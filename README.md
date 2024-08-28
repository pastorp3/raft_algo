# Distributed System Simulation with RAFT

### `Node` Class

The `Node` class represents an individual node in the distributed system. Each node has a unique identifier, can send and receive messages, and participates in leader elections and log management. The `Node` class manages the state of the node, including its term, leadership status, and network neighbors.


### `ElectionManager` Class

The `ElectionManager` class manages the leader election process for a node. It handles the initiation of elections, voting, and the broadcasting of election results. The `ElectionManager` ensures that the term is incremented each time a new leader is elected and that all nodes in the network are informed of the new leader.


### `LogManager` Class

The `LogManager` class is responsible for managing the log entries on a node. It handles appending new entries, committing entries, and synchronizing logs between nodes. The `LogManager` ensures that logs are consistent across the network, even in cases of disconnection and reconnection.

---
## Setup

Before execute any of the next cases, execute the next commands to include classes in your console session:

```ruby
irb
irb(main):001>  require_relative ".../node"
irb(main):001>  require_relative ".../log_manager"
irb(main):001>  require_relative ".../election_manager"
```




## Node Propose to be Leader

```ruby
node1 = Node.new(1)
node2 = Node.new(2)
node3 = Node.new(3)

node1.add_neighbor(node2)
node1.add_neighbor(node3)
node2.add_neighbor(node1)
node2.add_neighbor(node3)
node3.add_neighbor(node1)
node3.add_neighbor(node2)

node1.propose_to_leader

# Check if each node considers itself the leader
node1.leader?  # => true
node2.leader?  # => false
node3.leader?  # => false
```

---

## Leader Node Appends a New Entry

```ruby
node1 = Node.new(1)
node2 = Node.new(2)
node3 = Node.new(3)

node1.add_neighbor(node2)
node1.add_neighbor(node3)
node2.add_neighbor(node1)
node2.add_neighbor(node3)
node3.add_neighbor(node1)
node3.add_neighbor(node2)

node1.propose_to_leader
node1.append_log_entry("State 1 from Node 1")

# Retrieve logs from each node
node1.retrieve_log  # => [{"term"=>1, "data"=>"State 1 from Node 1"}]
node2.retrieve_log  # => [{"term"=>1, "data"=>"State 1 from Node 1"}]
node3.retrieve_log  # => [{"term"=>1, "data"=>"State 1 from Node 1"}]
```

---

## Leader Node Appends New Entries While a Follower Node is Disconnected and Reconnects to Get Missing Entries

```ruby
node1 = Node.new(1)
node2 = Node.new(2)
node3 = Node.new(3)

node1.add_neighbor(node2)
node1.add_neighbor(node3)
node2.add_neighbor(node1)
node2.add_neighbor(node3)
node3.add_neighbor(node1)
node3.add_neighbor(node2)

node1.propose_to_leader
node1.append_log_entry("State 1 from Node 1")

# Node 3 disconnects from the network
node3.disconnect

# Leader continues appending new log entries
node1.append_log_entry("State 2 from Node 1")
node1.append_log_entry("State 3 from Node 1")
node1.append_log_entry("State 4 from Node 1")
node1.append_log_entry("State 5 from Node 1")

# Node 3 reconnects to the network
node3.reconnect

# Leader appends another log entry after Node 3 has reconnected
node1.append_log_entry("State 6 from Node 1")

# Retrieve logs from each node
node1.retrieve_log  # => [{"term"=>1, "data"=>"State 1 from Node 1"}, ..., {"term"=>1, "data"=>"State 6 from Node 1"}]
node2.retrieve_log  # => [{"term"=>1, "data"=>"State 1 from Node 1"}, ..., {"term"=>1, "data"=>"State 6 from Node 1"}]
node3.retrieve_log  # => [{"term"=>1, "data"=>"State 1 from Node 1"}, ..., {"term"=>1, "data"=>"State 6 from Node 1"}]
```

---

## Leader Node Disconnects, and a New Node Proposes as Leader

```ruby
node1 = Node.new(1)
node2 = Node.new(2)
node3 = Node.new(3)

node1.add_neighbor(node2)
node1.add_neighbor(node3)
node2.add_neighbor(node1)
node2.add_neighbor(node3)
node3.add_neighbor(node1)
node3.add_neighbor(node2)

node1.propose_to_leader
node1.append_log_entry("State 1 from Node 1")

# Node 1 disconnects from the network
node1.disconnect

# Node 2 proposes itself as the new leader
node2.propose_to_leader

# Node 2 appends a new log entry as the leader
node2.append_log_entry("State 2 from Node 2")

# Node 1 reconnects to the network
node1.reconnect

# Node 2 appends another log entry after Node 1 has reconnected
node2.append_log_entry("State 3 from Node 2")

# Retrieve logs from each node
node1.retrieve_log  # => [{"term"=>1, "data"=>"State 1 from Node 1"}, ..., {"term"=>2, "data"=>"State 3 from Node 2"}]
node2.retrieve_log  # => [{"term"=>1, "data"=>"State 1 from Node 1"}, ..., {"term"=>2, "data"=>"State 3 from Node 2"}]
node3.retrieve_log  # => [{"term"=>1, "data"=>"State 1 from Node 1"}, ..., {"term"=>2, "data"=>"State 3 from Node 2"}]
```

---

## Node Proposes to be Leader but Doesn't Have a Majority of Votes

```ruby
node1 = Node.new(1)
node2 = Node.new(2)
node3 = Node.new(3)

node1.add_neighbor(node2)
node1.add_neighbor(node3)
node2.add_neighbor(node1)
node2.add_neighbor(node3)
node3.add_neighbor(node1)
node3.add_neighbor(node2)

# Nodes 2 and 3 disconnect from the network
node2.disconnect
node3.disconnect

# Node 1 attempts to become the leader
node1.propose_to_leader

# Node 1 cannot become the leader because it doesn't have a majority of votes.
```

---
