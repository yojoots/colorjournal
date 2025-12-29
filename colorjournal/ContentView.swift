import SwiftUI
import GoogleSignIn
import GoogleAPIClientForREST
import GTMSessionFetcher

// Activity model
struct Activity: Identifiable, Codable {
    var id: UUID
    var name: String
    var colorHex: String

    var color: Color {
        Color(hex: colorHex)
    }

    init(id: UUID = UUID(), name: String, color: Color) {
        self.id = id
        self.name = name
        self.colorHex = color.toHex()
    }
}

// Activities Manager
class ActivitiesManager: ObservableObject {
    @Published var activities: [Activity] = []

    private let defaults = UserDefaults.standard
    private let activitiesKey = "customActivities"

    init() {
        loadActivities()
    }

    private func loadActivities() {
        if let data = defaults.data(forKey: activitiesKey),
           let decoded = try? JSONDecoder().decode([Activity].self, from: data) {
            activities = decoded
        } else {
            // Default activities with concrete RGB colors
            activities = [
                Activity(name: "Exercise 🏋️‍♂️", color: Color(red: 1.0, green: 0.2, blue: 0.2)),
                Activity(name: "Stretch 🤸‍♀️", color: Color(red: 0.6, green: 0.95, blue: 0.8)),
                Activity(name: "Food 🥦", color: Color(red: 0.2, green: 0.8, blue: 0.2)),
                Activity(name: "Create 🛠️", color: Color(red: 0.2, green: 0.4, blue: 1.0)),
                Activity(name: "Work 💻", color: Color(red: 0.2, green: 0.7, blue: 0.7)),
                Activity(name: "Read 📚", color: Color(red: 1.0, green: 0.9, blue: 0.0)),
                Activity(name: "Journal ✍️", color: Color(red: 0.7, green: 0.3, blue: 0.9)),
                Activity(name: "Meditate 🧘", color: Color(red: 1.0, green: 0.6, blue: 0.0)),
                Activity(name: "Music 🎵", color: Color(red: 0.3, green: 0.2, blue: 0.8)),
                Activity(name: "Chores 🧹", color: Color(red: 1.0, green: 0.4, blue: 0.7)),
                Activity(name: "Sleep 💤", color: Color(red: 0.2, green: 0.8, blue: 1.0)),
                Activity(name: "Mind 💭", color: Color(red: 0.6, green: 0.6, blue: 0.6)),
                Activity(name: "Sick 🤒", color: Color(red: 0.6, green: 0.4, blue: 0.2))
            ]
        }
    }

    func saveActivities() {
        if let encoded = try? JSONEncoder().encode(activities) {
            defaults.set(encoded, forKey: activitiesKey)
        }
    }

    func addActivity(_ activity: Activity) {
        activities.append(activity)
        saveActivities()
    }

    func deleteActivity(at index: Int) {
        activities.remove(at: index)
        saveActivities()
    }

    func moveActivity(from: IndexSet, to: Int) {
        activities.move(fromOffsets: from, toOffset: to)
        saveActivities()
    }

    func updateActivity(at index: Int, name: String, color: Color) {
        activities[index].name = name
        activities[index].colorHex = color.toHex()
        saveActivities()
    }
}

// Configuration struct (for backwards compatibility)
struct AppConfig {
    static var colors: [(name: String, color: Color)] {
        // This is now a placeholder, actual activities come from ActivitiesManager
        return []
    }

    static func daysInYear(_ year: Int) -> Int {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = 12
        components.day = 31
        if let date = calendar.date(from: components) {
            return calendar.ordinality(of: .day, in: .year, for: date) ?? 365
        }
        return 365
    }

    static var daysInCurrentYear: Int {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        return daysInYear(year)
    }
}

struct YearGridCell: View, Equatable {
    let isColored: Bool
    let color: Color
    let cellSize: CGFloat

    static func == (lhs: YearGridCell, rhs: YearGridCell) -> Bool {
        lhs.isColored == rhs.isColored &&
        lhs.cellSize == rhs.cellSize &&
        lhs.color.description == rhs.color.description
    }

    var body: some View {
        Rectangle()
            .fill(isColored ? color : Color.black)
            .frame(width: cellSize, height: cellSize)
    }
}

// Optimized day column using Canvas for fast rendering
struct DayColumnView: View {
    let day: Int
    let dayData: [Bool]
    let activities: [Activity]
    let cellSize: CGFloat
    let cellSpacing: CGFloat
    let isSelected: Bool
    let highlightPadding: CGFloat
    let strokeWidth: CGFloat
    let isEditMode: Bool
    let showGridLines: Bool
    let isMonthStart: Bool
    let onCellTap: ((Int, Int) -> Void)?

    private var gridPadding: CGFloat { cellSpacing / 2 + 1 }

    var body: some View {
        Canvas { context, size in
            let totalCellHeight = cellSize + cellSpacing
            let yOffset = gridPadding

            // Draw cells
            for index in activities.indices {
                let isColored = index < dayData.count ? dayData[index] : false
                let y = CGFloat(index) * totalCellHeight + yOffset
                let rect = CGRect(x: 0, y: y, width: cellSize, height: cellSize)
                let color = isColored ? activities[index].color : Color.black
                context.fill(Path(rect), with: .color(color))
            }

            // Draw grid lines if enabled
            if showGridLines {
                let gridColor = Color.white.opacity(0.15)

                // Horizontal lines between each cell
                for i in 0...activities.count {
                    let y = CGFloat(i) * totalCellHeight - cellSpacing / 2 + yOffset
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: cellSize, y: y))
                    context.stroke(path, with: .color(gridColor), lineWidth: 1)
                }

                // Vertical lines on left and right edges
                var leftPath = Path()
                leftPath.move(to: CGPoint(x: 0, y: 0))
                leftPath.addLine(to: CGPoint(x: 0, y: size.height))
                context.stroke(leftPath, with: .color(gridColor), lineWidth: 1)
            }

            // Draw month separator line
            if isMonthStart {
                let monthLineColor = Color.white.opacity(0.3)
                var monthPath = Path()
                monthPath.move(to: CGPoint(x: 0, y: 0))
                monthPath.addLine(to: CGPoint(x: 0, y: size.height))
                context.stroke(monthPath, with: .color(monthLineColor), lineWidth: 1)
            }
        }
        .frame(width: cellSize, height: CGFloat(activities.count) * (cellSize + cellSpacing) - cellSpacing + gridPadding * 2)
        .padding(isSelected ? highlightPadding : 0)
        .overlay(
            Rectangle()
                .strokeBorder(isSelected ? Color.white : Color.clear, lineWidth: strokeWidth)
        )
        .contentShape(Rectangle())
        .onTapGesture { location in
            if isEditMode, let onCellTap = onCellTap {
                let index = Int(location.y / (cellSize + cellSpacing))
                if index >= 0 && index < activities.count {
                    onCellTap(day, index)
                }
            }
        }
    }
}

