//
//  RootView.swift
//  RECORD
//
//  Created by Amir Rashidov on 29.06.2026.
//

import SwiftUI
import Supabase

struct RootView: View {
    @StateObject private var session = Session()
    @StateObject private var audio = AudioPlayer()
    @State private var isLoggedIn = false
    @State private var checking = true
    @State private var pendingInvite: String?
    @State private var redeemMessage: String?

    var body: some View {
        Group {
            if checking {
                // brief loading while we check for an existing session
                Color.recordBG.ignoresSafeArea()
            } else if isLoggedIn {
                MainTabView()
                    .environmentObject(session)
                    .environmentObject(audio)
            } else {
                AuthView()
            }
        }
        .recordErrorBanner()
        .onOpenURL { url in
            // recordapp.live/i/<code>
            guard url.pathComponents.count >= 3,
                  url.pathComponents[1] == "i" else { return }
            pendingInvite = url.pathComponents[2]
            Task { await redeemPendingInvite() }
        }
        // The link can arrive before login finishes (cold launch into
        // AuthView) — redeeming needs auth.uid(), so retry once it flips.
        .onChange(of: isLoggedIn) { _, loggedIn in
            if loggedIn { Task { await redeemPendingInvite() } }
        }
        .alert("Invite",
               isPresented: Binding(get: { redeemMessage != nil },
                                     set: { if !$0 { redeemMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(redeemMessage ?? "")
        }
        .task {
            // check if there's already a logged-in session
            if (try? await supabase.auth.session) != nil {
                isLoggedIn = true
                await session.refresh()
            }
            checking = false

            // listen for login/logout changes
            for await state in supabase.auth.authStateChanges {
                let loggedIn = state.session != nil
                isLoggedIn = loggedIn
                if loggedIn {
                    await session.refresh()
                } else {
                    session.clear()
                }
            }
        }
    }

    // Consumes pendingInvite exactly once it's redeemable, so the two
    // triggers above (link arrives, login finishes) can both call this
    // without redeeming twice.
    func redeemPendingInvite() async {
        guard isLoggedIn, let code = pendingInvite else { return }
        pendingInvite = nil
        let result = await redeemInvite(code: code)
        redeemMessage = result.message
    }
}

#Preview {
    RootView()
}
