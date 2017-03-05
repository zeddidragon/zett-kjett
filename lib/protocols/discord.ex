defmodule ZettKjett.Protocols.Discord do
  alias ZettKjett.Protocols.Discord.Rest
  @behaviour ZettKjett.Protocols.Servers
  alias ZettKjett.Models.{Server, Channel, Chat, User, Message}

  def start_link listener do
    {:ok, pid} = Task.start_link fn ->
      socket = connect_socket()
      loop(listener, socket)
    end
    Process.register pid, __MODULE__
    {:ok, pid}
  end

  @path "./tmp/discord-ws"
  defp connect_socket attempts \\ 0
  defp connect_socket(attempts) when attempts > 2 do
    raise "Failed 3 times to connect to websocket"
  end
  defp connect_socket attempts do
    ws_url =
      case File.read @path do
        {:ok, url} -> url
        _ ->
          url = Rest.get("/gateway")
            |> Map.get(:body)
            |> Map.get("url")
          File.mkdir! "./tmp/"
          file = File.open @path, [:write]
          IO.binwrite file, url
          File.close file
          url
      end
    # TODO: Connect to socket after getting URL
  end

  defp loop listener, socket do
    # TODO
  end

  defp normalize_user obj do
    %User{
      id: obj["id"],
      name: obj["username"]
    }
  end

  defp normalize_dm obj do
    user = normalize_user(obj["recipient"])
    chat = %Chat{
      id: obj["id"]
    }
    {user, chat}
  end

  def normalize_message obj do
    user = normalize_user(obj["author"])
    message = %Message{
      id: obj["id"],
      sent_at: obj["timestamp"],
      edited_at: obj["edited_timestamp"],
      message: obj["content"]
    }
    {user, message}
  end

  defp normalize_channel obj do
    %Channel{id: obj["id"]}
  end

  def me do
    Rest.get("/users/@me")
      |> Map.get(:body)
      |> normalize_user()
  end

  def friends do
    Rest.get("/users/@me/channels")
      |> Map.get(:body)
      |> Enum.map(&normalize_dm/1)
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
  
  @version Mix.Project.config[:version]
  @url "https://github.com/zeddidragon/zett-kjett"
  def process_request_headers headers do
    token = Config.get[:Protocols][:Discord][:token]
    token || raise "Please insert discord token in config.toml"
    put_many_new headers, [
      {:"User-Agent", "ZettKjett (#{@url}, #{@version})"},
      {:"Authorization", token},
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
