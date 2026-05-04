class AuthConfig {
  // HS256 secret used to sign JWT tokens — must match the server's verification secret.
  static const String jwtSecret = 'REPLACE_WITH_YOUR_JWT_SECRET';

  static const List<AuthAccount> accounts = [
    AuthAccount(id: 'mobile_universe_api', label: 'Mobile Universe'),
    AuthAccount(id: 'lehner_versand', label: 'Lehner Versand'),
  ];

  static const List<AuthProject> projects = [
    AuthProject(id: 'win-p-mobileuniverse', label: 'Win-P Mobile Universe'),
    AuthProject(id: 'rtux-sandbox', label: 'RTUX Sandbox'),
  ];
}

class AuthAccount {
  final String id;
  final String label;
  const AuthAccount({required this.id, required this.label});
}

class AuthProject {
  final String id;
  final String label;
  const AuthProject({required this.id, required this.label});
}
