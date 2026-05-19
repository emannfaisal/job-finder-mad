class Job {
  final int id;
  final int? jobId;  // Used when this comes from saved jobs (SavedJob.job_id)
  final String title;
  final String company;
  final String location;
  final String link;
  Job({
    required this.id,
    this.jobId,
    required this.title,
    required this.company,
    required this.location,
    required this.link,

  });

  factory Job.fromJson(Map<String, dynamic> json) {
    // Handle nested job object from SavedJobResponse
    final jobData = json['job'] ?? json;
    
    return Job(
      id: json['id'] ?? jobData['id'],
      jobId: json['job_id'],  // Add this for saved jobs response
      title: jobData['title'] ?? '',
      company: jobData['company'] ?? '',
      location: jobData['location'] ?? '',
      link: jobData['link'] ?? '',
    );
  }
}