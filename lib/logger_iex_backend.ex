defmodule LoggerIexBackend do
  @moduledoc ~s"""
  A [Logger Backend](https://hexdocs.pm/logger/master/Logger.html#module-backends)
  for [IEx](https://hexdocs.pm/iex/IEx.html) interactive sessions.

  LoggerIexBackend enables logging debugging in *IEx* interactive sessions. See
  `start/0` and `set_rules/1` to learn how to use this module.

  ## Example

  Given the following code example:

      defmodule Example do
        require Logger

        def foo() do
          Logger.debug("A foo message")
        end

        defmodule Bar do
          require Logger

          def bar() do
            Logger.info("A bar message")
          end
        end
      end

  We can use *LoggerIexBackend* in a interactive shell like this:

      iex> Example.foo()
      00:00:01.000 [debug] A foo message
      :ok
      iex> LoggerIexBackend.start()
      {:ok, #PID<0.42.0>}
      iex> Example.foo()
      :ok # NOTE that by default, all logs are disabled by LoggerIexBackend
      iex> LoggerIexBackend.set_rules(allow: :info)
      :ok
      iex> Example.foo()
      :ok # No logs here yet
      iex> Example.Bar.bar()
      :ok
      00:00:02.000 [info]  A bar message
      iex> LoggerIexBackend.set_rules(allow: ~r/foo/) # Enable logs by message
      iex> LoggerIexBackend.set_rules(allow: [module: Example]) # Enable logs by module
      :ok
      iex> Example.foo()
      :ok
      00:00:03.000 [debug] A foo message
  """

  alias Logger.Backends.Console

  @behaviour :gen_event

  @levels [:debug, :info, :warn, :error]

  defstruct manager: nil,
            rules: []

  @typedoc "A predicate to allow or disallow a set of log entries."
  @type rule() :: {:allow, argument()} | {:disallow, argument()}

  @typedoc "A list of `t:rule/0`s."
  @type rules() :: [rule()]

  @typedoc """
  A condition used to filter logs.

  Any of the following arguments can be used as rule to allow or disallow
  matching logs:

  * `all`: matches all logs.
  * `:debug`, `:info`, `:error`, etc. Matches the specified log level.
  * A list of the previous values.
  * A string contained in log's messages.
  * A regular expression to test log's messages.
  * A tuple to match any other metadata value.

  ## Examples

      # Enable all logs:
      LoggerIexBackend.set_rules(allow: :all)

      # Enable logs by level:
      LoggerIexBackend.set_rules(allow: :debug)
      LoggerIexBackend.set_rules(allow: [:warn, :error])

      # Enable logs by messages:
      LoggerIexBackend.set_rules(allow: "foo") # All messages containing foo.
      LoggerIexBackend.set_rules(allow: ~r/foo/)

      # Enable logs by metadata:
      LoggerIexBackend.set_rules(allow: {:module, MyModule})
      LoggerIexBackend.set_rules(allow: {:file, "my_file.ex"})
  """
  @type argument() ::
          :all
          | Logger.level()
          | [Logger.level()]
          | String.t()
          | Regex.t()
          | {atom(), Regex.t()}
          | {atom(), term()}

  @typep logger_message() :: {Logger, String.t(), any(), any()}
  @typep logger_entry() :: {Logger.level(), pid(), logger_message()}
  @typep logger_event() :: logger_entry() | :flush

  @doc """
  Starts the *IEx Logger Backend*.

  This function will stop the current console backend, if enabled, and start
  the *IEx Backend*. All logs will be filtered out by default. Use
  `set_rules/1` to allow log messages to be printed.
  """
  @spec start() :: :ok | {:error, term()}
  def start() do
    Logger.BackendSupervisor.unwatch(:console)
    Logger.BackendSupervisor.watch(__MODULE__)
  end

  @doc """
  Set the current rules for log filtering.

  This function will remove previous rules for filtering log messages and apply
  the given new ones. More information about the kind of rules can be found at
  `t:argument/0`.
  """
  @spec set_rules(rule() | rules()) :: :ok
  def set_rules(rule_or_rules)

  def set_rules(rule) when not is_list(rule), do: set_rules([rule])
  def set_rules(rules), do: :gen_event.call(Logger, __MODULE__, {:rules, rules})

  @doc false
  @impl true
  def init(__MODULE__), do: init([])

  def init(opts) do
    handler = Keyword.get(opts, :handler, Console)
    handler_opts = Keyword.get(opts, :options, {Console, level: :debug})

    {:ok, manager} = :gen_event.start_link()
    :ok = :gen_event.add_handler(manager, handler, handler_opts)
    {:ok, %__MODULE__{manager: manager}}
  end

  @impl true
  def handle_call(request, state)

  def handle_call({:rules, rules}, state) do
    {:ok, :ok, %__MODULE__{state | rules: rules}}
  end

  @impl true
  def handle_event(event, %{manager: manager, rules: rules} = state) do
    if match_rules?(rules, event) do
      :ok = :gen_event.notify(manager, event)
    end

    {:ok, state}
  end

  @impl true
  def handle_info(info, state)

  def handle_info({:gen_event_EXIT, _handler, reason}, _state)
      when reason in [:normal, :shutdown] do
    :remove_handler
  end

  def handle_info({:gen_event_EXIT, _handler, reason}, _state) do
    IO.puts(:stderr, "console backend terminating: #{inspect(reason)}")
    :remove_handler
  end

  @spec match_rules?(rules(), logger_event()) :: boolean()
  defp match_rules?(_rules, :flush), do: true

  defp match_rules?(rules, entry) do
    Enum.reduce(rules, false, &match_step(&1, entry, &2))
  end

  @spec match_step(rule(), logger_entry(), boolean()) :: boolean()
  defp match_step(rule, entry, acc)

  defp match_step({action, :all}, _entry, _acc) do
    action == :allow
  end

  defp match_step({action, level}, {level, _gl, _msg}, _acc)
       when level in @levels do
    action == :allow
  end

  defp match_step({action, levels_or_metas}, {level, _gl, _msg} = entry, acc)
       when is_list(levels_or_metas) do
    if Keyword.keyword?(levels_or_metas) do
      meta_list = levels_or_metas
      Enum.reduce(meta_list, acc, &match_step({action, &1}, entry, &2))
    else
      levels = levels_or_metas
      if level in levels, do: action == :allow, else: acc
    end
  end

  defp match_step({_action, level}, _entry, acc)
       when level in @levels do
    acc
  end

  defp match_step({action, pattern}, {_lvl, _gl, {Logger, msg, _ts, _meta}}, acc)
       when is_binary(pattern) do
    if msg =~ pattern, do: action == :allow, else: acc
  end

  defp match_step({action, %Regex{} = regex}, {_lvl, _gl, {Logger, msg, _ts, _meta}}, acc) do
    if Regex.match?(regex, msg), do: action == :allow, else: acc
  end

  defp match_step({action, {key, %Regex{} = regex}}, {_lvl, _gl, {Logger, _msg, _ts, meta}}, acc) do
    if Keyword.has_key?(meta, key) do
      value = to_string(Keyword.fetch!(meta, key))

      if Regex.match?(regex, value) do
        action == :allow
      else
        acc
      end
    else
      acc
    end
  end

  defp match_step({action, {key, value}}, {_lvl, _gl, {Logger, _msg, _ts, meta}}, acc) do
    if Keyword.has_key?(meta, key) && Keyword.fetch!(meta, key) == value do
      action == :allow
    else
      acc
    end
  end
end
