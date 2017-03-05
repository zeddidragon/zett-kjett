defmodule ZettKjett.Protocols.Discord do
  alias ZettKjett.Protocols.Discord.Rest
  @behaviour ZettKjett.Protocols.Servers
  alias ZettKjett.Models.{Server, Channel, Chat, User, Message}

  def start_link listener do
    ZettKjett.Protocols.Discord.Websocket.start_link listener
  end

  def normalize_user obj do
    %User{
      id: obj["id"] || obj['id'],
      name: obj["username"] || obj['username']
    }
  end

  def normalize_dm obj do
    user = normalize_user(obj["recipient"] || obj['recipient'])
    chat = %Chat{
      id: obj["id"] || obj['id']
    }
    {user, chat}
  end

  def normalize_message obj do
    user = normalize_user(obj["author"])
    message = %Message{
      id: obj["id"] || obj['id'],
      sent_at: obj["timestamp"] || obj['timestamp'],
      edited_at: obj["edited_timestamp"] || obj['edited_timestamp'],
      content: obj["content"] || obj['content']
    }
    {user, message}
  end

  def normalize_channel obj do
    %Channel{
      id: obj["id"] || obj['id']
    }
  end

  def me do
    Rest.get("/users/@me")
      |> Map.get(:body)
      |> normalize_user()
  end

  def friends do
    []
  end

  def history chat do
    Rest.get("/channels/#{chat.id}/messages")
      |> Map.get(:body)
      |> Enum.map(&normalize_message/1)
  end

  def tell chat, message do
    body = %{ content: message }
    Rest.post("/channels/#{chat.id}/messages", body: body)
      |> Map.get(:body)
  end

  def servers do
    Rest.get("/users/@me/guilds")
      |> Map.get(:body)
  end

  def channels server do
    Rest.get("/guilds/#{server.id}/channels")
      |> Map.get(:body)
      |> Enum.map(&normalize_channel/1)
  end

  def create_server name, options \\ %{} do
    options = Map.put(options, :name, name)
    Rest.post("/guilds", body: options)
      |> Map.get(:body)
  end

  def update_server id, options \\ %{} do
    Rest.post("/guilds/#{id}", options)
      |> Map.get(:body)
  end
end

defmodule ZettKjett.Protocols.Discord.Rest do
  use HTTPotion.Base
  alias ZettKjett.Config

  def process_url url do
    "https://discordapp.com/api" <> url
  end

  def put_many_new headers, [] do
    headers
  end
  
  def put_many_new headers, [{k, v} | kvlist] do
    put_many_new Keyword.put_new(headers, k, v), kvlist
  end

  def token do
    Config.get[:Protocols][:Discord][:token] ||
      raise "Please insert discord token in config.toml"
  end
  
  @version Mix.Project.config[:version]
  @url "https://github.com/zeddidragon/zett-kjett"
  def process_request_headers headers do
    put_many_new headers, [
      {:"User-Agent", "ZettKjett (#{@url}, #{@version})"},
      {:"Authorization", token()},
      {:"Content-Type", "application/json"}
    ]
  end

  def process_request_body body do
    if body == "" do
      body
    else
      case JSON.encode body do
        {:ok, json} -> json
        _ -> body
      end
    end
  end

  def process_response_body(body) do
    body
      |> IO.iodata_to_binary
      |> JSON.decode!
  end
end

defmodule ZettKjett.Protocols.Disccord.Websocket do
  alias ZettKjett.Utils.{Socket, FileCache}
  alias ZettKjett.Protocols.Discord
  alias ZettKjett.Protocols.Discord.{Heartbeat}

  @enforce_keys [:listener, :socket]
  defstruct [
    listener: nil,
    socket: nil,
    heartbeat: nil
  ]

  def start_link listener do
    Task.start_link fn ->
      loop %__MODULE__{
        listener: listener,
        socket: connect()
      }
    end
  end

  defp connect attempts \\ 0
  defp connect(attempts) when attempts > 2 do
    raise "Failed 3 times to connect to websocket"
  end
  defp connect attempts do
    ws_url = FileCache.get_lazy! "discord-ws", fn ->
      Rest.get("/gateway")
        |> Map.get(:body)
        |> Map.get("url")
    end
    case Socket.connect ws_url do
      {:ok, pid} -> pid
      _ ->
        FileCache.invalidate! "discord-ws"
        connect attempts + 1
    end
  end

  defp loop state do
    state = receive do
      packet ->
        opcode = packet['op']
        data = packet['d']
        if opcode == 0 do
          send state.heartbeat, {:seq, packet['seq']}
          handle_event packet['t'], data, state
        else
          handle_opcode opcode, data, state
        end
    end
    loop state
  end

  # Hello
  def handle_opcode 10, data, state do
    Socket.call state.socket, %{
      'op' => 2,  # Identify
      'd' => %{
        'token' => String.to_charlist(Rest.token),
        'large_treshold' => 250,
        'compress' => false,
        'shard' => [0, 1],
        'properties' => %{
          '$os' => Atom.to_charlist(elem(:os.type, 1)),
          '$browser' => 'zett_kjett',
          '$device' => 'zett_kjett',
          '$referer' => '',
          '$referring_domain' => ''
        }
      }
    }
    %{state |
      heartbeat: Heartbeat.start_link(state.socket, data['heartbeat_interval'])
    }
  end

  # Heartbeat ACK
  def handle_opcode 11, _data, state do
    send state.heartbeat, {:ack}
    state
  end

  def handle_opcode code, data, state do
    Utils.inspect data, label: "Unhandled opcode #{code}"
    state
  end

  def handle_event 'READY', data, state do
    friends = Enum.map(data['private_channels'], &Discord.normalize_dm/1)
    send state.listener, {:friends, friends}
    state
  end

  def handle_event type, data, state do
    Utils.inspect data, label: "Unhandled event #{type}"
    state
  end
end

defmodule ZettKjett.Protocols.Discord.Heartbeat do
  alias ZettKjett.Utils.{Socket}

  @enforce_keys [:interval, :socket, :last_beat]
  defstruct [
    interval: nil,
    last_beat: nil,
    socket: nil,
    seq: nil,
    acknowledged: false
  ]

  def start_link socket, interval do 
    Task.start_link do
      loop %__MODULE__{
        socket: socket,
        interval: interval,
        last_beat: :os.system_time
      }
    end
  end

  def loop state do
    remaining = (:os.system_time - state.last_beat) / 1_000_000
    receive do
      {:ack} ->
        loop %{state | acknowledged: true}
      {:seq, seq} ->
        loop %{state | seq: seq}
    after
      remaining ->
        if state.acknowledged do
          Socket.cast state.socket, %{
            'op' => 1,  # Heartbeat
            'd' => state.seq
          }
          loop %{state | last_beat: :os.system_time}
        else
          raise "No heartbeat ack received"
        end
    end
  end
end
