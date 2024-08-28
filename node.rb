class Node
  attr_reader :id, :term, :neighbors, :disconnected

  def initialize(id)
    @id = id
    @term = 0
    @neighbors = []
    @disconnected = false
    @election_manager = ElectionManager.new(self)
    @log_manager = LogManager.new(self)
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
    @election_manager.start_election unless @disconnected
  end

  def append_log_entry(data)
    @log_manager.append_log_entry(data) unless @disconnected
  end

  def receive_message(message)
    return if @disconnected

    case message[:type]
    when :vote_request, :vote_response, :leader_elected
      @election_manager.handle_election_message(message)
    when :append_request, :append_response, :request_log_sync
      @log_manager.handle_log_message(message)
    when :request_leader
      respond_with_leader(message)
    when :current_leader
      update_leader_info(message)
    end
  end

  def leader?
    @election_manager.leader?
  end

  def current_leader
    @election_manager.current_leader
  end

  def retrieve_log
    @log_manager.log
  end

  private

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
    if current_leader
      @neighbors.each do |neighbor|
        if neighbor.id == message[:requestor_id] && !neighbor.disconnected
          neighbor.receive_message({
            type: :current_leader,
            leader_id: current_leader,
            term: @term
          })
        end
      end
    end
  end

  def update_leader_info(message)
    if message[:term] >= @term
      @election_manager.update_leader_info(message[:leader_id], message[:term])
      puts "Node #{@id} updated leader information to Node #{message[:leader_id]} for term #{@term}."
    end
  end
end
