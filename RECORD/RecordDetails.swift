//
//  RecordDetails.swift
//  RECORD
//
//  Track / artist / note — the three lines that describe a record.
//  Used by the Today card, feed rows, and diary rows so they can't drift apart.
//

import SwiftUI

struct RecordDetails: View {
    let track: String
    let artist: String
    let note: String?
    var trackSize: CGFloat = 19

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(track)
                .font(.display(trackSize, .bold))
                .foregroundStyle(Color.recordText)
                .lineLimit(1)
                .minimumScaleFactor(0.9)

            Text(artist)
                .font(.sans(13))
                .foregroundStyle(Color.recordArtist)
                .lineLimit(1)
                .padding(.top, -2)

            if let note, !note.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Rectangle()
                        .fill(Color.recordNoteRule)
                        .frame(width: 2)
                    Text(note)
                        .font(.sans(12.5))
                        .italic()
                        .foregroundStyle(Color.recordNote)
                        .padding(.top, 2)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
            }
        }
    }
}
