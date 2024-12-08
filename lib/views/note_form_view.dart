import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

class NoteForm extends StatefulWidget {
  final LatLng position;
  final Function(
    String title,
    String description,
    String? imagePath,
    String? pinCode,
    bool showAuthorName,
  ) onNoteSaved;

  const NoteForm({
    super.key,
    required this.position,
    required this.onNoteSaved,
  });

  @override
  State<NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends State<NoteForm> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  File? _selectedImage;
  bool _showAuthorName = true;

  bool _isTitleValid = true;
  bool _isDescriptionValid = true;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        final selectedFile = File(pickedFile.path);
        if (await selectedFile.exists()) {
          setState(() {
            _selectedImage = selectedFile;
          });
        } else {
          _showSnackbar('File path is invalid.');
        }
      } else {
        _showSnackbar('No image selected.');
      }
    } catch (e) {
      _showSnackbar('Error picking image: $e');
    }
  }

  void _deleteImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _submitNote() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final pinCode = _pinController.text.trim();
    final imagePath = _selectedImage?.path;

    setState(() {
      _isTitleValid = title.isNotEmpty;
      _isDescriptionValid = description.isNotEmpty;
    });

    if (!_isTitleValid || !_isDescriptionValid) return;

    widget.onNoteSaved(
      title,
      description,
      imagePath,
      pinCode.isNotEmpty ? pinCode : null,
      _showAuthorName,
    );

    Navigator.of(context).pop(); // Close the modal after submission
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: MediaQuery.of(context).viewInsets,
              child: SingleChildScrollView(
                controller: scrollController,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // Header
                      Center(
                        child: Container(
                          height: 4,
                          width: 40,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const Text(
                        "Leave Note",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Title Field
                      TextField(
                        controller: _titleController,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Title',
                          prefixIcon: const Icon(Icons.title, size: 20),
                          filled: true,
                          fillColor: Colors.grey[100],
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          errorText: !_isTitleValid ? 'Title is required' : null,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Description Field
                      TextField(
                        controller: _descriptionController,
                        maxLines: 3,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          prefixIcon: const Icon(Icons.description, size: 20),
                          filled: true,
                          fillColor: Colors.grey[100],
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          errorText: !_isDescriptionValid
                              ? 'Description is required'
                              : null,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Image Picker
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 100,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: _selectedImage == null
                              ? const Center(
                                  child: Text(
                                    'Tap to select an image',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _selectedImage!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                        ),
                      ),
                      if (_selectedImage != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _deleteImage,
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: const Text('Remove Image'),
                          ),
                        ),
                      const SizedBox(height: 8),

                      // Pin Code Field
                      TextField(
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Pin Code (Optional)',
                          prefixIcon: const Icon(Icons.lock, size: 20),
                          filled: true,
                          fillColor: Colors.grey[100],
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Show Author Checkbox
                      Row(
                        children: [
                          Checkbox(
                            value: _showAuthorName,
                            onChanged: (value) {
                              setState(() {
                                _showAuthorName = value ?? true;
                              });
                            },
                          ),
                          const Text('Show my name'),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Save Note Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitNote,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Save Note',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
