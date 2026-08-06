defmodule GettextFiles.MissingGettext do
  def test do
    ~H"""
    Hi everyone, this is missing a gettext!
    {gettext("Not missing here though!")}
    <p>
      This is missing gettext, but in a tag!
    </p>
    <p>{gettext("Non-missing gettext in a tag")}</p>
    <!-- No comments! -->
    ({gettext("This is translated")})
    <.link 
      item={1}
      aria-label={"Not translated!"}
    >$</.link>
    <p
      item={1}
      aria-label={"Not translated!"}
    >$</p>
    """
  end
end
