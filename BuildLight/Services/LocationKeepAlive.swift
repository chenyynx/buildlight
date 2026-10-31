import CoreLocation
import Foundation
import Observation

/// 定位保活腿（对应 OpenMinis `BackgroundKeepAliveManager` 的 location 分支）。
///
/// **为什么需要第二条腿**：静音音频只是「让系统认为你在工作」，
/// 一旦被来电、其他播放器抢占（`AVAudioSession` interruption），
/// 音频引擎会被系统停掉，进程照样挂起。
/// 定位更新是另一条独立的保活通道——只要还在持续定位，
/// 系统就不断定这个 App 仍然活跃。
///
/// 精度取 3 公里、5 秒一次：只要「有位置回调」这个事实，
/// 不追求精度，耗电和隐私影响都压到最低。
@MainActor
@Observable
final class LocationKeepAlive: NSObject, CLLocationManagerDelegate {
    static let shared = LocationKeepAlive()

    private(set) var isRunning = false
    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    /// 最近一次收到位置回调的时间，用来证明这条腿真的活着。
    private(set) var lastUpdateAt: Date?

    @ObservationIgnored private var manager: CLLocationManager?
    /// iOS 17+ 的后台活动会话：比纯 allowsBackgroundLocationUpdates 更省电、
    /// 且不会在灵动岛常驻定位指示。
    @ObservationIgnored private var activitySession: CLBackgroundActivitySession?
    @ObservationIgnored private var refreshTimer: Timer?
    @ObservationIgnored private var didConfigure = false

    private let refreshInterval: TimeInterval = 5

    /// 渲染/诊断读取的可用性。
    var isAuthorized: Bool {
        authorization == .authorizedAlways || authorization == .authorizedWhenInUse
    }

    /// 用户是否关了这条腿。
    nonisolated static let storageKey = "locationKeepAliveEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: storageKey) as? Bool ?? false
    }

    /// 只建对象、不做定位 IPC。必须在 Scene 建立之后调用。
    func configure() {
        guard !didConfigure else { return }
        didConfigure = true

        let manager = CLLocationManager()
        manager.delegate = self
        // 3 公里精度：只要能持续收到回调，不需要准确位置。
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        manager.pausesLocationUpdatesAutomatically = false
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = false

        self.manager = manager
        authorization = manager.authorizationStatus
    }

    /// 请求「使用期间」授权就够：配合 location 后台模式即可在后台继续收回调。
    func requestAuthorization() {
        configure()
        guard authorization == .notDetermined else { return }
        manager?.requestWhenInUseAuthorization()
    }

    func start() {
        guard Self.isEnabled else { return }
        configure()
        guard isAuthorized, !isRunning else { return }

        if #available(iOS 17.0, *) {
            activitySession = CLBackgroundActivitySession()
        }

        manager?.startUpdatingLocation()
        // 主动要一次，让系统立刻建立定位管道，而不是等自然变化。
        manager?.requestLocation()

        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: refreshInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.manager?.requestLocation()
            }
        }
        RunLoop.current.add(refreshTimer!, forMode: .common)

        isRunning = true
    }

    func stop() {
        guard isRunning || manager != nil else { return }

        refreshTimer?.invalidate()
        refreshTimer = nil
        manager?.stopUpdatingLocation()

        if #available(iOS 17.0, *) {
            activitySession?.invalidate()
            activitySession = nil
        }
        isRunning = false
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            // 授权刚下来且本应在跑 → 补启动。
            if self.isAuthorized, BackgroundKeepAlive.shared.isKeepingAlive, !self.isRunning {
                self.start()
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        Task { @MainActor in
            self.lastUpdateAt = .now
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        // 定位失败不致命，音频腿还在；这里只记录，不打断。
    }
}
