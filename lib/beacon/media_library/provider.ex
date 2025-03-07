defmodule Beacon.MediaLibrary.Provider do
  @moduledoc """
  Connects to an external service to store and serve assets in the Media Library.

  By default, Beacon comes with 2 providers:

    * `Beacon.MediaLibrary.Provider.Repo` - Store assets in the database.
    * `Beacon.MediaLibrary.Provider.S3` - Store assets in an S3 bucket.

  `Repo` is enabled by default for all media types since a database connection is already
  available, and caching is used to reduce overload on the database. But you can switch to `S3`
  using the `Beacon.MediaLibrary.Provider.S3` provider or create your own provider.

  See `Beacon.Config` and each provider module doc for more info.

  """

  alias Beacon.MediaLibrary.UploadMetadata
  alias Beacon.MediaLibrary.Asset

  import Ecto.Query
  import Beacon.Utils, only: [repo: 1]

  @doc false
  def process!(%UploadMetadata{} = metadata) do
    metadata.config.processor.(metadata)
  end

  @doc false
  @spec validate_for_delivery(UploadMetadata.t()) :: UploadMetadata.t()
  def validate_for_delivery(%UploadMetadata{} = metadata) do
    Enum.reduce(metadata.config.validations, metadata, fn
      validation, md -> validation.(md)
    end)
  end

  @doc false
  @spec validate_for_delivery({UploadMetadata.t(), any()}) :: UploadMetadata.t()
  def validate_for_delivery({%UploadMetadata{} = metadata, config}) do
    Enum.reduce(metadata.config.validations, metadata, fn
      validation, md -> validation.(md, config)
    end)
  end

  @doc false
  @spec send_to_cdns(UploadMetadata.t()) :: UploadMetadata.t()
  def send_to_cdns(%UploadMetadata{} = metadata) do
    Enum.reduce(metadata.config.providers, metadata, fn
      provider, md -> provider.send_to_cdn(md)
    end)
  end

  @doc false
  @spec send_to_cdns({UploadMetadata.t(), any()}) :: UploadMetadata.t()
  def send_to_cdns({%UploadMetadata{} = metadata, config}) do
    Enum.reduce(metadata.config.providers, metadata, fn
      provider, md -> provider.send_to_cdn(md, config)
    end)
  end

  @doc false
  @spec soft_delete(Asset.t(), any()) :: {:ok, Asset.t()} | :error
  def soft_delete(%Asset{} = asset, config) do
    update =
      repo(asset).update_all(
        from(asset in Asset, where: asset.id == ^asset.id),
        set: [deleted_at: DateTime.utc_now()]
      )

    case update do
      {1, _} ->
        Enum.reduce(config.providers, asset, fn
          provider, asset -> provider.soft_delete(asset)
        end)

      _ ->
        :error
    end
  end
end
