import SwiftUI

private enum ActiveHandle { case warning, critical }

struct MemoryThresholdSlider: View {
    let totalGB: Double
    let usedGB: Double
    @Binding var warningGB: Double
    @Binding var criticalGB: Double

    @State private var activeHandle: ActiveHandle? = nil

    private let trackHeight: CGFloat = 10
    private let handleSize:  CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("알림 수준 드래그로 설정")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            GeometryReader { geo in
                let w       = geo.size.width
                let warnX   = xPos(warningGB,  width: w)
                let critX   = xPos(criticalGB, width: w)
                let usedX   = xPos(min(usedGB, totalGB), width: w)

                ZStack(alignment: .leading) {
                    track(warnX: warnX, critX: critX, width: w)
                    usageFill(usedX: usedX)
                    handleCircle(color: .yellow, emoji: "⚠️", x: warnX, active: activeHandle == .warning)
                    handleCircle(color: .red,    emoji: "🚨", x: critX, active: activeHandle == .critical)
                }
                .frame(height: handleSize)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let x = max(0, min(value.location.x, w))

                            if activeHandle == nil {
                                activeHandle = abs(x - warnX) <= abs(x - critX) ? .warning : .critical
                            }

                            let gb = snapped(Double(x / w) * totalGB)
                            switch activeHandle {
                            case .warning:
                                warningGB  = max(1, min(gb, criticalGB - 1))
                            case .critical:
                                criticalGB = max(warningGB + 1, min(gb, totalGB))
                            case nil: break
                            }
                        }
                        .onEnded { _ in activeHandle = nil }
                )
            }
            .frame(height: handleSize)

            // 현재 설정값 레이블 (드래그 중 실시간 반영)
            HStack {
                Image(systemName: "exclamationmark.circle.fill").foregroundColor(.yellow)
                Text(String(format: "주의  %.1f GB", warningGB))
                Spacer()
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                Text(String(format: "위험  %.1f GB", criticalGB))
            }
            .font(.caption2)
            .fontWeight(.medium)
            .animation(.none, value: warningGB)
            .animation(.none, value: criticalGB)

            // 눈금
            HStack {
                Text("0 GB")
                Spacer()
                Text(String(format: "%.0f GB", totalGB))
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func track(warnX: CGFloat, critX: CGFloat, width: CGFloat) -> some View {
        let yOff = (handleSize - trackHeight) / 2

        ZStack(alignment: .leading) {
            Rectangle().fill(Color.secondary.opacity(0.1)).frame(width: width)
            Rectangle().fill(Color.green.opacity(0.2)).frame(width: warnX)
            Rectangle().fill(Color.yellow.opacity(0.2))
                .frame(width: max(0, critX - warnX))
                .offset(x: warnX)
            Rectangle().fill(Color.red.opacity(0.15))
                .frame(width: max(0, width - critX))
                .offset(x: critX)
        }
        .frame(height: trackHeight)
        .clipShape(Capsule())
        .offset(y: yOff)
    }

    @ViewBuilder
    private func usageFill(usedX: CGFloat) -> some View {
        let yOff  = (handleSize - trackHeight) / 2
        let color: Color = usedGB >= criticalGB ? .red : usedGB >= warningGB ? .yellow : .green

        Capsule()
            .fill(color.opacity(0.55))
            .frame(width: max(usedX, 2), height: trackHeight)
            .offset(y: yOff)
    }

    private func handleCircle(color: Color, emoji: String, x: CGFloat, active: Bool) -> some View {
        ZStack {
            Circle()
                .fill(color)
                .shadow(color: color.opacity(0.45), radius: active ? 5 : 2)
            Text(emoji).font(.system(size: 10))
        }
        .frame(width: handleSize, height: handleSize)
        .scaleEffect(active ? 1.18 : 1.0)
        .animation(.spring(response: 0.18, dampingFraction: 0.6), value: active)
        .offset(x: x - handleSize / 2)
    }

    // MARK: - Helpers

    private func xPos(_ gb: Double, width: CGFloat) -> CGFloat {
        guard totalGB > 0 else { return 0 }
        return CGFloat(gb / totalGB) * width
    }

    private func snapped(_ value: Double) -> Double {
        (value * 2).rounded() / 2   // 0.5 GB 단위 스냅
    }
}
