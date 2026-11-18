//
//  AppLog.swift
//  RECORD
//
//  One place for "something went wrong".
//
//  Every data call used to end in `print(...)` plus a default value — an empty
//  array, a nil, a zero. `print` writes to the debugger console and nowhere
//  else, so in a build running on a real phone those failures went to no one.
//  That is how the Diary tab managed to ask for a column that didn't exist,
//  fail on every single load, and still look merely empty rather than broken.
//
//  Two kinds of failure, deliberately different:
//
//    quiet — logged only. The feature is optional and the UI degrades on its
//            own. A missing Spotify link is not worth interrupting anyone.
//    loud  — logged and shown. The person asked for something and didn't get
//            it, so they need to know it failed rather than believe the empty
//            screen.
//
//  Both go to OSLog, which survives release builds and is readable in
//  Console.app and in Xcode's debug console.
//

import Combine
import Foundation
import OSLog
import SwiftUI

enum AppLog {
    private static let logger = Logger(subsystem: "live.recordapp.RECORD", category: "data")

    /// Logged, not shown.
    static func quiet(_ context: String, _ error: Error) {
        logger.error("\(context, privacy: .public) — \(String(describing: error), privacy: .public)")
    }

    /// Logged, not shown. For a failure with no Error value of its own.
    static func quiet(_ context: String) {
        logger.error("\(context, privacy: .public)")
    }

    /// Logged and shown to the person as a banner.
    @MainActor
    static func loud(_ context: String, _ error: Error, say message: String) {
        quiet(context, error)
        ErrorCenter.shared.show(message)
    }

    /// Shown to the person as a banner, with nothing underlying to log.
    @MainActor
    static func tell(_ message: String) {
        logger.notice("shown to user: \(message, privacy: .public)")
        ErrorCenter.shared.show(message)
    }
}

// MARK: - The banner's state
//
// A single shared object rather than @State per screen: the data functions in
// Feed.swift, Friendships.swift and the rest are free functions with no view
// to call back into, and threading a binding through all of them would be
// worse than one well-named singleton.

@MainActor
final class ErrorCenter: ObservableObject {
    static let shared = ErrorCenter()

    @Published private(set) var message: String?

    private var clearTask: Task<Void, Never>?

    private init() {}

    func show(_ text: String) {
        message = text
        clearTask?.cancel()
        clearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.message = nil
        }
    }

    func dismiss() {
        clearTask?.cancel()
        clearTask = nil
        message = nil
    }
}

// MARK: - The banner itself

private struct ErrorBannerModifier: ViewModifier {
    @ObservedObject private var center = ErrorCenter.shared

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message = center.message {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("!")
                            .font(.display(13, .bold))
                            .foregroundStyle(Color.recordInk)
                            .frame(width: 18, height: 18)
                            .background(Color.recordCaution)
                            .clipShape(Circle())

                        Text(message)
                            .font(.sans(12.5))
                            .foregroundStyle(Color.recordText)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.recordCardTop)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.recordCardBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, 16)
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
                    .onTapGesture { center.dismiss() }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityAddTraits(.isStaticText)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.9), value: center.message)
    }
}

extension View {
    /// Shows whatever `AppLog.loud` / `AppLog.tell` most recently reported.
    /// Attach once per window, not per screen.
    func recordErrorBanner() -> some View {
        modifier(ErrorBannerModifier())
    }
}
