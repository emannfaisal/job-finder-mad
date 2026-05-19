import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../providers/saved_jobs_provider.dart';

class RecommendedScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const RecommendedScreen({super.key, required this.onNavigate});

  @override
  State<RecommendedScreen> createState() => _RecommendedScreenState();
}

class _RecommendedScreenState extends State<RecommendedScreen> {
  late Future<List<Map<String, dynamic>>> _recommendations;

  @override
  void initState() {
    super.initState();
    _recommendations = ApiService.getRecommendations(limit: 20);
    Future.microtask(() {
      if (mounted) {
        Provider.of<SavedJobsProvider>(context, listen: false).fetchSavedJobs();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _recommendations,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'Failed to load recommendations',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _recommendations = ApiService.getRecommendations(limit: 20);
                          });
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final recommendations = snapshot.data ?? [];

            if (recommendations.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.explore_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No recommendations yet',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Complete your profile to get personalized recommendations',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recommended For You',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Jobs matched to your profile',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                // JOB COUNT
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    "${recommendations.length} Recommendations Found",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D1B2A),
                    ),
                  ),
                ),
                // JOB LIST
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: recommendations.length,
                    itemBuilder: (context, index) {
                      final rec = recommendations[index];
                      final score = rec['score'] as num?;
                      final jobLink = rec['link'] ?? '';
                      debugPrint('RECOMMENDED: Job $index - Title: ${rec['title']}, Link: $jobLink');
                      return _buildJobCard(
                        id: rec['id']?.toString() ?? '$index',
                        title: rec['title'] ?? 'Unknown',
                        company: rec['company'] ?? 'Unknown',
                        location: rec['location'] ?? 'Unknown',
                        link: jobLink,
                        score: score?.toDouble() ?? 0.0,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 3,
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

  Widget _buildJobCard({
    required String id,
    required String title,
    required String company,
    required String location,
    required String link,
    required double score,
  }) {
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
          // Score badge (only in recommended)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getScoreColor(score).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, color: _getScoreColor(score), size: 16),
                const SizedBox(width: 4),
                Text(
                  '${(score * 10).toStringAsFixed(0)}% Match',
                  style: TextStyle(
                    color: _getScoreColor(score),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Title, company and save button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      company,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 16),
                    ),
                  ],
                ),
              ),
              Consumer<SavedJobsProvider>(
                builder: (context, savedJobsProvider, child) {
                  final jobIdInt = int.tryParse(id) ?? 0;
                  final isSaved = savedJobsProvider.isSaved(jobIdInt);
                  return IconButton(
                    icon: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: isSaved ? const Color(0xFF9117FF) : Colors.grey,
                    ),
                    onPressed: () async {
                      try {
                        if (isSaved) {
                          await ApiService.removeSavedJob(jobIdInt);
                          await savedJobsProvider.fetchSavedJobs();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Removed from saved jobs")),
                            );
                          }
                        } else {
                          await ApiService.saveJob(jobIdInt);
                          await savedJobsProvider.fetchSavedJobs();
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
          // Location
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
              const SizedBox(width: 4),
              Text(location, style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          // Time
          Row(
            children: const [
              Icon(Icons.access_time, size: 18, color: Colors.grey),
              SizedBox(width: 4),
              Text("2 days ago", style: TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 16),
          // Apply button
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              onPressed: () {
                debugPrint('RECOMMENDED: Apply Now clicked - Link: "$link"');
                link.isNotEmpty
                    ? launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication)
                    : ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("No application link available")),
                      );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9117FF),
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

  Color _getScoreColor(double score) {
    if (score >= 8) return const Color(0xFF4CAF50); // Green - excellent match
    if (score >= 6) return const Color(0xFF2196F3); // Blue - good match
    if (score >= 4) return const Color(0xFFFFC107); // Amber - decent match
    return const Color(0xFFFF9800); // Orange - fair match
  }
}