struct StreakSegment: Identifiable {
    let id = UUID()
    let activityIndex: Int
    let startDay: Int
    let length: Int
}

struct YearGridView: View {
    let yearData: [Int: [Bool]]  // Day number -> array of activity statuses
    let selectedDate: Date
    let activities: [Activity]
    var isExpanded: Bool = false
    var isEditMode: Bool = false
    var showGridLines: Bool = false
    var showStreakOverlay: Bool = false
    var onCellTap: ((Int, Int) -> Void)? = nil  // (dayOfYear, activityIndex)

    private var cellSize: CGFloat { isExpanded ? 16 : 3 }
    private var cellSpacing: CGFloat { isExpanded ? 4 : 1 }
    private var highlightPadding: CGFloat { isExpanded ? 1 : 1 }
    private var strokeWidth: CGFloat { isExpanded ? 2 : 1 }

    private var selectedDayOfYear: Int {
        let calendar = Calendar.current
        let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: selectedDate))!
        return calendar.dateComponents([.day], from: startOfYear, to: selectedDate).day! + 1
    }

    // Computed once, cached
    private static let monthStartDaysCache: [Int: String] = {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        let monthLabels = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        var result: [Int: String] = [:]

        for month in 1...12 {
            if let firstOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
               let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) {
                let dayOfYear = calendar.dateComponents([.day], from: startOfYear, to: firstOfMonth).day! + 1
                result[dayOfYear] = monthLabels[month - 1]
            }
        }
        return result
    }()

    private func calculateStreakSegments() -> [StreakSegment] {
        var segments: [StreakSegment] = []
        let daysInYear = AppConfig.daysInCurrentYear

        for activityIndex in activities.indices {
            var day = 1
            while day <= daysInYear {
                let dayData = yearData[day] ?? []
                let isActive = activityIndex < dayData.count ? dayData[activityIndex] : false

                if isActive {
                    // Start of a streak
                    let startDay = day
                    var length = 0

                    while day <= daysInYear {
                        let d = yearData[day] ?? []
                        let active = activityIndex < d.count ? d[activityIndex] : false
                        if active {
                            length += 1
                            day += 1
                        } else {
                            break
                        }
                    }

                    // Only show number if streak is 2+ days
                    if length >= 2 {
                        segments.append(StreakSegment(activityIndex: activityIndex, startDay: startDay, length: length))
                    }
                } else {
                    day += 1
                }
            }
        }

        return segments
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    // Month markers (only in expanded mode)
                    if isExpanded {
                        LazyHStack(alignment: .top, spacing: 0) {
                            ForEach(1...AppConfig.daysInCurrentYear, id: \.self) { day in
                                if let label = Self.monthStartDaysCache[day] {
                                    Text(label)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .fixedSize()
                                        .frame(width: cellSize, alignment: .leading)
                                        .offset(x: day == 1 ? 0 : -10)
                                } else {
                                    Color.clear
                                        .frame(width: cellSize, height: 1)
                                }
                            }
                        }
                        .frame(height: 16)
                    }

                    // Day grid
                    let gridPadding: CGFloat = cellSpacing / 2 + 1
                    // Add extra height for selection border (highlightPadding + strokeWidth on top and bottom)
                    let selectionExtraHeight: CGFloat = (highlightPadding + strokeWidth) * 2
                    let gridHeight = CGFloat(activities.count) * (cellSize + cellSpacing) - cellSpacing + gridPadding * 2 + selectionExtraHeight
                    ZStack(alignment: .topLeading) {
                        LazyHStack(alignment: .top, spacing: 0) {
                            ForEach(1...AppConfig.daysInCurrentYear, id: \.self) { day in
                                let isSelected = day == selectedDayOfYear
                                let dayData = yearData[day] ?? []
                                let isMonthStart = Self.monthStartDaysCache[day] != nil
                                DayColumnView(
                                    day: day,
                                    dayData: dayData,
                                    activities: activities,
                                    cellSize: cellSize,
                                    cellSpacing: cellSpacing,
                                    isSelected: isSelected,
                                    highlightPadding: highlightPadding,
                                    strokeWidth: strokeWidth,
                                    isEditMode: isEditMode,
                                    showGridLines: showGridLines,
                                    isMonthStart: isExpanded && isMonthStart,
                                    onCellTap: onCellTap
                                )
                                .id(day)
                            }
                        }

                        // Streak overlay (only in expanded mode with showStreakOverlay)
                        if isExpanded && showStreakOverlay {
                            let segments = calculateStreakSegments()
                            ForEach(segments) { segment in
                                let xPos = CGFloat(segment.startDay - 1) * cellSize + CGFloat(segment.length) * cellSize / 2
                                let yPos = gridPadding + CGFloat(segment.activityIndex) * (cellSize + cellSpacing) + cellSize / 2
                                Text("\(segment.length)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 1, x: 0, y: 0)
                                    .shadow(color: .black, radius: 1, x: 0, y: 0)
                                    .position(x: xPos, y: yPos)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                    .frame(height: gridHeight)
                }
            }
            .frame(height: isExpanded ? nil : 50)
            .onAppear {
                // Scroll to current day, centered
                proxy.scrollTo(selectedDayOfYear, anchor: .center)
            }
            .onChange(of: selectedDate) { oldValue, newValue in
                // Scroll to selected day when date changes
                withAnimation {
                    proxy.scrollTo(selectedDayOfYear, anchor: .center)
                }
            }
        }
    }
}

struct ExpandedYearGridView: View {
    @ObservedObject var dataManager: LocalDataManager
    let selectedDate: Date
    let activities: [Activity]
    @Binding var isPresented: Bool
    @State private var isEditMode: Bool = false
    @State private var showGridLines: Bool = false
    @State private var showStreaks: Bool = false
    @State private var showLegend: Bool = true

    // Grid layout constants (must match YearGridView)
    private let cellSize: CGFloat = 16
    private let cellSpacing: CGFloat = 4

