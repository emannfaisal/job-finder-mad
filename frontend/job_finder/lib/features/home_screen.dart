import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/job_provider.dart';
import '../providers/saved_jobs_provider.dart';
import 'saved.dart';
import 'setting.dart';
import 'recommended.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late TextEditingController _searchController;
  int _currentIndex = 0;
  String? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    Future.microtask(() {
      if (mounted) {
        Provider.of<JobProvider>(context, listen: false).fetchJobs();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex == 1) {
      return SavedJobsScreen(
        onNavigate: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      );
    }
    
    if (_currentIndex == 2) {
      return SettingsScreen(
        onNavigate: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      );
    }

    if (_currentIndex == 3) {
      return RecommendedScreen(
        onNavigate: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SEARCH BAR SECTION
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                onChanged: (query) {
                  Provider.of<JobProvider>(context, listen: false).searchJobs(query);
                },
                decoration: InputDecoration(
                  hintText: 'Search jobs by title, company, or location',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Colors.grey, width: 0.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Colors.grey, width: 0.5),
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  _buildFilterChip("All", true),
                  const SizedBox(width: 8),
                  _buildFilterChip("Lahore", false),
                  const SizedBox(width: 8),
                  _buildFilterChip("Faisalabad", false),
                  const SizedBox(width: 8),
                  _buildFilterChip("Multan", false),
                  const SizedBox(width: 8),
                  _buildFilterChip("Karachi", false),
                ],
              ),
            ),
            // JOB COUNT HEADER
            Consumer<JobProvider>(
              builder: (context, provider, child) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    "${provider.jobs.length} Jobs Found",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D1B2A),
                    ),
                  ),
                );
              },
            ),
            Expanded(
              child: Consumer<JobProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (provider.jobs.isEmpty) {
                    return const Center(child: Text("No jobs found"));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: provider.jobs.length,
                    itemBuilder: (context, index) {
                      final job = provider.jobs[index];
                      return _buildJobCard(job);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF9117FF),
        unselectedItemColor: Colors.grey.shade400,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
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

  Widget _buildJobCard(dynamic job) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job.company, // Replace with job.company if available
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 16),
                    ),
                  ],
                ),
              ),
              Consumer<SavedJobsProvider>(
                builder: (context, savedJobsProvider, child) {
                  final isSaved = savedJobsProvider.isSaved(job.id);
                  return IconButton(
                    icon: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: isSaved ? const Color(0xFF9117FF) : Colors.grey,
                    ),
                    onPressed: () async {
                      try {
                        if (isSaved) {
                          await savedJobsProvider.removeSavedJob(job.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Removed from saved jobs")),
                            );
                          }
                        } else {
                          await savedJobsProvider.saveJob(job);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Added to saved jobs")),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error: $e")),
                          );
                        }
                      }
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
              const SizedBox(width: 4),
              Text(job.location, style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: const [
              Icon(Icons.access_time, size: 18, color: Colors.grey),
              SizedBox(width: 4),
              Text("2 days ago", style: TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              onPressed: () {
                job.link.isNotEmpty
                    ? launchUrl(Uri.parse(job.link))
                    : ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("No application link available")),
                      );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9117FF), // Purple color from image
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                "Apply Now",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    bool isLocationChip = label != "All" && label != "Full Time";
    
    return FilterChip(
      label: Text(label),
      selected: isSelected || (isLocationChip && _selectedLocation == label),
      onSelected: (bool selected) async {
        setState(() {
          if (label == "All") {
            _selectedLocation = null;
            _searchController.clear();
          } else if (isLocationChip) {
            _selectedLocation = selected ? label : null;
          }
        });

        if (selected && isLocationChip) {
          // Fetch jobs by location
          try {
            await Provider.of<JobProvider>(context, listen: false)
                .filterJobsByLocation(label);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Error filtering jobs: $e")),
              );
            }
          }
        } else if (label == "All") {
          // Fetch all jobs
          await Provider.of<JobProvider>(context, listen: false).fetchJobs();
        }
      },
      backgroundColor: Colors.grey.shade200,
      selectedColor: const Color(0xFF9117FF).withValues(alpha: 0.7),
      labelStyle: TextStyle(
        color: (isSelected || (isLocationChip && _selectedLocation == label))
            ? Colors.white
            : Colors.black,
      ),
    );
  }
}