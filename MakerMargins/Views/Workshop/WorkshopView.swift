// WorkshopView.swift
// MakerMargins
//
// Tab 2 root — the active production hub.
// Displays a flat, searchable list of all WorkSteps across all Products,
// formatted as "Product Name → Step Name" rows sorted by recently used.
// Tapping a row pushes WorkStepDetailView, from which the stopwatch launches.
//
// This tab exists so the most common active-production action (start a timer)
// is reachable in 2 taps from app launch, without navigating the product hierarchy.
//
// Navigation:
//   [push]  WorkStepDetailView(step)
//   [sheet] WorkStepFormView(step, product)   ← from edit button on WorkStepDetailView
//
// Epic 2 — placeholder.
