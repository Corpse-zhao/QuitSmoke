import WidgetKit
import SwiftUI
import Foundation

private let groupID = "group.com.corpsezhao.quitsmoke"
private let DAY: Double = 86400

// MARK: - 数据

struct Snap {
    var quitAt: Double
    var cigsPerDay: Int
    var pricePerPack: Double
    var cigsPerPack: Int
    var todayCigs: Int

    static func load() -> Snap {
        guard let defaults = UserDefaults(suiteName: groupID),
              let data = defaults.data(forKey: "widgetState"),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return Snap(quitAt: Date().timeIntervalSince1970 * 1000,
                        cigsPerDay: 20, pricePerPack: 25, cigsPerPack: 20, todayCigs: 0)
        }
        return Snap(
            quitAt: obj["quitAt"] as? Double ?? Date().timeIntervalSince1970 * 1000,
            cigsPerDay: obj["cigsPerDay"] as? Int ?? 20,
            pricePerPack: obj["pricePerPack"] as? Double ?? 25,
            cigsPerPack: obj["cigsPerPack"] as? Int ?? 20,
            todayCigs: obj["todayCigs"] as? Int ?? 0
        )
    }

    var days: Int {
        let elapsed = (Date().timeIntervalSince1970 * 1000 - quitAt) / (DAY * 1000)
        return max(0, Int(floor(elapsed)))
    }

    var moneySaved: Double {
        Double(days) * Double(cigsPerDay) * pricePerPack / Double(max(1, cigsPerPack))
    }

    var cigsAvoided: Int { days * cigsPerDay }
}

// MARK: - 时间线

struct Entry: TimelineEntry {
    let date: Date
    let snap: Snap
}

struct Provider: TimelineProvider {

    func placeholder(in context: Context) -> Entry {
        Entry(date: Date(), snap: Snap.load())
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: Date(), snap: Snap.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let entry = Entry(date: Date(), snap: Snap.load())
        // 下一个零点过后刷新天数
        let nextMidnight = Calendar.current.startOfDay(for: Date()).addingTimeInterval(DAY + 60)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}

// MARK: - 界面

struct StreakView: View {
    var entry: Entry
    @Environment(\.widgetFamily) var family

    private var moneyText: String {
        let v = entry.snap.moneySaved
        return v >= 100 ? "¥" + String(Int(v)) : String(format: "¥%.1f", v)
    }

    var body: some View {
        let s = entry.snap
        ZStack {
            LinearGradient(colors: [Color(red: 0.07, green: 0.62, blue: 0.49),
                                    Color(red: 0.02, green: 0.29, blue: 0.23)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("🍃")
                        .font(.system(size: 11))
                    Text("无烟日记")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(s.days)")
                        .font(.system(size: family == .systemSmall ? 42 : 36, weight: .heavy))
                        .foregroundColor(.white)
                    Text("天")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                }
                Text(s.todayCigs > 0
                        ? "今天记了 \(s.todayCigs) 支 · 省下 \(moneyText)"
                        : "今天还是干净的 · 省下 \(moneyText)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                if family == .systemMedium {
                    Text("已少抽 \(s.cigsAvoided) 支，每一分钟都在变好")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(12)
        }
    }
}

// MARK: - 注册

struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuitSmokeStreak", provider: Provider()) { entry in
            StreakView(entry: entry)
        }
        .configurationDisplayName("戒烟天数")
        .description("在主屏幕随时看到你坚持了多少天、省下了多少钱。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct QuitSmokeWidgets: WidgetBundle {
    var body: some Widget {
        StreakWidget()
    }
}
