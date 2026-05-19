import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api_service.dart';

class JobProvider with ChangeNotifier {
  List<Job> _jobs = [];
  List<Job> _filteredJobs = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';

  List<Job> get jobs => _filteredJobs.isEmpty && _searchQuery.isEmpty ? _jobs : _filteredJobs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchJobs() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _jobs = await ApiService.fetchJobs();
      _filteredJobs = [];
      _searchQuery = '';
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint("Error fetching jobs: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  void searchJobs(String query) {
    _searchQuery = query.toLowerCase().trim();
    if (_searchQuery.isEmpty) {
      _filteredJobs = [];
    } else {
      _filteredJobs = _jobs.where((job) {
        final titleMatch = job.title.toLowerCase().contains(_searchQuery);
        final companyMatch = job.company.toLowerCase().contains(_searchQuery);
        final locationMatch = job.location.toLowerCase().contains(_searchQuery);
        return titleMatch || companyMatch || locationMatch;
      }).toList();
    }
    notifyListeners();
  }

  Future<void> filterJobsByLocation(String location) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _jobs = await ApiService.fetchJobsByLocation(location);
      _filteredJobs = [];
      _searchQuery = '';
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint("Error fetching jobs by location: $e");
    }

    _isLoading = false;
    notifyListeners();
  }
}