import SwiftUI
import AppKit
import AgentPetCore

/// Rich menu bar popover content: header, live agent list, and a footer bar.
struct MenuContentView: View {
    @ObservedObject private var daemon = AppDaemon.shared
    @ObservedObject private var petWindow = PetWindowController.shared
    var dismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color.white.opacity(0.08))
            agentSection
            Divider().overlay(Color.white.opacity(0.08))
            controls
            Divider().overlay(Color.white.opacity(0.08))
            footer
        }
        .frame(width: 300)
        .background(Color(red: 0.10, green: 0.10, blue: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.accent)
                .frame(width: 28, height: 28)
                .overlay(Image(systemName: "pawprint.fill").font(.system(size: 13)).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 1) {
                Text("AgentPet").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
        }
        .padding(14)
    }

    private var subtitle: String {
        let total = daemon.sessions.count
        if total == 0 { return "No agents running" }
        let running = daemon.sessions.filter { $0.state == .working || $0.state == .registered }.count
        return "\(total) agent\(total == 1 ? "" : "s") · \(running) running"
    }

    // MARK: Agents

    private var agentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Agents")
            if daemon.sessions.isEmpty {
                Text("Nothing running right now.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.horizontal, 14).padding(.bottom, 12)
            } else {
                ForEach(daemon.sessions) { AgentRow(session: $0) }
                    .padding(.bottom, 6)
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold)).tracking(1.4)
            .foregroundStyle(.white.opacity(0.35))
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 6)
    }

    // MARK: Controls

    private var controls: some View {
        Toggle(isOn: $petWindow.isVisible) {
            HStack(spacing: 8) {
                Image(systemName: "pawprint")
                Text("Show pet")
            }
            .font(.system(size: 13))
            .foregroundStyle(.white)
        }
        .toggleStyle(.switch)
        .tint(Theme.accent)
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 14) {
            FooterButton(icon: "gearshape", label: "Settings") {
                dismiss()
                SettingsWindowController.shared.show()
            }
            Spacer()
            FooterButton(icon: "power", label: "Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}

private struct FooterButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.8))
        }
        .buttonStyle(.plain)
    }
}

private struct AgentRow: View {
    let session: AgentSession

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(dotColor).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(project).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                Text(session.state.rawValue.capitalized).font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(timeString(now: context.date))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
    }

    private var project: String {
        session.project.map { ($0 as NSString).lastPathComponent } ?? session.id
    }

    private var dotColor: Color {
        switch session.state {
        case .working, .registered: return .blue
        case .waiting: return .orange
        case .done: return .green
        case .idle: return .gray
        }
    }

    private func timeString(now: Date) -> String {
        switch session.state {
        case .done, .idle:
            return session.updatedAt.formatted(date: .omitted, time: .shortened)
        default:
            let s = max(0, Int(now.timeIntervalSince(session.updatedAt)))
            return s < 60 ? "\(s)s" : "\(s / 60)m \(s % 60)s"
        }
    }
}
