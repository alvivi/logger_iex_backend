defmodule LoggerIexBackendTest do
  use ExUnit.Case

  require Logger

  defmodule Mock do
    @behaviour :gen_event

    @impl true
    def init(observer), do: {:ok, observer}

    @impl true
    def handle_call(_request, observer) do
      {:ok, :ok, observer}
    end

    @impl true
    def handle_event(event, observer) do
      send(observer, event)
      {:ok, observer}
    end
  end

  setup_all do
    Logger.BackendSupervisor.unwatch(:console)
  end

  setup do
    start_args = [{Logger, LoggerIexBackend, handler: Mock, options: self()}]
    child_spec = %{id: LoggerIexBackend, start: {Logger.Watcher, :start_link, start_args}}

    with {:ok, _pid} <- start_supervised(child_spec) do
      :ok
    end
  end

  describe "set_rules/1" do
    test "called with `allow: :all` enables all logging levels" do
      LoggerIexBackend.set_rules({:allow, :all})

      Logger.debug("foo")
      assert_receive {:debug, _gl, {Logger, "foo", _ts, _meta}}

      Logger.info("bar")
      assert_receive {:info, _gl, {Logger, "bar", _ts, _meta}}

      Logger.warn("baz")
      assert_receive {:warn, _gl, {Logger, "baz", _ts, _meta}}

      Logger.error("qux")
      assert_receive {:error, _gl, {Logger, "qux", _ts, _meta}}
    end

    test "called with `disallow: :all` disables all logging levels" do
      LoggerIexBackend.set_rules(disallow: :all)

      Logger.debug("foo")
      refute_receive {:debug, _gl, {Logger, "foo", _ts, _meta}}

      Logger.info("bar")
      refute_receive {:info, _gl, {Logger, "bar", _ts, _meta}}

      Logger.warn("baz")
      refute_receive {:warn, _gl, {Logger, "baz", _ts, _meta}}

      Logger.error("qux")
      refute_receive {:error, _gl, {Logger, "qux", _ts, _meta}}
    end

    test "called with `allow: :debug` enables only debug logging" do
      LoggerIexBackend.set_rules(allow: :debug)

      Logger.debug("foo")
      Logger.info("bar")
      Logger.warn("baz")
      Logger.error("qux")

      assert_receive {:debug, _gl, {Logger, "foo", _ts, _meta}}
      refute_receive {:info, _gl, {Logger, "bar", _ts, _meta}}
      refute_receive {:warn, _gl, {Logger, "baz", _ts, _meta}}
      refute_receive {:error, _gl, {Logger, "qux", _ts, _meta}}
    end

    test "called with `allow: [:info, :warn]` enables these two levels" do
      LoggerIexBackend.set_rules(allow: [:info, :warn])

      Logger.debug("foo")
      Logger.info("bar")
      Logger.warn("baz")
      Logger.error("qux")

      refute_receive {:debug, _gl, {Logger, "foo", _ts, _meta}}
      assert_receive {:info, _gl, {Logger, "bar", _ts, _meta}}
      assert_receive {:warn, _gl, {Logger, "baz", _ts, _meta}}
      refute_receive {:error, _gl, {Logger, "qux", _ts, _meta}}
    end

    test "called with a meta list enables these two levels" do
      LoggerIexBackend.set_rules(allow: [line: 101])

      Logger.debug("foo")
      Logger.info("bar")

      assert_receive {:debug, _gl, {Logger, "foo", _ts, _meta}}
      refute_receive {:info, _gl, {Logger, "bar", _ts, _meta}}
    end

    test "called with a matching message binary enables that log" do
      LoggerIexBackend.set_rules(allow: "oo")

      Logger.debug("foo")
      Logger.info("bar")
      Logger.warn("foo")
      Logger.error("qux")

      assert_receive {:debug, _gl, {Logger, "foo", _ts, _meta}}
      refute_receive {:info, _gl, {Logger, "bar", _ts, _meta}}
      assert_receive {:warn, _gl, {Logger, "foo", _ts, _meta}}
      refute_receive {:error, _gl, {Logger, "qux", _ts, _meta}}
    end

    test "called with a matching message regex enables that log" do
      LoggerIexBackend.set_rules(allow: ~r/(qux)|(baz)/)

      Logger.debug("foo")
      Logger.info("bar")
      Logger.warn("baz")
      Logger.error("qux")

      refute_receive {:debug, _gl, {Logger, "foo", _ts, _meta}}
      refute_receive {:info, _gl, {Logger, "bar", _ts, _meta}}
      assert_receive {:warn, _gl, {Logger, "baz", _ts, _meta}}
      assert_receive {:error, _gl, {Logger, "qux", _ts, _meta}}
    end

    test "called with a matching meta regex enables that log" do
      LoggerIexBackend.set_rules(allow: {:module, ~r/Logger.*/})
      Logger.debug("foo")
      assert_receive {:debug, _gl, {Logger, "foo", _ts, _meta}}
    end

    test "called without a matching meta regex does not enable that log" do
      LoggerIexBackend.set_rules(allow: {:module, ~r/wow/})
      Logger.debug("foo")
      refute_receive {:debug, _gl, {Logger, "foo", _ts, _meta}}
    end

    test "called with a regex over invalid field does not enables that log" do
      LoggerIexBackend.set_rules(allow: {:mod, ~r/Logger.*/})
      Logger.debug("foo")
      refute_receive {:debug, _gl, {Logger, "foo", _ts, _meta}}
    end

    test "called with a matching meta value enables that log" do
      LoggerIexBackend.set_rules(allow: {:module, LoggerIexBackendTest})
      Logger.debug("foo")
      assert_receive {:debug, _gl, {Logger, "foo", _ts, _meta}}
    end

    test "called without a matching meta value does not enable that log" do
      LoggerIexBackend.set_rules(allow: {:module, nil})
      Logger.debug("foo")
      refute_receive {:debug, _gl, {Logger, "foo", _ts, _meta}}
    end
  end
end
