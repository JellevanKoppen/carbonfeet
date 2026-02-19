part of 'package:carbonfeet/main.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({required this.onSubmit, super.key});

  final String? Function(String email, String password, AuthMode mode) onSubmit;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  AuthMode _mode = AuthMode.register;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE4F2E8), Color(0xFFF8F4EA)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              margin: const EdgeInsets.all(20),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'CarbonFeet',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Track your footprint. Improve with clarity.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SegmentedButton<AuthMode>(
                      selected: <AuthMode>{_mode},
                      segments: const [
                        ButtonSegment(
                          value: AuthMode.register,
                          label: Text('Create account'),
                        ),
                        ButtonSegment(
                          value: AuthMode.login,
                          label: Text('Log in'),
                        ),
                      ],
                      onSelectionChanged: (selection) {
                        setState(() {
                          _mode = selection.first;
                          _error = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _submit,
                      child: Text(
                        _mode == AuthMode.register
                            ? 'Create account'
                            : 'Log in',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    final error = widget.onSubmit(
      _emailController.text,
      _passwordController.text,
      _mode,
    );

    setState(() {
      _error = error;
    });
  }
}
