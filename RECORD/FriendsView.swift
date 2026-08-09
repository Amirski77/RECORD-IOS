//
//  FriendsView.swift
//  RECORD
//
//  The Friends tab. Spec §2.
//
//  Three states share one screen: searching (results replace everything),
//  requests pending (section above the circle), and settled (circle only).
//

import SwiftUI
import Supabase

struct FriendsView: View {
    @Binding var path: NavigationPath

    @State private var friends: [Friend] = []
    @State private var requests: [FriendRequest] = []
    @State private var query = ""
    @State private var results: [UserSearchResult] = []
    @State private var searching = false

    // Rows we've just acted on, so the button flips before the server
    // round-trip finishes. Cleared whenever we reload.
    @State private var sentTo: Set<String> = []

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.recordBG.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        Text("Friends")
                            .font(.display(30, .bold))
                            .foregroundStyle(Color.recordDisplay)
                            .padding(.bottom, 16)

                        searchField

                        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                            searchResults
                        } else {
                            if !requests.isEmpty {
                                sectionHeader("REQUESTS · \(requests.count)",
                                              color: .recordText)
                                ForEach(requests) { request in
                                    requestRow(request)
                                    if request.id != requests.last?.id { divider }
                                }
                            }

                            sectionHeader("YOUR CIRCLE · \(friends.count)",
                                          color: .recordTertiary)

                            if friends.isEmpty {
                                emptyCircle
                            } else {
                                ForEach(friends) { friend in
                                    friendRow(friend)
                                    if friend.id != friends.last?.id { divider }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                }
                .refreshable { await load() }
            }
            .toolbar(.hidden, for: .tabBar)
            .recordDestinations(path: $path)
        }
        .task { await load() }
        .task(id: query) { await runSearch() }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(Color.recordFaint)

            TextField("", text: $query, prompt:
                Text("Find someone by username")
                    .foregroundStyle(Color.recordFaint)
            )
            .font(.sans(13))
            .foregroundStyle(Color.recordText)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.recordTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.recordAvatarFill)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.recordCardBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var searchResults: some View {
        if searching && results.isEmpty {
            Text("Searching…")
                .font(.sans(13))
                .foregroundStyle(Color.recordTertiary)
                .padding(.top, 24)
        } else if results.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("No one by that name.")
                    .font(.display(19, .bold))
                    .foregroundStyle(Color.recordText)
                Text("Usernames are exact from the start — try fewer letters.")
                    .font(.sans(13))
                    .foregroundStyle(Color.recordSecondary)
            }
            .padding(.top, 28)
        } else {
            sectionHeader("RESULTS", color: .recordTertiary)
            ForEach(results) { result in
                resultRow(result)
                if result.id != results.last?.id { divider }
            }
        }
    }

    private func runSearch() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else {
            results = []
            searching = false
            return
        }
        searching = true
        // Wait out fast typing. .task(id:) cancels this when query changes
        // again, so only the last keystroke reaches the network.
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        results = await searchUsers(q)
        searching = false
    }

    // MARK: - Rows

    private func resultRow(_ result: UserSearchResult) -> some View {
        HStack(spacing: 12) {
            FriendAvatar(username: result.username, url: result.avatar_url)

            Text(result.username)
                .font(.sans(14))
                .foregroundStyle(Color.recordText)

            Spacer()

            let relation = sentTo.contains(result.id) ? .sentByMe : result.relation

            switch relation {
            case .none:
                Button {
                    sentTo.insert(result.id)
                    Task { _ = await sendFriendRequest(to: result.id) }
                } label: {
                    pill("Add", filled: true)
                }
                .buttonStyle(.plain)

            case .sentByMe:
                pill("Requested", filled: false)
                    .foregroundStyle(Color.recordTertiary)

            case .sentToMe:
                Button {
                    Task {
                        _ = await acceptFriendRequest(from: result.id)
                        await load()
                    }
                } label: {
                    pill("Accept", filled: true)
                }
                .buttonStyle(.plain)

            case .friends:
                Text("In your circle")
                    .font(.sans(12))
                    .foregroundStyle(Color.recordTertiary)
            }
        }
        .padding(.vertical, 13)
    }

    private func requestRow(_ request: FriendRequest) -> some View {
        HStack(spacing: 12) {
            FriendAvatar(username: request.username, url: request.avatar_url)

            VStack(alignment: .leading, spacing: 2) {
                Text(request.username)
                    .font(.sans(14))
                    .foregroundStyle(Color.recordText)
                Text("\(request.record_count) record\(request.record_count == 1 ? "" : "s")")
                    .font(.sans(11))
                    .foregroundStyle(Color.recordTertiary)
            }

            Spacer()

            HStack(spacing: 6) {
                Button {
                    Task {
                        _ = await acceptFriendRequest(from: request.id)
                        await load()
                    }
                } label: {
                    pill("Accept", filled: true)
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        _ = await removeFriendship(with: request.id)
                        await load()
                    }
                } label: {
                    pill("Decline", filled: false)
                        .foregroundStyle(Color.recordSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 14)
    }

    private func friendRow(_ friend: Friend) -> some View {
        NavigationLink(value: ProfileRoute(userID: friend.id,
                                           username: friend.username,
                                           isMe: false)) {
            HStack(spacing: 12) {
                FriendAvatar(username: friend.username, url: friend.avatar_url)

                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.username)
                        .font(.sans(14))
                        .foregroundStyle(Color.recordText)
                    Text(friendSubtitle(friend))
                        .font(.sans(11))
                        .foregroundStyle(Color.recordTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.recordDot)
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func friendSubtitle(_ friend: Friend) -> String {
        guard friend.posted_today else { return "no record yet" }
        if friend.current_streak > 1 {
            return "posted today · \(friend.current_streak) day streak"
        }
        return "posted today"
    }

    // MARK: - Pieces

    private func sectionHeader(_ text: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(text)
                .font(.sans(10, .medium))
                .tracking(2)
                .foregroundStyle(color)
            Rectangle()
                .fill(Color.recordRule)
                .frame(height: 1)
        }
        .padding(.top, 26)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.recordSeparator)
            .frame(height: 1)
    }

    private func pill(_ text: String, filled: Bool) -> some View {
        Text(text)
            .font(.sans(12, .medium))
            .foregroundStyle(filled ? Color.recordInk : Color.recordSecondary)
            .padding(.horizontal, filled ? 13 : 12)
            .padding(.vertical, 6)
            .background {
                if filled {
                    Capsule().fill(Color.recordAccent)
                } else {
                    Capsule().stroke(Color.recordCardBorder, lineWidth: 1)
                }
            }
    }

    private var emptyCircle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No one yet.")
                .font(.display(19, .bold))
                .foregroundStyle(Color.recordText)
            Text("Search a username above to send your first request.")
                .font(.sans(13))
                .foregroundStyle(Color.recordSecondary)
        }
        .padding(.top, 20)
    }

    // MARK: - Loading

    private func load() async {
        sentTo.removeAll()
        async let f = fetchFriends()
        async let r = fetchFriendRequests()
        friends = await f
        requests = await r
    }
}

// MARK: - Avatar

struct FriendAvatar: View {
    let username: String
    let url: String?

    var body: some View {
        Group {
            if let url, let parsed = URL(string: url) {
                AsyncImage(url: parsed) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    AvatarView(username: username, size: 34)
                }
                .frame(width: 34, height: 34)
                .clipShape(Circle())
            } else {
                AvatarView(username: username, size: 34)
            }
        }
    }
}
