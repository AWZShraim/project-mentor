import SwiftUI

struct AuthView: View {
    @ObservedObject var auth: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var confirmationCode = ""
    @State private var isSigningUp = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Mentor").font(.largeTitle.bold())

            if auth.pendingConfirmation {
                TextField("Confirmation code", text: $confirmationCode)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                Button("Confirm") {
                    Task { await auth.confirmSignUp(email: email, code: confirmationCode) }
                }
                .buttonStyle(.borderedProminent)
            } else {
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)

                Button(isSigningUp ? "Sign Up" : "Sign In") {
                    Task {
                        if isSigningUp {
                            await auth.signUp(email: email, password: password)
                        } else {
                            await auth.signIn(email: email, password: password)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)

                Button(isSigningUp ? "Have an account? Sign in" : "New here? Sign up") {
                    isSigningUp.toggle()
                }
                .font(.footnote)
            }

            if let message = auth.errorMessage {
                Text(message).foregroundStyle(.red).font(.footnote)
            }
        }
        .padding()
    }
}
