import SwiftUI

// Configuration struct
struct AppConfig {
    static let colors: [(name: String, color: Color)] = [
        ("Exercise 🏋️‍♂️", .red),
        ("Stretch 🤸‍♀️", .mint),
        ("Food 🥦", .green),
        ("Create 🛠️", .blue),
        ("Work 💻", .teal),
        ("Read 📚", .yellow),
        ("Journal ✍️", .purple),
        ("Meditate 🧘", .orange),
        ("Music 🎵", .indigo),
        ("Chores 🧹", .pink),
        ("Sleep 💤", .cyan),
        ("Leafless 🌿", .gray),
        ("Sick 🤒", .brown)
    ]
}

struct YearGridView: View {
    let yearData: [Int: [Bool]]  // Day number -> array of activity statuses
    let selectedDate: Date
    let colors: [(name: String, color: Color)]

    private func getDayOfYear(_ date: Date) -> Int {
        let calendar = Calendar.current
        let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: date))!
        return calendar.dateComponents([.day], from: startOfYear, to: date).day! + 1
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(1...365, id: \.self) { day in
                        VStack(spacing: 1) {
                            ForEach(colors.indices, id: \.self) { index in
                                let isColored = yearData[day]?[index] ?? false
                                Rectangle()
                                    .fill(isColored ? colors[index].color : Color.black)
                                    .frame(width: 3, height: 3)
                            }
                        }
                        .overlay(
                            Rectangle()
                                .stroke(day == getDayOfYear(selectedDate) ? Color.white : Color.clear, lineWidth: 1)
                        )
                        .id(day)
                    }
                }
                .padding(.vertical)
            }
            .frame(height: 50)
            .onAppear {
                // Scroll to current day, centered
                let currentDay = getDayOfYear(Date())
                proxy.scrollTo(currentDay, anchor: .center)
            }
            .onChange(of: selectedDate) { oldValue, newValue in
                // Scroll to selected day when date changes
                let selectedDay = getDayOfYear(newValue)
                withAnimation {
                    proxy.scrollTo(selectedDay, anchor: .center)
                }
            }
        }
    }
}


class LocalDataManager: ObservableObject {
    @Published var cellStatuses: [Int: Bool] = [:] // Track colored status for each row
    @Published var yearData: [Int: [Bool]] = [:] // Day -> Array of activity statuses

    private let defaults = UserDefaults.standard
    private let dataKey = "activityData"

    // Data structure: [dateString: [activityIndex: true/false]]
    private var allData: [String: [Int: Bool]] = [:]

    init() {
        loadData()
        fetchYearData()
    }

    private func dateKey(from date: Date) -> String {
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

    func fetchYearData() {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        var newYearData: [Int: [Bool]] = [:]

        // Build year data from stored data
        for day in 1...365 {
            var dateComponents = DateComponents()
            dateComponents.year = year
            dateComponents.day = day

            if let date = calendar.date(from: dateComponents) {
                let key = dateKey(from: date)
                let dayActivities = allData[key] ?? [:]

                var activitiesArray = Array(repeating: false, count: AppConfig.colors.count)
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

    func fetchCellStatus(date: Date) {
        let key = dateKey(from: date)
        let dayData = allData[key] ?? [:]

        DispatchQueue.main.async {
            self.cellStatuses.removeAll()
            for index in 0..<AppConfig.colors.count {
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
    func exportToCSV() -> String {
        var csv = "Date," + AppConfig.colors.map { $0.name }.joined(separator: ",") + "\n"

        let sortedDates = allData.keys.sorted()
        for dateString in sortedDates {
            let dayData = allData[dateString] ?? [:]
            var row = [dateString]

            for index in 0..<AppConfig.colors.count {
                row.append(dayData[index] == true ? "✓" : "")
            }
            csv += row.joined(separator: ",") + "\n"
        }

        return csv
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
                LongPressGesture(minimumDuration: 0.5)
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
    let colors: [(name: String, color: Color)] = [
        ("Exercise 🏋️‍♂️", .red),
        ("Stretch 🤸‍♀️", .mint),
        ("Food 🥦", .green),
        ("Create 🛠️", .blue),
        ("Work 💻", .teal),
        ("Read 📚", .yellow),
        ("Journal ✍️", .purple),
        ("Meditate 🧘", .orange),
        ("Music 🎵", .indigo),
        ("Chores 🧹", .pink),
        ("Sleep 💤", .cyan),
        ("Leafless 🌿", .gray),
        ("Sick 🤒", .brown)
    ]
    
    @State private var selectedColor: Color = .red
    @State private var selectedDate = Date()
    @State private var showDatePicker = false
    @StateObject private var dataManager = LocalDataManager()

    @State private var animatingButtons: Set<String> = []
    @State private var particleButtons: Set<String> = []
    @State private var showExportSheet = false

    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    var body: some View {
        VStack {
            // Settings/Export button in top-right
            HStack {
                Spacer()
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
                            .frame(height: 20)

                        ForEach(colors.indices, id: \.self) { index in
                            let colorItem = colors[index]
                            HStack {
                                Button(action: {
                                    withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) {
                                        animatingButtons.insert(colorItem.name)
                                        particleButtons.insert(colorItem.name)
                                    }

                                    dataManager.updateCell(row: index, date: selectedDate, color: colorItem.color)
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        animatingButtons.remove(colorItem.name)
                                    }
                                }) {
                                    HStack {
                                        Text(colorItem.name)
                                            .foregroundColor(colorItem.name == "Read 📚" || colorItem.name == "Sleep 💤" ||
                                                colorItem.name == "Stretch 🤸‍♀️" ||
                                                colorItem.name == "Work 💻" ?
                                                .black : .white)
                                            .frame(maxWidth: .infinity)
                                    }
                                    .frame(height: 40)
                                    .frame(maxWidth: 250)
                                    .background(colorItem.color)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(SnapButtonStyle(
                                    color: colorItem.color,
                                    isAnimating: .init(
                                        get: { particleButtons.contains(colorItem.name) },
                                        set: { isAnimating in
                                            if !isAnimating {
                                                particleButtons.remove(colorItem.name)
                                            }
                                        }
                                    )
                                ))
                                .scaleEffect(animatingButtons.contains(colorItem.name) ? 1.05 : 1.0)
                                
                                // Add checkbox indicator
                                CheckmarkView(
                                    index: index,
                                    color: colorItem.color,
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
                             colors: colors)
                    .padding(.horizontal)
            
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

            Button(action: {
                showExportSheet = true
            }) {
                Text("Export Data")
                    .foregroundColor(.primary)
                    .padding()
            }
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            // Fetch cell statuses whenever date changes
            dataManager.fetchCellStatus(date: newValue)
        }
        .onAppear {
            dataManager.fetchCellStatus(date: selectedDate)
        }
        .sheet(isPresented: $showExportSheet) {
            ExportView(dataManager: dataManager)
        }
    }
}

struct ExportView: View {
    @ObservedObject var dataManager: LocalDataManager
    @Environment(\.dismiss) var dismiss
    @State private var showShareSheet = false
    @State private var csvData: String = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Export Your Data")
                    .font(.title)
                    .padding()

                Button(action: {
                    csvData = dataManager.exportToCSV()
                    showShareSheet = true
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

                Text("CSV files can be opened in Excel, Numbers, or imported into Google Sheets")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()
            }
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [csvData])
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
