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
                  const Icon(Icons.note, color: Colors.deepPurple),
                  const SizedBox(width: 8),
                  Text(
                    "Note Details",
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: Colors.deepPurple),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Image
              if (imageUrl != null && imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Center(child: Icon(Icons.broken_image, size: 80)),
                  ),
                ),
              if (imageUrl != null && imageUrl!.isNotEmpty)
                const SizedBox(height: 16),

              // Title
              const Text(
                "Title",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(title.isNotEmpty ? title : "Untitled"),
              const SizedBox(height: 16),

              // Description
              const Text(
                "Description",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(description.isNotEmpty ? description : "No description provided."),
              const SizedBox(height: 16),

              // Author Information
              if (authorName != null || authorSurname != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Author",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text("${authorName ?? ''} ${authorSurname ?? ''}".trim()),
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
