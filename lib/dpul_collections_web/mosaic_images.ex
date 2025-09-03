defmodule DpulCollectionsWeb.MosaicImages do
  alias DpulCollections.Item

  # After updating mosaic images, start a new CacheMosaicImages Oban Job to keep the
  # cache up-to-date:
  # `Oban.insert(DpulCollections.Workers.CacheMosaicImages.new(%{}))`
  def images() do
    [
      # Stakeholder favorites
      {"2e5d9c37-9fef-4657-b2cf-c6604a06a4a1",
       iiif_url("92%2Fe0%2F19%2F92e019185f38477ab102d9ee4ff3a453%2Fintermediate_file"),
       %Item{title: ["پڑوسی"], primary_thumbnail_width: 453, primary_thumbnail_height: 599}},
      {"14fbf890-a9f6-486e-811e-cc5fdd6e297c",
       iiif_url("c7%2Fd9%2F53%2Fc7d953954f6246a5a9bf153caf97d5e6%2Fintermediate_file"),
       %Item{title: ["پیاسا"], primary_thumbnail_width: 453, primary_thumbnail_height: 604}},
      {"0d530f0b-7bf3-499d-b5e3-f5c297533d91",
       iiif_url("5c%2Fd6%2F3b%2F5cd63b431c324d51a710540a0d9e8322%2Fintermediate_file"),
       %Item{title: ["ناہید"], primary_thumbnail_width: 453, primary_thumbnail_height: 601}},
      {"e8abfa75-253f-428a-b3df-0e83ff2b20f9",
       iiif_url("38%2F6a%2Fd8%2F386ad81f6bc54443a119950e1892f1bc%2Fintermediate_file"),
       %Item{title: ["Peace appeal"], primary_thumbnail_width: 453, primary_thumbnail_height: 647}},
      {"e379b822-27cc-4d0e-bca7-6096ac38f1e6",
       iiif_url("2d%2Ff7%2Fbc%2F2df7bc48d207415aa7be2d97b8d6bdc3%2Fintermediate_file"),
       %Item{title: ["عورت مارچ"], primary_thumbnail_width: 453, primary_thumbnail_height: 577}},
      {"1e5ae074-3a6e-494e-9889-6cd01f7f0621",
       iiif_url("cd%2F33%2Fb6%2Fcd33b6ba67774304824f5b891d4fb933%2Fintermediate_file"),
       %Item{
         title: ["India : Madras"],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 973
       }},
      {"036b86bf-28b0-4157-8912-6d3d9eeaa5a8",
       iiif_url("cb%2Ff8%2Fd7%2Fcbf8d760c9ed4dfca32e13f51c8b2752%2Fintermediate_file"),
       %Item{
         title: ["India : Kerala"],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 1017
       }},
      {"d82efa97-c69b-424c-83c2-c461baae8307",
       iiif_url("88%2Fd9%2F41%2F88d941bf46e44d7e8115157503159f77%2Fintermediate_file"),
       %Item{
         title: ["امن جمهوریت مسادى حقوق : 8 مارچ-عالمى یوم خواتین- تحریك خواتین پنجاب"],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 635
       }},
      {"e7cbee6a-34b9-4dba-865c-6e75fa7ac585",
       iiif_url("14%2Fae%2Fe5%2F14aee527ad784fa3a9dfe395c52f0857%2Fintermediate_file"),
       %Item{
         title: [
           "Sociólogxs para qué? Por una sociología crítica y comprometida con el cambio social."
         ],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 323
       }},
      {"9631f599-d957-47b8-81a3-4bb43f673aa5",
       iiif_url("0d%2F13%2F77%2F0d13770ccaf546528c3db8176e14c474%2Fintermediate_file"),
       %Item{
         title: ["Не ждать, а действовать!"],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 671
       }},
      {"4b507fd0-5ab5-4613-9ab8-5985502f6b17",
       iiif_url("fa%2F4d%2F7a%2Ffa4d7a385dd14b7aaece17bf7ee22f30%2Fintermediate_file"),
       %Item{title: ["Ship shape"], primary_thumbnail_width: 453, primary_thumbnail_height: 814}},
      {"c2ed16ae-b49d-469b-9eb3-32f0810be248",
       iiif_url("63%2Fab%2F73%2F63ab73791ace4412b3d50efaeb9a60fb%2Fintermediate_file"),
       %Item{
         title: [
           "Chile reconstruye unido. Trabajo voluntario. Reconstrucción de la zona asolada por los sismos."
         ],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 637
       }},
      {"c45e3698-f2fd-41ad-84ce-0af36350ba7e",
       iiif_url("ba%2Fa4%2Fd6%2Fbaa4d66267ff4fcbbc8935e2fa903992%2Fintermediate_file"),
       %Item{
         title: [
           "¿Cómo hacemos el país que queremos? Construyendo una cultura de paz para un país más justo en la diversidad."
         ],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 873
       }},
      {"feda8523-46f8-41ba-b420-44361991e732",
       iiif_url("2f%2Fd5%2F01%2F2fd501f1600947228c0ec2f60da4ea2d%2Fintermediate_file"),
       %Item{
         title: ["Igualdade racial. 23."],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 638
       }},
      {"722342eb-21d4-4915-9e2d-26a284a0994c",
       iiif_url("e2%2F19%2F21%2Fe2192149b2f14014a91c9e5ca5cf6b80%2Fintermediate_file"),
       %Item{
         title: ["Nadie está olvidadx. No estamos todxs."],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 884
       }},
      {"c7a83f47-6026-4aa4-a19a-bbe90b0de2db",
       iiif_url("61%2F12%2F0c%2F61120c43a45742049b72ebbe2e0212d6%2Fintermediate_file"),
       %Item{title: ["No CAA"], primary_thumbnail_width: 453, primary_thumbnail_height: 322}},
      {"0b83710d-380e-4172-9b50-623e18f75de2",
       iiif_url("65%2F21%2Ffd%2F6521fd6a556241c9a06d3a52fa2d3213%2Fintermediate_file"),
       %Item{
         title: ["10ma FLIA: Feria del Libro Independiente ]A[."],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 657
       }},
      {"aacb64e4-1641-4325-a478-f51b92e1b2b7",
       iiif_url("5d%2F1f%2F75%2F5d1f75beb6f54db1b3848fc37df1d33e%2Fintermediate_file"),
       %Item{
         title: ["No a la Baja."],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 451
       }},
      {"5b1a5a0c-20b3-4e71-9425-4dfeb9157e2c",
       iiif_url("e9%2F95%2F3e%2Fe9953ee5592c44bea066c3ad0f1f4162%2Fintermediate_file"),
       %Item{
         title: ["چاند تارے، حصه اول"],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 587
       }},
      {"e42b1db8-4180-4130-bfe0-7f3d05f15d32",
       iiif_url("76%2F8a%2Fa7%2F768aa7d4990541db9f88875100fd643e%2Fintermediate_file"),
       %Item{
         title: ["La poda de los árboles."],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 578
       }},
      {"bea17a20-535e-4140-91cc-ad2c31194e2c",
       iiif_url("43%2F66%2F6a%2F43666aa693ef45808f8eb4194da832fe%2Fintermediate_file"),
       %Item{
         title: ["Something for you."],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 941
       }},
      {"47465a33-6694-4624-a280-7d0d770dedae",
       iiif_url("b8%2Fbb%2Fd4%2Fb8bbd4a1fdb746959a7a19c7ad0435b8%2Fintermediate_file"),
       %Item{
         title: ["Sovet novoselam"],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 638
       }},
      {"f1eac718-4e40-4d2a-a42e-a27348c4a112",
       iiif_url("4a%2Fb9%2Fe9%2F4ab9e9d791f846b7b5ebf7f812043fe4%2Fintermediate_file"),
       %Item{
         title: ["Concurso Nacional de Guitarra Isaac Nicola."],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 671
       }},
      # tinfoil cat
      {"19577a4b-920f-4e6e-a4cd-f36f16915f23",
       iiif_url("56%2F04%2F5c%2F56045c5e06be455aa032f1503afd03f8%2Fintermediate_file"),
       %Item{
         title: [
           "# Apostatemos de las redes asociales de vigilancia masiva. ¡Venite al Fediverso!"
         ],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 634
       }},
      {"db7b7bf0-1add-40c4-b77b-aa5d012256ef",
       iiif_url("b5%2F16%2Fbf%2Fb516bfbcb796402cbbc50ef1e30f7df0%2Fintermediate_file"),
       %Item{
         title: ["Sindicalistas extranjeros opinan acerca de sanciones a Guatemala"],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 350
       }},
      {"a955eeb0-a453-4c6a-a693-349caf9b5de1",
       iiif_url("34%2Fe0%2F79%2F34e079224a0c4f7da0b9e8c1a60dcb5a%2Fintermediate_file"),
       %Item{title: ["Carbón."], primary_thumbnail_width: 453, primary_thumbnail_height: 307}},
      {"094bc013-e8bd-4ff7-802f-f4507b35ecad",
       iiif_url("d8%2F00%2F10%2Fd800107d048c497f99f0c3b1a4e59877%2Fintermediate_file"),
       %Item{
         title: ["\"Es el patrimonio de todos. El tren es para el pueblo.\" (CFK)"],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 920
       }},
      {"4b143941-7370-4061-8a9b-2e86c30f956b",
       iiif_url("4e%2F2e%2F4f%2F4e2e4fac891542618441b9ee80f929cd%2Fintermediate_file"),
       %Item{
         title: ["Requisitos para legalización de organizaciones de mujeres. "],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 932
       }},
      {"3e3d3285-1547-4887-b507-decc06b9b8e1",
       iiif_url("a0%2F0a%2Fbe%2Fa00abe73e8734bba8f35fb230c5d03b0%2Fintermediate_file"),
       %Item{
         title: [
           "Pensando en... las relaciones y el derecho de toda persona a ser tratada con respeto."
         ],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 862
       }},
      {"4cecc3a6-437a-495d-8e7c-c7ac6a8d42bb",
       iiif_url("09%2Fc5%2Fa7%2F09c5a7cad4b84845bc111aae6f49caa8%2Fintermediate_file"),
       %Item{
         title: ["- На процедуру ходить регулярно..."],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 603
       }},
      {"1ff4b3b6-616f-44c9-b367-2723d2a4c48b",
       iiif_url("53%2Fd0%2Fb2%2F53d0b2e9ad2b419bbf2feb3c7a853b03%2Fintermediate_file"),
       %Item{
         title: ["Home Insurance Solutions."],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 666
       }},
      {"c2ed16ae-b49d-469b-9eb3-32f0810be248",
       iiif_url("63%2Fab%2F73%2F63ab73791ace4412b3d50efaeb9a60fb%2Fintermediate_file"),
       %Item{
         title: [
           "Chile reconstruye unido. Trabajo voluntario. Reconstrucción de la zona asolada por los sismos."
         ],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 637
       }},
      {"f4a45837-3369-4571-8564-ae9889dbe4bc",
       iiif_url("63%2F30%2F8e%2F63308ec1b2054989ba4b53445e1baf2b%2Fintermediate_file"),
       %Item{
         title: ["Los gordos no flotan. Muestra personal. Dorian D. Agüero Anaya."],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 490
       }},
      {"dd67b7be-c709-44be-a9c3-c8045e07b7ba",
       iiif_url("ba%2F03%2F9a%2Fba039a4270f74aba9e16bd691600396d%2Fintermediate_file"),
       %Item{
         title: [
           "Avanzamos por la ruta del cambio y la revolución ciudadana. Leyes aprobadas por la Asamblea Nacional. 2009-2010."
         ],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 622
       }},
      {"d31f7e01-f949-46b2-911a-9f52a088d131",
       iiif_url("81%2F96%2F12%2F819612034024460ab21eb95e04b15d86%2Fintermediate_file"),
       %Item{title: ["ریمانڈ"], primary_thumbnail_width: 453, primary_thumbnail_height: 603}},
      {"aa79b393-657f-48d4-beee-e85c058d14b5",
       iiif_url("01%2F13%2Ffa%2F0113fa583c05415db633027ed9b2ab1d%2Fintermediate_file"),
       %Item{
         title: ["Programa Nacional de Control de la Tuberculosis: Consejería DOTS-C."],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 309
       }},
      {"844f4b8a-edd8-4d46-bd9d-8de4d8dca011",
       iiif_url("eb%2F92%2F36%2Feb923667853a46148b19789d3e9c17ba%2Fintermediate_file"),
       %Item{
         title: [
           "Tratamiento jurídico de la explotación sexual comercial de niños, niñas y adolescentes."
         ],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 641
       }},
      {"5af3a8a8-c818-48b3-8d68-263a7f5d1801",
       iiif_url("89%2Fda%2F59%2F89da596af4574daab64d9c360fec7626%2Fintermediate_file"),
       %Item{title: ["59 Октябрь"], primary_thumbnail_width: 453, primary_thumbnail_height: 707}},
      {"e0857177-0519-4bcb-905b-3d8e8412b5e8",
       iiif_url("05%2F38%2F39%2F053839bf540b4002a41c0ee91998eeba%2Fintermediate_file"),
       %Item{
         title: ["Не дадим наживаться на книге никакому рвачу и барыге!"],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 661
       }},
      {"373c0461-88ab-41f6-8511-fb02cf710cec",
       iiif_url("99%2F27%2F97%2F992797cb4267489b8fa89259d8208758%2Fintermediate_file"),
       %Item{
         title: ["Tan natural... Flores cultivadas por manos productivas de mujeres campesinas."],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 577
       }},
      {"610a4cac-7aab-4489-a9af-1514a57c7921",
       iiif_url("bb%2F67%2F97%2Fbb67970e45a94967aecfbd962c1164c6%2Fintermediate_file"),
       %Item{
         title: ["Brasilzinho e a Cidadania."],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 644
       }},
      {"ce4e7729-b328-4c84-a4fe-10faaf46f8c7",
       iiif_url("f2%2Faa%2F02%2Ff2aa025c5359403e9facf3e9bd36cdbd%2Fintermediate_file"),
       %Item{
         title: ["Yaracuy, ruta del placer."],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 969
       }},
      {"1165b3f8-ab8f-4db4-9c95-77b711b8ce73",
       iiif_url("a7%2Fa5%2F2e%2Fa7a52e899e754281afd360e0621edc4d%2Fintermediate_file"),
       %Item{
         title: ["Yo te amo, yo tu amo."],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 293
       }},
      {"5eb4601d-d06c-4f7f-b9d7-f22b9ffe1c5d",
       iiif_url("a5%2Fd0%2F4c%2Fa5d04c603b8a44029d1e782d6490630f%2Fintermediate_file"),
       %Item{
         title: ["Procedimientos electorales para la conformación de gobiernos estudiantiles."],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 463
       }},
      {"26bb9907-41cd-4083-83c2-0884a0d3d458",
       iiif_url("b5%2Ffd%2Fe3%2Fb5fde3d5660c47b8bc1734af6f570ea0%2Fintermediate_file"),
       %Item{
         title: ["FamFest. 12º Festival Internacional de Teatro Familiar."],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 624
       }},
      {"e18c591b-88eb-419c-897a-64c6327152d4",
       iiif_url("7c%2F31%2F17%2F7c3117632f64410ab643d4e1b304980e%2Fintermediate_file"),
       %Item{title: ["شیدا ٹلّی"], primary_thumbnail_width: 453, primary_thumbnail_height: 604}},
      {"e260c363-dbb3-45af-8925-05682131d5c5",
       iiif_url("4e%2F9b%2F17%2F4e9b17d727504e92b61421e14a8df44e%2Fintermediate_file"),
       %Item{
         title: ["Sahar Haghgoo"],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 453
       }},
      {"a50e758f-95a7-41f3-bc2a-b393d9037cb4",
       iiif_url("e1%2Ff6%2F05%2Fe1f605402c5548eeabec9dcedd862d93%2Fintermediate_file"),
       %Item{
         title: ["Holguín. Havanatur, el especialista de Cuba."],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 885
       }},
      {"d304cae2-3eff-44cc-9c46-e1b6bf1259e4",
       iiif_url("6a%2F34%2Fa1%2F6a34a119f2fb475f927f7d60ae6366aa%2Fintermediate_file"),
       %Item{
         title: ["Arte campo. 17ava. exposición y venta del 9 al 31 de diciembre de 2003."],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 456
       }},
      {"09d054d8-95c6-4228-9020-37349c660bda",
       iiif_url("1b%2Fd7%2F7a%2F1bd77aafe9ac40658ee7dcc0c7da1360%2Fintermediate_file"),
       %Item{
         title: ["Темпы отсталые в вашей работе..."],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 640
       }},
      {"b51ee428-e508-4e13-97e4-2acbf716d756",
       iiif_url("4b%2F94%2Fea%2F4b94ea618d1648bcb17e7079e8910c7e%2Fintermediate_file"),
       %Item{
         title: ["How to sell safety"],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 690
       }},
      {"5a5aed2a-7511-405f-8f36-b025d169812a",
       iiif_url("bd%2F24%2Fb3%2Fbd24b332a28c4a8db2ca2f09b2161bff%2Fintermediate_file"),
       %Item{
         title: ["San Ignacio de Velasco. Para quedarse y vivirlo..."],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 880
       }},
      {"a769edaa-ecf3-4bee-81c5-ba819eb7b673",
       iiif_url("73%2Fe8%2F45%2F73e8454a18024551af49b4f99f75a8b1%2Fintermediate_file"),
       %Item{
         title: ["Maryam Farahzadi"],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 782
       }},
      {"02c8124b-5133-487e-9646-7896bba289a2",
       iiif_url("f0%2F1e%2Ff3%2Ff01ef3671f944b55b364474ddf7624ae%2Fintermediate_file"),
       %Item{title: ["Sara Shoghi"], primary_thumbnail_width: 453, primary_thumbnail_height: 619}},
      {"d9701a1b-8373-4e8f-9f9d-670239a1923c",
       iiif_url("58%2F36%2Fc5%2F5836c5d04a5f49c89d7c017f99d9963c%2Fintermediate_file"),
       %Item{
         title: ["Mohammad Feizabadi"],
         primary_thumbnail_width: 453,
         primary_thumbnail_height: 523
       }}
    ]
  end

  # start x and y at a random point at least 15 percent into the image and
  # far enough from the other side to allow another 15 percent on that side.
  # limit the possible starting points so there few enough versions of each
  # image to cachethem all
  # x, y starting points: [15, 30, 45, 60]
  # percent: 25
  def configurations do
    [
      {"pct:15,15,25,25", "", "200"},
      {"pct:15,30,25,25", "", "200"},
      {"pct:15,45,25,25", "", "200"},
      {"pct:15,60,25,25", "", "200"},
      {"pct:30,15,25,25", "", "200"},
      {"pct:30,30,25,25", "", "200"},
      {"pct:30,45,25,25", "", "200"},
      {"pct:30,60,25,25", "", "200"},
      {"pct:45,15,25,25", "", "200"},
      {"pct:45,30,25,25", "", "200"},
      {"pct:45,45,25,25", "", "200"},
      {"pct:45,60,25,25", "", "200"},
      {"pct:60,15,25,25", "", "200"},
      {"pct:60,30,25,25", "", "200"},
      {"pct:60,45,25,25", "", "200"},
      {"pct:60,60,25,25", "", "200"}
    ]
  end

  defp iiif_url(encoded_portion) do
    {pct, _, _} = Enum.random(configurations())

    "https://iiif-cloud.princeton.edu/iiif/2/#{encoded_portion}/#{pct}/,200/0/default.jpg"
  end
end
