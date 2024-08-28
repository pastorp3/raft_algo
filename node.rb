class Node
  attr_reader :term, :log, :neighbors, :id, :votes_received, :leader_id, :committed_log, :disconnected

  def initialize(id)
    @id = id
    @term = 0
    @log = []
    @committed_log = []
    @neighbors = []
    @voted_for = nil
    @votes_received = 0
    @leader_id = nil
    @append_responses = 0
    @disconnected = false
  end

  def add_neighbor(node)
    @neighbors << node
  end

  def disconnect
    @disconnected = true
    puts "Node #{@id} has been disconnected."
  end

  def reconnect
    @disconnected = false
    puts "Node #{@id} has reconnected."
    request_current_leader
  end

  def propose_to_leader
    start_election unless @disconnected
  end

  def append_log_entry(data)
    return unless leader?

    @log << { term: @term, data: data }
    @append_responses = 1

    prev_log_index = @log.size - 2
    prev_log_term = prev_log_index >= 0 ? @log[prev_log_index][:term] : nil

    @neighbors.each do |neighbor|
      next if neighbor.disconnected

      neighbor.receive_message({
        type: :append_request,
        term: @term,
        leader_id: @id,
        log_entry: { term: @term, data: data },
        prev_log_index: prev_log_index,
        prev_log_term: prev_log_term
      })
    end

    check_commit
  end

  def receive_message(message)
    return if @disconnected

    case message[:type]
    when :vote_request
      handle_vote_request(message)
    when :vote_response
      handle_vote_response(message)
    when :leader_elected
      handle_leader_elected(message)
    when :append_request
      handle_append_request(message)
    when :append_response
      handle_append_response(message)
    when :request_leader
      respond_with_leader(message)
    when :current_leader
      update_leader_info(message)
    when :request_log_sync
      send_missing_log_entries(message)
    end
  end

  def leader?
    @leader_id == @id
  end

  def current_leader
    @leader_id
  end

  private

  def start_election
    @term += 1
    @votes_received = 1
    @voted_for = @id

    @neighbors.each do |neighbor|
      next if neighbor.disconnected

      neighbor.receive_message({
        type: :vote_request,
        term: @term,
        candidate_id: @id,
        log_size: @log.size
      })
    end

    wait_for_votes
  end

  def wait_for_votes
    sleep(1)

    if @votes_received > (@neighbors.size + 1) / 2
      broadcast_leader_election
    else
      puts "Node #{@id} could not secure a majority of votes and will not become leader."
    end
  end

  def handle_vote_request(message)
    if message[:term] > @term || (message[:term] == @term && @voted_for.nil?)
      if message[:log_size] >= @log.size
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
    @neighbors.each do |neighbor|
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
    @leader_id = @id
    @neighbors.each do |neighbor|
      next if neighbor.disconnected

      neighbor.receive_message({
        type: :leader_elected,
        leader_id: @leader_id,
        term: @term
      })
    end
    puts "Node #{@id} becomes leader in term #{@term}."
  end

  def handle_leader_elected(message)
    if message[:term] >= @term
      @leader_id = message[:leader_id]
      @term = message[:term]
      puts "Node #{@id} acknowledges leader #{message[:leader_id]} for term #{message[:term]}."
    end
  end

  def request_current_leader
    @neighbors.each do |neighbor|
      next if neighbor.disconnected

      neighbor.receive_message({
        type: :request_leader,
        requestor_id: @id
      })
    end
  end

  def respond_with_leader(message)
    if @leader_id
      @neighbors.each do |neighbor|
        if neighbor.id == message[:requestor_id] && !neighbor.disconnected
          neighbor.receive_message({
            type: :current_leader,
            leader_id: @leader_id,
            term: @term
          })
        end
      end
    end
  end

  def update_leader_info(message)
    if message[:term] >= @term
      @leader_id = message[:leader_id]
      @term = message[:term]
      puts "Node #{@id} updated leader information to Node #{@leader_id} for term #{@term}."
    end
  end

  def handle_append_request(message)
    if message[:term] >= @term && valid_append?(message)
      @term = message[:term]

      if message[:prev_log_index] + 1 < @log.size
        existing_entry = @log[message[:prev_log_index] + 1]
        return if existing_entry == message[:log_entry]
      end

      @log[message[:prev_log_index] + 1] = message[:log_entry]
      send_append_response(message[:leader_id], true)
    else
      send_log_sync_request(message[:leader_id], message[:prev_log_index], message[:prev_log_term])
    end
  end

  def send_append_response(leader_id, success)
    @neighbors.each do |neighbor|
      if neighbor.id == leader_id && !neighbor.disconnected
        neighbor.receive_message({
          type: :append_response,
          success: success
        })
      end
    end
  end

  def handle_append_response(message)
    @append_responses += 1 if message[:success]
    check_commit
  end

  def check_commit
    if @append_responses > (@neighbors.size + 1) / 2
      commit_last_entry
      broadcast_commit
    end
  end

  def commit_last_entry
    @committed_log << @log.last
    puts "Node #{@id} commits log entry: #{@log.last[:data]}"
  end

  def broadcast_commit
    @neighbors.each do |neighbor|
      next if neighbor.disconnected

      neighbor.committed_log << @log.last if neighbor.log.include?(@log.last)
    end
  end

  def valid_append?(message)
    if message[:prev_log_index] == -1
      true
    elsif message[:prev_log_index] < @log.size && @log[message[:prev_log_index]][:term] == message[:prev_log_term]
      true
    else
      false
    end
  end

  def send_log_sync_request(leader_id, prev_log_index, prev_log_term)
    puts "Node #{@id} requests log synchronization from leader #{leader_id}."
    @neighbors.each do |neighbor|
      if neighbor.id == leader_id && !neighbor.disconnected
        neighbor.receive_message({
          type: :request_log_sync,
          requestor_id: @id,
          requested_log_index: prev_log_index,
          requested_log_term: prev_log_term
        })
      end
    end
  end

  def send_missing_log_entries(message)
    requestor_node = @neighbors.find { |neighbor| neighbor.id == message[:requestor_id] }
    return if requestor_node.nil? || requestor_node.disconnected

    missing_logs = @log[message[:requested_log_index]..-1]
    missing_logs.each do |log_entry|
      prev_log_index = @log.index(log_entry) - 1
      prev_log_term = prev_log_index >= 0 ? @log[prev_log_index][:term] : nil

      requestor_node.receive_message({
        type: :append_request,
        term: log_entry[:term],
        leader_id: @id,
        log_entry: log_entry,
        prev_log_index: prev_log_index,
        prev_log_term: prev_log_term
      })
    end
  end
end
