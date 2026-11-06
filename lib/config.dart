import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _username = TextEditingController();
  bool _register = false;
  bool _busy = false;

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pw = _password.text;
    if (email.isEmpty || pw.length < 8) {
      _msg('Bitte E-Mail und ein Passwort mit mindestens 8 Zeichen eingeben.');
      return;
    }
    setState(() => _busy = true);
    final auth = Supabase.instance.client.auth;
    try {
      if (_register) {
        final name = _username.text.trim();
        if (name.length < 3) {
          _msg('Der Name braucht mindestens 3 Zeichen.');
          return;
        }
        await auth.signUp(email: email, password: pw, data: {'username': name});
        _msg('Fast geschafft: Bitte bestätige die E-Mail, die wir dir geschickt haben.');
        setState(() => _register = false);
      } else {
        await auth.signInWithPassword(email: email, password: pw);
      }
    } on AuthException catch (e) {
      _msg(e.message);
    } catch (_) {
      _msg('Das hat nicht geklappt. Prüfe deine Internetverbindung.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _msg(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Spielregal',
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(fontWeight: FontWeight.w800, color: cs.primary)),
                  const SizedBox(height: 4),
                  const Text('Spiele teilen statt stapeln.'),
                  const SizedBox(height: 28),
                  if (_register) ...[
                    TextField(
                      controller: _username,
                      decoration: const InputDecoration(
                          labelText: 'Spitzname', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                        labelText: 'E-Mail', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(
                        labelText: 'Passwort (mind. 8 Zeichen)',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(_register ? 'Konto erstellen' : 'Anmelden'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _register = !_register),
                    child: Text(_register
                        ? 'Ich habe schon ein Konto'
                        : 'Neu hier? Konto erstellen'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