    private var todayDayOfYear: Int {
        let calendar = Calendar.current
        let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: Date()))!
        return calendar.dateComponents([.day], from: startOfYear, to: Date()).day! + 1
    }

    private func dateFromDayOfYear(_ dayOfYear: Int) -> Date {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.day = dayOfYear
        return calendar.date(from: dateComponents) ?? Date()
    }

    private func toggleCell(dayOfYear: Int, activityIndex: Int) {
        let date = dateFromDayOfYear(dayOfYear)
        let dayData = dataManager.yearData[dayOfYear] ?? []
        let isCurrentlyOn = activityIndex < dayData.count ? dayData[activityIndex] : false

        if isCurrentlyOn {
            dataManager.clearCell(row: activityIndex, date: date)
        } else {
            dataManager.updateCell(row: activityIndex, date: date, color: activities[activityIndex].color)
        }
    }

    private func currentStreak(for activityIndex: Int) -> Int {
        var streak = 0
        var day = todayDayOfYear

        while day >= 1 {
            let dayData = dataManager.yearData[day] ?? []
            let isActive = activityIndex < dayData.count ? dayData[activityIndex] : false

            if isActive {
                streak += 1
                day -= 1
            } else {
                break
            }
        }

        return streak
    }

    private func trimTrailingEmoji(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespaces)
        while let lastChar = result.unicodeScalars.last {
            // Check if it's an emoji (various Unicode ranges)
            let isEmoji = lastChar.properties.isEmoji && lastChar.properties.isEmojiPresentation
                || (lastChar.value >= 0x1F300 && lastChar.value <= 0x1FAD6)
                || (lastChar.value >= 0x2600 && lastChar.value <= 0x27BF)
                || lastChar.value == 0xFE0F // variation selector
            if isEmoji {
                result = String(result.dropLast())
                result = result.trimmingCharacters(in: .whitespaces)
            } else {
                break
            }
        }
        return result
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                HStack {
                    Button(action: {
                        withAnimation {
                            isEditMode.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isEditMode ? "pencil.circle.fill" : "pencil.circle")
                                .font(.title2)
                            Text(isEditMode ? "Done" : "Edit")
                                .font(.subheadline)
                                .fixedSize()
                        }
                        .foregroundColor(isEditMode ? .yellow : .gray)
                    }
                    .padding()

                    Spacer()

                    Button(action: {
                        withAnimation {
                            showStreaks.toggle()
                        }
                    }) {
                        Image(systemName: showStreaks ? "flame.circle.fill" : "flame.circle")
                            .font(.title2)
                            .foregroundColor(showStreaks ? .orange : .gray)
                    }
                    .padding(.trailing, 8)

                    Button(action: {
                        withAnimation {
                            showLegend.toggle()
                        }
                    }) {
                        Image(systemName: showLegend ? "list.bullet.circle.fill" : "list.bullet.circle")
                            .font(.title2)
                            .foregroundColor(showLegend ? .cyan : .gray)
                    }
                    .padding(.trailing, 8)

                    Button(action: {
                        showGridLines.toggle()
                    }) {
                        Image(systemName: showGridLines ? "grid.circle.fill" : "grid.circle")
                            .font(.title2)
                            .foregroundColor(showGridLines ? .yellow : .gray)
                    }
                    .padding(.trailing, 8)

                    Button(action: {
                        withAnimation {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.gray)
                    }
                    .padding()
                }

                if showStreaks {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(activities.indices, id: \.self) { index in
                                let streak = currentStreak(for: index)
                                if streak > 0 {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(activities[index].color)
                                            .frame(width: 10, height: 10)
                                        Text("\(streak)d")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 30)
                }

                HStack(alignment: .top, spacing: 8) {
                    // Legend
                    if showLegend {
                        VStack(alignment: .trailing, spacing: 0) {
                            // Spacer for month markers row
                            Color.clear.frame(height: 20)

                            // Legend items aligned with grid rows
                            let gridPadding: CGFloat = cellSpacing / 2 + 1
                            VStack(alignment: .trailing, spacing: cellSpacing) {
                                ForEach(activities.indices, id: \.self) { index in
                                    HStack(spacing: 4) {
                                        Text(trimTrailingEmoji(activities[index].name))
                                            .font(.system(size: 9))
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                        Circle()
                                            .fill(activities[index].color)
                                            .frame(width: 8, height: 8)
                                    }
                                    .frame(height: cellSize)
                                }
                            }
                            .padding(.top, gridPadding)
                        }
                        .frame(width: 70)
                    }

                    YearGridView(
                        yearData: dataManager.yearData,
                        selectedDate: selectedDate,
                        activities: activities,
                        isExpanded: true,
                        isEditMode: isEditMode,
                        showGridLines: showGridLines,
                        showStreakOverlay: showStreaks,
                        onCellTap: { dayOfYear, activityIndex in
                            toggleCell(dayOfYear: dayOfYear, activityIndex: activityIndex)
                        }
                    )
                }
                .padding(.leading, 8)
                .padding(.trailing, 16)
                .padding(.top, showStreaks ? 20 : 40)

                if isEditMode {
                    Text("Tap cells to toggle")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                }

                Spacer()
            }
        }
        .onTapGesture {
            if !isEditMode && !showStreaks && !showLegend {
                withAnimation {
                    isPresented = false
                }
            }
        }
    }
}


class LocalDataManager: ObservableObject {
    @Published var cellStatuses: [Int: Bool] = [:] // Track colored status for each row
    @Published var yearData: [Int: [Bool]] = [:] // Day -> Array of activity statuses

    let defaults = UserDefaults.standard
    let dataKey = "activityData"

    // Data structure: [dateString: [activityIndex: true/false]]
    var allData: [String: [Int: Bool]] = [:]

    init() {
        loadData()
        // fetchYearData will be called from ContentView with proper activities count
    }

    func dateKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func loadData() {
        if let data = defaults.data(forKey: dataKey),
           let decoded = try? JSONDecoder().decode([String: [Int: Bool]].self, from: data) {
            allData = decoded
        }
    }

    private func saveData() {
        if let encoded = try? JSONEncoder().encode(allData) {
            defaults.set(encoded, forKey: dataKey)
        }
    }

    func clearAllData() {
        allData.removeAll()
        defaults.removeObject(forKey: dataKey)
        cellStatuses.removeAll()
        yearData.removeAll()
    }

