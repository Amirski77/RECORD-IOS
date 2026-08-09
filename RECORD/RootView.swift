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
    @State private var isLoggedIn = false
    @State private var checking = true

    var body: some View {
        Group {
            if checking {
                // brief loading while we check for an existing session
                Color.recordBG.ignoresSafeArea()
            } else if isLoggedIn {
                MainTabView()
                    .environmentObject(session)
            } else {
                AuthView()
            }
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
}

#Preview {
    RootView()
}
