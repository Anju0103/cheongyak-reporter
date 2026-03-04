import SwiftUI
import UIKit
import UserNotifications

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }

    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = UIHostingController(rootView: CheongyakRootView())
    self.window = window
    window.makeKeyAndVisible()
  }
}

struct CheongyakRootView: View {
  @StateObject private var store = CheongyakStore()
  @State private var isShowingSettings = false

  var body: some View {
    NavigationStack {
      Group {
        if store.filteredItems.isEmpty {
          emptyState
        } else {
          List {
            summarySection
            filterSection

            Section("무순위/잔여세대 공고") {
              ForEach(store.filteredItems) { item in
                CheongyakRow(
                  item: item,
                  isNew: store.recentNewIDs.contains(item.id)
                )
              }
            }
          }
          .listStyle(.insetGrouped)
        }
      }
      .navigationTitle("청약 리포터")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            Task { await store.refresh(forceNotificationSync: true) }
          } label: {
            if store.isLoading {
              ProgressView()
            } else {
              Image(systemName: "arrow.clockwise")
            }
          }
          .disabled(store.isLoading)
        }

        ToolbarItem(placement: .topBarTrailing) {
          Button {
            isShowingSettings = true
          } label: {
            Image(systemName: "gearshape")
          }
        }
      }
      .sheet(isPresented: $isShowingSettings) {
        SettingsView(store: store)
      }
      .task {
        await store.bootstrap()
      }
      .refreshable {
        await store.refresh(forceNotificationSync: true)
      }
      .alert("동기화 오류", isPresented: .constant(store.errorMessage != nil)) {
        Button("확인") {
          store.clearError()
        }
      } message: {
        Text(store.errorMessage ?? "")
      }
    }
  }

  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: "doc.text.magnifyingglass")
        .font(.system(size: 42))
        .foregroundStyle(.secondary)
      Text("표시할 공고가 없습니다")
        .font(.headline)
      Text("설정에서 피드 URL을 등록한 뒤 새로고침하세요")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      filterSection
        .padding(.top, 8)
    }
    .padding(24)
  }

  private var summarySection: some View {
    Section("오늘 리포트") {
      LabeledContent("기준 시각") {
        Text(store.generatedAtText)
      }
      LabeledContent("전체 건수") {
        Text("\(store.filteredItems.count)건")
          .fontWeight(.semibold)
      }
      LabeledContent("신규 건수") {
        Text("\(store.recentNewIDs.count)건")
          .fontWeight(.semibold)
          .foregroundStyle(store.recentNewIDs.isEmpty ? Color.secondary : Color.blue)
      }
      if let lastSynced = store.lastSyncedText {
        LabeledContent("앱 동기화") {
          Text(lastSynced)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private var filterSection: some View {
    Section("지역 필터") {
      Toggle("서울", isOn: $store.includeSeoul)
      Toggle("경기", isOn: $store.includeGyeonggi)
    }
  }
}

struct CheongyakRow: View {
  let item: CheongyakItem
  let isNew: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top) {
        Text(item.title)
          .font(.headline)
        Spacer()
        if isNew {
          Text("NEW")
            .font(.caption2)
            .bold()
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.blue.opacity(0.15))
            .foregroundStyle(.blue)
            .clipShape(Capsule())
        }
      }

      Text("\(item.region) \(item.city)")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      HStack(spacing: 12) {
        Label(item.category, systemImage: "building.2")
        Label(item.announcementDate, systemImage: "calendar")
      }
      .font(.caption)
      .foregroundStyle(.secondary)

      if let periodText = item.applyPeriodText {
        Text("접수: \(periodText)")
          .font(.caption)
      }

      if let url = URL(string: item.url), !item.url.isEmpty {
        Link(destination: url) {
          Label("청약홈 공고 열기", systemImage: "link")
            .font(.caption)
        }
      }
    }
    .padding(.vertical, 4)
  }
}

struct SettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject var store: CheongyakStore

  var body: some View {
    NavigationStack {
      Form {
        Section("피드") {
          TextField("JSON 피드 URL", text: $store.feedURLString)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
          Text("예: https://.../feed.json")
            .font(.caption)
            .foregroundStyle(.secondary)
          Button("기본 URL 복원") {
            store.restoreDefaultFeedURL()
          }
        }

        Section("일일 알림") {
          Toggle("매일 알림 사용", isOn: $store.dailyNotificationEnabled)
          DatePicker("알림 시간", selection: $store.notificationTime, displayedComponents: .hourAndMinute)

          Button("알림 권한 요청") {
            store.requestNotificationPermission()
          }

          Button("테스트 알림 (5초 후)") {
            store.sendTestNotification()
          }
        }

        Section("주의") {
          Text("iOS 로컬 알림은 백그라운드 동기화가 제한될 수 있습니다. 안정적인 매일 리포트는 서버에서 피드를 매일 갱신하는 방식을 권장합니다.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
      .navigationTitle("설정")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("완료") {
            store.persistSettings()
            Task { await store.refresh(forceNotificationSync: true) }
            dismiss()
          }
        }
      }
    }
  }
}

