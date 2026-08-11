//
//  LockedEditionView.swift
//  RECORD
//
//  Created by Amir Rashidov on 12.08.2026.
//  What sits under TODAY'S EDITION before you've posted. Spec §9.
//
//  Nothing real is behind the blur. The shapes are invented here from each
//  post's id — the server never sent a title or a cover, so there's nothing to
//  extract. Seeding off the id (rather than random) keeps the shapes still
//  between refreshes; shapes that reshuffle read as a loading skeleton, and a
//  skeleton says "wait" when this needs to say "do something".
//

import SwiftUI

struct LockedEditionView: View {
    let count: Int
    let seeds: [Int]        // post ids, for stable placeholder shapes

    var body: some View {
        ZStack {
            ghostRows
                .blur(radius: 17)
                .opacity(0.5)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.recordAvatarFill)
                        .frame(width: 52, height: 52)
                    Circle()
                        .stroke(Color.recordCardBorder, lineWidth: 1)
                        .frame(width: 52, height: 52)
                    Text("🔒")
                        .font(.system(size: 21))
                }
                .accessibilityHidden(true)

                VStack(spacing: 7) {
                    Text("^[\(count) friend](inflect: true) have posted.")
                        .font(.display(21, .bold))
                        .foregroundStyle(Color.recordDisplay)
                        .multilineTextAlignment(.center)

                    Text("Post your record to open today's edition.")
                        .font(.sans(14))
                        .foregroundStyle(Color.recordSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    // MARK: - Placeholders

    private var ghostRows: some View {
        VStack(spacing: 22) {
            ForEach(Array(seeds.prefix(4).enumerated()), id: \.offset) { index, seed in
                ghostRow(seed: seed)
            }
        }
    }

    private func ghostRow(seed: Int) -> some View {
        // Deterministic pseudo-random from the post id.
        let a = Double((seed &* 2_654_435_761) % 100) / 100
        let b = Double((seed &* 40_503) % 100) / 100
        let hue = Double((seed &* 7_919) % 360) / 360

        return HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hue: hue, saturation: 0.28, brightness: 0.30),
                            Color(hue: hue, saturation: 0.20, brightness: 0.13)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 9) {
                Capsule()
                    .fill(Color(white: 0.24))
                    .frame(width: 120 + a * 90, height: 11)
                Capsule()
                    .fill(Color(white: 0.17))
                    .frame(width: 80 + b * 70, height: 9)
            }

            Spacer(minLength: 0)
        }
    }
}
