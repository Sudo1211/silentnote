import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:silentnote/constants/routes.dart';

class AccountView extends StatefulWidget {
  const AccountView({super.key});

  @override
  State<AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends State<AccountView> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? name;
  String? surname;
  String? profileImageUrl;
  bool isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  Future<void> _fetchUserDetails() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          setState(() {
            name = doc.data()?['name'];
            surname = doc.data()?['surname'];
            profileImageUrl = doc.data()?['profileImageUrl'];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error fetching user details: $e');
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _updateProfile(String newName, String newSurname) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'name': newName,
          'surname': newSurname,
        }, SetOptions(merge: true));

        if (mounted) {
          setState(() {
            name = newName;
            surname = newSurname;
          });
          _showSnackBar('Profile updated successfully!');
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error updating profile: $e');
      }
    }
  }

  Future<void> _updateProfileImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() {
          isUploadingImage = true;
        });

        final user = _auth.currentUser;
        if (user != null) {
          final storageRef =
              _storage.ref().child('profile_images/${user.uid}.jpg');
          final uploadTask = storageRef.putFile(File(pickedFile.path));

          final snapshot = await uploadTask.whenComplete(() => null);
          final imageUrl = await snapshot.ref.getDownloadURL();

          await _firestore.collection('users').doc(user.uid).set({
            'profileImageUrl': imageUrl,
          }, SetOptions(merge: true));

          if (mounted) {
            setState(() {
              profileImageUrl = imageUrl;
              isUploadingImage = false;
            });
            _showSnackBar('Profile image updated!');
          }
        }
      } else if (mounted) {
        setState(() {
          isUploadingImage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isUploadingImage = false;
        });
        _showSnackBar('Error updating profile image: $e');
      }
    }
  }

  Future<void> _showUpdateDialog() async {
    final nameController = TextEditingController(text: name);
    final surnameController = TextEditingController(text: surname);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Update Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: surnameController,
                decoration: const InputDecoration(labelText: 'Surname'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newName = nameController.text.trim();
                final newSurname = surnameController.text.trim();
                if (newName.isNotEmpty && newSurname.isNotEmpty) {
                  _updateProfile(newName, newSurname);
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logOut() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sign out'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text(
                'Log out',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
    if (shouldLogout ?? false) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          loginRoute,
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Account',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logOut,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: profileImageUrl != null
                        ? NetworkImage(profileImageUrl!)
                        : null,
                    child: profileImageUrl == null && !isUploadingImage
                        ? const Icon(Icons.person, size: 60)
                        : null,
                  ),
                  if (isUploadingImage)
                    const CircularProgressIndicator(),
                  IconButton(
                    icon: const Icon(Icons.camera_alt, color: Colors.deepPurple),
                    onPressed: _updateProfileImage,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      name ?? 'No Name',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      surname ?? 'No Surname',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _showUpdateDialog,
              child: const Text('Edit Info'),
            ),
          ],
        ),
      ),
    );
  }
}