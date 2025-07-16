defmodule RoleImgAltFilter do
  @behaviour A11yAudit.ViolationFilter

  @impl A11yAudit.ViolationFilter
  def exclude_violation?(%A11yAudit.Results.Violation{} = violation) do
    ids_to_ignore = ["role-img-alt"]
    violation.id in ids_to_ignore
  end
end
