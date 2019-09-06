defmodule LoggerIexBackend do
  @moduledoc ~s"""
  TODO
  """

  alias Logger.Backends.Console

  @behaviour :gen_event

  @levels [:debug, :info, :warn, :error]

  defstruct manager: nil,
            rules: []

  @typedoc "TODO"
  @type action() :: :allow | :disallow

  @typedoc "TODO"
  @type rule() :: {action(), scope()}

  @typedoc "TODO"
  @type rules() :: [rule()]

  @typedoc "TODO"
  @type scope() ::
          :all
          | Logger.level()
          | [Logger.level()]
          | binary()
          | Regex.t()
          | {atom(), Regex.t()}
          | {atom(), term()}

  @typep logger_message() :: {Logger, String.t(), any(), any()}
  @typep logger_entry() :: {Logger.level(), pid(), logger_message()}
  @typep logger_event() :: logger_entry() | :flush

  @doc "TODO"
  @spec start() :: :ok | {:error, term()}
  def start() do
    Logger.BackendSupervisor.unwatch(:console)
    Logger.BackendSupervisor.watch(__MODULE__)
  end

  @doc "TODO"
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

  def handle_info({:gen_event_EXIT, _handler, reason}, state)
      when reason in [:normal, :shutdown] do
    {:stop, reason, state}
  end

  def handle_info({:gen_event_EXIT, _handler, reason}, state) do
    IO.puts(:stderr, "console backend terminating: #{inspect(reason)}")
    {:stop, reason, state}
  end

  @spec match_rules?(rules(), logger_event()) :: boolean()
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
