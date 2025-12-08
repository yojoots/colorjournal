import SwiftUI
import GoogleSignIn
import GoogleAPIClientForREST
import GTMSessionFetcher

// Configuration struct
struct GoogleConfig {
    static let spreadsheetId = "1DZKts9E4dQ51ShJbN_jxWCvi87QZK3UUgcKB8ch08LI"
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
                }
            }
            .padding(.vertical)
        }
        .frame(height: 50)
    }
}


class GoogleSheetsManager: ObservableObject {
    private var service: GTLRSheetsService?
    @Published var isSignedIn = false
    @Published var cellStatuses: [Int: Bool] = [:] // Track colored status for each row
    @Published var yearData: [Int: [Bool]] = [:] // Day -> Array of activity statuses
    
    init() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
            if let user = user {
                self?.setupSheetsService(user: user)
                self?.isSignedIn = true
                // Fetch initial status after successful sign-in restoration
                DispatchQueue.main.async {
                    self?.fetchCellStatus(date: Date())
                    self?.fetchYearData()
                }
            }
        }
    }
    
    private func setupSheetsService(user: GIDGoogleUser) {
        let service = GTLRSheetsService()
        service.authorizer = user.fetcherAuthorizer
        self.service = service
    }
    
    func signIn() {
        guard let presentingViewController = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController else { return }
        
        GIDSignIn.sharedInstance.signIn(
            withPresenting: presentingViewController,
            hint: nil,
            additionalScopes: ["https://www.googleapis.com/auth/spreadsheets"]
        ) { [weak self] result, error in
            if let user = result?.user {
                self?.setupSheetsService(user: user)
                self?.isSignedIn = true
                self?.fetchYearData() // Fetch year data after sign in
            }
        }
    }
    
    func fetchYearData() {
        let query = GTLRSheetsQuery_SpreadsheetsGet.query(
            withSpreadsheetId: GoogleConfig.spreadsheetId)
        
        // Get all columns for every day
        query.ranges = ["R2C2:R14C366"] // From Jan 1 (col 2) to Dec 31 (col 366)
        query.fields = "sheets.data.rowData.values.userEnteredFormat.backgroundColor"
        
        service?.executeQuery(query) { [weak self] (ticket, result, error) in
            DispatchQueue.main.async {
                var newYearData: [Int: [Bool]] = [:]
                
                if let sheet = (result as? GTLRSheets_Spreadsheet)?.sheets?.first,
                   let rowData = sheet.data?.first?.rowData {
                    // For each row (activity)
                    for (rowIndex, row) in rowData.enumerated() {
                        // For each column (day)
                        if let cells = row.values {
                            for (colIndex, cell) in cells.enumerated() {
                                let dayNumber = colIndex + 1
                                if newYearData[dayNumber] == nil {
                                    newYearData[dayNumber] = Array(repeating: false, count: GoogleConfig.colors.count)
                                }
                                
                                if let backgroundColor = cell.userEnteredFormat?.backgroundColor,
                                   (backgroundColor.red?.floatValue ?? 0 > 0 ||
                                    backgroundColor.green?.floatValue ?? 0 > 0 ||
                                    backgroundColor.blue?.floatValue ?? 0 > 0) {
                                    newYearData[dayNumber]?[rowIndex] = true
                                }
                            }
                        }
                    }
                }
                
                self?.yearData = newYearData
            }
        }
    }
    
    func fetchCellStatus(date: Date) {
        let calendar = Calendar.current
        let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: date))!
        let dayOfYear = calendar.dateComponents([.day], from: startOfYear, to: date).day! + 1
        
        // Add 1 to dayOfYear to account for label column
        let column = dayOfYear + 1
        
        // Instead of getting values first, directly get the formatting
        let query = GTLRSheetsQuery_SpreadsheetsGet.query(
            withSpreadsheetId: GoogleConfig.spreadsheetId)
        
        // Get the entire column for the day
        query.ranges = ["R2C\(column):R14C\(column)"]
        query.fields = "sheets.data.rowData.values.userEnteredFormat.backgroundColor"
        
        service?.executeQuery(query) { [weak self] (ticket, result, error) in
            DispatchQueue.main.async {
                // Reset current statuses
                self?.cellStatuses.removeAll()
                
                if let sheet = (result as? GTLRSheets_Spreadsheet)?.sheets?.first,
                   let rowData = sheet.data?.first?.rowData {
                    // Process each row
                    for (index, row) in rowData.enumerated() {
                        if let cell = row.values?.first,
                           let backgroundColor = cell.userEnteredFormat?.backgroundColor,
                           // Check if any color component is non-zero
                           (backgroundColor.red?.floatValue ?? 0 > 0 ||
                            backgroundColor.green?.floatValue ?? 0 > 0 ||
                            backgroundColor.blue?.floatValue ?? 0 > 0) {
                            self?.cellStatuses[index] = true
                        } else {
                            self?.cellStatuses[index] = false
                        }
                    }
                }
            }
        }
    }
    
    func updateCell(row: Int, date: Date, color: Color) {
        let calendar = Calendar.current
        let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: date))!
        let dayOfYear = calendar.dateComponents([.day], from: startOfYear, to: date).day! + 1
        
        // Column 1 is reserved for labels, and we're 0-based
        let col = dayOfYear
        
        let range = GTLRSheets_GridRange()
        // Add 1 to row to account for header row, and since we're 0-based
        range.startRowIndex = NSNumber(value: row + 1)
        range.endRowIndex = NSNumber(value: row + 2)
        range.startColumnIndex = NSNumber(value: col)
        range.endColumnIndex = NSNumber(value: col + 1)
        range.sheetId = NSNumber(value: 0)
        
        let cellFormat = GTLRSheets_CellFormat()
        let backgroundColor = GTLRSheets_Color()
        
        let uiColor = UIColor(hex: color.toHex())
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        backgroundColor.red = NSNumber(value: Float(red))
        backgroundColor.green = NSNumber(value: Float(green))
        backgroundColor.blue = NSNumber(value: Float(blue))
        
        cellFormat.backgroundColor = backgroundColor
        
        let request = GTLRSheets_Request()
        let repeatCell = GTLRSheets_RepeatCellRequest()
        repeatCell.range = range
        
        let cell = GTLRSheets_CellData()
        cell.userEnteredFormat = cellFormat
        repeatCell.cell = cell
        
        repeatCell.fields = "userEnteredFormat.backgroundColor"
        
        request.repeatCell = repeatCell
        
        let batchUpdate = GTLRSheets_BatchUpdateSpreadsheetRequest()
        batchUpdate.requests = [request]
        
        let query = GTLRSheetsQuery_SpreadsheetsBatchUpdate.query(
            withObject: batchUpdate,
            spreadsheetId: GoogleConfig.spreadsheetId)

        service?.executeQuery(query) { [weak self] (ticket, result, error) in
            DispatchQueue.main.async {
                if error == nil {
                    // Update both local states after successful update
                    self?.cellStatuses[row] = true
                    
                    // Update yearData for this day and activity
                    let calendar = Calendar.current
                    let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: date))!
                    let dayOfYear = calendar.dateComponents([.day], from: startOfYear, to: date).day! + 1
                    
                    // Create the array if it doesn't exist for this day
                    if self?.yearData[dayOfYear] == nil {
                        self?.yearData[dayOfYear] = Array(repeating: false, count: GoogleConfig.colors.count)
                    }
                    
                    // Update the specific activity for this day
                    self?.yearData[dayOfYear]?[row] = true
                }
            }
        }
    }
    
    func clearCell(row: Int, date: Date) {
        let calendar = Calendar.current
        let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: date))!
        let dayOfYear = calendar.dateComponents([.day], from: startOfYear, to: date).day! + 1
        
        // Column 1 is reserved for labels, and we're 0-based
        let col = dayOfYear
        
        let range = GTLRSheets_GridRange()
        // Add 1 to row to account for header row, and since we're 0-based
        range.startRowIndex = NSNumber(value: row + 1)
        range.endRowIndex = NSNumber(value: row + 2)
        range.startColumnIndex = NSNumber(value: col)
        range.endColumnIndex = NSNumber(value: col + 1)
        range.sheetId = NSNumber(value: 0)
        
        // Create a "clear formatting" request
        let request = GTLRSheets_Request()
        let repeatCell = GTLRSheets_RepeatCellRequest()
        repeatCell.range = range
        
        // Create an empty cell format (this effectively clears the formatting)
        let cell = GTLRSheets_CellData()
        let format = GTLRSheets_CellFormat()
        format.backgroundColor = nil
        cell.userEnteredFormat = format
        repeatCell.cell = cell
        
        // Specify we want to update the background color
        repeatCell.fields = "userEnteredFormat.backgroundColor"
        
        request.repeatCell = repeatCell
        
        let batchUpdate = GTLRSheets_BatchUpdateSpreadsheetRequest()
        batchUpdate.requests = [request]
        
        let query = GTLRSheetsQuery_SpreadsheetsBatchUpdate.query(
            withObject: batchUpdate,
            spreadsheetId: GoogleConfig.spreadsheetId)

        service?.executeQuery(query) { [weak self] (ticket, result, error) in
            DispatchQueue.main.async {
                if error == nil {
                    // Update both local states after successful clear
                    self?.cellStatuses[row] = false
                    
                    // Update yearData for this day and activity
                    if let yearData = self?.yearData[dayOfYear] {
                        self?.yearData[dayOfYear]?[row] = false
                    }
                }
            }
        }
    }
}

