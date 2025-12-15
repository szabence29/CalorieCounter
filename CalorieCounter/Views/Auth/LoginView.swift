import SwiftUI
import FirebaseAuth           // Email/jelszó és 3rd-party auth Firebase-hez
import FirebaseCore           // FirebaseApp hozzáférés (clientID kinyerése)
import GoogleSignIn           // Google bejelentkezés
import AuthenticationServices  // (Előkészítve Apple Sign In-hez; itt még nincs használva)

struct LoginView: View {
    // ── UI állapot és űrlapmezők ────────────────────────────────────────────────
    @State private var email = ""               // email mező
    @State private var password = ""            // jelszó mező
    @State private var confirmPassword = ""     // jelszó megerősítés regisztrációnál
    @State private var isRegistering = false    // login <-> regisztráció mód
    @State private var showAlert = false        // alert láthatósága
    @State private var alertMessage = ""        // alert szöveg
    @State private var isLoggedIn = false       // sikeres auth után true

    @Environment(\.colorScheme) var colorScheme // dark/light mód (ha kell)

    var body: some View {
        NavigationView { // iOS 16-tól inkább NavigationStack javasolt
            VStack(spacing: 20) {

                // App név / logó
                Text("Calorie Counter")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 30)

                // Email mező
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                // Jelszó mező
                SecureField("Password", text: $password)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                // Csak regisztrációs módban jelenik meg
                if isRegistering {
                    SecureField("Confirm Password", text: $confirmPassword)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }

                // Fő műveleti gomb: regisztráció vagy bejelentkezés
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

                // Módváltó gomb (login <-> reg)
                Button(action: {
                    isRegistering.toggle()
                    password = ""         // váltáskor mezők ürítése
                    confirmPassword = ""
                }) {
                    Text(isRegistering
                         ? "Already have an account? Login"
                         : "Don't have an account? Register")
                        .foregroundColor(.blue)
                }

                // 3rd party bejelentkezés (Google)
                VStack(spacing: 15) {
                    Text("OR")
                        .foregroundColor(.gray)

                    Button(action: signInWithGoogle) {
                        HStack {
                            Image(systemName: "g.circle.fill")
                                .foregroundColor(.red) // ikon jelzés
                            Text("Sign in with Google")
                                .fontWeight(.medium)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    // Apple sign in gomb
                }

                Spacer()
            }
            .padding()
            // Hiba/siker üzenetek megjelenítése
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Message"),
                      message: Text(alertMessage),
                      dismissButton: .default(Text("OK")))
            }
            .navigationBarHidden(true) // fejléc elrejtése (NavigationView mellett)
        }
        // Sikeres auth után teljes képernyőn megnyitja a fő UI-t
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

    // ── Google Sign-In, majd Firebase-be beléptetés Google credentiallel ──────
    private func signInWithGoogle() {
        // ClientID kinyerése a Firebase konfigurációból
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }

        // Google konfiguráció beállítása
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // Szükség van egy prezentáló view controllerre (UIKit)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else { return }

        // Google bejelentkezési flow indítása
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error = error {
                alertMessage = error.localizedDescription
                showAlert = true
                return
            }

            // Siker: tokenek kinyerése Google-tól
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else { return }

            // Firebase credential létrehozása Google tokenekből
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: user.accessToken.tokenString)

            // Beléptetés Firebase-be a Google credentiallel
            Auth.auth().signIn(with: credential) { result, error in
                if let error = error {
                    alertMessage = error.localizedDescription
                    showAlert = true
                } else {
                    isLoggedIn = true
                }
            }
        }
    }
}
