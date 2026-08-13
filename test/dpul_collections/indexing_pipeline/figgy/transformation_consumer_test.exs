defmodule DpulCollections.IndexingPipeline.Figgy.TransformationConsumerTest do
  use DpulCollections.DataCase
  import Mock

  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.Figgy.HydrationConsumer
  alias DpulCollections.IndexingPipeline.Figgy.TransformationConsumer

  describe "ScannedResource processing" do
    test "allows through ScannedResources from complete/published collections" do
      record_id = "ee3528e9-88a4-4d2b-adee-f05efede87a7"
      cache_version = 1
      resource = IndexingPipeline.get_figgy_resource!(record_id)

      HydrationConsumer.process_and_persist(resource, cache_version)

      entry = IndexingPipeline.get_hydration_cache_entry!(record_id, cache_version)
      classified = TransformationConsumer.process(entry, cache_version)

      assert classified |> elem(0) == :update
    end

    test "allows through ScannedResources from incomplete/published collections in staging" do
      cache_version = 1
      record_id = "ee3528e9-88a4-4d2b-adee-f05efede87a7"
      resource = IndexingPipeline.get_figgy_resource!(record_id)

      collection =
        IndexingPipeline.get_figgy_resource!("52abe8f7-e2a1-46e9-9d13-3dc4fbc0bf0a")
        |> put_in(
          [
            Access.key!(:metadata),
            "state"
          ],
          "pending"
        )

      # Return the updated collection if asked
      with_mock IndexingPipeline, [:passthrough],
        get_figgy_resources: fn
          ["3bab572e-6603-4abf-8305-16ce6fe3ac5c", "52abe8f7-e2a1-46e9-9d13-3dc4fbc0bf0a"] ->
            [collection]

          args ->
            passthrough([args])
        end do
        HydrationConsumer.process_and_persist(resource, cache_version)
        entry = IndexingPipeline.get_hydration_cache_entry!(record_id, cache_version)
        classified = TransformationConsumer.process(entry, cache_version)

        assert classified |> elem(0) == :update
      end
    end

    test "rejects ScannedResources from incomplete/published collections in production" do
      initial_env = Application.get_env(:dpul_collections, :environment_name)
      on_exit(fn -> Application.put_env(:dpul_collections, :environment_name, initial_env) end)
      Application.put_env(:dpul_collections, :environment_name, "production")

      cache_version = 1
      record_id = "ee3528e9-88a4-4d2b-adee-f05efede87a7"
      resource = IndexingPipeline.get_figgy_resource!(record_id)

      collection =
        IndexingPipeline.get_figgy_resource!("52abe8f7-e2a1-46e9-9d13-3dc4fbc0bf0a")
        |> put_in(
          [
            Access.key!(:metadata),
            "state"
          ],
          ["pending"]
        )

      # Return the updated collection if asked
      with_mock IndexingPipeline, [:passthrough],
        get_figgy_resources: fn
          ["3bab572e-6603-4abf-8305-16ce6fe3ac5c", "52abe8f7-e2a1-46e9-9d13-3dc4fbc0bf0a"] ->
            [collection]

          args ->
            passthrough([args])
        end do
        HydrationConsumer.process_and_persist(resource, cache_version)
        entry = IndexingPipeline.get_hydration_cache_entry!(record_id, cache_version)
        classified = TransformationConsumer.process(entry, cache_version)

        assert classified |> elem(0) == :skip
      end
    end
  end
end
