class LogManager
  attr_reader :log, :committed_log

  def initialize(node)
    @node = node
    @log = []
    @committed_log = []
    @append_responses = 0
  end

  def append_log_entry(data)
    return unless @node.leader?

    @log << { term: @node.term, data: data }
    @append_responses = 1

    prev_log_index = @log.size - 2
    prev_log_term = prev_log_index >= 0 ? @log[prev_log_index][:term] : nil

    @node.neighbors.each do |neighbor|
      next if neighbor.disconnected

      neighbor.receive_message({
        type: :append_request,
        term: @node.term,
        leader_id: @node.id,
        log_entry: { term: @node.term, data: data },
        prev_log_index: prev_log_index,
        prev_log_term: prev_log_term
      })
    end

    check_commit
  end

  def handle_log_message(message)
    case message[:type]
    when :append_request
      handle_append_request(message)
    when :append_response
      handle_append_response(message)
    when :request_log_sync
      send_missing_log_entries(message)
    end
  end

  def log_size
    @log.size
  end

  def commit_log_entry(log_entry)
    @committed_log << log_entry unless @committed_log.include?(log_entry)
  end

  private

  def handle_append_request(message)
    if message[:term] >= @node.term && valid_append?(message)
      @node.instance_variable_set(:@term, message[:term])

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
    @node.neighbors.each do |neighbor|
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
    if @append_responses > (@node.neighbors.size + 1) / 2
      commit_last_entry
      broadcast_commit
    end
  end

  def commit_last_entry
    @committed_log << @log.last
    puts "Node #{@node.id} commits log entry: #{@log.last[:data]}"
  end

  def broadcast_commit
    @node.neighbors.each do |neighbor|
      next if neighbor.disconnected

      neighbor.instance_variable_get(:@log_manager).commit_log_entry(@log.last) if neighbor.instance_variable_get(:@log_manager).log.include?(@log.last)
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
    puts "Node #{@node.id} requests log synchronization from leader #{leader_id}."
    @node.neighbors.each do |neighbor|
      if neighbor.id == leader_id && !neighbor.disconnected
        neighbor.receive_message({
          type: :request_log_sync,
          requestor_id: @node.id,
          requested_log_index: prev_log_index,
          requested_log_term: prev_log_term
        })
      end
    end
  end

  def send_missing_log_entries(message)
    requestor_node = @node.neighbors.find { |neighbor| neighbor.id == message[:requestor_id] }
    return if requestor_node.nil? || requestor_node.disconnected

    missing_logs = @log[message[:requested_log_index]..-1]
    missing_logs.each do |log_entry|
      prev_log_index = @log.index(log_entry) - 1
      prev_log_term = prev_log_index >= 0 ? @log[prev_log_index][:term] : nil

      requestor_node.receive_message({
        type: :append_request,
        term: log_entry[:term],
        leader_id: @node.id,
        log_entry: log_entry,
        prev_log_index: prev_log_index,
        prev_log_term: prev_log_term
      })
    end
  end
end
