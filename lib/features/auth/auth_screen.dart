part of 'package:carbonfeet/main.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.onSubmit,
    this.isSubmitting = false,
    super.key,
  });

  final Future<String?> Function(String email, String password, AuthMode mode)
  onSubmit;
  final bool isSubmitting;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  AuthMode _mode = AuthMode.register;
  String? _emailError;
  String? _passwordError;
  String? _formError;

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
                      onSelectionChanged: widget.isSubmitting
                          ? null
                          : (selection) {
                              setState(() {
                                _mode = selection.first;
                                _clearErrors();
                              });
                            },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !widget.isSubmitting,
                      onChanged: (_) {
                        if (_emailError == null && _formError == null) {
                          return;
                        }
                        setState(() {
                          _emailError = null;
                          _formError = null;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: const OutlineInputBorder(),
                        errorText: _emailError,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      enabled: !widget.isSubmitting,
                      onChanged: (_) {
                        if (_passwordError == null && _formError == null) {
                          return;
                        }
                        setState(() {
                          _passwordError = null;
                          _formError = null;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        errorText: _passwordError,
                      ),
                    ),
                    if (_formError != null) ...[
                      const SizedBox(height: 10),
                      Text(_formError!, style: const TextStyle(color: Colors.red)),
                    ],
                    if (widget.isSubmitting) ...[
                      const SizedBox(height: 10),
                      const Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Submitting...'),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: widget.isSubmitting ? null : _submit,
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

  Future<void> _submit() async {
    if (widget.isSubmitting) {
      return;
    }

    final normalizedEmail = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final emailError = InputValidation.validateEmail(normalizedEmail);
    final passwordError = _mode == AuthMode.register
        ? InputValidation.validatePassword(password)
        : (password.isEmpty ? 'Enter your password.' : null);
    if (emailError != null || passwordError != null) {
      setState(() {
        _emailError = emailError;
        _passwordError = passwordError;
        _formError = null;
      });
      return;
    }

    final error = await widget.onSubmit(normalizedEmail, password, _mode);
    if (!mounted) {
      return;
    }
    setState(() {
      _clearErrors();
      if (error == null) {
        return;
      }
      if (error == 'An account for this email already exists.') {
        _emailError = error;
        return;
      }
      if (error == 'Incorrect email or password.') {
        _formError = error;
        return;
      }
      if (error.contains('email')) {
        _emailError = error;
        return;
      }
      if (error.contains('Password') || error.contains('password')) {
        _passwordError = error;
        return;
      }
      _formError = error;
    });
  }

  void _clearErrors() {
    _emailError = null;
    _passwordError = null;
    _formError = null;
  }
}
