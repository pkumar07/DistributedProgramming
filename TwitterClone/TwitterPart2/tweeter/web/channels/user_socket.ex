defmodule Tweeter.UserSocket do
  use Phoenix.Socket

  ## Channels
  # channel "room:*", Tweeter.RoomChannel
  channel "tweeter:*", TweeterWeb.TweeterWebChannel
  ## Transports
  transport :websocket, Phoenix.Transports.WebSocket
  # transport :longpoll, Phoenix.Transports.LongPoll

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
 # def connect(%{"name" => name} =  map, socket) do
    def connect(_params, socket) do
    #{:ok, socket}  
  #  {:ok, assign(socket, :name, name)}
    #token = Phoenix.Token.sign(TweeterWeb.Endpoint, "process salt", user_id)
    #case Phoenix.Token.verify(socket, map.name, token, max_age: 1209600) do
      #{:ok, process} ->
      #  socket = assign(socket, String.to_atom(params.name), params.name)
        {:ok, socket}
      #{:error, _} -> #...
    #end
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "users_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     Tweeter.Endpoint.broadcast("users_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  #def id(socket), do: "#{socket.assigns.name}"
  def id(socket), do: nil
end
