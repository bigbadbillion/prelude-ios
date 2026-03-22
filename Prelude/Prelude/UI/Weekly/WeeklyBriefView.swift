import SwiftData
import SwiftUI

struct WeeklyBriefView: View {
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \WeeklyBrief.generatedAt, order: .reverse) private var briefs: [WeeklyBrief]

    private var palette: PreludePalette { PreludePalette.palette(for: scheme) }
    private var weekly: WeeklyBrief? { briefs.first }

    var body: some View {
        ZStack {
            palette.depth.ignoresSafeArea()
            ScrollView {
                if let w = weekly {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("This week.")
                            .font(PreludeTypeScale.title())
                            .foregroundStyle(palette.primary)
                        Text(w.summary)
                            .font(PreludeTypeScale.cardBody())
                            .foregroundStyle(palette.primary)
                            .lineSpacing(4)
                        if let s = w.suggestions.first {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Worth bringing up:")
                                    .font(PreludeTypeScale.label())
                                    .foregroundStyle(palette.amber)
                                Text(s)
                                    .font(PreludeTypeScale.cardBody())
                                    .foregroundStyle(palette.primary)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .preludeGlassCard()
                    .padding(20)
                } else {
                    Text("Your weekly brief will appear after you complete sessions.")
                        .font(PreludeTypeScale.cardBody())
                        .foregroundStyle(palette.secondary)
                        .padding(24)
                }
            }
        }
        .navigationTitle("This Week")
        .navigationBarTitleDisplayMode(.large)
    }
}
