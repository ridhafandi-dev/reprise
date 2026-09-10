import SwiftUI

enum GateMetrics {
    static let closed = CGSize(width: 22, height: 76)
    static let expanded = CGSize(width: 416, height: 560)
    static let receipt = CGSize(width: 416, height: 336)
    static let canvas = expanded
    @MainActor static func size(_ session: GateSession) -> CGSize {
        session.isOpen ? (session.receipt != nil ? receipt : expanded) : closed
    }
}

struct GateNotch: View {
    @ObservedObject var session: GateSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        let size = GateMetrics.size(session)
        let shape = SideNotchShape(edge: .right, curlRadius: 9, cornerRadius: 16)
        ZStack(alignment: .trailing) {
            if session.isOpen {
                ZStack {
                    RepriseGlass()
                    Color(red: 0.04, green: 0.055, blue: 0.08).opacity(0.48)
                    LinearGradient(colors: [.white.opacity(0.07), Ink.sky.opacity(0.06), .black.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    SurfaceFold().stroke(.white.opacity(0.2), lineWidth: 8).blur(radius: 6).accessibilityHidden(true)
                    SurfaceFold().stroke(.white.opacity(0.28), lineWidth: 0.7).accessibilityHidden(true)
                    card.padding(.horizontal, 16).padding(.trailing, 32).padding(.vertical, 24)
                    VStack {
                        Button { session.close() } label: {
                            Image(systemName: "chevron.right").font(.system(size: 12)).frame(width: 28, height: 32)
                        }.buttonStyle(SurfaceButton(dark: true, filled: true))
                            .accessibilityLabel("Fermer sans décider")
                        Spacer()
                    }.padding(.vertical, 24).padding(.trailing, 4).frame(maxWidth: .infinity, alignment: .trailing)
                }
                .overlay(shape.stroke(.white.opacity(0.28), lineWidth: 0.7).allowsHitTesting(false))
            } else {
                shape.fill(Ink.black)
                Button { session.reveal() } label: {
                    RepriseMark(color: session.request == nil && session.receipt == nil ? Ink.muted : Ink.sky)
                        .frame(width: 13, height: 13).frame(width: 22, height: 76)
                }.buttonStyle(.plain).accessibilityLabel(session.request == nil ? "Reprise — aucune demande" : "Ouvrir la demande d’autorisation")
            }
        }
        .frame(width: size.width, height: size.height).clipShape(shape)
        .animation(reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.91), value: size)
        .frame(width: GateMetrics.canvas.width, height: GateMetrics.canvas.height, alignment: .trailing)
        .foregroundStyle(.white.opacity(0.92)).preferredColorScheme(.dark)
    }
    @ViewBuilder private var card: some View {
        if let receipt = session.receipt {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    RepriseMark(color: Ink.sky).frame(width: 16, height: 16)
                    Text("DÉCISION ENREGISTRÉE").font(.system(size: 12)).foregroundStyle(Atelier.soft)
                }
                Text(receiptTitle(receipt.decision.outcome)).font(.system(size: 18, weight: .semibold))
                Text(Date(timeIntervalSince1970: Double(receipt.decision.decidedAt) / 1000), style: .time)
                    .font(.system(size: 12)).monospacedDigit().foregroundStyle(.white.opacity(0.64))
                ScrollView {
                    field("PORTÉE CONCERNÉE", receipt.request.scope)
                }
                Text("Décision locale · aucune action exécutée")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.64))
                if session.otherCount > 0 { waiting }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if let request = session.request {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DEMANDE D’AUTORISATION").font(.system(size: 12)).foregroundStyle(Atelier.soft)
                    HStack(alignment: .top, spacing: 8) {
                        Text(request.requester).font(.system(size: 16)).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Text(String(format: "%02d:%02d", session.remaining / 60, session.remaining % 60))
                            .font(.system(size: 12)).monospacedDigit().foregroundStyle(Atelier.soft)
                            .accessibilityLabel("Expire dans \(session.remaining) secondes")
                    }
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(request.action).font(.system(size: 18, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                        field("CIBLE", request.target)
                        field("PORTÉE EXACTE", request.scope)
                        field("NIVEAU D’EFFET", effectTitle(request.effect))
                        if !request.evidence.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("PREUVES DÉCLARÉES · NON VÉRIFIÉES").font(.system(size: 12)).foregroundStyle(.white.opacity(0.64))
                                ForEach(Array(request.evidence.prefix(2).enumerated()), id: \.offset) { _, evidence in
                                    Text(evidence).font(.system(size: 16)).fixedSize(horizontal: false, vertical: true)
                                }
                                if request.evidence.count > 2 {
                                    Text("2 déclarations affichées sur \(request.evidence.count)").font(.system(size: 12)).foregroundStyle(.white.opacity(0.64))
                                }
                            }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.id(request.requestDigest)
                if !session.error.isEmpty { Text(session.error).font(.system(size: 12)) }
                if session.otherCount > 0 { waiting }
                HStack(spacing: 8) {
                    Button { session.deny(request) } label: {
                        Text("Refuser").padding(.horizontal, 12).frame(height: 40)
                    }.buttonStyle(SurfaceButton(dark: true, filled: true))
                    Button { session.approve(request) } label: {
                        Text(session.confirming ? "Confirmer cette portée" : "Autoriser une fois")
                            .frame(maxWidth: .infinity).frame(height: 40)
                    }.buttonStyle(SurfaceButton(dark: true, filled: true))
                        .background(Ink.blue.opacity(0.6), in: Capsule())
                }.font(.system(size: 12)).disabled(!session.canDecide)
                Text(session.confirming ? "Second clic requis · confirmation valable 5 s" : "Cette requête uniquement. Aucune permission permanente.")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.64))
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            Text(session.error).font(.system(size: 16)).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
    private var waiting: some View {
        Text("\(session.otherCount) autre\(session.otherCount > 1 ? "s" : "") demande\(session.otherCount > 1 ? "s" : "") en attente")
            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.64))
    }
    private func field(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 12)).foregroundStyle(.white.opacity(0.64))
            Text(text).font(.system(size: 16)).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func effectTitle(_ effect: GateEffect) -> String {
        switch effect {
        case .reversible: return "Réversible"
        case .difficult: return "Difficile à annuler · confirmation renforcée"
        case .irreversible: return "Irréversible · confirmation renforcée"
        case .unknown: return "Inconnu · confirmation renforcée"
        }
    }
    private func receiptTitle(_ outcome: GateOutcome) -> String {
        switch outcome { case .approveOnce: return "Autorisé une fois"; case .deny: return "Refusé"; case .expired: return "Expiré" }
    }
}
