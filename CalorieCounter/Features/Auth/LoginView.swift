import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isRegistering = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoggedIn = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Logo or app name
                Text("Calorie Counter")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 30)
                
                // Form fields
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                
                SecureField("Password", text: $password)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                
                if isRegistering {
                    SecureField("Confirm Password", text: $confirmPassword)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                
                // Action button
                Button(action: {
                    isRegistering ? registerUser() : loginUser()
                }) {
                    Text(isRegistering ? "Register" : "Login")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                
                // Toggle between login and register
                Button(action: {
                    isRegistering.toggle()
                    password = ""
                    confirmPassword = ""
                }) {
                    Text(isRegistering ? "Already have an account? Login" : "Don't have an account? Register")
                        .foregroundColor(.blue)
                }
                
                Spacer()
            }
            .padding()
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Message"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .navigationBarHidden(true)
        }
        .fullScreenCover(isPresented: $isLoggedIn) {
            MainTabBar()
        }
    }
    
    private func registerUser() {
        if password != confirmPassword {
            alertMessage = "Passwords do not match"
            showAlert = true
            return
        }
        
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                alertMessage = error.localizedDescription
                showAlert = true
            } else {
                alertMessage = "Registration successful!"
                showAlert = true
                isLoggedIn = true
            }
        }
    }
    
    private func loginUser() {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                alertMessage = error.localizedDescription
                showAlert = true
            } else {
                isLoggedIn = true
            }
        }
    }
}
