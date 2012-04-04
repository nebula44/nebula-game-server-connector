
describe GameServerConnector do
  let(:server_control_port) { 55345 }
  let(:server_auth_token) { "token" }
  let(:logger) { Logger.new('/dev/null') }
  let(:game_server_connector) {
    GameServerConnector.new(
      logger, "example.host", server_control_port, server_auth_token
    )
  }

  describe "#request" do
    let(:params) { ['action', {:param => :value}] }

    it 'should call send_to_remote' do
      message = {
        :action => params.first,
        :params => params.last
      }

      GameServerConnector.any_instance.should_receive(:send_to_remote).
        with(message)
      GameServerConnector.any_instance.stub(:send_to_remote)

      game_server_connector.request(*params)
    end

    it "should reraise error" do
      game_server_connector.should_receive(:send_to_remote).
        and_raise(GameServerConnector::RemoteError)

      lambda {
        game_server_connector.request(params)
      }.should raise_error(GameServerConnector::RemoteError)
    end
  end

  describe "#send_to_remote" do
    let(:message) { {:foo => "bar"} }
    let(:mock)    { mock(TCPSocket) }

    it "should do full request" do
      # send json message with token attached, read, close socket and return
      # parsed message
      message = {:foo => "bar"}
      mock = mock(TCPSocket)

      TCPSocket.should_receive(:new).
        with(game_server_connector.hostname, server_control_port).
        and_return(mock)

      time = Time.now
      Time.stub(:now).and_return(time)

      mock.should_receive(:write).with(message.merge(
        :params => {
          :control_token => server_auth_token
        },
        :id => time.to_i.to_s
      ).to_json + "\n").ordered


      mock.should_receive(:gets).with("\n").ordered.
        and_return(%Q{{"foo": "bar"}})
      mock.should_receive(:gets).with("\n").ordered.
        and_return(%Q{{"foo": "bar"}})

      mock.should_receive(:close).ordered


      game_server_connector.send(:send_to_remote, message)
    end

    [Errno::ECONNREFUSED, Errno::EHOSTUNREACH].each do |exception|
      describe "on #{exception}" do
        before(:each) do
          TCPSocket.stub!(:new).and_raise(exception)
        end

        it "should raise error" do
          expect {
            game_server_connector.send(:send_to_remote, {})
          }.should raise_error
        end
      end
    end
  end
end