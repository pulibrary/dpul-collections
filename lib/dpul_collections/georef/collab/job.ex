defmodule DpulCollections.Georef.Collab.Job do
  @moduledoc "One canvas for a volunteer's browser to georeference."
  use DpulCollections.Schema

  schema "georef_jobs" do
    belongs_to :atlas, DpulCollections.Georef.Collab.Atlas, type: :string
    field :canvas_index, :integer
    field :round, :integer, default: 1
    field :status, :string, default: "queued"
    field :attempts, :integer, default: 0
    field :claimed_at, :utc_datetime_usec
    field :worker, :string
    belongs_to :user, DpulCollections.Accounts.User, type: :id
    field :result, :map
    field :error, :string
    field :finished_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end
end
