import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onCompleted;
  const OnboardingScreen({super.key, required this.onCompleted});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _districtController = TextEditingController();
  final _schoolStandardController = TextEditingController();
  final _degreeNameController = TextEditingController();

  String _targetExam = 'UPSC'; // 'UPSC' or 'TNPSC'
  String _yearsTrying = '1st Attempt';
  String _educationStatus = 'studying'; // 'studying' or 'graduated'
  String _educationLevel = 'college'; // 'school' or 'college'
  String _collegeDegreeType = 'UG'; // 'UG' or 'PG'

  bool _agreedToPrivacyPolicy = false;
  bool _isSubmitting = false;

  final List<String> _yearsOptions = [
    '1st Attempt',
    '1 Year',
    '2 Years',
    '3 Years',
    '4+ Years',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _districtController.dispose();
    _schoolStandardController.dispose();
    _degreeNameController.dispose();
    super.dispose();
  }

  void _showPrivacyPolicyModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: ListView(
                controller: controller,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Privacy Policy & Terms',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text(
                    '1. Data Collection & Usage',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'ExamPrep collects your name, email, phone number, district, and academic details strictly to personalize your exam practice, track test scores, and provide accurate performance analytics. We never sell or share your personal data with third-party advertisers.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '2. Payment Processing (Razorpay)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Each practice test access fee is ₹1.00 (One Rupee). Payments are processed securely via RBI-compliant payment gateway Razorpay using 128-bit bank-grade encryption. ExamPrep does not store your card, CVV, or UPI PIN credentials.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '3. Instant Access & Refund Terms',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Upon payment capture, the mock test is instantly unlocked for your account. Since test access is delivered digitally and immediately, test purchases are non-refundable once started. For duplicate deductions or technical failures, contact support at manojvip36@gmail.com.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '4. Test Integrity & Fairness',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Exam test timers, negative marking (-0.66 per wrong answer), and score evaluations simulate actual UPSC and TNPSC preliminary exam rules to give you the most accurate benchmark.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() => _agreedToPrivacyPolicy = true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('I Understand & Agree'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitStudentDetails() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreedToPrivacyPolicy) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.red),
              SizedBox(width: 8),
              Text('Mandatory Acceptance'),
            ],
          ),
          content: const Text(
            'You must review and accept the Privacy Policy & Terms of Service by checking the box before proceeding to Test 11.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showPrivacyPolicyModal();
              },
              child: const Text('Read Privacy Policy'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _agreedToPrivacyPolicy = true);
              },
              child: const Text('I Accept'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();

      final studentData = {
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'district': _districtController.text.trim(),
        'target_exam': _targetExam,
        'years_trying': _yearsTrying,
        'education_status': _educationStatus,
        'education_level': _educationStatus == 'studying' ? _educationLevel : 'graduated',
        'school_standard': _educationStatus == 'studying' && _educationLevel == 'school'
            ? _schoolStandardController.text.trim()
            : null,
        'college_degree_type': _educationLevel == 'college' || _educationStatus == 'graduated'
            ? _collegeDegreeType
            : null,
        'college_degree_name': _educationLevel == 'college' || _educationStatus == 'graduated'
            ? _degreeNameController.text.trim()
            : null,
        'created_at': DateTime.now().toIso8601String(),
      };

      // 1. Save locally in device SharedPreferences
      await prefs.setString('student_name', _nameController.text.trim());
      await prefs.setString('student_phone', _phoneController.text.trim());
      await prefs.setString('student_email', _emailController.text.trim());
      await prefs.setString('student_district', _districtController.text.trim());
      await prefs.setString('target_exam', _targetExam);
      await prefs.setBool('onboarding_completed', true);

      // 2. Insert into Supabase if initialized
      try {
        if (Supabase.instance.isInitialized) {
          final res = await Supabase.instance.client
              .from('students')
              .insert(studentData)
              .select('id')
              .maybeSingle();

          if (res != null && res['id'] != null) {
            await prefs.setString('student_id', res['id'].toString());
          }
        }
      } catch (dbError) {
        debugPrint('Supabase sync note: $dbError');
      }

      widget.onCompleted();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving details: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Student Profile Registration'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Welcome to ExamPrep!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Please fill in your details to customize your prelims mock tests.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 24),

                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
                ),
                const SizedBox(height: 16),

                // Phone
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().length < 10) ? 'Enter valid 10-digit phone number' : null,
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address *',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email address' : null,
                ),
                const SizedBox(height: 16),

                // District
                TextFormField(
                  controller: _districtController,
                  decoration: const InputDecoration(
                    labelText: 'District / City *',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your district' : null,
                ),
                const SizedBox(height: 24),

                // Target Exam selection
                const Text(
                  'Which Exam are you preparing for? *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('UPSC Civil Services')),
                        selected: _targetExam == 'UPSC',
                        selectedColor: const Color(0xFF1E3A8A),
                        labelStyle: TextStyle(
                          color: _targetExam == 'UPSC' ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _targetExam = 'UPSC');
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('TNPSC Group Services')),
                        selected: _targetExam == 'TNPSC',
                        selectedColor: const Color(0xFF047857),
                        labelStyle: TextStyle(
                          color: _targetExam == 'TNPSC' ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _targetExam = 'TNPSC');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Years trying
                const Text(
                  'How many years have you been preparing? *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _yearsTrying,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.timeline_outlined),
                  ),
                  items: _yearsOptions.map((opt) {
                    return DropdownMenuItem(value: opt, child: Text(opt));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _yearsTrying = val);
                  },
                ),
                const SizedBox(height: 20),

                // Studying or Graduated
                const Text(
                  'Are you currently Studying or Graduated? *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Studying'),
                        value: 'studying',
                        groupValue: _educationStatus,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setState(() => _educationStatus = val!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Graduated'),
                        value: 'graduated',
                        groupValue: _educationStatus,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setState(() => _educationStatus = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // If studying: School or College?
                if (_educationStatus == 'studying') ...[
                  const Text(
                    'Studying in School or College? *',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('School'),
                          value: 'school',
                          groupValue: _educationLevel,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) => setState(() => _educationLevel = val!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('College'),
                          value: 'college',
                          groupValue: _educationLevel,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) => setState(() => _educationLevel = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_educationLevel == 'school') ...[
                    TextFormField(
                      controller: _schoolStandardController,
                      decoration: const InputDecoration(
                        labelText: 'Standard / Class (e.g. 10th, 11th, 12th) *',
                        prefixIcon: Icon(Icons.school_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (_educationStatus == 'studying' && _educationLevel == 'school' && (v == null || v.trim().isEmpty))
                          ? 'Please specify your standard'
                          : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                ],

                // If college or graduated: UG/PG and Degree Name
                if (_educationStatus == 'graduated' || (_educationStatus == 'studying' && _educationLevel == 'college')) ...[
                  const Text(
                    'Degree Category *',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('UG (Undergraduate)'),
                          value: 'UG',
                          groupValue: _collegeDegreeType,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) => setState(() => _collegeDegreeType = val!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('PG (Postgraduate)'),
                          value: 'PG',
                          groupValue: _collegeDegreeType,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) => setState(() => _collegeDegreeType = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _degreeNameController,
                    decoration: const InputDecoration(
                      labelText: 'Degree & Major (e.g. B.E Mechanical, B.Sc Maths, B.A History) *',
                      prefixIcon: Icon(Icons.school_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your degree name' : null,
                  ),
                  const SizedBox(height: 20),
                ],

                // Mandatory Privacy Policy & Terms Checkbox
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _agreedToPrivacyPolicy ? Colors.indigo.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _agreedToPrivacyPolicy ? Colors.indigo.shade200 : Colors.red.shade200,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: _agreedToPrivacyPolicy,
                        activeColor: const Color(0xFF1E3A8A),
                        onChanged: (val) {
                          setState(() => _agreedToPrivacyPolicy = val ?? false);
                        },
                      ),
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'I agree to the ',
                              style: TextStyle(fontSize: 13),
                            ),
                            InkWell(
                              onTap: _showPrivacyPolicyModal,
                              child: const Text(
                                'Privacy Policy & Terms *',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A8A),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            const Text(
                              ' (Mandatory)',
                              style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitStudentDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Save & Start Preparing',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
