# 1. Filters

Date: 2026-03-30

## Status

Accepted 2026-03-30

## Context

Filters (or "facets" in common library vocabulary) are an oft-discussed feature to restrict a search result's items.

### User Testing to Keep in Mind:

Many of the conclusions here came from excellent testing from [CRKN-RCDR Blacklight Search UX Research](https://crkn-rcdr.gitbook.io/user-centered-design#facet-listing)

1. Patrons generally do not like paging through filters.
1. Filters are often missed - patrons expect keyword searches to be robust.

### Use Cases

1. As a librarian a patron has come to me asking for all "Chilean posters from the 1980s and 90s" and I want to create a result set that includes just those materials and send them a link to it so that they can continue their research without me.
1. As a researcher I want to see all collections and subjects related to a keyword result so that I can discover other potential avenues for finding material related to my topic and get an idea of how likely it is that Princeton will have the kind of material I need.


### Design Guidelines

Filter design should:

1. Be accessible
2. Allow for an arbitrarily large set of possible filters
3. Be searchable using a browser's built in text search or through a UI element.
4. Make it very clear what the results of selecting a filter is.
5. Work similarly in both mobile and desktop.
6. Not overwhelm the casual keyword search experience - be an opt in enhancement rather than an expected interaction.

## Decision

![An image of a search interface where filtering results is in a drawer that slides from the right, initiated by a Filters button, with a collapsible section for every filter](images/filters.png)

Filters will:

1. Be initiated by a "Filters" button
1. Open a drawer from the right with all possible filters, a preview of how many results there will be, and all active filters.
1. Display active filters when the drawer is either open or closed.
1. Display all available options in each filter group, with a search bar to find relevant ones.

## Consequences

Choosing to place filters behind a button will mean that we should work to improve the keyword search functionality as a priority.

Allowing an infinite number of filters may result in overwhelm from the opt-in filter interface.

Loading many filters during every search will likely have a performance impact.
