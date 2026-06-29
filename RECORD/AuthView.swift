//
//  AuthView.swift
//  RECORD
//
//  Created by Amir Rashidov on 28.06.2026.
//

import SwiftUI
import Supabase

struct Profile: Codable {
    let id: UUID
    let username: String
}

struct AuthView: View {
    // STATE — these remember what the user types and does
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.recordBG
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                // WORDMARK
                Text("RECORD")
                    .font(.display(28, .bold))
                    .tracking(3)
                    .foregroundStyle(Color.recordText)

                Text(isSignUp ? "Create your account" : "Welcome back")
                    .font(.display(20, .bold))
                    .foregroundStyle(Color.recordText)
                
                // FIELDS
                VStack(spacing: 12) {
                    if isSignUp {
                        TextField("", text: $username, prompt: Text("Username").foregroundColor(.recordDim))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding()
                            .background(Color.recordSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(Color.recordText)
                    }

                    TextField("", text: $email, prompt: Text("Email").foregroundColor(.recordDim))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(Color.recordSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(Color.recordText)

                    SecureField("", text: $password, prompt: Text("Password").foregroundColor(.recordDim))
                        .padding()
                        .background(Color.recordSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(Color.recordText)
                }
                // ERROR MESSAGE
                if let errorMessage {
                    Text(errorMessage)
                        .font(.sans(12))
                        .foregroundStyle(Color.recordGreen)
                }
                
                // MAIN BUTTON
                Button {
                    Task { await handleAuth() }
                } label: {
                    Text(isLoading ? "..." : (isSignUp ? "Sign Up" : "Log In"))
                        .font(.sans(15, .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.recordGreen)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                
                // TOGGLE
                Button {
                    isSignUp.toggle()
                    errorMessage = nil
                } label: {
                    Text(isSignUp ? "Already have an account? Log in" : "No account? Sign up")
                        .font(.sans(13))
                        .foregroundStyle(Color.recordMuted)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(24)
        }
    }

    func handleAuth() async {
        errorMessage = nil //clear old errors
        isLoading = true  // show we're busy
        defer { isLoading = false } // ALWAYS turn off busy when done

        do {
            if isSignUp {
                try await signUp()
            } else {
                try await logIn()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUp() async throws {
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Pick a username."
            return
        }

        let response = try await supabase.auth.signUp(email: email, password: password)
        let userID = response.user.id

        let profile = Profile(id: userID, username: username.trimmingCharacters(in: .whitespaces))
        try await supabase
            .from("profiles")
            .insert(profile)
            .execute()
    }

    func logIn() async throws {
        try await supabase.auth.signIn(email: email, password: password)
    }
}

#Preview {
    AuthView()
}
