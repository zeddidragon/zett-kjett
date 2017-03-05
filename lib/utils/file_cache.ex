defmodule ZettKjett.Utils.FileCache do
  def path key do
    "./tmp/#{key}"
  end

  def get_lazy! key, cb do
    case File.read path(key) do
      {:ok, data} -> data
      _ ->
        data = cb.()
        File.mkdir_p! "./tmp/"
        {:ok, file} = File.open path(key), [:write]
        ZettKjett.Utils.inspect data, label: "Filecaching data"
        IO.binwrite file, data
        File.close file
        data
    end
  end

  def invalidate! key do
    File.rm! path(key)
  end
end
