//
//  PostConfirmView.swift
//  RECORD
//
//  Created by Amir Rashidov on 01.07.2026.
//

import SwiftUI
import Supabase

// This struct is the SHAPE OF A ROW we're writing to the `posts` table.
// Same idea as `Profile` struct in AuthView — property names must
// match your Postgres column names exactly, so Supabase can turn this
// into a row automatically. We only include columns WE set; we leave
// `id` and `created_at` out so Postgres fills them itself.
struct NewPost: Encodable {
    let user_id: UUID
    let track_id: String
    let track_name: String
    let artist_name: String
    let album_art_url: String
    let preview_url: String?
    let apple_music_url: String?
    let note: String?
}

struct PostConfirmView: View {
    let song: Song
    @Binding var path: NavigationPath

    @State private var note = ""
    @State private var isPosting = false
    @State private var errorMessage: String?

    // This lets us close this screen (pop back) after a successful post.
    @Environment(\.dismiss) private var dismiss

    // Upscale the iTunes artwork: swap 100x100 → 600x600 for a crisp big image.
    private var bigArtworkURL: URL? {
        guard let raw = song.artworkUrl100 else { return nil }
        return URL(string: raw.replacingOccurrences(of: "100x100", with: "600x600"))
    }

    var body: some View {
        ZStack {
            Color.recordBG.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {

                Text("YOUR RECORD · TODAY")
                    .font(.sans(10, .medium))
                    .tracking(1.5)
                    .foregroundStyle(Color.recordGreen)

                // BIG ALBUM ART
                AsyncImage(url: bigArtworkURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Color.recordSurface
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // SONG INFO
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.trackName)
                        .font(.display(22, .bold))
                        .foregroundStyle(Color.recordText)
                    Text(song.artistName)
                        .font(.sans(15))
                        .foregroundStyle(Color.recordMuted)
                }

                // OPTIONAL NOTE — matches your web app's 280-char note field.
                // `axis: .vertical` lets it grow to a few lines as you type.
                TextField("", text: $note,
                          prompt: Text("Add a note (optional)").foregroundColor(.recordDim),
                          axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                    .padding()
                    .background(Color.recordSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(Color.recordText)
                    .onChange(of: note) { _, newValue in
                        // hard cap at 280, same as web
                        if newValue.count > 280 { note = String(newValue.prefix(280)) }
                    }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.sans(12))
                        .foregroundStyle(Color.recordGreen)
                }

                // POST BUTTON
                Button {
                    Task { await post() }
                } label: {
                    Text(isPosting ? "..." : "Post record  →")
                        .font(.sans(15, .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.recordGreen)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isPosting)

                Spacer()
            }
            .padding(20)
        }
        .navigationBarBackButtonHidden(false)
    }

    // THE POST FUNCTION — this is your web app's /post route, in Swift.
    func post() async {
        errorMessage = nil
        isPosting = true
        defer { isPosting = false }   // always flip off, even on error

        do {
            // 1. Who is posting? Grab the logged-in user's id (a uuid),
            //    same way loadProfile() does it on the main screen.
            let userID = try await supabase.auth.session.user.id

            // 2. ONE-POST-PER-DAY CHECK (friendly version, in Swift).
            //    We ask: does this user already have a post today?
            //    NOTE: this is the nice-message guard. The REAL lock has to
            //    live in the database before friends use it — flagged below.
            if try await hasPostedToday(userID: userID) {
                errorMessage = "You've already posted today. Come back tomorrow."
                return
            }

            // 3. Build the row. note → nil if empty (matches web's `note or None`).
            let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            let newPost = NewPost(
                user_id: userID,
                track_id: String(song.id),
                track_name: song.trackName,
                artist_name: song.artistName,
                album_art_url: song.artworkUrl100 ?? "",
                preview_url: song.previewUrl,
                apple_music_url: song.trackViewUrl,
                note: trimmedNote.isEmpty ? nil : trimmedNote
            )

            // 4. Write the row.
            try await supabase
                .from("posts")
                .insert(newPost)
                .execute()

            // 5. Success — pop all the way home to the feed.
            path = NavigationPath()
            
        } catch {
            // If the DB rejected a second post for today (the unique index),
            // show the friendly message instead of the raw Postgres error.
            if "\(error)".contains("one_post_per_utc_day") {
                errorMessage = "You've already posted today. Come back tomorrow."
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    // Asks Supabase: any post by this user since the start of "today"?
    // For now "today" = start of the current UTC day. This is a SIMPLER
    // boundary than your web app's 4am-Almaty rule — read the note after.
    func hasPostedToday(userID: UUID) async throws -> Bool {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let startOfDay = utcCalendar.startOfDay(for: Date())
        
        let iso = ISO8601DateFormatter().string(from: startOfDay)

        let rows: [PostRow] = try await supabase
            .from("posts")
            .select("id")
            .eq("user_id", value: userID)
            .gte("created_at", value: iso)
            .execute()
            .value

        return !rows.isEmpty
    }
}

// Tiny struct just to decode the check above (we only need to know rows exist).
struct PostRow: Decodable {
    let id: Int
}

#Preview {
    NavigationStack {
        PostConfirmView(song: Song(
            id: 1,
            trackName: "Sample Song",
            artistName: "Sample Artist",
            artworkUrl100: "https://via.placeholder.com/100",
            previewUrl: nil,
            trackViewUrl: nil
        ),
        path: .constant(NavigationPath())
        )
    }
}


