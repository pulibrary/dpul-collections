defmodule DpulCollectionsWeb.HomeLive do
  use DpulCollectionsWeb, :live_view
  use Gettext, backend: DpulCollectionsWeb.Gettext
  import DpulCollectionsWeb.BrowseItem
  alias DpulCollections.{Item, Solr}

  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        item_count: Solr.document_count(),
        q: nil,
        recent_items:
          Solr.recently_digitized(3)["docs"]
          |> Enum.map(&Item.from_solr(&1)),
        hero_images:
          Enum.chunk_every(hero_images() |> Enum.shuffle(), floor(length(hero_images()) / 3))
      )

    {:ok, socket,
     temporary_assigns: [item_count: nil], layout: {DpulCollectionsWeb.Layouts, :home}}
  end

  def hero_images() do
    [
      # Stakeholder favorites
      {"2e5d9c37-9fef-4657-b2cf-c6604a06a4a1",
       "https://iiif-cloud.princeton.edu/iiif/2/92%2Fe0%2F19%2F92e019185f38477ab102d9ee4ff3a453%2Fintermediate_file/full/,200/0/default.jpg"},
      {"14fbf890-a9f6-486e-811e-cc5fdd6e297c",
       "https://iiif-cloud.princeton.edu/iiif/2/c7%2Fd9%2F53%2Fc7d953954f6246a5a9bf153caf97d5e6%2Fintermediate_file/full/,200/0/default.jpg"},
      {"0d530f0b-7bf3-499d-b5e3-f5c297533d91",
       "https://iiif-cloud.princeton.edu/iiif/2/5c%2Fd6%2F3b%2F5cd63b431c324d51a710540a0d9e8322%2Fintermediate_file/full/,200/0/default.jpg"},
      {"e8abfa75-253f-428a-b3df-0e83ff2b20f9",
       "https://iiif-cloud.princeton.edu/iiif/2/38%2F6a%2Fd8%2F386ad81f6bc54443a119950e1892f1bc%2Fintermediate_file/full/,200/0/default.jpg"},
      {"e379b822-27cc-4d0e-bca7-6096ac38f1e6",
       "https://iiif-cloud.princeton.edu/iiif/2/2d%2Ff7%2Fbc%2F2df7bc48d207415aa7be2d97b8d6bdc3%2Fintermediate_file/full/,200/0/default.jpg"},
      {"1e5ae074-3a6e-494e-9889-6cd01f7f0621",
       "https://iiif-cloud.princeton.edu/iiif/2/cd%2F33%2Fb6%2Fcd33b6ba67774304824f5b891d4fb933%2Fintermediate_file/full/,200/0/default.jpg"},
      {"036b86bf-28b0-4157-8912-6d3d9eeaa5a8",
       "https://iiif-cloud.princeton.edu/iiif/2/cb%2Ff8%2Fd7%2Fcbf8d760c9ed4dfca32e13f51c8b2752%2Fintermediate_file/full/,200/0/default.jpg"},
      {"d82efa97-c69b-424c-83c2-c461baae8307",
       "https://iiif-cloud.princeton.edu/iiif/2/88%2Fd9%2F41%2F88d941bf46e44d7e8115157503159f77%2Fintermediate_file/full/,200/0/default.jpg"},
      {"e7cbee6a-34b9-4dba-865c-6e75fa7ac585",
       "https://iiif-cloud.princeton.edu/iiif/2/14%2Fae%2Fe5%2F14aee527ad784fa3a9dfe395c52f0857%2Fintermediate_file/full/,200/0/default.jpg"},
      {"9631f599-d957-47b8-81a3-4bb43f673aa5",
       "https://iiif-cloud.princeton.edu/iiif/2/0d%2F13%2F77%2F0d13770ccaf546528c3db8176e14c474%2Fintermediate_file/full/,200/0/default.jpg"},
      {"4b507fd0-5ab5-4613-9ab8-5985502f6b17",
       "https://iiif-cloud.princeton.edu/iiif/2/fa%2F4d%2F7a%2Ffa4d7a385dd14b7aaece17bf7ee22f30%2Fintermediate_file/full/,200/0/default.jpg"},
      {"c2ed16ae-b49d-469b-9eb3-32f0810be248",
       "https://iiif-cloud.princeton.edu/iiif/2/63%2Fab%2F73%2F63ab73791ace4412b3d50efaeb9a60fb%2Fintermediate_file/full/,200/0/default.jpg"},
      {"c45e3698-f2fd-41ad-84ce-0af36350ba7e",
       "https://iiif-cloud.princeton.edu/iiif/2/ba%2Fa4%2Fd6%2Fbaa4d66267ff4fcbbc8935e2fa903992%2Fintermediate_file/full/,200/0/default.jpg"},
      {"feda8523-46f8-41ba-b420-44361991e732",
       "https://iiif-cloud.princeton.edu/iiif/2/2f%2Fd5%2F01%2F2fd501f1600947228c0ec2f60da4ea2d%2Fintermediate_file/full/,200/0/default.jpg"},
      {"722342eb-21d4-4915-9e2d-26a284a0994c",
       "https://iiif-cloud.princeton.edu/iiif/2/e2%2F19%2F21%2Fe2192149b2f14014a91c9e5ca5cf6b80%2Fintermediate_file/full/,200/0/default.jpg"},
      {"c7a83f47-6026-4aa4-a19a-bbe90b0de2db",
       "https://iiif-cloud.princeton.edu/iiif/2/61%2F12%2F0c%2F61120c43a45742049b72ebbe2e0212d6%2Fintermediate_file/full/,200/0/default.jpg"},
      {"0b83710d-380e-4172-9b50-623e18f75de2",
       "https://iiif-cloud.princeton.edu/iiif/2/65%2F21%2Ffd%2F6521fd6a556241c9a06d3a52fa2d3213%2Fintermediate_file/full/,200/0/default.jpg"},
      {"aacb64e4-1641-4325-a478-f51b92e1b2b7",
       "https://iiif-cloud.princeton.edu/iiif/2/5d%2F1f%2F75%2F5d1f75beb6f54db1b3848fc37df1d33e%2Fintermediate_file/full/,200/0/default.jpg"},
      {"5b1a5a0c-20b3-4e71-9425-4dfeb9157e2c",
       "https://iiif-cloud.princeton.edu/iiif/2/e9%2F95%2F3e%2Fe9953ee5592c44bea066c3ad0f1f4162%2Fintermediate_file/full/,200/0/default.jpg"},
      {"e42b1db8-4180-4130-bfe0-7f3d05f15d32",
       "https://iiif-cloud.princeton.edu/iiif/2/76%2F8a%2Fa7%2F768aa7d4990541db9f88875100fd643e%2Fintermediate_file/full/,200/0/default.jpg"},
      {"bea17a20-535e-4140-91cc-ad2c31194e2c",
       "https://iiif-cloud.princeton.edu/iiif/2/43%2F66%2F6a%2F43666aa693ef45808f8eb4194da832fe%2Fintermediate_file/full/,200/0/default.jpg"},
      {"47465a33-6694-4624-a280-7d0d770dedae",
       "https://iiif-cloud.princeton.edu/iiif/2/b8%2Fbb%2Fd4%2Fb8bbd4a1fdb746959a7a19c7ad0435b8%2Fintermediate_file/full/,200/0/default.jpg"},
      {"f1eac718-4e40-4d2a-a42e-a27348c4a112",
       "https://iiif-cloud.princeton.edu/iiif/2/4a%2Fb9%2Fe9%2F4ab9e9d791f846b7b5ebf7f812043fe4%2Fintermediate_file/full/,200/0/default.jpg"},
      {"19577a4b-920f-4e6e-a4cd-f36f16915f23",
       "https://iiif-cloud.princeton.edu/iiif/2/56%2F04%2F5c%2F56045c5e06be455aa032f1503afd03f8%2Fintermediate_file/full/,200/0/default.jpg"},
      {"db7b7bf0-1add-40c4-b77b-aa5d012256ef",
       "https://iiif-cloud.princeton.edu/iiif/2/b5%2F16%2Fbf%2Fb516bfbcb796402cbbc50ef1e30f7df0%2Fintermediate_file/full/,200/0/default.jpg"},
      {"a955eeb0-a453-4c6a-a693-349caf9b5de1",
       "https://iiif-cloud.princeton.edu/iiif/2/34%2Fe0%2F79%2F34e079224a0c4f7da0b9e8c1a60dcb5a%2Fintermediate_file/full/,200/0/default.jpg"},
      {"094bc013-e8bd-4ff7-802f-f4507b35ecad",
       "https://iiif-cloud.princeton.edu/iiif/2/d8%2F00%2F10%2Fd800107d048c497f99f0c3b1a4e59877%2Fintermediate_file/full/,200/0/default.jpg"},
      {"4b143941-7370-4061-8a9b-2e86c30f956b",
       "https://iiif-cloud.princeton.edu/iiif/2/4e%2F2e%2F4f%2F4e2e4fac891542618441b9ee80f929cd%2Fintermediate_file/full/,200/0/default.jpg"},
      {"3e3d3285-1547-4887-b507-decc06b9b8e1",
       "https://iiif-cloud.princeton.edu/iiif/2/a0%2F0a%2Fbe%2Fa00abe73e8734bba8f35fb230c5d03b0%2Fintermediate_file/full/,200/0/default.jpg"},
      {"4cecc3a6-437a-495d-8e7c-c7ac6a8d42bb",
       "https://iiif-cloud.princeton.edu/iiif/2/09%2Fc5%2Fa7%2F09c5a7cad4b84845bc111aae6f49caa8%2Fintermediate_file/full/,200/0/default.jpg"},
      {"1ff4b3b6-616f-44c9-b367-2723d2a4c48b",
       "https://iiif-cloud.princeton.edu/iiif/2/53%2Fd0%2Fb2%2F53d0b2e9ad2b419bbf2feb3c7a853b03%2Fintermediate_file/full/,200/0/default.jpg"},
      {"c2ed16ae-b49d-469b-9eb3-32f0810be248",
       "https://iiif-cloud.princeton.edu/iiif/2/63%2Fab%2F73%2F63ab73791ace4412b3d50efaeb9a60fb%2Fintermediate_file/full/,200/0/default.jpg"},
      {"f4a45837-3369-4571-8564-ae9889dbe4bc",
       "https://iiif-cloud.princeton.edu/iiif/2/63%2F30%2F8e%2F63308ec1b2054989ba4b53445e1baf2b%2Fintermediate_file/full/,200/0/default.jpg"},
      {"dd67b7be-c709-44be-a9c3-c8045e07b7ba",
       "https://iiif-cloud.princeton.edu/iiif/2/ba%2F03%2F9a%2Fba039a4270f74aba9e16bd691600396d%2Fintermediate_file/full/,200/0/default.jpg"},
      {"d31f7e01-f949-46b2-911a-9f52a088d131",
       "https://iiif-cloud.princeton.edu/iiif/2/81%2F96%2F12%2F819612034024460ab21eb95e04b15d86%2Fintermediate_file/full/,200/0/default.jpg"},
      {"aa79b393-657f-48d4-beee-e85c058d14b5",
       "https://iiif-cloud.princeton.edu/iiif/2/01%2F13%2Ffa%2F0113fa583c05415db633027ed9b2ab1d%2Fintermediate_file/full/,200/0/default.jpg"},
      {"844f4b8a-edd8-4d46-bd9d-8de4d8dca011",
       "https://iiif-cloud.princeton.edu/iiif/2/eb%2F92%2F36%2Feb923667853a46148b19789d3e9c17ba%2Fintermediate_file/full/,200/0/default.jpg"},
      {"5af3a8a8-c818-48b3-8d68-263a7f5d1801",
       "https://iiif-cloud.princeton.edu/iiif/2/89%2Fda%2F59%2F89da596af4574daab64d9c360fec7626%2Fintermediate_file/full/,200/0/default.jpg"},
      {"e0857177-0519-4bcb-905b-3d8e8412b5e8",
       "https://iiif-cloud.princeton.edu/iiif/2/05%2F38%2F39%2F053839bf540b4002a41c0ee91998eeba%2Fintermediate_file/full/,200/0/default.jpg"},
      {"373c0461-88ab-41f6-8511-fb02cf710cec",
       "https://iiif-cloud.princeton.edu/iiif/2/99%2F27%2F97%2F992797cb4267489b8fa89259d8208758%2Fintermediate_file/full/,200/0/default.jpg"},
      {"610a4cac-7aab-4489-a9af-1514a57c7921",
       "https://iiif-cloud.princeton.edu/iiif/2/bb%2F67%2F97%2Fbb67970e45a94967aecfbd962c1164c6%2Fintermediate_file/full/,200/0/default.jpg"},
      {"ce4e7729-b328-4c84-a4fe-10faaf46f8c7",
       "https://iiif-cloud.princeton.edu/iiif/2/f2%2Faa%2F02%2Ff2aa025c5359403e9facf3e9bd36cdbd%2Fintermediate_file/full/,200/0/default.jpg"},
      {"1165b3f8-ab8f-4db4-9c95-77b711b8ce73",
       "https://iiif-cloud.princeton.edu/iiif/2/a7%2Fa5%2F2e%2Fa7a52e899e754281afd360e0621edc4d%2Fintermediate_file/full/,200/0/default.jpg"},
      {"5eb4601d-d06c-4f7f-b9d7-f22b9ffe1c5d",
       "https://iiif-cloud.princeton.edu/iiif/2/a5%2Fd0%2F4c%2Fa5d04c603b8a44029d1e782d6490630f%2Fintermediate_file/full/,200/0/default.jpg"},
      {"26bb9907-41cd-4083-83c2-0884a0d3d458",
       "https://iiif-cloud.princeton.edu/iiif/2/b5%2Ffd%2Fe3%2Fb5fde3d5660c47b8bc1734af6f570ea0%2Fintermediate_file/full/,200/0/default.jpg"},
      {"e18c591b-88eb-419c-897a-64c6327152d4",
       "https://iiif-cloud.princeton.edu/iiif/2/7c%2F31%2F17%2F7c3117632f64410ab643d4e1b304980e%2Fintermediate_file/full/,200/0/default.jpg"},
      {"e260c363-dbb3-45af-8925-05682131d5c5",
       "https://iiif-cloud.princeton.edu/iiif/2/4e%2F9b%2F17%2F4e9b17d727504e92b61421e14a8df44e%2Fintermediate_file/full/,200/0/default.jpg"},
      {"a50e758f-95a7-41f3-bc2a-b393d9037cb4",
       "https://iiif-cloud.princeton.edu/iiif/2/e1%2Ff6%2F05%2Fe1f605402c5548eeabec9dcedd862d93%2Fintermediate_file/full/,200/0/default.jpg"},
      {"d304cae2-3eff-44cc-9c46-e1b6bf1259e4",
       "https://iiif-cloud.princeton.edu/iiif/2/6a%2F34%2Fa1%2F6a34a119f2fb475f927f7d60ae6366aa%2Fintermediate_file/full/,200/0/default.jpg"},
      {"09d054d8-95c6-4228-9020-37349c660bda",
       "https://iiif-cloud.princeton.edu/iiif/2/1b%2Fd7%2F7a%2F1bd77aafe9ac40658ee7dcc0c7da1360%2Fintermediate_file/full/,200/0/default.jpg"},
      {"1c533970-eb00-44d3-bd8b-976cce558b2",
       "https://iiif-cloud.princeton.edu/iiif/2/23%2F1a%2Ff8%2F231af8df734d4012a774610af030f9aa%2Fintermediate_file/full/,200/0/default.jpg"},
      {"b51ee428-e508-4e13-97e4-2acbf716d756",
       "https://iiif-cloud.princeton.edu/iiif/2/4b%2F94%2Fea%2F4b94ea618d1648bcb17e7079e8910c7e%2Fintermediate_file/full/,200/0/default.jpg"},
      {"5a5aed2a-7511-405f-8f36-b025d169812a",
       "https://iiif-cloud.princeton.edu/iiif/2/bd%2F24%2Fb3%2Fbd24b332a28c4a8db2ca2f09b2161bff%2Fintermediate_file/full/,200/0/default.jpg"},
      {"a769edaa-ecf3-4bee-81c5-ba819eb7b673",
       "https://iiif-cloud.princeton.edu/iiif/2/73%2Fe8%2F45%2F73e8454a18024551af49b4f99f75a8b1%2Fintermediate_file/full/,200/0/default.jpg"},
      {"02c8124b-5133-487e-9646-7896bba289a2",
       "https://iiif-cloud.princeton.edu/iiif/2/f0%2F1e%2Ff3%2Ff01ef3671f944b55b364474ddf7624ae%2Fintermediate_file/full/,200/0/default.jpg"},
      {"d9701a1b-8373-4e8f-9f9d-670239a1923c",
       "https://iiif-cloud.princeton.edu/iiif/2/58%2F36%2Fc5%2F5836c5d04a5f49c89d7c017f99d9963c%2Fintermediate_file/full/,200/0/default.jpg"}
    ]
  end

  def render(assigns) do
    ~H"""
    <div class="grid grid-flow-row auto-rows-max">
      <div class="explore-header grid-row bg-taupe relative">
        <div class="shadow-lg bg-taupe absolute max-h-[600px] sm:min-w-[350px] w-full lg:max-w-1/2 2xl:max-w-1/3 top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 z-10 p-8">
          <div class="content-area text-center h-full w-full flex flex-col justify-evenly">
            <h1 class="normal-case">Explore Our Collections</h1>
            <div class="content-area page-y-padding text-xl flex-grow">
              Here you'll find a wide variety of material including <a class="text-rust" href="#">Photographs</a>, <a
                class="text-rust"
                href="#"
              >Posters</a>, <a class="text-rust" href="#">Books</a>, and
              <.link navigate={~p"/browse"} class="text-rust">more</.link>
              to inspire and support your research.
            </div>
            <div class="content-area bg-dark-blue text-taupe p-4 text-2xl">
              <.link navigate={~p"/browse"} class="">
                {gettext("Browse all items")}
              </.link>
            </div>
          </div>
        </div>
        <div class="h-[600px] overflow-hidden">
          <%= for chunk <- @hero_images do %>
            <div class="h-[200px] flex items-start overflow-hidden">
              <%= for {id, image_url} <- chunk do %>
                <div class="h-[200px] w-auto min-w-px flex-shrink-0">
                  <.link navigate={~p"/item/#{id}"}>
                    <img
                      class="h-full w-auto opacity-40 select-none hover:opacity-90 cursor-pointer"
                      draggable="false"
                      src={image_url}
                    />
                  </.link>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
      <hr class="h-1 border-0 bg-rust" />

      <div class="recent-items grid-row bg-cloud">
        <div class="content-area">
          <div class="page-t-padding" />
          <h1>{gettext("Recently Added Items")}</h1>
          <p class="my-2 font-regular">
            {gettext("Our collections are constantly growing. Discover something new!")}
          </p>
          <div class="flex gap-8 justify-stretch page-t-padding">
            
    <!-- cards -->
            <div class="w-full recent-container">
              <.browse_item :for={item <- @recent_items} item={item} added?={true} pinnable?={false} />
            </div>
            
    <!-- next arrow -->
            <div class="w-12 flex-none content-center">
              <.link id="recently-added-link" navigate={~p"/search?sort_by=recently_added"}>
                <button class="btn-arrow w-full h-14" aria-label="more recently added items" />
              </.link>
            </div>
          </div>
          <div class="page-b-padding" />
        </div>
      </div>
    </div>
    """
  end
end
