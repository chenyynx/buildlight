import AVFoundation
import Foundation
import UIKit

/// 静音音频保活。
///
/// **为什么需要它**：iOS 在 App 进入后台约 30 秒后就会挂起进程，
/// `beginBackgroundTask` 只能撑那么久。进程一挂起，轮询就停，
/// 构建结束时没人发现，也就没有通知——这正是「挂在后台收不到通知」的根因。
///
/// **做法**（照搬 OpenMinis `BackgroundKeepAliveManager` 的音频腿）：
/// 用一个 `AVAudioEngine` 循环播放 1 秒静音 buffer，
/// 音频会话声明 `.playback` + `.mixWithOthers`，
/// 并在 Info.plist 里声明 `UIBackgroundModes: audio`。
/// 系统认定这个 App 在做音频播放，就不会挂起它。
///
/// 只在对的时候开：有构建在跑、且 App 在后台。
/// 没有任务时立刻停，不白耗电。
@MainActor
final class BackgroundKeepAlive {
    static let shared = BackgroundKeepAlive()

    /// 现在是否正在保活（供设置页诊断）。
    private(set) var isKeepingAlive = false
    /// 保活启动时间，用于展示「已持续多久」。
    private(set) var startedAt: Date?

    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var interruptionObserver: NSObjectProtocol?
    private var activationRetries = 0

    /// 音频会话被别的 App 抢占（来电、播放器）后最多重试几次。
    private let maxActivationRetries = 3

    private init() {
        // 只把原始数值带进 Task。Notification 本身不是 Sendable，
        // 直接跨隔离域传会在 Swift 6 下报错。
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt else {
                return
            }
            Task { @MainActor in
                BackgroundKeepAlive.shared.handleInterruption(rawValue: raw)
            }
        }
    }

    // MARK: 对外

    func start(reason: String) {
        guard !isKeepingAlive else { return }
        guard Self.isEnabled else { return }

        do {
            try configureSession()
        } catch {
            // 会话配不上就别硬来，退回普通后台窗口。
            return
        }

        guard startEngine(reason: reason) else { return }
        isKeepingAlive = true
        startedAt = .now
    }

    func stop() {
        guard isKeepingAlive || engine != nil else { return }

        engine?.stop()
        player?.stop()
        engine = nil
        player = nil
        isKeepingAlive = false
        startedAt = nil
        activationRetries = 0

        // 让出音频焦点，别人的音乐能正常恢复音量。
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    /// 保活期间引擎被系统悄悄停掉时，从后台回到前台能自检出来。
    func verifyStillRunning() {
        guard isKeepingAlive else { return }
        guard engine?.isRunning != true else { return }
        engine = nil
        player = nil
        isKeepingAlive = false
        start(reason: "reclaim")
    }

    // MARK: 设置

    nonisolated static let storageKey = "backgroundKeepAliveEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: storageKey) as? Bool ?? true
    }

    // MARK: 内部

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        // .mixWithOthers：不打断用户正在听的音乐，只是混进去一条听不见的静音。
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
    }

    @discardableResult
    private func startEngine(reason: String) -> Bool {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        let sampleRate: Double = 44_100
        let frameCount = AVAudioFrameCount(sampleRate) // 1 秒
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        ), let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return false
        }

        buffer.frameLength = frameCount
        // buffer 本身是零填充的，即静音。

        engine.connect(player, to: engine.mainMixerNode, format: format)
        // 音量压到几乎为零：能证明「在播放」，又听不见。
        engine.mainMixerNode.outputVolume = 0.001

        do {
            try engine.start()
            player.scheduleBuffer(buffer, at: nil, options: .loops)
            player.play()
        } catch {
            return false
        }

        self.engine = engine
        self.player = player
        activationRetries = 0
        return true
    }

    private func handleInterruption(rawValue: UInt) {
        guard isKeepingAlive else { return }
        guard let type = AVAudioSession.InterruptionType(rawValue: rawValue) else { return }

        switch type {
        case .began:
            // 被抢占：引擎已经停了，等结束后重启。
            engine?.stop()
            engine = nil
            player = nil
            isKeepingAlive = false

        case .ended:
            guard activationRetries < maxActivationRetries else { return }
            activationRetries += 1
            start(reason: "interruptionEnded")

        @unknown default:
            break
        }
    }
}
