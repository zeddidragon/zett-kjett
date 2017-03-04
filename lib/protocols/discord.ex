defmodule ZettKjett.Protocols.Discord do
  alias ZettKjett.Protocols.Discord.Rest
  use ZettKjett.Protocols.Base
  @behaviour ZettKjett.Protocols.Servers
  alias ZettKjett.Models.{Server, Channel, Chat, User, Message}

  def start_link! listener do
    {:ok, pid} = Task.start_link fn -> loop(listener) end
    Process.register pid, __MODULE__
    {:ok, pid}
  end

  defp loop listener do
    receive do
      message -> IO.inspect(message)
    end
    loop listener
  end

  defp normalize_user obj do
    %User{id: obj["id"], name: obj["username"]}
  end

  def normalize_dm obj do
    user = normalize_user(obj["recipient"])
    {%Chat{id: obj["id"], user_id: user.id }, user}
  end

  def me! do
    {:ok, user} = Rest.get("/users/@me")
      |> Map.get(:body)
    user
      |> normalize_user()
  end

  def nick! name do
    Rest.patch("/users/@me", body: %{username: name})
  end

  def friends! do
    {:ok, channels} = Rest.get("/users/@me/channels")
      |> Map.get(:body)
    channels
      |> Enum.map(&normalize_dm(&1))
  end

  def channels! guild do
    Rest.get("/guilds/#{guild["id"]}/channels") |> Map.get(:body)
  end

  def servers! do
    Rest.get("/users/@me/guilds") |> Map.get(:body)
  end

  def create_server! name, options \\ %{} do
    options = Map.put(options, :name, name)
    Rest.post("/guilds", body: options)
      |> Map.get(:body)
  end

  def update_server! id, options \\ %{} do
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
    # Discord would give me a 400 Bad Request for all GET requests
    # unless I put this check in.
    if body == "" do
      body
    else
      JSON.encode body
    end
  end

  def process_response_body(body) do
    body
      |> IO.iodata_to_binary
      |> JSON.decode
  end
end
