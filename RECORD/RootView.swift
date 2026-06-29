//
//  RootView.swift
//  RECORD
//
//  Created by Amir Rashidov on 29.06.2026.
//

import SwiftUI
import Supabase

struct RootView: View {
    @State private var isLoggedIn = false
    @State private var checking = true

    var body: some View {
        Group {
            if checking {
                // brief loading while we check for an existing session
                Color.recordBG.ignoresSafeArea()
            } else if isLoggedIn {
                ContentView()
            } else {
                AuthView()
            }
        }
        .task {
            // check if there's already a logged-in session
            if let _ = try? await supabase.auth.session {
                isLoggedIn = true
            }
            checking = false

            // listen for login/logout changes
            for await state in supabase.auth.authStateChanges {
                isLoggedIn = state.session != nil
            }
        }
    }
}

#Preview {
    RootView()
}
