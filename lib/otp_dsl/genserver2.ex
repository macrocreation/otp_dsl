defmodule OtpDsl.Genserver2 do

  @moduledoc OtpDsl.Util.LazyDoc.for("## OtpDsl.Genserver")

  @hidden_state_name :s_t_a_t_e

  @doc nil
  defmacro __using__(options) do

    quote do
      use GenServer
      import unquote(__MODULE__)
      
      def start_link(state, opts \\ []) do
        GenServer.start_link(__MODULE__, state, opts)
      end    

    end
  end

  @doc """
  Define both a module API and the function that handles calls to that API in the server.
  For example, if you write

      defcall increment(n) do
        reply(n+1)
      end

  You will get the following two functions defined

     def increment(n) do
       gen_server.call(my_name, {:increment, n})
     end

     def handle_call({:increment, n}, _from, «state») do
       { :reply, n+1, «state» }
     end

  In this case, our server maintains no state of its own, so we fake out a
  state (shown as «state» above).

  If you need state, then pass in the name of the state parameter as a second
  argument to defcall, and pass a new state out as a second parameter
  to the `reply` call.

      defmodule KvServer do
        use OtpDsl.Genserver, initial_state: HashDict.new

        defcall put(key, value), kv_store do
          reply(value, Dict.put(kv_store, key, value))
        end

        defcall get(key), kv_store do
          reply(Dict.get(kv_store, key), kv_store)
        end
      end

  In this example, we make the state available in the variable
  `kv_store`.
  """

  defmacro defcall({name, meta, params}, state_name \\ {@hidden_state_name, [], nil}, do: body) do
    quote do
      def unquote({name, meta, [{:pid, meta, nil}] ++ params}) do
        :gen_server.call(unquote({:pid, meta, nil}), {unquote(name), unquote_splicing(params)}, :infinity)
      end

      def handle_call({unquote(name), unquote_splicing(params)}, var!(_from, nil), unquote(state_name)) do
        case unquote(body) do
          { :reply, value, unquote(@hidden_state_name) } -> { :reply, value, unquote(state_name) }
          { :reply, value, new_state }          -> { :reply, value, new_state }
        end
      end
    end
    
  end

  @doc """
  Define both a module API and the function for broadcasting the message to the server.
  For example, if you write

      defcast chat_message(msg) do
        IO.puts msg
        noreply
      end

  You will get the following two functions defined:

      def chat_message(msg) do
        gen_server.cast(my_name, {:chat_message, msg})
      end

      def handle_cast({:chat_message, msg}, _from, «state») do
        IO.puts msg
        { :noreply, «state» }
      end

  In this case, our server maintains no state of its own, so we fake out a
  state (shown as «state» above).

  If you need state, then pass in the name of the state parameter as a second
  argument to `defcast`, and pass the new state to `noreply`.

      defmodule ChatServer do
        use OtpDsl.Genserver, initial_state: []

        defcast message(text), history do
          noreply [text|history]
        end

        defcall log(), history do
          reply history, history
        end
      end

  In this example, we make the state available in the variable
  `history`.
  """
  defmacro defcast({name, meta, params}, state_name \\ {@hidden_state_name, [], nil}, do: body) do
    quote do
      def unquote({name, meta, [{:pid, meta, nil}] ++ params}) do
        :gen_server.cast(unquote({:pid, meta, nil}), {unquote(name), unquote_splicing(params)})
      end

      def handle_cast({unquote(name), unquote_splicing(params)}, unquote(state_name)) do
        unquote(body)
      end
    end
  end

  @doc """
  Generate a reply from a call handler. The value will be
  returned as the second element of the :reply tuple. The optional
  second parameter gives the new state value. If omitted, it
  defaults to the value of the state passed into `handle_call`.
  """
  def reply(value),            do: { :reply, value, @hidden_state_name }
  def reply(value, new_state), do: { :reply, value, new_state }

  @doc """
  Generate a "no reply" from a call handler. No value will be returned.
  The optional parameter is the new state value.
  If omitted, it defaults to the value of the state passed into `handle_call`.
  """
  def noreply,            do: { :noreply, @hidden_state_name }
  def noreply(new_state), do: { :noreply, new_state }

  #####
  # Ideally should be private, but...

  def name_from(module_name) do
    Regex.replace(~r{(.)\.?([A-Z])}, inspect(module_name), "\\1_\\2")
    |> String.downcase
    |> :erlang.binary_to_atom(:latin1)
  end
end
