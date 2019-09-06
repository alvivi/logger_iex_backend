# LoggerIexBackend

*LoggerIexBackend* is a
[Logger Backend](https://hexdocs.pm/logger/master/Logger.html#module-backends)
for [IEx](https://hexdocs.pm/iex/IEx.html) interactive sessions.

If you have run into an *IEx* session of an Elixir application that makes
exhaustive use of standard output logging, you probably have found a mostly
unusable interactive shell. This is usually solved disabling logging, increasing
logger lever or using an alternative backend like
[LoggerFileBackend](https://github.com/onkel-dirtus/logger_file_backend).

*LoggerIexBackend* solves this problem and also enables logging debugging
with tools like logs filtering and dynamic log configuration.


## Example

Given the following code example:

```elixir
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
```

We can use *LoggerIexBackend* in a interactive shell like this:

```
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
```
