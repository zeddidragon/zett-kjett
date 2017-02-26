defmodule ZettKjett.Protocols.Discord do
  alias ZettKjett.Protocols.Discord.Rest

  def me do
    Rest.get '/users/@me'
  end

  def guilds do
    Rest.get '/users/@me/guilds'
  end

  def create_guild name do
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
    token = Config.get[:discord][:token]
    token || raise "Please insert discord token in config.toml"
    put_many_new headers, [
      {:"User-Agent", "ZettKjett (#{@url}, #{@version})"},
      {:"Authorization", token},
      {:"Content-Type", "application/json"}
    ]
  end

  def process_request_body body do
    :jsx.encode body
  end

  def process_response_body(body) do
    body
      |> IO.iodata_to_binary
      |> :jsx.decode
  end
end
