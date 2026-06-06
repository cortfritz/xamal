defmodule Xamal.LocalIdentity do
  @moduledoc false

  def performer do
    case git_user() do
      {name, nil} -> name
      {name, email} -> "#{name} <#{email}>"
      nil -> whoami()
    end
  end

  def git_user_name do
    case git_config("user.name") do
      nil -> "Unknown"
      name -> name
    end
  end

  defp git_user do
    case git_config("user.name") do
      nil -> nil
      name -> {name, git_config("user.email")}
    end
  end

  defp git_config(key) do
    case System.cmd("git", ["config", key], stderr_to_stdout: true) do
      {value, 0} -> String.trim(value)
      _ -> nil
    end
  end

  defp whoami do
    case System.cmd("whoami", [], stderr_to_stdout: true) do
      {user, 0} -> String.trim(user)
      _ -> ""
    end
  end
end
