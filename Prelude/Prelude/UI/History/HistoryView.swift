import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]

    private var palette: PreludePalette { PreludePalette.palette(for: scheme) }

    var body: some View {
        ZStack {
            palette.depth.ignoresSafeArea()
            List {
                ForEach(sessions.filter { $0.completedAt != nil }, id: \.id) { session in
                    NavigationLink {
                        BriefDetailView(sessionId: session.id)
                    } label: {
                        SessionRowView(session: session)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Sessions")
        .navigationBarTitleDisplayMode(.large)
    }
}
