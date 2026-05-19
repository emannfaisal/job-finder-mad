import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';
import 'signup_page.dart';

class SettingsScreen extends StatefulWidget {
  final Function(int) onNavigate;
  
  const SettingsScreen({super.key, required this.onNavigate});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _jobRoleController;
  late TextEditingController _locationController;
  late TextEditingController _skillInputController;
  final List<String> _skills = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _jobRoleController = TextEditingController();
    _locationController = TextEditingController();
    _skillInputController = TextEditingController();
    
    // Add listeners to update progress
    _nameController.addListener(() => setState(() {}));
    _emailController.addListener(() => setState(() {}));
    _jobRoleController.addListener(() => setState(() {}));
    _locationController.addListener(() => setState(() {}));
    
    Future.microtask(() {
      if (mounted) {
        Provider.of<UserProvider>(context, listen: false).fetchUserProfile();
        _loadUserData();
      }
    });
  }

  Future<void> _loadUserData() async {
    try {
      // Load user profile
      final userProfile = await ApiService.getCurrentUserProfile();
      if (mounted) {
        setState(() {
          _nameController.text = userProfile['name'] ?? '';
          _emailController.text = userProfile['email'] ?? '';
          // Handle cases where backend columns might not exist yet
          _jobRoleController.text = userProfile['preferred_job_title'] ?? userProfile['job_title'] ?? '';
          _locationController.text = userProfile['preferred_location'] ?? userProfile['location'] ?? '';
        });
      }

      // Load user skills
      final skills = await ApiService.getUserSkills();
      if (mounted) {
        setState(() {
          _skills.clear();
          for (var skill in skills) {
            _skills.add(skill['skill_name'] ?? '');
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: Check backend database schema'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Update user profile
      await ApiService.updateUserProfile(
        name: _nameController.text,
        email: _emailController.text,
        preferredJobTitle: _jobRoleController.text.isNotEmpty ? _jobRoleController.text : null,
        preferredLocation: _locationController.text.isNotEmpty ? _locationController.text : null,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addSkill(String skillName) async {
    if (skillName.isEmpty || _skills.contains(skillName)) {
      return;
    }

    try {
      await ApiService.addUserSkill(skillName);
      if (mounted) {
        setState(() {
          _skills.add(skillName);
          _skillInputController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding skill: $e')),
        );
      }
    }
  }

  Future<void> _removeSkill(String skillName) async {
    try {
      await ApiService.removeUserSkillByName(skillName);
      if (mounted) {
        setState(() {
          _skills.remove(skillName);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing skill: $e')),
        );
      }
    }
  }

  // Calculate profile completion percentage
  double _getProfileCompletion() {
    int filledFields = 0;
    int totalFields = 5; // name, email, job role, location, skills

    if (_nameController.text.isNotEmpty) filledFields++;
    if (_emailController.text.isNotEmpty) filledFields++;
    if (_jobRoleController.text.isNotEmpty) filledFields++;
    if (_locationController.text.isNotEmpty) filledFields++;
    if (_skills.isNotEmpty) filledFields++;

    return filledFields / totalFields;
  }

  // Get progress message and icon based on completion
  Map<String, dynamic> _getProgressMessage() {
    final completion = _getProfileCompletion();
    final percentage = (completion * 100).toInt();

    if (completion == 0) {
      return {
        'message': 'Start by filling your basic info',
        'icon': Icons.edit_outlined,
        'color': const Color(0xFFFF9800),
        'percentage': percentage,
      };
    } else if (completion < 0.4) {
      return {
        'message': 'Just getting started! Keep going!',
        'icon': Icons.trending_up,
        'color': const Color(0xFFFF9800),
        'percentage': percentage,
      };
    } else if (completion < 0.6) {
      return {
        'message': 'Halfway there! Almost done!',
        'icon': Icons.auto_awesome,
        'color': const Color(0xFF9117FF),
        'percentage': percentage,
      };
    } else if (completion < 1.0) {
      return {
        'message': 'Almost complete! Final touches needed!',
        'icon': Icons.star_half,
        'color': const Color(0xFF2196F3),
        'percentage': percentage,
      };
    } else {
      return {
        'message': '🎉 Profile complete! Great job!',
        'icon': Icons.check_circle,
        'color': const Color(0xFF4CAF50),
        'percentage': percentage,
      };
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _jobRoleController.dispose();
    _locationController.dispose();
    _skillInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryPurple = Color(0xFF9117FF);
    const Color lightBg = Color(0xFFFAFAFA);
    const Color cardBorder = Color(0xFFEFEFEF);
    
    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        backgroundColor: lightBg,
        elevation: 0,
        toolbarHeight: 90,
        title: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "My Profile",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "Personalize your job search experience",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          final userName = userProvider.userName;
          final userEmail = userProvider.userEmail;
          final firstLetter = userName.isNotEmpty ? userName[0].toUpperCase() : 'D';

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. PROGRESS CARD
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 65,
                            height: 65,
                            decoration: BoxDecoration(
                              color: primaryPurple,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              firstLetter,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName.isNotEmpty ? userName : "Demo User",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  userEmail.isNotEmpty ? userEmail : "user@gmail.com",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Builder(
                        builder: (context) {
                          final progressData = _getProgressMessage();
                          final completion = _getProfileCompletion();
                          final percentage = progressData['percentage'];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(progressData['icon'], color: progressData['color'], size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        progressData['message'],
                                        style: TextStyle(
                                          color: progressData['color'],
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    "$percentage%",
                                    style: TextStyle(
                                      color: progressData['color'],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: completion,
                                  minHeight: 8,
                                  backgroundColor: const Color(0xFFF1E6FF),
                                  valueColor: AlwaysStoppedAnimation<Color>(progressData['color']),
                                ),
                              ),
                              const SizedBox(height: 14),
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                                  children: [
                                    TextSpan(
                                      text: completion == 1.0
                                          ? "Your profile is complete! You'll get "
                                          : "Complete your profile to get ",
                                    ),
                                    TextSpan(
                                      text: "better-matched job recommendations.",
                                      style: TextStyle(color: progressData['color'], fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 2. BASIC INFO SECTION
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader("BASIC INFO"),
                      const SizedBox(height: 16),
                      _buildInputLabel(Icons.person_outline, "Full Name"),
                      const SizedBox(height: 8),
                      _buildEditableField(_nameController, "Enter your full name"),
                      const SizedBox(height: 20),
                      _buildInputLabel(Icons.mail_outline, "Email Address"),
                      const SizedBox(height: 8),
                      _buildEditableField(_emailController, "Enter your email"),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 3. JOB PREFERENCES SECTION
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader("JOB PREFERENCES"),
                      const SizedBox(height: 16),
                      _buildInputLabel(Icons.business_center_outlined, "Preferred Job Role"),
                      const SizedBox(height: 8),
                      _buildEditableField(_jobRoleController, "e.g. Frontend Engineer, Product Manager"),
                      const SizedBox(height: 20),
                      _buildInputLabel(Icons.location_on_outlined, "Preferred Location"),
                      const SizedBox(height: 8),
                      _buildEditableField(_locationController, "e.g. Remote, New York, London"),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 4. SKILLS SECTION
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader("SKILLS"),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _skillInputController,
                              decoration: InputDecoration(
                                hintText: "Type a skill and press Enter",
                                hintStyle: TextStyle(color: Colors.grey.shade400),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFF9117FF), width: 1.5),
                                ),
                              ),
                              onSubmitted: (value) {
                                _addSkill(value);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              _addSkill(_skillInputController.text);
                            },
                            child: Container(
                              height: 50,
                              width: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFF9117FF),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.add, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Quick add:",
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._skills.map((skill) => _buildSkillChipRemovable(skill)),
                          ...(["React", "TypeScript", "Python", "Node.js", "SQL", "AWS", "Docker"]
                              .where((s) => !_skills.contains(s))
                              .map((skill) => _buildSkillChipAddable(skill))
                              .toList()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      RichText(
                        text: TextSpan(
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                          children: const [
                            TextSpan(text: "Press "),
                            TextSpan(text: "Enter", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                            TextSpan(text: " or click "),
                            TextSpan(text: "+ ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                            TextSpan(text: " to add a skill"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 5. SAVE PROFILE BUTTON
                ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPurple,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Save Profile",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 6. ACCOUNT / LOG OUT SECTION
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                        child: _buildSectionHeader("ACCOUNT"),
                      ),
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                        ),
                        title: const Text(
                          "Log Out",
                          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Colors.redAccent, size: 20),
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          await FirebaseAuth.instance.signOut();
                          if (mounted) {
                            navigator.pushAndRemoveUntil(
                              MaterialPageRoute(builder: (context) => const MyApp()),
                              (route) => false,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // BOTTOM DEMO TEXT BANNER
                Center(
                  child: Text(
                    "Demo app - data stored locally in your browser",
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ));
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2, 
        selectedItemColor: const Color(0xFF9117FF),
        unselectedItemColor: Colors.grey.shade400,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        onTap: (index) {
          widget.onNavigate(index);
        },
        items: const [
          BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.home_outlined)), label: 'Home'),
          BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.bookmark_outline)), label: 'Saved'),
          BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.circle, size: 22)), label: 'Profile'),
          BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.lightbulb_outline)), label: 'Recommended'),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.blueGrey,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildInputLabel(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.black54),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEditableField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF9117FF), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSkillChipRemovable(String label) {
    return GestureDetector(
      onTap: () {
        _removeSkill(label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1E6FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF9117FF), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(color: Color(0xFF9117FF), fontWeight: FontWeight.w500, fontSize: 13),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.close, color: Color(0xFF9117FF), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillChipAddable(String label) {
    return GestureDetector(
      onTap: () {
        _addSkill(label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "+ ",
              style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              label,
              style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }}