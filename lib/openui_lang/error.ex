defmodule OpenUILang.Error do
  @moduledoc """
  Exception struct raised or returned when an OpenUILang operation fails.
  """
  defexception [:reason, :details]

  @type t :: %__MODULE__{
          reason: atom(),
          details: map() | nil
        }

  @impl Exception
  def message(%__MODULE__{reason: reason, details: nil}) do
    "OpenUILang operation failed: #{inspect(reason)}"
  end

  def message(%__MODULE__{reason: reason, details: details}) do
    "OpenUILang operation failed (#{inspect(reason)}): #{inspect(details)}"
  end
end
