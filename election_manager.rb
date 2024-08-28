class ElectionManager
  attr_reader :leader_id

  def initialize(node)
    @node = node
    @term = node.term
    @votes_received = 0
    @voted_for = nil
    @leader_id = nil
  end

  def start_election
    @term += 1
    @votes_received = 1
    @voted_for = @node.id

    @node.neighbors.each do |neighbor|
      next if neighbor.disconnected

      neighbor.receive_message({
        type: :vote_request,
        term: @term,
        candidate_id: @node.id,
        log_size: @node.retrieve_log.size
      })
    end

    wait_for_votes
  end

  def handle_election_message(message)
    case message[:type]
    when :vote_request
      handle_vote_request(message)
    when :vote_response
      handle_vote_response(message)
    when :leader_elected
      handle_leader_elected(message)
    end
  end

  def leader?
    @leader_id == @node.id
  end

  def current_leader
    @leader_id
  end

  def update_leader_info(leader_id, term)
    @leader_id = leader_id
    @term = term
  end

  private

  def wait_for_votes
    sleep(1)

    if @votes_received > (@node.neighbors.size + 1) / 2
      @node.instance_variable_set(:@term, @term)
      broadcast_leader_election
    else
      puts "Node #{@node.id} could not secure a majority of votes and will not become leader."
    end
  end

  def handle_vote_request(message)
    if message[:term] > @term || (message[:term] == @term && @voted_for.nil?)
      if message[:log_size] >= @node.retrieve_log.size
        @voted_for = message[:candidate_id]
        @term = message[:term]

        send_vote_response(message[:candidate_id], true)
      else
        send_vote_response(message[:candidate_id], false)
      end
    else
      send_vote_response(message[:candidate_id], false)
    end
  end

  def send_vote_response(candidate_id, vote_granted)
    @node.neighbors.each do |neighbor|
      if neighbor.id == candidate_id && !neighbor.disconnected
        neighbor.receive_message({
          type: :vote_response,
          term: @term,
          vote_granted: vote_granted
        })
      end
    end
  end

  def handle_vote_response(message)
    @votes_received += 1 if message[:vote_granted]
  end

  def broadcast_leader_election
    @leader_id = @node.id
    @node.neighbors.each do |neighbor|
      next if neighbor.disconnected

      neighbor.receive_message({
        type: :leader_elected,
        leader_id: @leader_id,
        term: @term
      })
    end
    puts "Node #{@node.id} becomes leader in term #{@term}."
  end

  def handle_leader_elected(message)
    if message[:term] >= @term
      @leader_id = message[:leader_id]
      @term = message[:term]
      puts "Node #{@node.id} acknowledges leader #{message[:leader_id]} for term #{@term}."
    end
  end
end
