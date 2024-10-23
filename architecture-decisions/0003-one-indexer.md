# 3. Record architecture decisions

Date: 2024-10-23

## Status

Accepted

## Context

We're using Broadway for indexing, which has no built in concept of multi-machine distributed indexing. Right now we're unsure we need to scale past one machine for indexing our documents.

## Decision

We will use one special machine that can be scaled independently to have more resources for indexing.

## Consequences

If we need to distribute indexing later, and can't just add resources to the one machine, then we'll have to develop a way for Broadway to distribute.
