# Color Journal - Project Notes

## Overview
iOS/SwiftUI habit tracking app. Users track daily activities with colored buttons, visualized as a year-long grid.

## Project Structure
- **Single main file**: `colorjournal/ContentView.swift` (~1700 lines) contains almost everything
- Standard Xcode project structure otherwise

## Key Components in ContentView.swift

### Data & State
- `Activity` - Model for trackable activities (name, color)
- `ActivitiesManager` - Manages list of activities, persists to UserDefaults
- `LocalDataManager` - Stores daily activity data, generates year grid data
- `GoogleSheetsExporter` - Handles Google Sheets export with colors

### Views
- `ContentView` - Main view with activity buttons, year grid, date picker
- `YearGridView` - Horizontal scrolling year visualization (compact or expanded)
- `DayColumnView` - Single day column in year grid, uses Canvas for performance
- `ExpandedYearGridView` - Full-screen zoomed grid with edit mode
- `CheckmarkView` - Checkbox indicator next to activity buttons
- `SettingsView` / `ActivityEditView` - Activity management
- `ExportView` - CSV and Google Sheets export

### Key Patterns
- Year grid uses `Canvas` for fast rendering of many cells
- `isExpanded` boolean switches between compact (3px cells) and expanded (16px cells) modes
- Selected day has white border via `.strokeBorder` overlay
- Activities stored by index, so reordering requires `remapIndices()`

## Common Tasks
- UI tweaks to year grid: Look at `DayColumnView` and `YearGridView`
- Activity button styling: Look at the `ForEach` in `ContentView.body`
- Data persistence: `LocalDataManager.allData` dictionary, keyed by date string
