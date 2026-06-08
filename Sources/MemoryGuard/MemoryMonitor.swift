import Foundation
import AppKit
import Darwin

enum AlertLevel {
    case normal, warning, critical
}

struct AppMemoryInfo: Identifiable {
    var id: String { name }  // 안정적 ID — 매 갱신마다 SwiftUI 재렌더 방지
    let name: String
    let memoryMB: Double
}

class MemoryMonitor: ObservableObject {
    // macOS 메모리 패널 체감값과 맞추기 위해 2진 단위로 환산한다.
    private let bytesPerGB: Double = 1_073_741_824
    private let bytesPerMB: Double = 1_048_576

    @Published var usedMemoryGB: Double = 0
    @Published var totalMemoryGB: Double = 0
    @Published var memoryPressure: Double = 0
    @Published var topApps: [AppMemoryInfo] = []
    @Published var currentLevel: AlertLevel = .normal

    @Published var warningGB: Double {
        didSet { UserDefaults.standard.set(warningGB, forKey: "warningGB") }
    }
    @Published var criticalGB: Double {
        didSet { UserDefaults.standard.set(criticalGB, forKey: "criticalGB") }
    }

    private var statsTimer: Timer?
    private var appLaunchObserver: NSObjectProtocol?
    private let bgQueue = DispatchQueue(label: "com.memoryguard.monitor", qos: .utility)

    private func currentSwapUsedGB() -> Double {
        var size = MemoryLayout<xsw_usage>.size
        var swapUsage = xsw_usage()
        let result = withUnsafeMutablePointer(to: &swapUsage) { ptr in
            ptr.withMemoryRebound(to: UInt8.self, capacity: size) { bytes in
                sysctlbyname("vm.swapusage", bytes, &size, nil, 0)
            }
        }
        guard result == 0 else { return 0 }
        return Double(swapUsage.xsu_used) / bytesPerGB
    }

    init() {
        let savedWarning  = UserDefaults.standard.double(forKey: "warningGB")
        let savedCritical = UserDefaults.standard.double(forKey: "criticalGB")
        warningGB  = savedWarning  == 0 ? 14.0 : savedWarning
        criticalGB = savedCritical == 0 ? 18.0 : savedCritical
        totalMemoryGB = Double(ProcessInfo.processInfo.physicalMemory) / bytesPerGB
        startMonitoring()
        watchAppLaunches()
    }

    func startMonitoring() {
        updateStats()
        // 5초 간격 — 3초 대비 CPU 웨이크업 40% 감소
        statsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
    }

    func updateStats() {
        bgQueue.async { [weak self] in
            guard let self else { return }

            // vm 통계 수집 (백그라운드)
            var vmStats = vm_statistics64_data_t()
            var infoCount = mach_msg_type_number_t(
                MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
            )
            let result = withUnsafeMutablePointer(to: &vmStats) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) {
                    host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &infoCount)
                }
            }
            guard result == KERN_SUCCESS else { return }

            let pageSize = Double(vm_page_size)
            // Activity Monitor의 "사용된 메모리"와 최대한 일치시키기 위해
            // Internal + Purgeable + Wired + Compressed 조합으로 계산한다.
            let usedPages = Double(
                vmStats.internal_page_count +
                vmStats.purgeable_count +
                vmStats.wire_count +
                vmStats.compressor_page_count
            )
            let ramUsed = usedPages * pageSize / self.bytesPerGB
            let swapUsed = self.currentSwapUsedGB()
            let used = ramUsed + swapUsed

            DispatchQueue.main.async {
                self.usedMemoryGB = used
                self.memoryPressure = used / self.totalMemoryGB
                if used >= self.criticalGB {
                    self.currentLevel = .critical
                } else if used >= self.warningGB {
                    self.currentLevel = .warning
                } else {
                    self.currentLevel = .normal
                }
            }
        }
    }

    func fetchTopApps() {
        bgQueue.async { [weak self] in
            guard let self else { return }

            // proc_pidinfo로 직접 조회 — ps 서브프로세스 불필요
            let pidToName: [Int32: String] = Dictionary(
                uniqueKeysWithValues: NSWorkspace.shared.runningApplications.compactMap { app -> (Int32, String)? in
                    guard let name = app.localizedName else { return nil }
                    return (app.processIdentifier, name)
                }
            )

            let pidCount = proc_listallpids(nil, 0)
            guard pidCount > 0 else { return }
            var pids = [Int32](repeating: 0, count: Int(pidCount))
            proc_listallpids(&pids, pidCount * Int32(MemoryLayout<Int32>.size))

            var memByName: [String: Double] = [:]

            for pid in pids where pid > 0 {
                var info = proc_taskinfo()
                let ret = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, Int32(MemoryLayout<proc_taskinfo>.size))
                guard ret > 0 else { continue }

                let memMB = Double(info.pti_resident_size) / self.bytesPerMB
                guard memMB > 0.5 else { continue }

                var nameBuffer = [CChar](repeating: 0, count: 256)
                proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
                let rawName = String(cString: nameBuffer)

                let name = pidToName[pid] ?? (rawName.isEmpty ? "PID \(pid)" : rawName)
                memByName[name, default: 0] += memMB
            }

            let top10 = memByName
                .map { AppMemoryInfo(name: $0.key, memoryMB: $0.value) }
                .sorted { $0.memoryMB > $1.memoryMB }
                .prefix(10)

            DispatchQueue.main.async {
                self.topApps = Array(top10)
            }
        }
    }

    private func watchAppLaunches() {
        appLaunchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: nil  // 백그라운드 큐에서 처리
        ) { [weak self] notification in
            guard let self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let appName = app.localizedName else { return }

            self.bgQueue.asyncAfter(deadline: .now() + 2.5) {
                self.updateStats()
                // updateStats는 비동기이므로 잠시 후 알림 판단
                self.bgQueue.asyncAfter(deadline: .now() + 0.2) {
                    let used = self.usedMemoryGB
                    DispatchQueue.main.async {
                        if used >= self.criticalGB {
                            NotificationManager.shared.sendWarning(appName: appName, usedGB: used, level: .critical)
                        } else if used >= self.warningGB {
                            NotificationManager.shared.sendWarning(appName: appName, usedGB: used, level: .warning)
                        }
                    }
                }
            }
        }
    }

    deinit {
        statsTimer?.invalidate()
        if let observer = appLaunchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}
