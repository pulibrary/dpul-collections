# Digital Collections Style Guide

## Overview

This style guide documents the design system for the Digital Collections Phoenix application, based on the existing CSS custom properties, utility classes, and component patterns used throughout the application.

## Color Palette

### Primary Colors

- **Taupe** (`--color-taupe: #f4f2f0`) - Primary background color
- **Wafer Pink** (`--color-wafer-pink: #e2d4c9`) - Warm accent
- **Sage** (`--color-sage: #d0d3ac`) - Primary brand color base
- **Dark Sage** (`--color-dark-sage: #9fa06c`) - Darker sage variant
- **Cloud** (`--color-cloud: #c1ccc3`) - Secondary UI elements
- **Rust** (`--color-rust: #a0562c`) - Accent color for highlights and links
- **Dark Blue** (`--color-dark-blue: #3a4151`) - Navigation and headers
- **Light Green** (`--color-light-green: #ECF2CB`) - Button text on dark backgrounds
- **Princeton Black** (`--color-princeton-black: #121212`) - Primary text and brand elements

### Sage Color Scale

A monochromatic sage color scale provides consistent visual hierarchy:

- **Sage 100** (`--color-sage-100: #E8E6DC`) - Lightest sage for cards and containers
- **Sage 200** (`--color-sage-200: #D6D3C0`) - Secondary elements and search backgrounds
- **Sage 300** (`--color-sage-300: #C4BFA4`) - Card shadows
- **Sage 500** (`--color-sage-500: #B2AC88`) - Mid-tone sage
- **Sage 600** (`--color-sage-600: #A0996C`) - Hover states and shadows
- **Sage 700** (`--color-sage-700: #878057`) - Darker sage
- **Sage 900** (`--color-sage-900: #6B6645`) - Darkest sage

### Semantic Colors

- **Background** (`--color-background`) - Maps to Taupe for main content areas
- **Light Text** (`--color-light-text`) - Maps to Taupe for text on dark backgrounds
- **Dark Text** (`--color-dark-text`) - Maps to Princeton Black for primary text
- **Brand** (`--color-brand`) - Maps to Princeton Black for headers and navigation
- **Primary** (`--color-primary`) - Maps to DPULC Primary for call-to-action buttons
- **Secondary** (`--color-secondary`) - Maps to Sage 200 for secondary elements
- **Light Secondary** (`--color-light-secondary`) - Maps to Sage 100 for subtle backgrounds
- **Accent** (`--color-accent`) - Maps to Rust for links, highlights, and interactive elements
- **Search** (`--color-search`) - Maps to Sage 200 for search-related UI

## Typography

### Fonts

- **Sans-serif** - Poppins followed by system sans-serif stack
- **Serif** - Aleo followed by system serif stack for descriptions and body content

### Text Sizing

- **Tiny Text** (`--text-tiny: 0.625rem`) - Small labels and captions
  - Line height: `1.5rem`
  - Letter spacing: `0.125rem`
  - Font weight: `500`

### Heading Styles

- **H1** - Uppercase, semibold, 2xl size, dark text color
- **H2** - XL size, bold font weight

## Component Styles

### Buttons

#### Primary Button (`.btn-primary`)
- Background: Primary color
- Text: Dark text
- Padding: 8px horizontal
- Height: 56px (h-14)
- Uppercase text
- Bold font weight
- Hover: Lighter background (`#c5c6b5`)
- Disabled: 50% opacity, cursor not-allowed

#### Secondary Button (`.btn-secondary`)
- Background: Cloud color
- Text: Dark text
- Hover: Lighter background (`#e1e2e5`)

#### Danger Button (`.btn-danger`)
- Background: Rust color
- Text: Light text
- Hover: Lighter rust (`#c67355`)

#### Icon Button (`.btn-icon`)
- Background: Primary color
- Tiny text size
- Center alignment

#### Transparent Button (`.btn-transparent`)
- No background
- Center alignment

### Special Button Shapes

#### Arrow Buttons
- **Left Arrow** (`.left-arrow-box`) - Polygon clip-path with left-pointing arrow
- **Right Arrow** (`.right-arrow-box`) - Polygon clip-path with right-pointing arrow
- **Button Arrow** (`.btn-arrow`) - Triangle clip-path with accent background

#### Diagonal Elements
- **Browse Link** (`.browse-link`) - Diagonal top-left corner cut
- **Diagonal Drop** (`.diagonal-drop`) - Diagonal bottom-left corner
- **Diagonal Rise** (`.diagonal-rise`) - Diagonal top-left corner

### Cards

#### Card Component (`.card`)
- Drop shadow: `0.25rem 0.25rem 0.25rem var(--color-sage-300)`
- Hover shadow: `0 0 0.7rem var(--color-sage-600)`
- No underlines on nested links

### Action Icons

#### Item Action Icons (`.item-action-icon`)
- Hover: White text on accent background
- Size: 40px × 40px
- Padding: 8px
- Background: Secondary color

#### Pane Action Icons (`.pane-action-icon`)
- Text: Accent color
- Hover: Secondary background
- Size: 24px × 24px
- Padding: 4px
- Background: Background color

### Layout Utilities

#### Content Areas
- **Content Area** (`.content-area`) - Max width 1280px, centered, responsive padding
- **Home Content Area** (`.home-content-area`) - Content area with 80% max width on small screens

#### Header Spacing
- **Header X Padding** - 16px/32px/40px responsive horizontal padding
- **Header Y Padding** - 16px vertical padding
- **Heading Y Padding** - 12px vertical padding

#### Page Spacing
- **Page Y Padding** - 24px top and bottom padding

### Links

#### Link Hover Effects (`.link-hover`)
- Underline on hover
- Underline offset: 8px
- Accent color decoration
- 2px underline thickness

#### Filter Links (`.filter-link`)
- Accent color text
- Semibold font weight

### Special Effects

#### Corner Cut (`.corner-cut`)
- Complex polygon clip-path creating cut corners on all sides

#### Obfuscate (`.obfuscate`)
- Blur effect (`blur-xl`)
- Clip-path inset for masking

### Grid Layouts

#### Recent Items Container (`.recent-container`)
- CSS Grid with auto-fit columns
- Minimum column width: 250px
- Complex row structure for masonry-like layout

#### Search Results
- Auto-fit grid with 300px minimum column width
- 24px gap between items

#### Metadata Layout
- Brief metadata sections with right borders using `border-e-1 border-search`

## Usage Guidelines

### Color Usage
- Use semantic color variables rather than specific color values
- Maintain color hierarchy with sage scale for subtle variations
- Reserve rust accent color for interactive elements and highlights
- Use Princeton Black for primary text and brand elements

### Typography
- Use Poppins for UI elements and headings
- Use Aleo serif for long-form content and descriptions
- Apply uppercase styling to headings for visual hierarchy

### Component Consistency
- Follow established button patterns for new interactive elements
- Use card component for content containers
- Apply consistent hover states using defined color variations
- Maintain spacing consistency using utility classes

### Accessibility
- Ensure sufficient color contrast between text and backgrounds
- Use semantic markup with appropriate heading hierarchy
- Provide focus states for interactive elements
- Include proper ARIA labels and descriptions