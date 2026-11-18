//
//  AuthView.swift
//  RECORD
//
//  Created by Amir Rashidov on 28.06.2026.
//

import SwiftUI
import Supabase

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
                        TextField("", text: $username, prompt: Text("Username").foregroundColor(.recordTertiary))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding()
                            .background(Color.recordSeparator)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(Color.recordText)
                    }

                    TextField("", text: $email, prompt: Text("Email").foregroundColor(.recordTertiary))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(Color.recordSeparator)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(Color.recordText)

                    SecureField("", text: $password, prompt: Text("Password").foregroundColor(.recordTertiary))
                        .padding()
                        .background(Color.recordSeparator)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(Color.recordText)
                }
                // ERROR MESSAGE
                if let errorMessage {
                    Text(errorMessage)
                        .font(.sans(12))
                        .foregroundStyle(Color.recordDestructive)
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
                        .background(Color.recordAccent)
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
                        .foregroundStyle(Color.recordSecondary)
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
            AppLog.quiet(isSignUp ? "sign up" : "log in", error)
            let text = String(describing: error).lowercased()
            if isSignUp, text.contains("duplicate key") || text.contains("database error") {
                // Almost always profiles_username_lower_key: someone took the
                // name between the check above and the insert.
                errorMessage = "That username was just taken. Try another."
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    func signUp() async throws {
        let name = username.trimmingCharacters(in: .whitespaces)

        guard !name.isEmpty else {
            errorMessage = "Pick a username."
            return
        }
        guard Self.isWellFormed(name) else {
            errorMessage = "Usernames are 2–20 characters, using letters, numbers, dots or underscores."
            return
        }
        // A courtesy check so the common case gets a clear message. It is not
        // the guard — profiles_username_lower_key is, and it settles the race
        // between two people claiming one name at the same moment.
        guard await isUsernameAvailable(name) else {
            errorMessage = "“\(name)” is taken. Try another."
            return
        }

        // The profile row is created by the on_auth_user_created trigger, in
        // the same transaction as the account, from this metadata. It is
        // deliberately NOT a second request from here: a separate insert that
        // could fail on its own is what used to leave accounts that can log
        // in but have no profile.
        try await supabase.auth.signUp(
            email: email,
            password: password,
            data: ["username": .string(name)]
        )
    }

    /// Mirrors the profiles_username_shape constraint, so the message comes
    /// from here rather than from Postgres.
    static func isWellFormed(_ name: String) -> Bool {
        (2...20).contains(name.count)
            && name.allSatisfy { c in
                c.isASCII && (c.isLetter || c.isNumber || c == "." || c == "_")
            }
    }

    /// Case-insensitive, and callable before an account exists.
    func isUsernameAvailable(_ name: String) async -> Bool {
        do {
            return try await supabase
                .rpc("username_available", params: ["u": name])
                .execute()
                .value
        } catch {
            // Couldn't ask. Let the signup attempt and the unique index decide
            // rather than blocking someone on a network blip.
            AppLog.quiet("username availability check", error)
            return true
        }
    }

    func logIn() async throws {
        try await supabase.auth.signIn(email: email, password: password)
    }
}

#Preview {
    AuthView()
}
