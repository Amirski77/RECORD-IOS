//
//  MainTabView.swift
//  RECORD
//
//  Root shell for the app. Spec §3.
//
//  The three NavigationPaths live HERE rather than inside each screen, because
//  the tab bar needs to clear them: tapping the tab you're already on pops that
//  tab back to its root. State that gets reset from outside has to live outside.
//

import SwiftUI

// MARK: - Tabs

enum RecordTab: Hashable, CaseIterable {
    case today, diary, friends

    var label: String {
        switch self {
        case .today:   "Today"
        case .diary:   "Diary"
        case .friends: "Friends"
        }
    }
}

// MARK: - Shell

struct MainTabView: View {
    @State private var selection: RecordTab = .today

    @State private var todayPath = NavigationPath()
    @State private var diaryPath = NavigationPath()
    @State private var friendsPath = NavigationPath()

    var body: some View {
        TabView(selection: $selection) {
            ContentView(path: $todayPath)
                .tag(RecordTab.today)

            DiaryTabView(path: $diaryPath)
                .tag(RecordTab.diary)

            FriendsView(path: $friendsPath)
                .tag(RecordTab.friends)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            RecordTabBar(selection: $selection, onReselect: popToRoot)
        }
        .background(Color.recordBG.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func popToRoot(_ tab: RecordTab) {
        switch tab {
        case .today:   todayPath = NavigationPath()
        case .diary:   diaryPath = NavigationPath()
        case .friends: friendsPath = NavigationPath()
        }
    }
}

// MARK: - Shared navigation destinations
//
// A destination is only visible to the NavigationStack it's registered on.
// Three tabs means three stacks, so this goes on all of them.

struct RecordDestinations: ViewModifier {
    @Binding var path: NavigationPath

    func body(content: Content) -> some View {
        content
            .navigationDestination(for: String.self) { value in
                switch value {
                case "search":   SearchView(path: $path)
                case "settings": SettingsView()
                default:         EmptyView()
                }
            }
            .navigationDestination(for: Song.self) { song in
                PostConfirmView(song: song, path: $path)
            }
            .navigationDestination(for: ProfileRoute.self) { route in
                ProfileView(userID: route.userID,
                            username: route.username,
                            isMe: route.isMe)
            }
    }
}

extension View {
    func recordDestinations(path: Binding<NavigationPath>) -> some View {
        modifier(RecordDestinations(path: path))
    }
}

// MARK: - Diary tab
//
// ProfileView needs userID / username / isMe, and a tab root has no parent to
// pass them. This wrapper reads them from the shared Session instead.

struct DiaryTabView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject private var session: Session

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if session.userID.isEmpty {
                    Color.recordBG.ignoresSafeArea()
                } else {
                    ProfileView(userID: session.userID,
                                username: session.username,
                                isMe: true)
                        .id(session.userID)   // rebuild once identity resolves
                }
            }
            .toolbar(.hidden, for: .tabBar)
            .recordDestinations(path: $path)
        }
    }
}

// MARK: - The bar

struct RecordTabBar: View {
    @Binding var selection: RecordTab
    var onReselect: (RecordTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(RecordTab.allCases, id: \.self) { tab in
                item(tab)
            }
        }
        .frame(height: 49)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color.recordBG.opacity(0.94)
            }
            .ignoresSafeArea(edges: .bottom)   // fills the home-indicator area
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.recordSeparator)
                .frame(height: 1)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func item(_ tab: RecordTab) -> some View {
        let isActive = selection == tab

        return Button {
            if isActive {
                onReselect(tab)      // already here → pop to root
            } else {
                selection = tab
            }
        } label: {
            VStack(spacing: 5) {
                TabIcon(tab: tab)
                    .frame(width: 19, height: 19)
                Text(tab.label)
                    .font(.sans(10, isActive ? .bold : .medium))
            }
            .foregroundStyle(isActive ? Color.recordAccent : Color.recordTertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)   // full-height hit target
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.label)
        .accessibilityAddTraits(isActive ? [.isSelected, .isButton] : .isButton)
    }
}

// MARK: - Icons
//
// Drawn, not SF Symbols. 19pt box, 1.6pt stroke, inherits foregroundStyle.

struct TabIcon: View {
    let tab: RecordTab

    var body: some View {
        switch tab {

        case .today:        // a record: circle outline + centre dot
            ZStack {
                Circle().strokeBorder(lineWidth: 1.6)
                Circle().frame(width: 4.5, height: 4.5)
            }

        case .diary:        // three stacked rules, last at 58%
            VStack(alignment: .leading, spacing: 4.6) {
                Capsule().frame(height: 1.6)
                Capsule().frame(height: 1.6)
                Capsule().frame(width: 11, height: 1.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .friends:      // two overlapping circle outlines
            ZStack {
                Circle().strokeBorder(lineWidth: 1.6)
                    .frame(width: 13, height: 13)
                    .offset(x: -3.2)
                Circle().strokeBorder(lineWidth: 1.6)
                    .frame(width: 13, height: 13)
                    .offset(x: 3.2)
            }
        }
    }
}
