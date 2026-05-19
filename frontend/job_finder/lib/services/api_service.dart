import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models.dart';

class ApiService {
  // IMPORTANT: change this to your backend URL
  static const String baseUrl = "http://192.168.100.72:8000";

  static Future<String> _getToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated. Please log in again.');
    }
    
    try {
      final token = await user.getIdToken(true); // Force refresh token
      if (token == null || token.isEmpty) {
        throw Exception('Failed to get authentication token');
      }
      debugPrint('API: Token obtained successfully');
      return token;
    } catch (e) {
      debugPrint('API ERROR: Failed to get token: $e');
      throw Exception('Authentication error: $e');
    }
  }

  // Sync user after login/signup
  static Future<void> syncUser() async {
    try {
      final token = await _getToken();
      final fullUrl = "$baseUrl/auth/sync-user";
      
      debugPrint('API: Syncing user with backend...');
      debugPrint('API: POST $fullUrl');
      
      final response = await http.post(
        Uri.parse(fullUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'token': token,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout - Backend server not responding');
        },
      );

      debugPrint('API: User sync response status: ${response.statusCode}');
      debugPrint('API: Response: ${response.body}');
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to sync user: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('API ERROR (syncUser): $e');
      rethrow;
    }
  }

  // Fetch all jobs
  static Future<List<Job>> fetchJobs() async {
    try {
      final fullUrl = "$baseUrl/jobs/";
      debugPrint('API: Attempting to fetch jobs from: $fullUrl');
      
      final response = await http.get(Uri.parse(fullUrl)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout - Backend server not responding');
        },
      );

      debugPrint('API: Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        List data = jsonDecode(response.body);
        debugPrint('API: Successfully fetched ${data.length} jobs');

        return data.map((job) => Job.fromJson(job)).toList();
      } else {
        throw Exception("Failed to load jobs: Status ${response.statusCode}");
      }
    } catch (e) {
      debugPrint('API ERROR (fetchJobs): $e');
      rethrow;
    }
  }

  // Fetch jobs by location
  static Future<List<Job>> fetchJobsByLocation(String location) async {
    try {
      final fullUrl = "$baseUrl/jobs/location/$location";
      debugPrint('API: Attempting to fetch jobs from location: $fullUrl');
      
      final response = await http.get(Uri.parse(fullUrl)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout - Backend server not responding');
        },
      );

      debugPrint('API: Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        List data = jsonDecode(response.body);
        debugPrint('API: Successfully fetched ${data.length} jobs from location: $location');

        return data.map((job) => Job.fromJson(job)).toList();
      } else {
        throw Exception("Failed to load jobs from location: Status ${response.statusCode}");
      }
    } catch (e) {
      debugPrint('API ERROR (fetchJobsByLocation): $e');
      rethrow;
    }
  }

  // Save a job
  static Future<void> saveJob(int jobId) async {
    try {
      final token = await _getToken();
      final fullUrl = "$baseUrl/jobs/save";
      
      debugPrint('API: Saving job with ID: $jobId');
      debugPrint('API: POST $fullUrl');
      
      final response = await http.post(
        Uri.parse(fullUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'job_id': jobId}),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout - Backend server not responding');
        },
      );

      debugPrint('API: Save job response status: ${response.statusCode}');
      debugPrint('API: Response: ${response.body}');
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to save job: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('API ERROR (saveJob): $e');
      rethrow;
    }
  }

  // Fetch saved jobs
  static Future<List<Job>> fetchSavedJobs() async {
    try {
      final token = await _getToken();
      final fullUrl = "$baseUrl/users/me/saved-jobs";
      
      debugPrint('API: Fetching saved jobs...');
      debugPrint('API: GET $fullUrl');
      
      final response = await http.get(
        Uri.parse(fullUrl),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout - Backend server not responding');
        },
      );

      debugPrint('API: Fetch saved jobs response status: ${response.statusCode}');
      debugPrint('API: Response: ${response.body}');
      
      if (response.statusCode == 200) {
        List data = jsonDecode(response.body);
        debugPrint('API: Successfully fetched ${data.length} saved jobs');
        return data.map((job) => Job.fromJson(job)).toList();
      } else {
        throw Exception("Failed to load saved jobs: Status ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint('API ERROR (fetchSavedJobs): $e');
      rethrow;
    }
  }

  // Remove a saved job
  static Future<void> removeSavedJob(int jobId) async {
    try {
      final token = await _getToken();
      final fullUrl = "$baseUrl/jobs/unsave";
      
      debugPrint('API: Removing saved job with ID: $jobId');
      debugPrint('API: POST $fullUrl');
      
      final response = await http.post(
        Uri.parse(fullUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'job_id': jobId}),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout - Backend server not responding');
        },
      );

      debugPrint('API: Remove saved job response status: ${response.statusCode}');
      debugPrint('API: Response: ${response.body}');
      if (response.statusCode != 200 && response.statusCode != 201 && response.statusCode != 204) {
        throw Exception('Failed to remove saved job: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('API ERROR (removeSavedJob): $e');
      rethrow;
    }
  }

  // Get current user profile
  static Future<Map<String, dynamic>> getCurrentUserProfile() async {
    try {
      final token = await _getToken();
      final fullUrl = "$baseUrl/users/me";
      
      debugPrint('API: Fetching user profile...');
      debugPrint('API: GET $fullUrl');
      
      final response = await http.get(
        Uri.parse(fullUrl),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout - Backend server not responding');
        },
      );

      debugPrint('API: Get user profile response status: ${response.statusCode}');
      debugPrint('API: Response: ${response.body}');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed: Invalid or expired token. Please log in again.');
      } else {
        throw Exception("Failed to get user profile: Status ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint('API ERROR (getCurrentUserProfile): $e');
      rethrow;
    }
  }

  // Update user profile
  static Future<Map<String, dynamic>> updateUserProfile({
    String? name,
    String? email,
    String? preferredJobTitle,
    String? preferredLocation,
  }) async {
    try {
      final token = await _getToken();
      final fullUrl = "$baseUrl/users/me";
      
      debugPrint('API: Updating user profile...');
      debugPrint('API: PUT $fullUrl');
      
      final response = await http.put(
        Uri.parse(fullUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'preferred_job_title': preferredJobTitle,
          'preferred_location': preferredLocation,
        }..removeWhere((_, v) => v == null)),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout - Backend server not responding');
        },
      );

      debugPrint('API: Update user profile response status: ${response.statusCode}');
      debugPrint('API: Response: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed: Invalid or expired token. Please log in again.');
      } else {
        throw Exception('Failed to update user profile: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('API ERROR (updateUserProfile): $e');
      rethrow;
    }
  }

  // Add user skill
  static Future<Map<String, dynamic>> addUserSkill(String skillName) async {
    try {
      final token = await _getToken();
      final fullUrl = "$baseUrl/users/me/skills";
      
      debugPrint('API: Adding skill: $skillName');
      debugPrint('API: POST $fullUrl');
      debugPrint('API: Token length: ${token.length}');
      
      final response = await http.post(
        Uri.parse(fullUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'skill_name': skillName}),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout - Backend server not responding');
        },
      );

      debugPrint('API: Add skill response status: ${response.statusCode}');
      debugPrint('API: Response: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed: Invalid or expired token. Please log in again.');
      } else {
        throw Exception('Failed to add skill: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('API ERROR (addUserSkill): $e');
      rethrow;
    }
  }

  // Get user skills
  static Future<List<Map<String, dynamic>>> getUserSkills() async {
    try {
      final token = await _getToken();
      final fullUrl = "$baseUrl/users/me/skills";
      
      debugPrint('API: Fetching user skills...');
      debugPrint('API: GET $fullUrl');
      
      final response = await http.get(
        Uri.parse(fullUrl),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout - Backend server not responding');
        },
      );

      debugPrint('API: Get skills response status: ${response.statusCode}');
      debugPrint('API: Response: ${response.body}');
      
      if (response.statusCode == 200) {
        List data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed: Invalid or expired token. Please log in again.');
      } else {
        throw Exception('Failed to get skills: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('API ERROR (getUserSkills): $e');
      rethrow;
    }
  }

  // Remove user skill by name
  static Future<Map<String, dynamic>> removeUserSkillByName(String skillName) async {
    try {
      final token = await _getToken();
      final fullUrl = "$baseUrl/users/me/skills/by-name/$skillName";
      
      debugPrint('API: Removing skill: $skillName');
      debugPrint('API: DELETE $fullUrl');
      
      final response = await http.delete(
        Uri.parse(fullUrl),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout - Backend server not responding');
        },
      );

      debugPrint('API: Remove skill response status: ${response.statusCode}');
      debugPrint('API: Response: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        return response.statusCode == 204 ? {"deleted": true} : jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed: Invalid or expired token. Please log in again.');
      } else {
        throw Exception('Failed to remove skill: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('API ERROR (removeUserSkillByName): $e');
      rethrow;
    }
  }

  // Get personalized job recommendations
  static Future<List<Map<String, dynamic>>> getRecommendations({int limit = 10}) async {
    try {
      final token = await _getToken();
      final fullUrl = "$baseUrl/recommendations?limit=$limit";
      
      debugPrint('API: Fetching recommendations...');
      debugPrint('API: GET $fullUrl');
      
      final response = await http.get(
        Uri.parse(fullUrl),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout - Backend server not responding');
        },
      );

      debugPrint('API: Get recommendations response status: ${response.statusCode}');
      debugPrint('API: Response: ${response.body}');
      
      if (response.statusCode == 200) {
        List data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed: Invalid or expired token. Please log in again.');
      } else {
        throw Exception('Failed to get recommendations: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('API ERROR (getRecommendations): $e');
      rethrow;
    }
  }
}