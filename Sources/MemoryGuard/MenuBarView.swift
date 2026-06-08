import SwiftUI
import ServiceManagement

struct MenuBarView: View {
    @EnvironmentObject var monitor: MemoryMonitor
    @State private var showTerminationSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()
            memoryStats
            pressureBar
            Divider()
            topAppsSection
            Divider()
            limitSetting
            Divider()
            actionButtons
        }
        .padding(14)
        .frame(width: 290)
        .onAppear {
            monitor.fetchTopApps()
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "shield.fill")
                .foregroundColor(.blue)
                .font(.title3)
            Text("MemoryGuard")
                .font(.headline)
            Spacer()
            Text(levelLabel)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(pressureColor.opacity(0.85), in: Capsule())
        }
    }

    private var levelLabel: String {
        switch monitor.currentLevel {
        case .normal:   return "정상"
        case .warning:  return "주의"
        case .critical: return "위험"
        }
    }

    private var memoryStats: some View {
        VStack(spacing: 4) {
            statRow(
                label: "사용 중",
                value: String(format: "%.2f GB", monitor.usedMemoryGB),
                color: pressureColor
            )
            statRow(
                label: "전체",
                value: String(format: "%.0f GB", monitor.totalMemoryGB),
                color: .secondary
            )
        }
    }

    private var pressureBar: some View {
        VStack(alignment: .leading, spacing: 3) {
            ProgressView(value: min(monitor.memoryPressure, 1.0))
                .tint(pressureColor)
            Text(String(format: "메모리 사용률 %.0f%%", monitor.memoryPressure * 100))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var topAppsSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("메모리 TOP 10")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    monitor.fetchTopApps()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }

            if monitor.topApps.isEmpty {
                Text("불러오는 중...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                let maxMem = monitor.topApps.first?.memoryMB ?? 1
                ForEach(Array(monitor.topApps.enumerated()), id: \.element.id) { index, app in
                    HStack(spacing: 5) {
                        Text("\(index + 1)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 14, alignment: .trailing)

                        Text(app.name)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.secondary.opacity(0.15))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(memColor(app.memoryMB))
                                .frame(width: 44 * CGFloat(app.memoryMB / maxMem))
                        }
                        .frame(width: 44, height: 7)

                        Text(formatMem(app.memoryMB))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(memColor(app.memoryMB))
                            .frame(width: 52, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func memColor(_ mb: Double) -> Color {
        switch mb {
        case 0..<500:  return .green
        case 500..<1500: return .yellow
        default:       return .orange
        }
    }

    private func formatMem(_ mb: Double) -> String {
        mb >= 1024
            ? String(format: "%.1f GB", mb / 1024)
            : String(format: "%.0f MB", mb)
    }

    private var limitSetting: some View {
        MemoryThresholdSlider(
            totalGB:    monitor.totalMemoryGB,
            usedGB:     monitor.usedMemoryGB,
            warningGB:  Binding(get: { monitor.warningGB  }, set: { monitor.warningGB  = $0 }),
            criticalGB: Binding(get: { monitor.criticalGB }, set: { monitor.criticalGB = $0 })
        )
    }

    private var actionButtons: some View {
        VStack(spacing: 2) {
            Button {
                NotificationManager.shared.runPurge()
                monitor.updateStats()
            } label: {
                Label("메모리 캐시 정리", systemImage: "trash.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 3)

            Divider()

            Button {
                showTerminationSettings = true
            } label: {
                Label("앱 종료 키워드 설정", systemImage: "keyboard")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 3)
            .sheet(isPresented: $showTerminationSettings) {
                TerminationSettingsView()
            }

            Divider()

            Toggle(isOn: Binding(
                get: { isLoginItemEnabled },
                set: { _ in toggleLoginItem() }
            )) {
                Label("로그인 시 자동 실행", systemImage: "clock.arrow.circlepath")
            }
            .toggleStyle(.switch)
            .padding(.vertical, 3)

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("MemoryGuard 종료", systemImage: "xmark.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 3)
        }
    }

    private var isLoginItemEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    private func toggleLoginItem() {
        do {
            if isLoginItemEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            print("Login item error: \(error)")
        }
    }

    private var pressureColor: Color {
        switch monitor.currentLevel {
        case .normal:   return .green
        case .warning:  return .yellow
        case .critical: return .red
        }
    }

    private func statRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}
