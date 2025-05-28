# lib/my_app_web/components/header_component.ex
defmodule DpulCollectionsWeb.FooterComponent do
  use DpulCollectionsWeb, :html
  use Gettext, backend: DpulCollectionsWeb.Gettext

  def footer(assigns) do
    ~H"""
    <footer class="text-white flex flex-wrap sm:flex-row gap-10 items-center bg-brand py-6 sm:py-10 header-x-padding">
      <div class="footer-links flex-none w-32 sm:w-60">
        <ul class="text-xs">
          <li class="py-1">
            <a href="https://library.princeton.edu/about/policies/copyright-and-permissions-policies">
              {gettext("Copyright Policy")}
            </a>
          </li>
          <li class="py-1">
            <a href="https://www.princeton.edu/privacy-notice">
              {gettext("Privacy Notice")}
            </a>
          </li>
          <li class="py-1">
            <a href="https://accessibility.princeton.edu/help">
              {gettext("Accessibility Help")}
            </a>
          </li>
        </ul>
      </div>
      <div class="app_name sm:flex-1 sm:text-center">
        © 2025 {gettext("The Trustees of Princeton University")}
      </div>
      <div class="university-logo flex-none w-24 sm:w-48">
        <img src={~p"/images/university-logo.svg"} alt="Princeton University Logo" />
      </div>
    </footer>
    """
  end
end
