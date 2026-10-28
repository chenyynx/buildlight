import Foundation

struct HistoryDayGroup: Identifiable {
    let day: Date
    let runs: [RunRecord]

    var id: Date { day }
}
