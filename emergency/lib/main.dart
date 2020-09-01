import 'dart:ffi';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:async';
import 'dart:io';

import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';

import 'package:intl/intl.dart';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as sst;
import 'package:flutter/animation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:wakelock/wakelock.dart';
import 'dart:collection';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
// The following statement enables the wakelock.
  bool on = true;
// The following statement enables the wakelock.
  Wakelock.toggle(on: on);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {

  bool _hasSpeech = false;
  double level = 0.0;
  double minSoundLevel = 50000;
  double maxSoundLevel = -50000;
  String lastWords = "";
  String lastError = "";
  String lastStatus = "";
  String _currentLocaleId = "en_ZA";
  final sst.SpeechToText speech = sst.SpeechToText();

  @override
  void initState() {
    initialise();
    super.initState();
  }
  FirebaseUser _firebaseUser;
  String id;
  final db= Firestore.instance;

  String _status= "Sign in";
  bool flag=false;
  Color _color= Colors.blue;
  final FirebaseAuth _firebaseAuth=FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn= new GoogleSignIn();
  bool Mode= true;


  final CollectionReference _collectionReference= Firestore.instance.collection("Tokens");
  void update(String usern, bool Mode1){
    try{
      _collectionReference.document(_firebaseUser.uid).setData({ 'location':_startAddress,
        'device_token': _deviceToken,
        'mode':Mode1,
        'user': user
      });
    }catch(e){
      print("signIn: "+ e.toString());
      _scaffoldKey.currentState.showSnackBar(
        SnackBar(
          content: Text(
              e.toString()),
        ),
      );
    }
  }
  
  void SignInOut(String usern, bool Mode1) async {
    if (!flag) {
      try{
        final GoogleSignInAccount _googleSignInAccount= await _googleSignIn.signIn();
        final GoogleSignInAuthentication _googleAut= await _googleSignInAccount.authentication;

        final AuthCredential credential= GoogleAuthProvider.getCredential(
            idToken: _googleAut.idToken, accessToken: _googleAut.accessToken);
        _firebaseUser= (await _firebaseAuth.signInWithCredential(credential)).user;
        update(usern, Mode1);

        setState(() {
          // change the button color anh text
          if (user=='user'){
              initSpeechState();
          }
          flag=true;
          _status= "SignOut";
          _color= Colors.red;

        });
      }catch(e){print("signIn: "+ e.toString());
      _scaffoldKey.currentState.showSnackBar(
        SnackBar(
          content: Text(
              e.toString()),
        ),
      );
      }
    }else {
      try{

        setState(() {
          // change the button color anh text
          flag=false;
          _status= "SignIn";
          _color= Colors.blue;
          Mode= true;
          update(usern, true);
        });
        // resetting
        await _firebaseAuth.signOut();
        await _googleSignIn.disconnect();
        await _googleSignIn.signOut();

      }catch(e){print('signOut: '+ e.toString());
      }
    }
  }

  //DATE                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             NNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
  DateTime afterTenMinutes = DateTime.now();
  String _emergency='';
  DateTime now = DateTime.now();
  AddEmergency(call) async{
    try{
      if (flag){
        DocumentReference reference= await db.collection('Message').add({
          'ms':call,
          'location':_startAddress,
          'date': DateFormat('yyyy-MM-dd').format(now),
          'emergency': _emergency,
          'coord': _stratCoord,
          'token': _deviceToken,
        });
        setState(() {
          id= reference.documentID;
        });
        print(reference.documentID);
        update('user', false);
      }
    } catch(e){
      print("connection loss"+e.toString());
    }
  }

  //storing in DB
  Future<void> initSpeechState() async {
    bool hasSpeech = await speech.initialize(
        onError: errorListener, onStatus: statusListener);
    if (hasSpeech) {
      var systemLocale = await speech.systemLocale();
      _currentLocaleId = systemLocale.localeId;
    }
    if (!mounted) return;
    setState(() {
      _hasSpeech = hasSpeech;
    });
  }

  //MAP
  GoogleMapController _controller;
  Location _location= Location();
  List<double> _stratCoord=[];

  void _onMapCreated(GoogleMapController controller) async{
    setState(() {
      _controller=controller;
    });
    await _location.onLocationChanged().listen((l) {
      setState(() {
        _stratCoord = [l.latitude, l.longitude];
      });

      if (!Mode){
        _calculateDistance();
      }else{
        _getAddress();
        _controller.animateCamera(
            CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: LatLng(l.latitude, l.longitude),
                  zoom: 14.0,
                )
            )
        );
      }
    }
    );
  }
  bool marked =true;

  final Geolocator _geolocator = Geolocator();
  String _currentAddress;

  final startAddressController = TextEditingController();
  final destinationAddressController = TextEditingController();

  String _startAddress = '';
  String _destinationAddress = '';
  String _placeDistance;


  Set<Marker> markers = {};

  PolylinePoints polylinePoints;
  Map<PolylineId, Polyline> polylines = {};
  List<LatLng> polylineCoordinates = [];

  _getAddress() async {
    try {
      List<Placemark> p = await _geolocator.placemarkFromCoordinates(
          _stratCoord[0],_stratCoord[1]);

      Placemark place = p[0];
      print("${place.name}, ${place.locality}, ${place.postalCode}, ${place.country}");
      setState(() {
        _currentAddress = "${place.name}, ${place.locality}, ${place.postalCode}, ${place.country}";
        startAddressController.text = _currentAddress;
        _startAddress = _currentAddress;
      });
    } catch (e) {
      print(e);
    }
  }

  GoogleMapController mapController;
  List<double> destinationCoordinates = [];
  Future<bool> _calculateDistance() async {

    try {
      _getAddress();
      // Retrieving placemarks from addresses
      List<Placemark> startPlacemark =
      await _geolocator.placemarkFromAddress(_startAddress);
      List<Placemark> destinationPlacemark =
      await _geolocator.placemarkFromAddress(_destinationAddress);

      if (startPlacemark != null && destinationPlacemark != null) {
        // Use the retrieved coordinates of the current position,
        // instead of the address if the start position is user's
        // current position, as it results in better accuracy.

          // Destination Location Marker
        Marker startMarker = Marker(
          markerId: MarkerId('$_stratCoord'),
          position: LatLng(
              _stratCoord[0],
              _stratCoord[1]
          ),
          infoWindow: InfoWindow(
            title: 'Destination',
            snippet: _startAddress,
          ),
          icon: BitmapDescriptor.defaultMarker,
        );

        Marker destinationMarker = Marker(
          markerId: MarkerId('$destinationCoordinates'),
          position: LatLng(
              destinationCoordinates[0],
              destinationCoordinates[1]
          ),
          infoWindow: InfoWindow(
            title: 'Destination',
            snippet: _destinationAddress,
          ),
          icon: BitmapDescriptor.defaultMarker,
        );

        // Adding the markers to the list
        markers.clear();
        markers.add(destinationMarker);
        markers.add(startMarker);

        print('START COORDINATES: $_stratCoord');
        print('DESTINATION COORDINATES: $destinationCoordinates');

        List<double> _northeastCoordinates;
        List<double> _southwestCoordinates;

        // Calculating to check that
        // southwest coordinate <= northeast coordinate
        if (_stratCoord[0] <= destinationCoordinates[0]) {
          _southwestCoordinates = _stratCoord;
          _northeastCoordinates = destinationCoordinates;
        } else {
          _southwestCoordinates = destinationCoordinates;
          _northeastCoordinates = _stratCoord;
        }

        // Accomodate the two locations within the
        // camera view of the map
        var centerBounds = [
            (_northeastCoordinates[0]  + _southwestCoordinates[0])/2,
            (_northeastCoordinates[1]  + _southwestCoordinates[1])/2
        ];
        _controller.animateCamera(
            CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: LatLng(centerBounds[0], centerBounds[1]),
                  zoom: 17,
                )
          ),
        );

        await _createPolylines(_stratCoord, destinationCoordinates);

        double totalDistance = 0.0;

        // Calculating the total distance by adding the distance
        // between small segments
        for (int i = 0; i < polylineCoordinates.length - 1; i++) {
          totalDistance += _stratCoordinateDistance(
            polylineCoordinates[i].latitude,
            polylineCoordinates[i].longitude,
            polylineCoordinates[i + 1].latitude,
            polylineCoordinates[i + 1].longitude,
          );
        }

        setState(() {
           polylineCoordinates = [];
          _placeDistance = totalDistance.toStringAsFixed(2);
          print('DISTANCE: $totalDistance km');
        });

        return true;
      }
    } catch (e) {
      print(e);
    }
    return false;
  }

  double _stratCoordinateDistance(lat1, lon1, lat2, lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  _createPolylines(List<double> start, List<double>  destination) async {
    polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      'AIzaSyDbWRjxuzt5vFYd5lOCXZI7qcB3BiRwdp4', // Google Maps API Key
      PointLatLng(start[0], start[1]),
      PointLatLng(destination[0], destination[1]),
      travelMode: TravelMode.transit,
    );

    if (result.points.isNotEmpty) {
      result.points.forEach((PointLatLng point) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
    }

    PolylineId id = PolylineId('poly');
    Polyline polyline = Polyline(
      polylineId: id,
      color: Colors.red,
      points: polylineCoordinates,
      width: 3,
    );
    polylines[id] = polyline;
  }
  String user= "";
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  @override
  Widget build(BuildContext context) {
    final actionSheet= CupertinoActionSheet(
      title: Text("Login as", style: TextStyle(fontSize: 20),
      ),
      actions: <Widget>[
        CupertinoActionSheetAction(
          child: Text("User"),
          isDefaultAction: true,
          onPressed: (){
            user='user';
            SignInOut("user", true);
            Navigator.pop(context);},
        ),CupertinoActionSheetAction(
          child: Text("Police"),
          isDestructiveAction: true,
          onPressed: (){
            user='police';
            SignInOut("police", true);
            Navigator.pop(context);},
        ),CupertinoActionSheetAction(
          child: Text("Ambulance"),
          isDestructiveAction: true,
          onPressed: (){
            user='ambulance';
            SignInOut("ambulance", true);
            Navigator.pop(context);},
        ),CupertinoActionSheetAction(
          child: Text("FireFigther"),
          isDestructiveAction: true,
          onPressed: (){
            user='fire';
            SignInOut("fire", true);
            Navigator.pop(context);},
        ),CupertinoActionSheetAction(
          child: Text("Cancel"),
          onPressed: (){Navigator.pop(context);},
        )

      ],

    );
    return new Scaffold(
      key: _scaffoldKey,
      body: Stack(
        children: <Widget>[
          Container(
            height: MediaQuery.of(context).size.height,
            width:  MediaQuery.of(context).size.width,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(0.0, 0.0),
              ),
              polylines: Set<Polyline>.of(polylines.values),
              markers: markers != null ? Set<Marker>.from(markers) : null,
                  mapType: MapType.terrain,
              onMapCreated: _onMapCreated,
              myLocationEnabled: true,
              compassEnabled: true,
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white70,
                    borderRadius: BorderRadius.all(
                      Radius.circular(20.0),
                    ),
                  ),
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
                    child: Visibility(
                      visible: _placeDistance == null? false : true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'DISTANCE: $_placeDistance km',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 5),
                          RaisedButton(
                            child: Text('Done'),
                            onPressed: ()  {
                              setState(() {
                                markers.clear();
                                polylines.clear();
                                polylineCoordinates.clear();
                                _placeDistance = null;
                                Mode=true;
                                update(user, true);
                              });
                            },
                            color: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 30,
            left: 30,
            child: Visibility(
                visible: user == 'user' && flag ? true : false,
                child:Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                            blurRadius: .26,
                            spreadRadius: level * 1.5,
                            color: Colors.black.withOpacity(.05))
                      ],
                      color: Colors.white,
                      borderRadius:
                      BorderRadius.all(Radius.circular(70)),
                    ),
                    child: IconButton(icon: Icon(Icons.mic,color: Colors.blue.shade400,),iconSize:30 ,onPressed: !_hasSpeech || speech.isListening
                        ? null : startListening,),
                  ),
                ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (){ if (flag){
          SignInOut('', true);
        }else{
          showCupertinoModalPopup(context: context, builder: (context)=> actionSheet);
        }
        },
        label: Text(_status),
        icon: Icon(Icons.thumb_up),
        backgroundColor: _color,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void startListening() {
    lastWords = "";
    lastError = "";
    speech.listen(
        onResult: resultListener,
        listenFor: Duration(seconds: 10),
        localeId: _currentLocaleId,
        onSoundLevelChange: soundLevelListener,
        cancelOnError: true,
        partialResults: true);
    setState(() {});
  }

  void resultListener(SpeechRecognitionResult result) async {
    await _getAddress();
    setState(() {
      lastWords = "${result.recognizedWords} - ${result.finalResult}";
      print("-------------------result-------------------");
      _emergency= lastWords;
      if (result.finalResult && _startAddress!=''){
        var date=DateFormat('yyyy-MM-dd').format(now);
        var call= "Depart: ${result.recognizedWords.toString()} \nLocation: $_startAddress \nTime: $date \n Coord: $_stratCoord" ;
        AddEmergency(call);
        _scaffoldKey.currentState.showSnackBar(
          SnackBar(
            content: Text(
                'Message sent (${result.recognizedWords.toString()})'),
          ),
        );
      }
    });
  }

  void soundLevelListener(double level) {
    minSoundLevel = min(minSoundLevel, level);
    maxSoundLevel = max(maxSoundLevel, level);
    //print("sound level $level: $minSoundLevel - $maxSoundLevel ");
    setState(() {
      this.level = level;
    });
  }

  void errorListener(SpeechRecognitionError error) {
    print("Received error status: $error, listening: ${speech.isListening}");
    setState(() {
      lastError = "${error.errorMsg} - ${error.permanent}";
    });
  }

  void statusListener(String status) {
    print(
        "Received listener status: $status, listening: ${speech.isListening}");
    setState(() {
      lastStatus = "$status";
    });
  }

  final FirebaseMessaging _fcm = FirebaseMessaging();
  void _showItemDialog(k) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(title: Text("Accept" ), content: Text(k),
        actions: <Widget>[
          FlatButton(
            child: Text('No'),
            onPressed: (){
              Navigator.of(_).pop();
            },
          ),
          FlatButton(
            child: Text('Yes'),
            onPressed: (){
              setState(() {
                update(user, false);
                Mode=false;
              });
              Navigator.of(_).pop();
            },
          ),
        ],
        elevation: 24.0,
      ),
    );
  }

  String _deviceToken='';
  void getToken(){
    _fcm.getToken().then((deviceToken){
      setState(() {
        print("tokkkkkkkkkkkkkkkkkkkkkkkkkkkkkk $deviceToken");
        _deviceToken= deviceToken;
      });

    });
  }

  Future initialise() async {
    print('-------------------notification-------------------------');
    if (Platform.isIOS) {
      // request permission on IOS
      _fcm.requestNotificationPermissions(IosNotificationSettings());
    }
    getToken();
    String msg;
    _fcm.configure(
      //called when app iss in back ground
      onMessage: (Map<String, dynamic> message) async {
        print("--------------------------onmass: $message");
        msg=message['data']['message'];
        if (msg!=''){
          var co=msg.split("Coord:")[msg.split("Coord: ").length -1];
          print(co.substring(2,co.length-1).split(',')[0]);
          print(co.substring(2,co.length-1).split(',')[1]);
          var string=msg.split("Location: ")[msg.split("Location: ").length -1];
          print(string.split('Time')[0]);
          setState(() {
            _destinationAddress=string;
            destinationCoordinates=[double.parse(co.substring(2,co.length-1).split(',')[0]),double.parse(co.substring(2,co.length-1).split(',')[1])];
          });
          _showItemDialog(msg.split("Coord:")[0]);
        }
      },
      onLaunch: (Map<String, dynamic> message) async {
        print("-------------------------onLaunch: $message");
        msg=message['data']['message'];
        if (msg!=''){
          var co=msg.split("Coord:")[msg.split("Coord: ").length -1];
          print(co.substring(2,co.length-1).split(',')[0]);
          print(co.substring(2,co.length-1).split(',')[1]);
          var string=msg.split("Location: ")[msg.split("Location: ").length -1];
          print(string.split('Time')[0]);
          setState(() {
            _destinationAddress=string;
            destinationCoordinates=[double.parse(co.substring(2,co.length-1).split(',')[0]),double.parse(co.substring(2,co.length-1).split(',')[1])];
          });
          _showItemDialog(msg.split("Coord:")[0]);
        }
      },
      onResume: (Map<String, dynamic> message) async {
        print("--------------------------------onResume: $message");
        msg=message['data']['message'];
        if (msg!=''){
          var co=msg.split("Coord:")[msg.split("Coord: ").length -1];
          print(co.substring(2,co.length-1).split(',')[0]);
          print(co.substring(2,co.length-1).split(',')[1]);
          var string=msg.split("Location: ")[msg.split("Location: ").length -1];
          print(string.split('Time')[0]);
          setState(() {
            _destinationAddress=string;
            destinationCoordinates=[double.parse(co.substring(2,co.length-1).split(',')[0]),double.parse(co.substring(2,co.length-1).split(',')[1])];
          });
          _showItemDialog(msg.split("Coord:")[0]);
        }
      },
    );
  }
}

