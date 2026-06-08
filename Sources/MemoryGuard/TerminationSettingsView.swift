import SwiftUI
import AppKit

struct InstalledApp: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    var icon: NSImage { NSWorkspace.shared.icon(forFile: url.path) }
}

struct AppPickerButton: View {
    @Binding var selected: InstalledApp?
    let apps: [InstalledApp]

    @State private var showPicker = false
    @State private var searchText = ""

    private var filtered: [InstalledApp] {
        searchText.isEmpty ? apps : apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        Button { showPicker.toggle() } label: {
            HStack(spacing: 4) {
                if let app = selected {
                    Image(nsImage: app.icon).resizable().frame(width: 14, height: 14)
                    Text(app.name).font(.caption).foregroundColor(.primary)
                } else {
                    Text("앱 선택").font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundColor(.secondary)
            }
            .padding(.horizontal, 6).padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(NSColor.separatorColor), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPicker, arrowEdge: .bottom) {
            VStack(spacing: 0) {
                TextField("검색", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(8)
                Divider()
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { app in
                            Button {
                                selected = app
                                showPicker = false
                                searchText = ""
                            } label: {
                                HStack(spacing: 6) {
                                    Image(nsImage: app.icon).resizable().frame(width: 16, height: 16)
                                    Text(app.name).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 200)
            }
            .frame(width: 220)
        }
    }
}

struct TerminationSettingsView: View {
    @ObservedObject private var settings = TerminationSettings.shared
    @State private var newKeyword = ""
    @State private var selectedApp: InstalledApp? = nil
    @State private var installedApps: [InstalledApp] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("앱 종료 키워드 설정")
                .font(.headline)
                .padding(.bottom, 10)

            Text("알림에서 '앱 종료 요청' 입력 시 인식할 단어와 대상 앱을 등록하세요.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(settings.entries) { entry in
                        HStack(spacing: 8) {
                            Text(entry.keyword)
                                .font(.caption)
                                .frame(width: 80, alignment: .leading)
                                .lineLimit(1)
                            Image(systemName: "arrow.right").font(.caption2).foregroundColor(.secondary)
                            Text(entry.appName)
                                .font(.caption).foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading).lineLimit(1)
                            Button {
                                settings.entries.removeAll { $0.id == entry.id }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red.opacity(0.7)).font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 5)
                        Divider()
                    }
                }
            }
            .frame(maxHeight: 200)

            Divider().padding(.bottom, 8)

            HStack(spacing: 6) {
                TextField("키워드", text: $newKeyword)
                    .textFieldStyle(.roundedBorder).font(.caption).frame(width: 80)
                Image(systemName: "arrow.right").font(.caption2).foregroundColor(.secondary)
                AppPickerButton(selected: $selectedApp, apps: installedApps)
                    .frame(maxWidth: .infinity)
                Button { addEntry() } label: {
                    Image(systemName: "plus.circle.fill").foregroundColor(.blue).font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(newKeyword.trimmingCharacters(in: .whitespaces).isEmpty || selectedApp == nil)
            }
        }
        .padding(16)
        .frame(width: 340)
        .onAppear { loadInstalledApps() }
    }

    private func loadInstalledApps() {
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let dirs: [URL] = [
                URL(fileURLWithPath: "/Applications"),
                URL(fileURLWithPath: "/Applications/Utilities"),
                URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications")
            ]
            var apps: [InstalledApp] = []
            for dir in dirs {
                guard let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
                for url in contents where url.pathExtension == "app" {
                    let name = fm.displayName(atPath: url.path)
                    apps.append(InstalledApp(name: name, url: url))
                }
            }
            let sorted = apps.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
            DispatchQueue.main.async { installedApps = sorted }
        }
    }

    private func addEntry() {
        let k = newKeyword.trimmingCharacters(in: .whitespaces)
        guard !k.isEmpty, let app = selectedApp else { return }
        settings.entries.append(.init(keyword: k, appName: app.name))
        newKeyword = ""
        selectedApp = nil
    }
}
