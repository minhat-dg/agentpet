import SwiftUI
import AgentPetCore

/// The pet's right-click card: stats only — who this companion is, its level,
/// XP progress, hunger and feeding numbers. Controls live in the menu bar
/// popover and Settings, not here.
struct PetStatsView: View {
    @ObservedObject private var care = PetCareController.shared
    @ObservedObject private var pet = PetController.shared
    @ObservedObject private var imagePets = ImagePetStore.shared

    private static let stageIcons = ["leaf.fill", "pawprint.fill", "binoculars.fill", "shield.fill", "crown.fill"]
    private static let stageColors: [Color] = [.green, .teal, .blue, .purple, .orange]

    private var pack: ImagePetPack? {
        pet.selectedPetID.flatMap { imagePets.pack(id: $0) }
    }

    private var stageColor: Color { Self.stageColors[min(care.stageIndex, Self.stageColors.count - 1)] }

    var body: some View {
        let state = care.current
        VStack(alignment: .leading, spacing: 10) {
            // Who
            HStack(spacing: 10) {
                Group {
                    if let frame = pack?.clip(0).first {
                        Image(nsImage: frame).resizable().interpolation(.none).scaledToFit()
                    } else {
                        Image(systemName: "pawprint.fill").foregroundStyle(.secondary)
                    }
                }
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(stageColor.opacity(0.14)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(pack?.displayName ?? NSLocalizedString("Your pet", comment: ""))
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                    HStack(spacing: 6) {
                        Text(verbatim: "Lv \(care.level)")
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(stageColor)
                        Text(NSLocalizedString(care.stageKey, comment: "stage"))
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(stageColor.opacity(0.2)))
                            .foregroundStyle(stageColor)
                    }
                }
                Spacer()
                Text(hungerText)
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
            }

            // XP
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: care.levelProgress).tint(stageColor).controlSize(.small)
                Text(verbatim: "\(state.xp) / \(PetCare.xpToReach(level: care.level + 1)) XP")
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
            }

            divider

            statRow(label: NSLocalizedString("Today", comment: ""),
                    value: todayValue(state))
            statRow(label: NSLocalizedString("Streak", comment: ""),
                    value: streakValue(state))
            statRow(label: NSLocalizedString("Lifetime", comment: ""),
                    value: lifetimeValue(state))
            if let last = state.lastFedAt {
                statRow(label: NSLocalizedString("Last fed", comment: ""),
                        value: last.formatted(.relative(presentation: .named)))
            }
        }
        .padding(14)
        .frame(width: 280)
        .background(.regularMaterial)
        .environment(\.colorScheme, .dark)
        .noFocusRing()
    }

    private var divider: some View { Divider().overlay(Color.white.opacity(0.08)) }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 11)).foregroundStyle(.white.opacity(0.45))
            Spacer()
            Text(verbatim: value).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.85))
        }
    }

    private func todayValue(_ s: PetCareState) -> String {
        if s.mealsToday == 1 {
            return String(format: NSLocalizedString("%@ tokens · 1 meal", comment: ""), Self.tokenString(s.tokensToday))
        }
        return String(format: NSLocalizedString("%@ tokens · %d meals", comment: ""),
                      Self.tokenString(s.tokensToday), s.mealsToday)
    }

    private func streakValue(_ s: PetCareState) -> String {
        s.streakDays == 1
            ? NSLocalizedString("1 day", comment: "")
            : String(format: NSLocalizedString("%d days", comment: ""), s.streakDays)
    }

    private func lifetimeValue(_ s: PetCareState) -> String {
        String(format: NSLocalizedString("%@ tokens · %d sessions", comment: ""),
               Self.tokenString(s.totalTokens), s.totalMeals)
    }

    private var hungerText: String {
        switch care.hunger {
        case .full: return NSLocalizedString("Full", comment: "hunger")
        case .satisfied: return NSLocalizedString("Satisfied", comment: "hunger")
        case .peckish: return NSLocalizedString("Peckish", comment: "hunger")
        case .hungry: return NSLocalizedString("Hungry", comment: "hunger")
        case .starving: return NSLocalizedString("Starving", comment: "hunger")
        }
    }

    private static func tokenString(_ n: Int) -> String {
        switch n {
        case 1_000_000...: return String(format: "%.1fM", Double(n) / 1_000_000)
        case 1_000...: return String(format: "%.0fk", Double(n) / 1_000)
        default: return "\(n)"
        }
    }
}
