import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'note_form_view.dart';
import 'note_details_view.dart';
import 'package:geolocator/geolocator.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  late GoogleMapController mapController;

  LatLng _initialPosition =
      const LatLng(37.7749, -122.4194); // Default location
  final List<Marker> _markers = [];
  final List<Polygon> _polygons = [];
  final List<LatLng> _polygonPoints = [];
  Polygon? _currentPolygon;
  bool _isDrawingMode = false;

  // User details
  String? _userName;
  String? _userSurname;

  @override
  void initState() {
    super.initState();
    _setUserCurrentLocation();
    _fetchUserDetails();
    _fetchMapData();
  }

  /// Fetches the logged-in user's details
  Future<void> _fetchUserDetails() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          setState(() {
            _userName = userDoc.data()?['name'];
            _userSurname = userDoc.data()?['surname'];
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching user details: $e')),
      );
    }
  }

  /// Sets the user's current location as the map's initial position
  Future<void> _setUserCurrentLocation() async {
    try {
      // Check for location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied';
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _initialPosition = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching location: $e')),
        );
      }
    }
  }

  /// Fetches markers and polygons from Firestore
  Future<void> _fetchMapData() async {
    try {
      final notesCollection = FirebaseFirestore.instance.collection('notes');
      final snapshot = await notesCollection.get();

      if (!mounted) return;

      final List<Marker> fetchedMarkers = [];
      final List<Polygon> fetchedPolygons = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();

        // Load Markers
        if (data.containsKey('latitude') && data.containsKey('longitude')) {
          final position = LatLng(data['latitude'], data['longitude']);
          fetchedMarkers.add(
            Marker(
              markerId: MarkerId(doc.id),
              position: position,
              icon: data['isLongPress']
                  ? BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed) // Red for long-tap markers
                  : BitmapDescriptor.defaultMarker,
              infoWindow: InfoWindow(
                title: data['title'] ?? 'No Title',
                snippet: data['description'] ?? 'No Description',
              ),
              onTap: () {
                if (data['pinCode'] != null) {
                  _verifyPinCode(data); // Ask for PIN
                } else {
                  _showNoteDetails(data); // Directly show note details
                }
              },
            ),
          );
        }

        // Load Polygons
        if (data.containsKey('polygonPoints')) {
          final polygonPoints = (data['polygonPoints'] as List)
              .map((point) => LatLng(point['lat'], point['lng']))
              .toList();
          fetchedPolygons.add(
            Polygon(
              polygonId: PolygonId(doc.id),
              points: polygonPoints,
              strokeColor: Colors.deepPurple,
              fillColor: Colors.deepPurple.withOpacity(0.3),
              strokeWidth: 2,
              onTap: () {
                if (data['pinCode'] != null) {
                  _verifyPinCode(data); // Ask for PIN
                } else {
                  _showNoteDetails(data); // Directly show note details
                }
              },
            ),
          );

          // Add a marker at the center of the polygon
          final LatLng center = _calculatePolygonCentroid(polygonPoints);
          fetchedMarkers.add(
            Marker(
              markerId: MarkerId('center_${doc.id}'),
              position: center,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue), // Blue for polygon centers
              onTap: () {
                if (data['pinCode'] != null) {
                  _verifyPinCode(data); // Ask for PIN
                } else {
                  _showNoteDetails(data); // Directly show note details
                }
              },
            ),
          );
        }
      }

      setState(() {
        _markers
          ..clear()
          ..addAll(fetchedMarkers);
        _polygons
          ..clear()
          ..addAll(fetchedPolygons);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading map data: $e')),
        );
      }
    }
  }

  /// Toggles the drawing mode
  void _toggleDrawingMode() {
    setState(() {
      _isDrawingMode = !_isDrawingMode;
      if (!_isDrawingMode) {
        _polygonPoints.clear();
        _currentPolygon = null;
      }
    });
  }

  /// Handles touch gestures for drawing
  void _onMapPanUpdate(DragUpdateDetails details) async {
    if (_isDrawingMode) {
      final LatLng latLng = await _getLatLngFromScreenPosition(
        details.localPosition,
      );
      if (!_polygonPoints.contains(latLng)) {
        setState(() {
          _polygonPoints.add(latLng);

          _currentPolygon = Polygon(
            polygonId: const PolygonId('drawnPolygon'),
            points: _polygonPoints,
            fillColor: Colors.deepPurple.withOpacity(0.3),
            strokeColor: Colors.deepPurple,
            strokeWidth: 2,
          );
        });
      }
    }
  }

  /// Converts screen coordinates to map coordinates
  Future<LatLng> _getLatLngFromScreenPosition(Offset screenPosition) async {
    final ScreenCoordinate screenCoordinate = ScreenCoordinate(
      x: screenPosition.dx.toInt(),
      y: screenPosition.dy.toInt(),
    );
    return await mapController.getLatLng(screenCoordinate);
  }

  /// Opens the NoteForm to save the drawn polygon
  void _savePolygon() {
    if (_polygonPoints.isEmpty) return;

    final String noteId = FirebaseFirestore.instance
        .collection('notes')
        .doc()
        .id; // Generate noteId
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => NoteForm(
        position: _polygonPoints.first,
        onNoteSaved: (String title, String description, String? imagePath,
            String? pinCode, bool showAuthorName) async {
          try {
            final newDocRef = FirebaseFirestore.instance
                .collection('notes')
                .doc(noteId); // Use noteId
            await newDocRef.set({
              'noteId': noteId, // Save noteId
              'polygonPoints': _polygonPoints
                  .map((point) =>
                      {'lat': point.latitude, 'lng': point.longitude})
                  .toList(),
              'title': title,
              'description': description,
              'pinCode': pinCode,
              'userName': showAuthorName ? _userName : null,
              'userSurname': showAuthorName ? _userSurname : null,
              'showAuthorName': showAuthorName,
              'timestamp': FieldValue.serverTimestamp(),
            });

            _fetchMapData();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Polygon saved successfully!')),
            );

            setState(() {
              _isDrawingMode = false;
              _polygonPoints.clear();
              _currentPolygon = null;
            });
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error saving polygon: $e')),
            );
          }
        },
      ),
    );
  }

  /// Displays a PIN verification dialog
  void _verifyPinCode(Map<String, dynamic> noteData) {
    final TextEditingController pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Enter PIN"),
          content: TextField(
            controller: pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "PIN Code",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (pinController.text.trim() == noteData['pinCode']) {
                  Navigator.pop(context); // Close dialog
                  _showNoteDetails(noteData); // Show note details
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Incorrect PIN")),
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

  /// Displays note details in a modal
  void _showNoteDetails(Map<String, dynamic> noteData) {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => NoteDetailsView(
        title: noteData['title'] ?? 'No Title',
        description: noteData['description'] ?? 'No Description',
        imageUrl: noteData['imageUrl'],
        authorName:
            noteData['showAuthorName'] == true ? noteData['userName'] : null,
        authorSurname:
            noteData['showAuthorName'] == true ? noteData['userSurname'] : null,
      ),
    );
  }

  /// Handles a long press on the map to open a NoteForm
  void _onMapLongPress(LatLng position) {
    final String noteId = FirebaseFirestore.instance
        .collection('notes')
        .doc()
        .id; // Generate noteId
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => NoteForm(
        position: position,
        onNoteSaved: (String title, String description, String? imagePath,
            String? pinCode, bool showAuthorName) async {
          try {
            final newDocRef = FirebaseFirestore.instance
                .collection('notes')
                .doc(noteId); // Use noteId
            await newDocRef.set({
              'noteId': noteId, // Save noteId
              'latitude': position.latitude,
              'longitude': position.longitude,
              'title': title,
              'description': description,
              'imagePath': imagePath,
              'pinCode': pinCode,
              'userName': showAuthorName ? _userName : null,
              'userSurname': showAuthorName ? _userSurname : null,
              'showAuthorName': showAuthorName,
              'isLongPress': true, // Mark as a long-press note
              'timestamp': FieldValue.serverTimestamp(),
            });

            _fetchMapData(); // Refresh the map
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Note saved successfully!')),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error saving note: $e')),
            );
          }
        },
      ),
    );
  }

  /// Calculates the centroid of a polygon
  LatLng _calculatePolygonCentroid(List<LatLng> points) {
    double latitudeSum = 0;
    double longitudeSum = 0;

    for (final point in points) {
      latitudeSum += point.latitude;
      longitudeSum += point.longitude;
    }

    return LatLng(latitudeSum / points.length, longitudeSum / points.length);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: _isDrawingMode ? _onMapPanUpdate : null,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Map',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.deepPurple,
          centerTitle: true,
        ),
        body: Stack(
          children: [
            GoogleMap(
              onMapCreated: _onMapCreated,
              onLongPress: _onMapLongPress,
              initialCameraPosition: CameraPosition(
                target: _initialPosition,
                zoom: 12.0,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              mapType: MapType.normal,
              markers: Set<Marker>.of(_markers),
              polygons: Set<Polygon>.of(
                _polygons
                  ..addAll(_currentPolygon != null ? [_currentPolygon!] : []),
              ),
              scrollGesturesEnabled: !_isDrawingMode,
              zoomGesturesEnabled: !_isDrawingMode,
            ),

            // Refresh Map Button (Top-Right)
            Positioned(
              top: 16,
              right: 16,
              child: FloatingActionButton(
                onPressed: _fetchMapData, // Refresh the map data
                backgroundColor: Colors.green,
                child: const Icon(Icons.refresh, color: Colors.white),
              ),
            ),

            // Toggle Drawing Mode Button (Middle Right)
            Positioned(
              top: MediaQuery.of(context).size.height *
                  0.4, // Middle of the screen
              right: 16,
              child: FloatingActionButton(
                onPressed: _toggleDrawingMode,
                backgroundColor:
                    _isDrawingMode ? Colors.red : Colors.deepPurple,
                child: Icon(
                  _isDrawingMode ? Icons.close : Icons.edit,
                  color: Colors.white,
                ),
              ),
            ),

            // Save Area Button (Bottom Right)
            if (_isDrawingMode)
              Positioned(
                bottom: 16, // Distance from the bottom
                left: MediaQuery.of(context).size.width * 0.5 -
                    100, // Center horizontally
                child: FloatingActionButton.extended(
                  onPressed: _savePolygon,
                  backgroundColor: Colors.deepPurple,
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text('Save Area',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }
}
