defmodule DpulCollections.IndexingPipeline.Figgy.CombinedFiggyResourceTest do
  use DpulCollections.DataCase
  alias DpulCollections.IndexingPipeline
  alias DpulCollections.IndexingPipeline.Figgy

  describe "#to_solr_document" do
    test "converting an EphemeraProject" do
      doc =
        IndexingPipeline.get_figgy_resource!("f99af4de-fed4-4baa-82b1-6e857b230306")
        |> Figgy.Resource.to_combined()
        |> Figgy.CombinedFiggyResource.to_solr_document()

      assert %{
               id: "f99af4de-fed4-4baa-82b1-6e857b230306",
               title_txtm: ["South Asian Ephemera"],
               resource_type_s: "collection",
               tagline_txtm: [
                 "The South Asian Ephemera Collection is an openly accessible repository of items that spans a variety of subjects and languages and supports research, teaching, and private study. Newly acquired materials are digitized and added on an ongoing basis."
               ],
               authoritative_slug_s: "sae"
             } = doc

      assert hd(doc[:summary_txtm]) =~ "already robust <a"
    end

    test "converting a ScannedResource with MMS-ID metadata but no date doesn't index a date" do
      doc =
        IndexingPipeline.get_figgy_resource!("27fd4d29-1170-47a5-891b-f2743873bcef")
        |> Figgy.Resource.to_combined()
        |> put_in(
          [
            Access.key!(:resource),
            Access.key!(:metadata),
            Access.key("imported_metadata"),
            Access.all(),
            Access.key!("date")
          ],
          nil
        )
        |> Figgy.CombinedFiggyResource.to_solr_document()

      assert doc[:display_date_s] == nil
    end

    test "converting a ScannedResource with MMS-ID metadata but an odd date takes the date as written" do
      doc =
        IndexingPipeline.get_figgy_resource!("27fd4d29-1170-47a5-891b-f2743873bcef")
        |> Figgy.Resource.to_combined()
        |> put_in(
          [
            Access.key!(:resource),
            Access.key!(:metadata),
            Access.key("imported_metadata"),
            Access.all(),
            Access.key!("date")
          ],
          "Seventh of September"
        )
        |> Figgy.CombinedFiggyResource.to_solr_document()

      assert doc[:display_date_s] == "Seventh of September"
    end

    # This was the case for
    # https://figgy.princeton.edu/catalog/72507ee3-850b-4ad6-9098-141257cb319f,
    # which we'll index eventually.
    test "converting a ScannedResource with MMS-ID metadata and a nil content_warning is able to convert it without erroring" do
      doc =
        IndexingPipeline.get_figgy_resource!("1a8c14ca-060c-434f-b999-6191db4c336c")
        |> Figgy.Resource.to_combined()
        |> put_in(
          [
            Access.key!(:resource),
            Access.key!(:metadata),
            Access.key!("content_warning")
          ],
          nil
        )
        |> Figgy.CombinedFiggyResource.to_solr_document()

      assert doc[:contents_ss] |> hd() == "Miniatures: fol. 4a: [Firdawsi and the Court Poets]"
    end

    test "converting a ScannedResource with MMS-ID metadata but an odd language value takes the language as written" do
      doc =
        IndexingPipeline.get_figgy_resource!("27fd4d29-1170-47a5-891b-f2743873bcef")
        |> Figgy.Resource.to_combined()
        |> put_in(
          [
            Access.key!(:resource),
            Access.key!(:metadata),
            Access.key("imported_metadata"),
            Access.all(),
            Access.key!("language")
          ],
          "Klingon"
        )
        |> Figgy.CombinedFiggyResource.to_solr_document()

      assert doc[:language_txt_sort] == "Klingon"
    end

    test "converting a featurable EphemeraFolder sets a boolean" do
      doc =
        IndexingPipeline.get_figgy_resource!("e8abfa75-253f-428a-b3df-0e83ff2b20f9")
        |> Figgy.Resource.to_combined()
        |> Figgy.CombinedFiggyResource.to_solr_document()

      assert %{
               featurable_b: true
             } = doc

      unfeatured_doc =
        IndexingPipeline.get_figgy_resource!("3da68e1c-06af-4d17-8603-fc73152e1ef7")
        |> Figgy.Resource.to_combined()
        |> Figgy.CombinedFiggyResource.to_solr_document()

      assert unfeatured_doc[:featurable_b] == false
    end

    test "subjects and subject categories have a grouping relationship" do 
      doc = IndexingPipeline.get_figgy_resource!("e8abfa75-253f-428a-b3df-0e83ff2b20f9")
        |> Figgy.Resource.to_combined()
        |> Figgy.CombinedFiggyResource.to_solr_document()

      assert %{
        categories_txt_sort: [
          "Minorities, ethnic and racial groups",
          "Politics and government",
          "Religion"
        ],
        subject_txt_sort: [
          "Ethnic relations",
          "Peace movements",
          "Peace negotiations",
          "Liberation theology"
        ],
        category_subjects_txt: "{\"Minorities, ethnic and racial groups\":[\"Ethnic relations\"],\"Politics and government\":[\"Peace movements\",\"Peace negotiations\"],\"Religion\":[\"Liberation theology\"]}"
      } = doc
    end 

    test "file count filters out members without thumbnails" do
      doc =
        IndexingPipeline.get_figgy_resource!("e8abfa75-253f-428a-b3df-0e83ff2b20f9")
        |> Figgy.Resource.to_combined()
        |> Figgy.CombinedFiggyResource.to_solr_document()

      assert doc[:file_count_i] == 9
    end
  end
end
