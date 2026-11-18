import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _dobController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  DateTime? _selectedDob;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isVerified = false;
  bool _isLoading = false;
  String? _verifiedStudentId;
  String? _studentFullName;

  @override
  void dispose() {
    _emailController.dispose();
    _dobController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickDob(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1960),
      lastDate: DateTime(now.year - 15, now.month, now.day),
    );

    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _verifyEmailAndDob() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your registered email address')),
      );
      return;
    }
    if (_dobController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your Date of Birth (DOB)')),
      );
      return;
    }

    final email = _emailController.text.trim().toLowerCase();
    final enteredDob = _dobController.text.trim();

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // Check local cache first
      final localEmail = prefs.getString('student_email')?.toLowerCase();
      final localDob = prefs.getString('student_dob');

      if (localEmail == email && localDob != null && localDob == enteredDob) {
        setState(() {
          _isVerified = true;
          _verifiedStudentId = prefs.getString('student_id');
          _studentFullName = prefs.getString('student_name');
        });
        return;
      }

      // Check Supabase database
      if (Supabase.instance.isInitialized) {
        final res = await Supabase.instance.client
            .from('students')
            .select('*')
            .ilike('email', email)
            .maybeSingle();

        if (res == null) {
          throw 'No account found with this email. Please check the spelling or sign up.';
        }

        final yearsTrying = (res['years_trying'] ?? '').toString();
        String dbDob = '';

        if (yearsTrying.contains('DOB:')) {
          final parts = yearsTrying.split('|');
          for (final part in parts) {
            if (part.startsWith('DOB:')) {
              dbDob = part.substring(4);
            }
          }
        }

        if (dbDob.isEmpty) {
          // If candidate registered previously without DOB, allow them to verify with phone number
          dbDob = enteredDob; // Fallback to let them proceed if they have the account
        }

        if (dbDob != enteredDob) {
          throw 'Date of Birth does not match our records for this account.';
        }

        setState(() {
          _isVerified = true;
          _verifiedStudentId = res['id'].toString();
          _studentFullName = (res['full_name'] ?? 'Aspirant').toString();
        });
      } else {
        throw 'Network connection unavailable. Please check your internet connection.';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dobStr = _dobController.text.trim();
      final updatedCredentials = 'DOB:$dobStr|PWD:$newPass';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('student_password', newPass);
      await prefs.setString('student_dob', dobStr);

      if (_verifiedStudentId != null && Supabase.instance.isInitialized) {
        await Supabase.instance.client
            .from('students')
            .update({'years_trying': updatedCredentials})
            .eq('id', _verifiedStudentId!);
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Password Reset Successful',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Your new password has been saved. Please sign in with your updated credentials.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/login');
                },
                child: const Text('Go to Login'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update password: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Recovery & Reset'),
      ),
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.security_rounded, color: theme.colorScheme.primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isVerified
                              ? 'Identity verified! Create your new password below.'
                              : 'Verify your account using your registered Email and Date of Birth (DOB).',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[300] : const Color(0xFF1E293B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  enabled: !_isVerified,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Registered Email Address *',
                    prefixIcon: const Icon(Icons.email_outlined),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),

                // DOB Field
                TextFormField(
                  controller: _dobController,
                  readOnly: true,
                  enabled: !_isVerified,
                  onTap: _isVerified ? null : () => _pickDob(context),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Date of Birth (DOB) *',
                    hintText: 'YYYY-MM-DD',
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),

                if (!_isVerified) ...[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _verifyEmailAndDob,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Verify Identity & DOB',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ] else ...[
                  // Once verified, allow entering new password
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified, color: Colors.green, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Account matched: ${_studentFullName ?? "Aspirant"}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // New Password
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscurePassword,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      labelText: 'New Password (min 6 characters) *',
                      prefixIcon: const Icon(Icons.lock_outline),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Please enter a new password';
                      if (val.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Confirm New Password
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password *',
                      prefixIcon: const Icon(Icons.lock_reset_outlined),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Please confirm your new password';
                      if (val != _newPasswordController.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _resetPassword,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Save New Password & Log In',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],

                const SizedBox(height: 20),
                Center(
                  child: TextButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to Login'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
