import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api_service.dart';

class SavedJobsProvider with ChangeNotifier {
  List<Job> _savedJobs = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Job> get savedJobs => _savedJobs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  // Get list of saved job IDs
  List<int> get savedJobIds => _savedJobs.map((job) => job.id).toList();

  // Fetch saved jobs from backend
  Future<void> fetchSavedJobs() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _savedJobs = await ApiService.fetchSavedJobs();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint("Error fetching saved jobs: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  // Save a job to backend
  Future<void> saveJob(Job job) async {
    try {
      await ApiService.saveJob(job.id);
      
      // Add to local list if not already there
      if (!_savedJobs.any((savedJob) => savedJob.id == job.id)) {
        _savedJobs.add(job);
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint("Error saving job: $e");
      notifyListeners();
      rethrow;
    }
  }

  // Remove a saved job from backend
  Future<void> removeSavedJob(int jobId) async {
    try {
      await ApiService.removeSavedJob(jobId);
      
      _savedJobs.removeWhere((job) => job.id == jobId);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint("Error removing saved job: $e");
      notifyListeners();
      rethrow;
    }
  }

  // Check if a job is saved
  bool isSaved(int jobId) {
    return _savedJobs.any((job) => job.id == jobId);
  }
}