struct CheckmarkView: View {
    let index: Int
    let color: Color
    let isChecked: Bool
    let date: Date
    @ObservedObject var sheetsManager: GoogleSheetsManager
    @State private var isLongPressing = false
    
    var body: some View {
        Image(systemName: isChecked ? "checkmark.square.fill" : "square")
            .foregroundColor(color)
            .imageScale(.large)
            .padding(.leading, 8)
            .scaleEffect(isLongPressing ? 1.2 : 1.0)
            .onTapGesture {
                if !isChecked {
                    sheetsManager.updateCell(row: index, date: date, color: color)
                }
            }
            .gesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        if isChecked {
                            // Add haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            
                            sheetsManager.clearCell(row: index, date: date)
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
    @StateObject private var sheetsManager = GoogleSheetsManager()
    
    @State private var animatingButtons: Set<String> = []
    @State private var particleButtons: Set<String> = []
    @State private var isLoading = true

    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    var body: some View {
        VStack {
            if isLoading {
                // Show nothing while loading
                Color.clear
            } else if !sheetsManager.isSignedIn {
                Button("Sign in with Google") {
                    sheetsManager.signIn()
                }
                .padding()
            } else {
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
                                    
                                    sheetsManager.updateCell(row: index, date: selectedDate, color: colorItem.color)
                                    
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
                                    isChecked: sheetsManager.cellStatuses[index] == true,
                                    date: selectedDate,
                                    sheetsManager: sheetsManager
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                YearGridView(yearData: sheetsManager.yearData,
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
            }
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            // Fetch cell statuses whenever date changes
            sheetsManager.fetchCellStatus(date: newValue)
        }
        .onChange(of: sheetsManager.isSignedIn) { oldValue, newValue in
            if newValue {
                sheetsManager.fetchCellStatus(date: selectedDate)
            }
        }
        // Fetch initial status when view appears
        .onAppear {
            // Add a small delay before showing any UI
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.isLoading = false
            }

            if sheetsManager.isSignedIn {
                sheetsManager.fetchCellStatus(date: selectedDate)
                sheetsManager.fetchYearData()
            }
        }
    }
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