@MainActor
final class CheongyakStore: ObservableObject {
  @Published var items: [CheongyakItem] = []
  @Published var recentNewIDs: Set<String> = []
  @Published var isLoading = false
  @Published var errorMessage: String?

  @Published var feedURLString: String = ""
  @Published var includeSeoul: Bool = true {
    didSet { persistSettings() }
  }
  @Published var includeGyeonggi: Bool = true {
    didSet { persistSettings() }
  }
  @Published var dailyNotificationEnabled: Bool = true {
    didSet {
      persistSettings()
      if dailyNotificationEnabled {
        syncDailyNotification()
      } else {
        removeDailyNotification()
      }
    }
  }
  @Published var notificationTime: Date = Calendar.current.date(from: DateComponents(hour: 8, minute: 30)) ?? Date() {
    didSet {
      persistSettings()
      syncDailyNotification()
    }
  }

  @Published private(set) var generatedAtText: String = "-"
  @Published private(set) var lastSyncedText: String?

  private let defaults = UserDefaults.standard
  private let bundledDefaultFeedURL = (
    Bundle.main.object(forInfoDictionaryKey: "CheongyakDefaultFeedURL") as? String
  )?.trimmingCharacters(in: .whitespacesAndNewlines)

  private enum Key {
    static let feedURL = "cheongyak.feedURL"
    static let includeSeoul = "cheongyak.includeSeoul"
    static let includeGyeonggi = "cheongyak.includeGyeonggi"
    static let dailyNotificationEnabled = "cheongyak.dailyNotificationEnabled"
    static let notificationHour = "cheongyak.notificationHour"
    static let notificationMinute = "cheongyak.notificationMinute"
    static let cachedFeed = "cheongyak.cachedFeed"
    static let knownIDs = "cheongyak.knownIDs"
    static let lastSynced = "cheongyak.lastSynced"
  }

  var filteredItems: [CheongyakItem] {
    items
      .filter { item in
        let region = item.region
        let isSeoul = region.contains("서울")
        let isGyeonggi = region.contains("경기")

        return (includeSeoul && isSeoul) || (includeGyeonggi && isGyeonggi)
      }
      .sorted(by: { $0.announcementDate > $1.announcementDate })
  }

  func bootstrap() async {
    loadSettings()
    loadCache()
    if items.isEmpty {
      await loadBundledSample()
    }
    await refresh(forceNotificationSync: false)
  }

  func refresh(forceNotificationSync: Bool) async {
    isLoading = true
    defer { isLoading = false }

    do {
      let feed = try await fetchFeed()
      apply(feed: feed)
      cache(feed: feed)
      lastSyncedText = DateText.display(Date())
      defaults.set(Date().timeIntervalSince1970, forKey: Key.lastSynced)
      if dailyNotificationEnabled || forceNotificationSync {
        syncDailyNotification()
      }
      return
    } catch {
      if items.isEmpty {
        await loadBundledSample()
      }
      errorMessage = "피드 동기화 실패: \(error.localizedDescription)"
    }
  }

  func clearError() {
    errorMessage = nil
  }

  func requestNotificationPermission() {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
  }

  func sendTestNotification() {
    let content = UNMutableNotificationContent()
    content.title = "청약 리포터 테스트"
    content.body = "서울/경기 무순위 공고 알림이 정상 동작합니다."
    content.sound = .default

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
    let request = UNNotificationRequest(identifier: "cheongyak-test", content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request)
  }

  func persistSettings() {
    defaults.set(feedURLString, forKey: Key.feedURL)
    defaults.set(includeSeoul, forKey: Key.includeSeoul)
    defaults.set(includeGyeonggi, forKey: Key.includeGyeonggi)
    defaults.set(dailyNotificationEnabled, forKey: Key.dailyNotificationEnabled)

    let time = Calendar.current.dateComponents([.hour, .minute], from: notificationTime)
    defaults.set(time.hour ?? 8, forKey: Key.notificationHour)
    defaults.set(time.minute ?? 30, forKey: Key.notificationMinute)
  }

  func restoreDefaultFeedURL() {
    feedURLString = bundledDefaultFeedURL ?? ""
    persistSettings()
  }

