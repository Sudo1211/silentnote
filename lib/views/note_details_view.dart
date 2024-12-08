import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NoteDetailsView extends StatelessWidget {
  final String title;
  final String description;
  final String? imageUrl;
  final String? authorName;
  final String? authorSurname;
  final String? noteId; // Firestore note ID

  const NoteDetailsView({
    super.key,
    required this.title,
    required this.description,
    this.imageUrl,
    this.authorName,
    this.authorSurname,
    this.noteId,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.note, color: Colors.deepPurple, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    "Note Details",
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: Colors.deepPurple, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Image
              if (imageUrl != null && imageUrl!.isNotEmpty)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(child: Icon(Icons.broken_image, size: 80)),
                    ),
                  ),
                ),
              if (imageUrl != null && imageUrl!.isNotEmpty)
                const SizedBox(height: 16),

              // Title
              _buildSectionTitle(context, "Title"),
              Text(
                title.isNotEmpty ? title : "Untitled",
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),

              // Description
              _buildSectionTitle(context, "Description"),
              Text(
                description.isNotEmpty ? description : "No description provided.",
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),

              // Author Information
              if (authorName != null || authorSurname != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(context, "Author"),
                    Text(
                      "${authorName ?? ''} ${authorSurname ?? ''}".trim(),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              const SizedBox(height: 24),

              // Complain Button
              Center(
                child: ElevatedButton.icon(
                  onPressed: () => _showComplainDialog(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.report, color: Colors.white),
                  label: const Text("Complain"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper: Section Title
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .bodyLarge
          ?.copyWith(fontWeight: FontWeight.bold, color: Colors.deepPurple),
    );
  }

  /// Show Complain Dialog
  void _showComplainDialog(BuildContext context) {
    final TextEditingController complainController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Submit a Complaint"),
          content: TextField(
            controller: complainController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: "Enter your complaint here...",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final complaint = complainController.text.trim();
                if (complaint.isNotEmpty) {
                  await _submitComplaint(complaint, context, dialogContext);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Complaint cannot be empty.")),
                  );
                }
              },
              child: const Text("Submit"),
            ),
          ],
        );
      },
    );
  }

  /// Save Complaint to Firestore
  Future<void> _submitComplaint(
      String complaint, BuildContext context, BuildContext dialogContext) async {
    if (noteId != null && noteId!.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('complaints').add({
          'noteId': noteId,
          'complaint': complaint,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Close dialogs and show success
        Navigator.pop(dialogContext); // Close complaint dialog
        Navigator.pop(context); // Close note details modal
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Complaint submitted successfully!")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error submitting complaint: $e")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Note ID is missing. Cannot save complaint.")),
      );
    }
  }
}