    /// Remaps stored activity data indices when activities are reordered.
    /// This ensures streak data follows the activity when moved.
    func remapIndices(from sourceIndices: IndexSet, to destination: Int, totalCount: Int) {
        guard let sourceIndex = sourceIndices.first else { return }

        // Calculate the actual destination index after removal
        let actualDestination = sourceIndex < destination ? destination - 1 : destination

        // Build the index mapping: oldIndex -> newIndex
        var indexMap: [Int: Int] = [:]

        for i in 0..<totalCount {
            if i == sourceIndex {
                // The moved item goes to its new position
                indexMap[i] = actualDestination
            } else if sourceIndex < actualDestination {
                // Moving down: items between source and destination shift up
                if i > sourceIndex && i <= actualDestination {
                    indexMap[i] = i - 1
                } else {
                    indexMap[i] = i
                }
            } else {
                // Moving up: items between destination and source shift down
                if i >= actualDestination && i < sourceIndex {
                    indexMap[i] = i + 1
                } else {
                    indexMap[i] = i
                }
            }
        }

        // Apply the mapping to all stored data
        var newAllData: [String: [Int: Bool]] = [:]

        for (dateKey, dayData) in allData {
            var newDayData: [Int: Bool] = [:]
            for (oldIndex, value) in dayData {
                if let newIndex = indexMap[oldIndex] {
                    newDayData[newIndex] = value
                } else if oldIndex < totalCount {
                    // Keep data at same index if not in map (shouldn't happen)
                    newDayData[oldIndex] = value
                }
            }
            newAllData[dateKey] = newDayData
        }

        allData = newAllData
        saveData()
    }

    func fetchYearData(activitiesCount: Int = 13) {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        var newYearData: [Int: [Bool]] = [:]

        // Build year data from stored data
        for day in 1...AppConfig.daysInYear(year) {
            var dateComponents = DateComponents()
            dateComponents.year = year
            dateComponents.day = day

            if let date = calendar.date(from: dateComponents) {
                let key = dateKey(from: date)
                let dayActivities = allData[key] ?? [:]

                var activitiesArray = Array(repeating: false, count: activitiesCount)
                for (index, isActive) in dayActivities {
                    if index < activitiesArray.count {
                        activitiesArray[index] = isActive
                    }
                }
                newYearData[day] = activitiesArray
            }
        }

        DispatchQueue.main.async {
            self.yearData = newYearData
        }
    }

    func fetchCellStatus(date: Date, activitiesCount: Int = 13) {
        let key = dateKey(from: date)
        let dayData = allData[key] ?? [:]

        DispatchQueue.main.async {
            self.cellStatuses.removeAll()
            for index in 0..<activitiesCount {
                self.cellStatuses[index] = dayData[index] ?? false
            }
        }
    }

    func updateCell(row: Int, date: Date, color: Color) {
        let key = dateKey(from: date)

        if allData[key] == nil {
            allData[key] = [:]
        }
        allData[key]?[row] = true

        saveData()

        // Update local states
        DispatchQueue.main.async {
            self.cellStatuses[row] = true

            // Update yearData
            let calendar = Calendar.current
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: date))!
            let dayOfYear = calendar.dateComponents([.day], from: startOfYear, to: date).day! + 1

            if self.yearData[dayOfYear] == nil {
                self.yearData[dayOfYear] = Array(repeating: false, count: AppConfig.colors.count)
            }
            self.yearData[dayOfYear]?[row] = true
        }
    }

    func clearCell(row: Int, date: Date) {
        let key = dateKey(from: date)

        if allData[key] != nil {
            allData[key]?[row] = false
        }

        saveData()

        // Update local states
        DispatchQueue.main.async {
            self.cellStatuses[row] = false

            // Update yearData
            let calendar = Calendar.current
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: date))!
            let dayOfYear = calendar.dateComponents([.day], from: startOfYear, to: date).day! + 1

            if self.yearData[dayOfYear] != nil {
                self.yearData[dayOfYear]?[row] = false
            }
        }
    }

    // Export functionality
    func exportToCSV(activities: [Activity]) -> String {
        var csv = "Date," + activities.map { $0.name }.joined(separator: ",") + "\n"

        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())

        // Generate CSV for all days of the current year
        for day in 1...AppConfig.daysInYear(year) {
            var dateComponents = DateComponents()
            dateComponents.year = year
            dateComponents.day = day

            if let date = calendar.date(from: dateComponents) {
                let dateString = dateKey(from: date)
                let dayData = allData[dateString] ?? [:]
                var row = [dateString]

                for index in 0..<activities.count {
                    row.append(dayData[index] == true ? "✓" : "")
                }
                csv += row.joined(separator: ",") + "\n"
            }
        }

        return csv
    }
}

// Google Sheets Exporter for colored export
class GoogleSheetsExporter: ObservableObject {
    private var service: GTLRSheetsService?
    @Published var isSignedIn = false
    @Published var isExporting = false
    @Published var exportStatus: String = ""

    private let defaults = UserDefaults.standard
    private let savedSpreadsheetKey = "savedSpreadsheetId"

    var savedSpreadsheetId: String? {
        get { defaults.string(forKey: savedSpreadsheetKey) }
        set { defaults.set(newValue, forKey: savedSpreadsheetKey) }
    }

