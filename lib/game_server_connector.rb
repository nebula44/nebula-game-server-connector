require 'socket'

class GameServerConnector
  # Raised when error in remote side is given.
  class RemoteError < RuntimeError; end

  attr_reader :hostname, :port

  def initialize(logger, hostname, port, auth_token)
    @logger = logger
    @hostname = hostname
    @port = port
    @auth_token = auth_token
  end

  def request(action, params = {})
    message = {
      :action => action,
      :params => params
    }

    send_to_remote(message)
  rescue RemoteError => e
    raise e.class, "Failed to complete the action: #{action}!\n\nMessage:\n#{
      message.inspect}\n#{e.message}", e.backtrace
  end

  private

  def send_to_remote(action)
    @logger.info("Connecting to #{@hostname}:#{@port}")
    socket = TCPSocket.new(@hostname, @port)

    action[:params] ||= {}
    action[:params][:control_token] = @auth_token
    action[:id] = Time.now.to_i.to_s

    json = action.to_json
    @logger.debug("Sending: #{json}")
    socket.write(json + "\n")

    response = JSON.parse(socket.gets("\n"))

    if response["reply_to"]
      confirmation = response
      @logger.debug("Server sent no response.")
      @logger.debug("Received confirmation: #{confirmation.inspect}")
      params = {}
    else
      confirmation = socket.gets("\n")
      confirmation = JSON.parse(confirmation) unless confirmation.nil?
      params = response["params"]
      @logger.debug("Received response: #{response.inspect}")
      @logger.debug("Received confirmation: #{confirmation.inspect}")
    end

    socket.close

    if confirmation.nil?
      @logger.info("Server sent blank response, auth_token may be incorrect")
      raise RemoteError, "Server sent blank response, auth_token may be incorrect"
    elsif confirmation['failed']
      @logger.info("Remote action failed, confirmation: #{confirmation.inspect}")
      error = confirmation['error']
      raise RemoteError, "#{error['type']}: #{error['message']}"
    else
      @logger.info("Success!")
    end

    params
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
    @logger.error("Connection to #{
      @hostname}:#{@port} failed!")
    false
  end
end
