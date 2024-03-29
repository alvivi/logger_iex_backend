[![Build Status](https://travis-ci.org/alvivi/logger_iex_backend.svg?branch=master)](https://travis-ci.org/alvivi/logger_iex_backend)
[![Coverage Status](https://coveralls.io/repos/github/alvivi/logger_iex_backend/badge.svg?branch=master)](https://coveralls.io/github/alvivi/logger_iex_backend?branch=master)
[![Docs](https://img.shields.io/badge/hex-1.0.0-success)](https://hexdocs.pm/logger_iex_backend/1.0.0/LoggerIexBackend.html)

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

```none
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

## Using LoggerIexBackend with IEx

To use LoggerIexBackend in your projects, first add LoggerIexBackend as a
dependency.

```elixir
def deps do
  [
    {:ex_doc, "~> 1.0", only: :dev}
  ]
end
```

Then, after installing the library using `mix deps.get` we have call
`LoggerIexBackend.start/0` to start using it.

We can also enable *IEx* log backend by default in interactive shell sessions of
our projects using `.iex.exs`:

```elixir
if :erlang.function_exported(LoggerIexBackend, :start, 0) do
  LoggerIexBackend.start()
end
```