    init() {
        // Restore previous sign-in
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
            if let user = user {
                let service = GTLRSheetsService()
                service.authorizer = user.fetcherAuthorizer
                self?.service = service
                DispatchQueue.main.async {
                    self?.isSignedIn = true
                }
            }
        }
    }

    func signIn(completion: @escaping (Bool) -> Void) {
        guard let presentingViewController = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController else {
            completion(false)
            return
        }

        GIDSignIn.sharedInstance.signIn(
            withPresenting: presentingViewController,
            hint: nil,
            additionalScopes: ["https://www.googleapis.com/auth/spreadsheets"]
        ) { [weak self] result, error in
            if let user = result?.user {
                let service = GTLRSheetsService()
                service.authorizer = user.fetcherAuthorizer
                self?.service = service
                self?.isSignedIn = true
                completion(true)
            } else {
                DispatchQueue.main.async {
                    let errorMsg = error?.localizedDescription ?? "Sign in cancelled"
                    self?.exportStatus = "Sign in failed: \(errorMsg)"
                }
                completion(false)
            }
        }
    }

    func createNewSpreadsheet(completion: @escaping (Bool, String?) -> Void) {
        guard let service = service else {
            exportStatus = "Please sign in first"
            completion(false, nil)
            return
        }

        isExporting = true
        exportStatus = "Creating new spreadsheet..."

        let spreadsheet = GTLRSheets_Spreadsheet()
        spreadsheet.properties = GTLRSheets_SpreadsheetProperties()
        spreadsheet.properties?.title = "Color Journal Export - \(Date().formatted(date: .abbreviated, time: .omitted))"

        let query = GTLRSheetsQuery_SpreadsheetsCreate.query(withObject: spreadsheet)

        service.executeQuery(query) { [weak self] (ticket, result, error) in
            DispatchQueue.main.async {
                if let error = error {
                    self?.isExporting = false
                    let errorMsg = error.localizedDescription
                    self?.exportStatus = "Failed to create spreadsheet"
                    print("Error creating spreadsheet: \(errorMsg)")
                    completion(false, nil)
                    return
                }

                if let createdSheet = result as? GTLRSheets_Spreadsheet,
                   let spreadsheetId = createdSheet.spreadsheetId {
                    self?.savedSpreadsheetId = spreadsheetId
                    self?.exportStatus = "Spreadsheet created!"
                    completion(true, spreadsheetId)
                } else {
                    self?.isExporting = false
                    self?.exportStatus = "Failed to create spreadsheet"
                    completion(false, nil)
                }
            }
        }
    }

    func exportToGoogleSheets(dataManager: LocalDataManager, activitiesManager: ActivitiesManager, spreadsheetId: String, completion: @escaping (Bool, String) -> Void) {
        guard let service = service else {
            completion(false, "Please sign in to Google first")
            return
        }

        isExporting = true
        exportStatus = "Exporting data with colors..."

        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        let daysInYear = AppConfig.daysInYear(year)
        let totalColumns = daysInYear + 1  // +1 for activity names column

        // Build the data with colors
        var requests: [GTLRSheets_Request] = []

        // 1. Resize sheet to have enough columns
        let resizeRequest = GTLRSheets_Request()
        let updateSheetProperties = GTLRSheets_UpdateSheetPropertiesRequest()
        let sheetProperties = GTLRSheets_SheetProperties()
        sheetProperties.sheetId = 0
        let gridProperties = GTLRSheets_GridProperties()
        gridProperties.columnCount = NSNumber(value: totalColumns)
        gridProperties.rowCount = NSNumber(value: activitiesManager.activities.count + 1) // 1 header + activities
        sheetProperties.gridProperties = gridProperties
        updateSheetProperties.properties = sheetProperties
        updateSheetProperties.fields = "gridProperties.columnCount,gridProperties.rowCount"
        resizeRequest.updateSheetProperties = updateSheetProperties
        requests.append(resizeRequest)

        // Set column widths - narrow date columns
        let columnWidthRequest = GTLRSheets_Request()
        let updateDimensionProperties = GTLRSheets_UpdateDimensionPropertiesRequest()
        let dimensionRange = GTLRSheets_DimensionRange()
        dimensionRange.sheetId = 0
        dimensionRange.dimension = "COLUMNS"
        dimensionRange.startIndex = 1  // Start from column B (first date column)
        dimensionRange.endIndex = NSNumber(value: totalColumns)  // Through all date columns
        updateDimensionProperties.range = dimensionRange

        let dimensionProperties = GTLRSheets_DimensionProperties()
        dimensionProperties.pixelSize = NSNumber(value: 35)  // Narrow width for dates
        updateDimensionProperties.properties = dimensionProperties
        updateDimensionProperties.fields = "pixelSize"
        columnWidthRequest.updateDimensionProperties = updateDimensionProperties
        requests.append(columnWidthRequest)

        // 2. Create header row with dates across the top
        var rowData: [GTLRSheets_RowData] = []
        let headerRow = GTLRSheets_RowData()
        var headerCells: [GTLRSheets_CellData] = []

        // Empty first cell (top-left corner)
        let emptyCell = GTLRSheets_CellData()
        headerCells.append(emptyCell)

        // Date headers for all days
        for day in 1...daysInYear {
            var dateComponents = DateComponents()
            dateComponents.year = year
            dateComponents.day = day

            if let date = calendar.date(from: dateComponents) {
                let cell = GTLRSheets_CellData()
                cell.userEnteredValue = GTLRSheets_ExtendedValue()
                // Format as M/D (e.g., 1/1, 1/2, ..., 12/31)
                let formatter = DateFormatter()
                formatter.dateFormat = "M/d"
                cell.userEnteredValue?.stringValue = formatter.string(from: date)
                headerCells.append(cell)
            }
        }
        headerRow.values = headerCells
        rowData.append(headerRow)

        // 3. Create one row per activity
        for (activityIndex, activity) in activitiesManager.activities.enumerated() {
            let row = GTLRSheets_RowData()
            var cells: [GTLRSheets_CellData] = []

            // Activity name in first column
            let nameCell = GTLRSheets_CellData()
            nameCell.userEnteredValue = GTLRSheets_ExtendedValue()
            nameCell.userEnteredValue?.stringValue = activity.name
            cells.append(nameCell)

            // Cell for each day
            for day in 1...daysInYear {
                var dateComponents = DateComponents()
                dateComponents.year = year
                dateComponents.day = day

                if let date = calendar.date(from: dateComponents) {
                    let dateString = dataManager.dateKey(from: date)
                    let dayData = dataManager.allData[dateString] ?? [:]
                    let isActive = dayData[activityIndex] == true

                    let cell = GTLRSheets_CellData()

                    if isActive {
                        cell.userEnteredValue = GTLRSheets_ExtendedValue()
                        cell.userEnteredValue?.stringValue = "✓"

                        // Apply background color
                        let format = GTLRSheets_CellFormat()
                        let bgColor = GTLRSheets_Color()

                        let uiColor = UIColor(activity.color)
                        var red: CGFloat = 0
                        var green: CGFloat = 0
                        var blue: CGFloat = 0
                        var alpha: CGFloat = 0
                        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

                        bgColor.red = NSNumber(value: Float(red))
                        bgColor.green = NSNumber(value: Float(green))
                        bgColor.blue = NSNumber(value: Float(blue))

                        format.backgroundColor = bgColor
                        cell.userEnteredFormat = format
                    }

                    cells.append(cell)
                }
            }

            row.values = cells
            rowData.append(row)
        }

        // 4. Update cells request
        let updateRequest = GTLRSheets_Request()
        let updateCells = GTLRSheets_UpdateCellsRequest()
        let gridRange = GTLRSheets_GridRange()
        gridRange.sheetId = 0
        gridRange.startRowIndex = 0
        gridRange.startColumnIndex = 0
        gridRange.endRowIndex = NSNumber(value: rowData.count)
        gridRange.endColumnIndex = NSNumber(value: totalColumns)

        updateCells.range = gridRange
        updateCells.fields = "userEnteredValue,userEnteredFormat.backgroundColor"
        updateCells.rows = rowData

        updateRequest.updateCells = updateCells
        requests.append(updateRequest)

        // Execute batch update
        let batchUpdate = GTLRSheets_BatchUpdateSpreadsheetRequest()
        batchUpdate.requests = requests

        let query = GTLRSheetsQuery_SpreadsheetsBatchUpdate.query(
            withObject: batchUpdate,
            spreadsheetId: spreadsheetId)

        service.executeQuery(query) { [weak self] (ticket, result, error) in
            DispatchQueue.main.async {
                self?.isExporting = false

                if let error = error {
                    let errorMsg = error.localizedDescription
                    self?.exportStatus = "Export failed"
                    print("Export error: \(errorMsg)")

                    // Provide user-friendly error messages
                    let userMessage: String
                    if errorMsg.contains("permission") || errorMsg.contains("access") {
                        userMessage = "Permission denied. Please make sure you have access to this spreadsheet."
                    } else if errorMsg.contains("not found") || errorMsg.contains("404") {
                        userMessage = "Spreadsheet not found. Please check the URL and try again."
                    } else if errorMsg.contains("network") || errorMsg.contains("internet") {
                        userMessage = "Network error. Please check your internet connection."
                    } else {
                        userMessage = "Export failed. Please try again."
                    }

                    completion(false, userMessage)
                } else {
                    self?.exportStatus = "Export complete!"
                    self?.savedSpreadsheetId = spreadsheetId
                    completion(true, "Successfully exported with colors!")
                }
            }
        }
    }

    func getSpreadsheetUrl(id: String) -> String {
        return "https://docs.google.com/spreadsheets/d/\(id)"
    }
}

