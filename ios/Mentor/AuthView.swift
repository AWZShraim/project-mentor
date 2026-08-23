import SwiftUI

struct AuthView: View {
    @ObservedObject var auth: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var confirmationCode = ""
    @State private var isSigningUp = false

    var body: some View {
        VStack(spacing: 18) {
            Text("Mentor")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(Theme.purple)
                .shadow(color: Theme.purple.opacity(0.5), radius: 16)

            VStack(spacing: 12) {
                if auth.pendingConfirmation {
                    TextField("Confirmation code", text: $confirmationCode)
                        .textFieldStyle(.themed)
                        .keyboardType(.numberPad)
                    Button("Confirm") {
                        Task { await auth.confirmSignUp(email: email, code: confirmationCode) }
                    }
                    .buttonStyle(.mentorPrimary)
                } else {
                    TextField("Email", text: $email)
                        .textFieldStyle(.themed)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    SecureField("Password", text: $password)
                        .textFieldStyle(.themed)

                    Button(isSigningUp ? "Sign Up" : "Sign In") {
                        Task {
                            if isSigningUp {
                                await auth.signUp(email: email, password: password)
                            } else {
                                await auth.signIn(email: email, password: password)
                            }
                        }
                    }
                    .buttonStyle(.mentorPrimary)

                    Button(isSigningUp ? "Have an account? Sign in" : "New here? Sign up") {
                        isSigningUp.toggle()
                    }
                    .font(.footnote)
                    .foregroundStyle(Theme.blue)
                }

                if let message = auth.errorMessage {
                    Text(message).foregroundStyle(Theme.danger).font(.footnote)
                }
            }
            .cardStyle(padding: 20)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}
