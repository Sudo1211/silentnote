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

  bool _isPointInPolygon(LatLng point, List<LatLng> polygonPoints) {
    int intersections = 0;
    for (int i = 0; i < polygonPoints.length; i++) {
      LatLng p1 = polygonPoints[i];
      LatLng p2 = polygonPoints[(i + 1) % polygonPoints.length];

      if (point.latitude > p1.latitude != point.latitude > p2.latitude &&
          point.longitude <
              (p2.longitude - p1.longitude) *
                      (point.latitude - p1.latitude) /
                      (p2.latitude - p1.latitude) +
                  p1.longitude) {
        intersections++;
      }
    }
    return intersections % 2 == 1;
  }

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

  Future<void> _setUserCurrentLocation() async {
    try {
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

  Future<void> _fetchMapData() async {
    try {
      final notesCollection = FirebaseFirestore.instance.collection('notes');
      final snapshot = await notesCollection.get();

      if (!mounted) return;

      final List<Marker> fetchedMarkers = [];
      final List<Polygon> fetchedPolygons = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();

        if (data.containsKey('latitude') && data.containsKey('longitude')) {
          final position = LatLng(data['latitude'], data['longitude']);
          fetchedMarkers.add(
            Marker(
              markerId: MarkerId(doc.id),
              position: position,
              icon: data['isLongPress']
                  ? BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed)
                  : BitmapDescriptor.defaultMarker,
              infoWindow: InfoWindow(
                title: data['title'] ?? 'No Title',
                snippet: data['description'] ?? 'No Description',
              ),
              onTap: () {
                if (data['pinCode'] != null) {
                  _verifyPinCode(data);
                } else {
                  _showNoteDetails(data);
                }
              },
            ),
          );
        }

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
              onTap: () async {
                final position = await Geolocator.getCurrentPosition();
                LatLng userLocation =
                    LatLng(position.latitude, position.longitude);

                if (_isPointInPolygon(userLocation, polygonPoints)) {
                  if (data['pinCode'] != null) {
                    _verifyPinCode(data);
                  } else {
                    _showNoteDetails(data);
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('You are outside the polygon area.')),
                  );
                }
              },
            ),
          );

          final LatLng center = _calculatePolygonCentroid(polygonPoints);
          fetchedMarkers.add(
            Marker(
              markerId: MarkerId('center_${doc.id}'),
              position: center,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue),
              onTap: () async {
                final position = await Geolocator.getCurrentPosition();
                LatLng userLocation =
                    LatLng(position.latitude, position.longitude);

                if (_isPointInPolygon(userLocation, polygonPoints)) {
                  if (data['pinCode'] != null) {
                    _verifyPinCode(data);
                  } else {
                    _showNoteDetails(data);
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('You are outside the polygon area.')),
                  );
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

  void _toggleDrawingMode() {
    setState(() {
      _isDrawingMode = !_isDrawingMode;
      if (!_isDrawingMode) {
        _polygonPoints.clear();
        _currentPolygon = null;
      }
    });
  }

  void _onMapPanUpdate(DragUpdateDetails details) async {
    if (_isDrawingMode) {
      try {
        // Adjust the global position upwards by a specific offset
        const double verticalOffset = -130; // Adjust this value as needed
        final Offset adjustedPosition = Offset(
          details.globalPosition.dx,
          details.globalPosition.dy + verticalOffset,
        );

        // Convert the adjusted position to LatLng
        final LatLng latLng = await mapController.getLatLng(
          ScreenCoordinate(
            x: adjustedPosition.dx.toInt(),
            y: adjustedPosition.dy.toInt(),
          ),
        );

        // Add the adjusted LatLng point to the polygon
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
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error drawing polygon: $e')),
        );
      }
    }
  }

  Future<LatLng> _getLatLngFromScreenPosition(Offset screenPosition) async {
    final ScreenCoordinate screenCoordinate = ScreenCoordinate(
      x: screenPosition.dx.toInt(),
      y: screenPosition.dy.toInt(),
    );
    return await mapController.getLatLng(screenCoordinate);
  }

  void _savePolygon() {
    if (_polygonPoints.isEmpty) return;

    final String noteId =
        FirebaseFirestore.instance.collection('notes').doc().id;
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
            final newDocRef =
                FirebaseFirestore.instance.collection('notes').doc(noteId);
            await newDocRef.set({
              'noteId': noteId,
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
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (pinController.text.trim() == noteData['pinCode']) {
                  Navigator.pop(context);
                  _showNoteDetails(noteData);
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

  void _onMapLongPress(LatLng position) {
    final String noteId =
        FirebaseFirestore.instance.collection('notes').doc().id;
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
            final newDocRef =
                FirebaseFirestore.instance.collection('notes').doc(noteId);
            await newDocRef.set({
              'noteId': noteId,
              'latitude': position.latitude,
              'longitude': position.longitude,
              'title': title,
              'description': description,
              'imagePath': imagePath,
              'pinCode': pinCode,
              'userName': showAuthorName ? _userName : null,
              'userSurname': showAuthorName ? _userSurname : null,
              'showAuthorName': showAuthorName,
              'isLongPress': true,
              'timestamp': FieldValue.serverTimestamp(),
            });

            _fetchMapData();
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
            Positioned(
              top: 16,
              right: 16,
              child: FloatingActionButton(
                onPressed: _fetchMapData,
                backgroundColor: Colors.green,
                child: const Icon(Icons.refresh, color: Colors.white),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.4,
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
            if (_isDrawingMode)
              Positioned(
                bottom: 16,
                left: MediaQuery.of(context).size.width * 0.5 - 70,
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