struct CheckmarkView: View {
    let index: Int
    let color: Color
    let isChecked: Bool
    let date: Date
    @ObservedObject var dataManager: LocalDataManager
    @State private var isLongPressing = false
    
    var body: some View {
        Image(systemName: isChecked ? "checkmark.square.fill" : "square")
            .foregroundColor(color)
            .imageScale(.large)
            .padding(.leading, 8)
            .scaleEffect(isLongPressing ? 1.2 : 1.0)
            .onTapGesture {
                if !isChecked {
                    dataManager.updateCell(row: index, date: date, color: color)
                }
            }
            .gesture(
                LongPressGesture(minimumDuration: 0.25)
                    .onEnded { _ in
                        if isChecked {
                            // Add haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()

                            dataManager.clearCell(row: index, date: date)
                        }
                    }
                    .simultaneously(with: DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isLongPressing {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isLongPressing = true
                                }
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isLongPressing = false
                            }
                        }
                    )
            )
    }
}

struct ParticleView: View {
    let color: Color
    @State private var particles: [(id: Int, x: CGFloat, y: CGFloat, scale: CGFloat, opacity: Double)] = []
    @Binding var isAnimating: Bool
    
    var body: some View {
        ZStack {
            ForEach(particles, id: \.id) { particle in
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .scaleEffect(particle.scale)
                    .opacity(particle.opacity)
                    .position(x: particle.x, y: particle.y)
            }
        }
        .onChange(of: isAnimating) { oldValue, newValue in
            if newValue {
                createParticles()
            }
        }
    }
    
    private func createParticles() {
        // Create particles in a circle
        particles = (0..<16).map { i in
            let angle = (Double(i) / 16.0) * 2 * .pi
            return (
                id: i,
                x: 125,
                y: 20,
                scale: 0.1,
                opacity: 1.0
            )
        }
        
        // Animate each particle
        for i in particles.indices {
            let angle = (Double(i) / 16.0) * 2 * .pi
            let duration = 0.4
            
            withAnimation(.easeOut(duration: duration)) {
                particles[i].x += cos(angle) * 100
                particles[i].y += sin(angle) * 100
                particles[i].scale = 1.5
                particles[i].opacity = 0
            }
        }
        
        // Reset after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            particles = []
            isAnimating = false
        }
    }
}

struct SnapButtonStyle: ButtonStyle {
    let color: Color
    @Binding var isAnimating: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.15, dampingFraction: 0.5, blendDuration: 0), value: configuration.isPressed)
            .overlay(
                ZStack {
                    ParticleView(color: color, isAnimating: $isAnimating)
                }
            )
    }
}

struct ContentView: View {
    @StateObject private var activitiesManager = ActivitiesManager()
    @StateObject private var dataManager = LocalDataManager()

    @State private var selectedColor: Color = .red
    @State private var selectedDate = Date()
    @State private var showDatePicker = false
    @State private var animatingButtons: Set<String> = []
    @State private var particleButtons: Set<String> = []
    @State private var showExportSheet = false
    @State private var showSettingsSheet = false
    @State private var showExpandedGrid = false

    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    func needsDarkText(for color: Color) -> Bool {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // Calculate luminance
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        return luminance > 0.6 // Use dark text for bright colors
    }

