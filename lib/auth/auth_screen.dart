import 'package:flutter/material.dart';
import 'package:webs/auth/auth_config.dart';
import 'package:webs/auth/token_service.dart';
import 'package:webs/live_chat/live_chat_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  AuthAccount? _account;
  AuthProject? _project;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final token = TokenService.generate(
        email: _emailCtrl.text.trim(),
        account: _account!.id,
        project: _project!.id,
      );
      await TokenService.saveToken(token);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LiveChat()),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD6C9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    size: 30,
                    color: Color(0xFF1F2330),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Welcome',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2330),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sign in to access your AI agents',
                  style: TextStyle(fontSize: 14, color: Color(0xFF747787)),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE9EAF0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Label('Email address'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          style: const TextStyle(fontSize: 14),
                          decoration: _fieldDecoration(hint: 'you@company.com'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(v.trim())) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        const _Label('Account'),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<AuthAccount>(
                          initialValue: _account,
                          decoration: _fieldDecoration(hint: 'Select account'),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1F2330),
                          ),
                          items: AuthConfig.accounts
                              .map((a) => DropdownMenuItem(
                                    value: a,
                                    child: Text(a.label),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _account = v),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 20),
                        const _Label('GCP Project'),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<AuthProject>(
                          initialValue: _project,
                          decoration: _fieldDecoration(hint: 'Select project'),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1F2330),
                          ),
                          items: AuthConfig.projects
                              .map((p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p.label),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _project = v),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1F2330),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  const Color(0xFF1F2330).withValues(alpha: 0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Continue'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static InputDecoration _fieldDecoration({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFADB5BD)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true,
        fillColor: const Color(0xFFF9FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE9EAF0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE9EAF0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1F2330)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFB42318)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFB42318)),
        ),
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1F2330),
          letterSpacing: 0.2,
        ),
      );
}