  private func loadSettings() {
    if let storedURL = defaults.string(forKey: Key.feedURL)?
      .trimmingCharacters(in: .whitespacesAndNewlines),
      !storedURL.isEmpty
    {
      feedURLString = storedURL
    } else if let bundledDefaultFeedURL, !bundledDefaultFeedURL.isEmpty {
      feedURLString = bundledDefaultFeedURL
    }

    if defaults.object(forKey: Key.includeSeoul) != nil {
      includeSeoul = defaults.bool(forKey: Key.includeSeoul)
    }
    if defaults.object(forKey: Key.includeGyeonggi) != nil {
      includeGyeonggi = defaults.bool(forKey: Key.includeGyeonggi)
    }
    if defaults.object(forKey: Key.dailyNotificationEnabled) != nil {
      dailyNotificationEnabled = defaults.bool(forKey: Key.dailyNotificationEnabled)
    }

    let hour = defaults.integer(forKey: Key.notificationHour)
    let minute = defaults.integer(forKey: Key.notificationMinute)
    if defaults.object(forKey: Key.notificationHour) != nil {
      notificationTime = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? notificationTime
    }

    if let lastSyncedEpoch = defaults.object(forKey: Key.lastSynced) as? TimeInterval {
      lastSyncedText = DateText.display(Date(timeIntervalSince1970: lastSyncedEpoch))
    }
  }

  private func fetchFeed() async throws -> FeedEnvelope {
    guard !feedURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw NSError(domain: "CheongyakStore", code: 1001, userInfo: [NSLocalizedDescriptionKey: "피드 URL이 비어 있습니다"])
    }

    guard let url = URL(string: feedURLString) else {
      throw NSError(domain: "CheongyakStore", code: 1002, userInfo: [NSLocalizedDescriptionKey: "피드 URL 형식이 올바르지 않습니다"])
    }

    let (data, response) = try await URLSession.shared.data(from: url)
    guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
      throw NSError(domain: "CheongyakStore", code: 1003, userInfo: [NSLocalizedDescriptionKey: "피드 응답이 비정상입니다"])
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    do {
      return try decoder.decode(FeedEnvelope.self, from: data)
    } catch {
      throw NSError(domain: "CheongyakStore", code: 1004, userInfo: [NSLocalizedDescriptionKey: "피드 JSON 파싱 실패"])
    }
  }

  private func apply(feed: FeedEnvelope) {
    let previousKnown = Set(defaults.stringArray(forKey: Key.knownIDs) ?? [])
    let nowIDs = Set(feed.items.map { $0.id })

    recentNewIDs = nowIDs.subtracting(previousKnown)
    defaults.set(Array(previousKnown.union(nowIDs)), forKey: Key.knownIDs)

    items = feed.items
    generatedAtText = feed.generatedAt.map(DateText.display) ?? "-"
  }

  private func cache(feed: FeedEnvelope) {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    if let data = try? encoder.encode(feed) {
      defaults.set(data, forKey: Key.cachedFeed)
    }
  }

  private func loadCache() {
    guard let data = defaults.data(forKey: Key.cachedFeed) else { return }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    if let cached = try? decoder.decode(FeedEnvelope.self, from: data) {
      items = cached.items
      generatedAtText = cached.generatedAt.map(DateText.display) ?? "-"
    }
  }

  private func loadBundledSample() async {
    guard let url = Bundle.main.url(forResource: "sample_feed", withExtension: "json"),
          let data = try? Data(contentsOf: url)
    else {
      return
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    if let sample = try? decoder.decode(FeedEnvelope.self, from: data) {
      apply(feed: sample)
      generatedAtText = "샘플 데이터"
    }
  }

  private func syncDailyNotification() {
    guard dailyNotificationEnabled else { return }

    let seoulCount = items.filter { $0.region.contains("서울") }.count
    let gyeonggiCount = items.filter { $0.region.contains("경기") }.count

    let content = UNMutableNotificationContent()
    content.title = "무순위 청약 일일 리포트"
    content.body = "서울 \(seoulCount)건, 경기 \(gyeonggiCount)건, 신규 \(recentNewIDs.count)건"
    content.sound = .default

    let time = Calendar.current.dateComponents([.hour, .minute], from: notificationTime)
    var triggerDate = DateComponents()
    triggerDate.hour = time.hour
    triggerDate.minute = time.minute

    let request = UNNotificationRequest(
      identifier: "cheongyak-daily-summary",
      content: content,
      trigger: UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: true)
    )

    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: ["cheongyak-daily-summary"])
    center.add(request)
  }

  private func removeDailyNotification() {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["cheongyak-daily-summary"])
  }
}

struct FeedEnvelope: Codable {
  let generatedAt: Date?
  let source: String?
  let items: [CheongyakItem]
}

struct CheongyakItem: Codable, Identifiable, Hashable {
  let id: String
  let region: String
  let city: String
  let title: String
  let category: String
  let announcementDate: String
  let applyStartDate: String?
  let applyEndDate: String?
  let source: String?
  let url: String

  var applyPeriodText: String? {
    let start = applyStartDate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let end = applyEndDate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    if start.isEmpty && end.isEmpty { return nil }
    if !start.isEmpty && !end.isEmpty {
      return "\(start) ~ \(end)"
    }
    return start.isEmpty ? end : start
  }
}

enum DateText {
  private static let formatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter
  }()

  static func display(_ date: Date) -> String {
    formatter.string(from: date)
  }
}