    var body: some View {
        VStack {
            // Settings/Export buttons in top-right
            HStack {
                Spacer()
                Button(action: {
                    showSettingsSheet = true
                }) {
                    Image(systemName: "gearshape")
                        .imageScale(.large)
                        .padding()
                }
                Button(action: {
                    showExportSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .imageScale(.large)
                        .padding()
                }
            }

            ScrollView {
                    VStack(spacing: 10) {
                        Spacer()
                            .frame(height: 5)

                        ForEach(activitiesManager.activities.indices, id: \.self) { index in
                            let activity = activitiesManager.activities[index]
                            HStack {
                                Button(action: {
                                    withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
                                        animatingButtons.insert(activity.name)
                                        particleButtons.insert(activity.name)
                                    }

                                    dataManager.updateCell(row: index, date: selectedDate, color: activity.color)

                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        animatingButtons.remove(activity.name)
                                    }
                                }) {
                                    HStack {
                                        Text(activity.name)
                                            .foregroundColor(needsDarkText(for: activity.color) ? .black : .white)
                                            .frame(maxWidth: .infinity)
                                    }
                                    .frame(height: 40)
                                    .frame(maxWidth: 250)
                                    .background(activity.color)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(SnapButtonStyle(
                                    color: activity.color,
                                    isAnimating: .init(
                                        get: { particleButtons.contains(activity.name) },
                                        set: { isAnimating in
                                            if !isAnimating {
                                                particleButtons.remove(activity.name)
                                            }
                                        }
                                    )
                                ))
                                .scaleEffect(animatingButtons.contains(activity.name) ? 1.05 : 1.0)
                                
                                // Add checkbox indicator
                                CheckmarkView(
                                    index: index,
                                    color: activity.color,
                                    isChecked: dataManager.cellStatuses[index] == true,
                                    date: selectedDate,
                                    dataManager: dataManager
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }


                YearGridView(yearData: dataManager.yearData,
                             selectedDate: selectedDate,
                             activities: activitiesManager.activities)
                    .padding(.horizontal)
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded {
                                withAnimation {
                                    showExpandedGrid = true
                                }
                            }
                    )
            
                let calendar = Calendar.current
                let currentYear = calendar.component(.year, from: Date())
                let dateRange: ClosedRange<Date> = {
                    let calendar = Calendar.current
                    let startComponents = DateComponents(year: currentYear, month: 1, day: 1)
                    let endComponents = DateComponents(year: currentYear, month: 12, day: 31, hour: 23, minute: 59, second: 59)
                    return calendar.date(from:startComponents)!
                        ...
                        calendar.date(from:endComponents)!
                }()
            
                Button(action: {
                    showDatePicker = true
                }) {
                    Text(dateFormatter.string(from: selectedDate))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .popover(isPresented: $showDatePicker, attachmentAnchor: .point(.bottom)) {
                    DatePicker(
                        "",
                        selection: $selectedDate,
                        in: dateRange,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .onChange(of: selectedDate) { oldValue, newValue in  // Updated onChange syntax
                        showDatePicker = false
                    }
                    .padding()
                }
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            // Fetch cell statuses whenever date changes
            dataManager.fetchCellStatus(date: newValue, activitiesCount: activitiesManager.activities.count)
        }
        .onChange(of: activitiesManager.activities.count) { oldValue, newValue in
            // Refresh data when activities change
            dataManager.fetchYearData(activitiesCount: newValue)
            dataManager.fetchCellStatus(date: selectedDate, activitiesCount: newValue)
        }
        .onAppear {
            dataManager.fetchCellStatus(date: selectedDate, activitiesCount: activitiesManager.activities.count)
            dataManager.fetchYearData(activitiesCount: activitiesManager.activities.count)
        }
        .sheet(isPresented: $showExportSheet) {
            ExportView(dataManager: dataManager, activitiesManager: activitiesManager)
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView(activitiesManager: activitiesManager, dataManager: dataManager)
        }
        .fullScreenCover(isPresented: $showExpandedGrid) {
            ExpandedYearGridView(
                dataManager: dataManager,
                selectedDate: selectedDate,
                activities: activitiesManager.activities,
                isPresented: $showExpandedGrid
            )
        }
    }
}

struct ExportView: View {
    @ObservedObject var dataManager: LocalDataManager
    @ObservedObject var activitiesManager: ActivitiesManager
    @Environment(\.dismiss) var dismiss
    @State private var showShareSheet = false
    @State private var fileURL: URL?
    @StateObject private var sheetsExporter = GoogleSheetsExporter()
    @State private var spreadsheetId: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var createdSheetUrl: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Export Your Data")
                        .font(.title)
                        .padding()

                    // CSV Export Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("CSV Export")
                            .font(.headline)
                            .padding(.horizontal)

                        Button(action: {
                            exportToFile()
                        }) {
                            HStack {
                                Image(systemName: "doc.text")
                                Text("Export to CSV")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)

                        Text("Plain text file - no colors")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }

                    Divider()
                        .padding(.vertical)

                    // Google Sheets Export Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Google Sheets Export (with Colors!)")
                            .font(.headline)
                            .padding(.horizontal)

                        if !sheetsExporter.isSignedIn {
                            Button(action: {
                                sheetsExporter.signIn { success in
                                    if !success {
                                        alertMessage = "Failed to sign in to Google"
                                        showAlert = true
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "person.circle")
                                    Text("Sign in with Google")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .padding(.horizontal)
                        } else {
                            // Create new spreadsheet
                            Button(action: {
                                sheetsExporter.createNewSpreadsheet { success, id in
                                    if success, let spreadsheetId = id {
                                        // Now export to the newly created sheet
                                        sheetsExporter.exportToGoogleSheets(dataManager: dataManager, activitiesManager: activitiesManager, spreadsheetId: spreadsheetId) { exportSuccess, message in
                                            if exportSuccess {
                                                createdSheetUrl = sheetsExporter.getSpreadsheetUrl(id: spreadsheetId)
                                                alertMessage = "Created and exported!\n\nOpen in Google Sheets?"
                                                showAlert = true
                                            } else {
                                                alertMessage = message
                                                showAlert = true
                                            }
                                        }
                                    } else {
                                        alertMessage = "Failed to create spreadsheet"
                                        showAlert = true
                                    }
                                }
                            }) {
                                HStack {
                                    if sheetsExporter.isExporting {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .padding(.trailing, 5)
                                    }
                                    Image(systemName: "plus.circle")
                                    Text(sheetsExporter.isExporting ? sheetsExporter.exportStatus : "Create New Sheet")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(sheetsExporter.isExporting ? Color.gray : Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(sheetsExporter.isExporting)
                            .padding(.horizontal)

                            Text("or")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)

                            // Export to existing spreadsheet
                            VStack(spacing: 10) {
                                TextField("Paste Google Sheets URL or ID", text: $spreadsheetId)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .autocapitalization(.none)
                                    .padding(.horizontal)

                                if let savedId = sheetsExporter.savedSpreadsheetId, spreadsheetId.isEmpty {
                                    Button(action: {
                                        spreadsheetId = savedId
                                    }) {
                                        Text("Use last sheet: \(savedId.prefix(10))...")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }

                                Button(action: {
                                    let extractedId = extractSpreadsheetId(from: spreadsheetId)
                                    sheetsExporter.exportToGoogleSheets(dataManager: dataManager, activitiesManager: activitiesManager, spreadsheetId: extractedId) { success, message in
                                        alertMessage = message
                                        showAlert = true
                                        if success {
                                            createdSheetUrl = sheetsExporter.getSpreadsheetUrl(id: extractedId)
                                        }
                                    }
                                }) {
                                    HStack {
                                        if sheetsExporter.isExporting {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .padding(.trailing, 5)
                                        }
                                        Image(systemName: "arrow.up.doc")
                                        Text(sheetsExporter.isExporting ? sheetsExporter.exportStatus : "Export to This Sheet")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(spreadsheetId.isEmpty || sheetsExporter.isExporting ? Color.gray : Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                .disabled(spreadsheetId.isEmpty || sheetsExporter.isExporting)
                                .padding(.horizontal)
                            }

                            Text("Exports all days of the year with colored streaks!")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                    }

                    Spacer()
                }
            }
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = fileURL {
                ShareSheet(items: [url])
            }
        }
        .alert(alertMessage, isPresented: $showAlert) {
            if let url = createdSheetUrl {
                Button("Open Sheet") {
                    if let sheetURL = URL(string: url) {
                        UIApplication.shared.open(sheetURL)
                    }
                    createdSheetUrl = nil
                }
                Button("OK", role: .cancel) {
                    createdSheetUrl = nil
                }
            } else {
                Button("OK", role: .cancel) { }
            }
        }
    }

    private func exportToFile() {
        let csvString = dataManager.exportToCSV(activities: activitiesManager.activities)

        // Create a temporary file
        let fileName = "colorjournal_export_\(Date().timeIntervalSince1970).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            fileURL = tempURL
            showShareSheet = true
        } catch {
            print("Error writing CSV file: \(error)")
        }
    }

    private func extractSpreadsheetId(from input: String) -> String {
        // Handle full URL: https://docs.google.com/spreadsheets/d/SPREADSHEET_ID/edit...
        if input.contains("docs.google.com/spreadsheets") {
            let components = input.components(separatedBy: "/")
            if let dIndex = components.firstIndex(of: "d"), dIndex + 1 < components.count {
                return components[dIndex + 1]
            }
        }
        // Otherwise assume it's just the ID
        return input.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct SettingsView: View {
    @ObservedObject var activitiesManager: ActivitiesManager
    @ObservedObject var dataManager: LocalDataManager
    @Environment(\.dismiss) var dismiss
    @State private var editingActivity: Activity?
    @State private var showingEditSheet = false
    @State private var showingClearDataAlert = false

    var body: some View {
        NavigationView {
            List {
                ForEach(activitiesManager.activities) { activity in
                    HStack {
                        Circle()
                            .fill(activity.color)
                            .frame(width: 30, height: 30)

                        Text(activity.name)

                        Spacer()

                        Button(action: {
                            editingActivity = activity
                            showingEditSheet = true
                        }) {
                            Image(systemName: "pencil")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(BorderlessButtonStyle())

                        Button(action: {
                            if let index = activitiesManager.activities.firstIndex(where: { $0.id == activity.id }) {
                                activitiesManager.deleteActivity(at: index)
                            }
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                .onDelete { indexSet in
                    indexSet.sorted(by: >).forEach { activitiesManager.deleteActivity(at: $0) }
                }
                .onMove { from, to in
                    // Remap streak data indices before moving activities
                    dataManager.remapIndices(from: from, to: to, totalCount: activitiesManager.activities.count)
                    activitiesManager.moveActivity(from: from, to: to)
                    // Refresh year data to reflect the new order
                    dataManager.fetchYearData(activitiesCount: activitiesManager.activities.count)
                }

                Button(action: {
                    let newActivity = Activity(name: "New Activity", color: Color(red: 0.6, green: 0.6, blue: 0.6))
                    activitiesManager.addActivity(newActivity)

                    // Delay to ensure the activity is added and view is updated
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        editingActivity = newActivity
                        showingEditSheet = true
                    }
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Activity")
                    }
                }

                Section {
                    Button(action: {
                        showingClearDataAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                            Text("Clear All Data")
                                .foregroundColor(.red)
                        }
                    }
                } header: {
                    Text("Data Management")
                } footer: {
                    Text("This will permanently delete all your activity tracking data. Your custom activities list will be preserved.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(
                leading: EditButton(),
                trailing: Button("Done") {
                    dismiss()
                }
            )
        }
        .alert("Clear All Data?", isPresented: $showingClearDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All Data", role: .destructive) {
                dataManager.clearAllData()
            }
        } message: {
            Text("This will permanently delete all your activity tracking data. This cannot be undone.")
        }
        .sheet(isPresented: $showingEditSheet) {
            if let activity = editingActivity {
                ActivityEditView(
                    activitiesManager: activitiesManager,
                    activity: activity
                )
            }
        }
    }
}

struct ActivityEditView: View {
    @ObservedObject var activitiesManager: ActivitiesManager
    @State var activity: Activity
    @Environment(\.dismiss) var dismiss

    let availableColors: [(name: String, color: Color)] = [
        ("Red", Color(red: 1.0, green: 0.2, blue: 0.2)),
        ("Orange", Color(red: 1.0, green: 0.6, blue: 0.0)),
        ("Yellow", Color(red: 1.0, green: 0.9, blue: 0.0)),
        ("Green", Color(red: 0.2, green: 0.8, blue: 0.2)),
        ("Mint", Color(red: 0.6, green: 0.95, blue: 0.8)),
        ("Teal", Color(red: 0.2, green: 0.7, blue: 0.7)),
        ("Cyan", Color(red: 0.2, green: 0.8, blue: 1.0)),
        ("Blue", Color(red: 0.2, green: 0.4, blue: 1.0)),
        ("Indigo", Color(red: 0.3, green: 0.2, blue: 0.8)),
        ("Purple", Color(red: 0.7, green: 0.3, blue: 0.9)),
        ("Pink", Color(red: 1.0, green: 0.4, blue: 0.7)),
        ("Brown", Color(red: 0.6, green: 0.4, blue: 0.2)),
        ("Gray", Color(red: 0.6, green: 0.6, blue: 0.6))
    ]

    var body: some View {
        NavigationView {
            Form {
                Section("Activity Name") {
                    TextField("Name", text: $activity.name)
                }

                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 15) {
                        ForEach(availableColors, id: \.name) { colorOption in
                            Circle()
                                .fill(colorOption.color)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Circle()
                                        .stroke(activity.colorHex == colorOption.color.toHex() ? Color.white : Color.clear, lineWidth: 3)
                                )
                                .onTapGesture {
                                    activity.colorHex = colorOption.color.toHex()
                                }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Edit Activity")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    if let index = activitiesManager.activities.firstIndex(where: { $0.id == activity.id }) {
                        activitiesManager.updateActivity(
                            at: index,
                            name: activity.name,
                            color: Color(hex: activity.colorHex)
                        )
                    }
                    dismiss()
                }
            )
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
    }
}
