import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';


int waitIfBigger = 10;
double checkDistancOne = 0.0;
int positionBySteps =0;
String origin = "";
String destination= "";


class ChatPage extends StatefulWidget {
  final BluetoothDevice server;

  const ChatPage({required this.server});

  @override
  _ChatPage createState() => new _ChatPage();
}

class _Message {
  int whom;
  String text;

  _Message(this.whom, this.text);
}

class _ChatPage extends State<ChatPage> {
  final Location _location = Location();
  LocationData? currentLocation;
  List<dynamic> stepsCordi = [];
  List<dynamic> maneuver = [];
  List<dynamic> dis = [];
  List<dynamic> steps = [];
  BluetoothConnection? connection;

  List<_Message> messages = List<_Message>.empty(growable: true);
  String _messageBuffer = '';

  final ScrollController listScrollController = new ScrollController();

  bool isConnecting = true;
  bool get isConnected => (connection?.isConnected ?? false);

  bool isDisconnecting = false;

//getroute
  Future<void> getRoute() async {
    if(stepsCordi.isEmpty) {
      String apiKey = "";
      String url =
          "https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&mode=walking&key=$apiKey";
      var response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        if (data.isEmpty) {
          print("Somthing went wrong with URL request");
        }
        steps = await data['routes'][0]['legs'][0]['steps'];
      }

      print("Should be printed 1 time");
      maneuver = [];
      dis = [];

    }

    print(stepsCordi);

    // all possible maneuver
    //     turn-right: The driver should turn right at the next intersection.
    //     turn-left: The driver should turn left at the next intersection.
    //     slight-right: The driver should bear slightly to the right at the next intersection.
    //     slight-left: The driver should bear slightly to the left at the next intersection.
    //     ramp-right: The driver should turn or exit to the right onto a ramp or slip road.
    //     ramp-left: The driver should turn or exit to the left onto a ramp or slip road.
    //     fork-right: The driver should bear to the right at a fork in the road where two or more separate roads diverge from a common point.
    //     fork-left: The driver should bear to the left at a fork in the road where two or more separate roads diverge from a common point.
    //     merge: Two separate roadways become one, and the driver is instructed to safely blend their vehicle into the flow of traffic on the combined roadway.
    //     roundabout-left: The driver should navigate the roundabout in a counterclockwise direction until they reach their desired exit on the left.
    //     roundabout-right: The driver should navigate the roundabout in a clockwise direction until they reach their desired exit on the right.
    //     roundabout-alternative: The driver should take an alternative route that bypasses the roundabout.

    if(maneuver.isEmpty) {
      for (int i = 0; i < steps.length; i++) {
        stepsCordi.add(LatLng(steps[i]['start_location']['lat'],
            steps[i]['start_location']['lng']));
        print(steps[i]['maneuver']);
        if (steps[i]['maneuver'] == "straight") {
          maneuver.add('W');
        }
        if (steps[i]['maneuver'] == "turn-left") {
          maneuver.add('S');
        }
        if (steps[i]['maneuver'] == "turn-slight-right") {
          maneuver.add('E');
        }
        if (steps[i]['maneuver'] == "turn-right") {
          maneuver.add('D');
        }
        if (steps[i]['maneuver'] == "sharp-right") {
          maneuver.add('D');
        }
        if (steps[i]['maneuver'] == "U-turn") {
          maneuver.add('S');
        }
        if (steps[i]['maneuver'] == "turn-sharp-left") {
          maneuver.add('A');
        }
        if (steps[i]['maneuver'] == "turn-left") {
          maneuver.add('A');
        }
        if (steps[i]['maneuver'] == "turn-slight-left") {
          maneuver.add('Q');
        }
        if (steps[i]['maneuver'] == "arrive-at-destination") {
          maneuver.add('2');
        }
        if (steps[i]['maneuver'] == "depart") {
          maneuver.add('0');
        }
        if (steps[i]['maneuver'] == "end-of-road") {
          maneuver.add('2');
        }
        if (steps[i]['maneuver'] == "fork-right") {
          maneuver.add('E');
        }
        if (steps[i]['maneuver'] == "fork-left") {
          maneuver.add('Q');
        }
        if (steps[i]['maneuver'] == "merge") {
          maneuver.add('W');
        }
        if (steps[i]['maneuver'] == "ramp-right") {
          maneuver.add('D');
        }
        if (steps[i]['maneuver'] == "ramp-left") {
          maneuver.add('A');
        }
        if (steps[i]['maneuver'] == "exit-right") {
          maneuver.add('D');
        }
        if (steps[i]['maneuver'] == "exit-left") {
          maneuver.add('A');
        }
        if (steps[i]['maneuver'] == "continue") {
          maneuver.add('W');
        }
        if (steps[i]['maneuver'] == "roundabout") {
          maneuver.add('D');
        }
        if (steps[i]['maneuver'] == "rotary") {
          maneuver.add('D');
        }
        if (steps[i]['maneuver'] == "roundabout-left") {
          maneuver.add('A');
        }
        if (steps[i]['maneuver'] == "roundabout-right") {
          maneuver.add('D');
        }
        if (steps[i]['maneuver'] == "roundabout-alternative") {
          maneuver.add('D');
        }
        if (steps[i]['maneuver'] == "exit-roundabout") {
          maneuver.add('D');
        }
        if (steps[i]['maneuver'] == "exit-rotary") {
          maneuver.add('D');
        }
        dis.add(steps[i]['distance']);
      }
    }

    double checkDistance = await calculateDistance(positionBySteps);
    print(checkDistance);
    print(positionBySteps);
    print(stepsCordi[0]);

    if(checkDistance > checkDistancOne){
      waitIfBigger++;
      if(waitIfBigger == 10){
        checkDistancOne = checkDistance;
        waitIfBigger = 0;
        stepsCordi = [];
      }
    }

    checkDistancOne = checkDistance;

    if (checkDistance < 0.05 ) {
      print('The current location and destination location match: send 3, ${maneuver[positionBySteps]}, Position: ${positionBySteps}');
      positionBySteps++;
    } else if(checkDistance > 0.2) {
      print('Distance > 200Meter : send 0');
    } else if(checkDistance < 0.2 && checkDistance > 0.1){
      print('Distance 200-100Meter : send 1');
    } else if(checkDistance < 0.1 && checkDistance > 0.05){
      print('Distance 100-20Meter : send 2');
    }
  }
//calculate distance
  Future<double> calculateDistance(positionBySteps) async {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((stepsCordi[positionBySteps].latitude - currentLocation!.latitude!) * p) / 2 +
        c(currentLocation!.latitude! * p) *
            c(stepsCordi[positionBySteps].latitude * p) *
            (1 -
                c((stepsCordi[positionBySteps].longitude - currentLocation!.longitude!) *
                    p)) /
            2;
    return 12742 * asin(sqrt(a));
  }




  @override
  void initState() {
    super.initState();
    _location.onLocationChanged.listen((locationData) {
      setState(() {
        currentLocation = locationData;
      });
    });
    BluetoothConnection.toAddress(widget.server.address).then((_connection) {
      print('Connected to the device');
      connection = _connection;
      setState(() {
        isConnecting = false;
        isDisconnecting = false;
      });

      connection!.input!.listen(_onDataReceived).onDone(() {
        // Example: Detect which side closed the connection
        // There should be `isDisconnecting` flag to show are we are (locally)
        // in middle of disconnecting process, should be set before calling
        // `dispose`, `finish` or `close`, which all causes to disconnect.
        // If we except the disconnection, `onDone` should be fired as result.
        // If we didn't except this (no flag set), it means closing by remote.
        if (isDisconnecting) {
          print('Disconnecting locally!');
        } else {
          print('Disconnected remotely!');
        }
        if (this.mounted) {
          setState(() {});
        }
      });
    }).catchError((error) {
      print('Cannot connect, exception occurred');
      print(error);
    });
  }

  final _controller = TextEditingController();
  final _controller1 = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _controller1.dispose();
    // Avoid memory leak (`setState` after dispose) and disconnect
    if (isConnected) {
      isDisconnecting = true;
      connection?.dispose();
      connection = null;
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    destination == ""
        ? const Center()
        : getRoute();
    return Scaffold(
      appBar: AppBar(
        title: SizedBox(
          child: Text('Firefly'),
        ),
      ),
      body: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Ziel (Leerzeichen mit + ersetzen)',
            ),
            controller: _controller1,
          ),
          ElevatedButton(
            onPressed: _sendMessage,
            child: Text("Send Route"),
          ),

        ],
      ),
    );
  }

  void _onDataReceived(Uint8List data) {
    // Allocate buffer for parsed data
    int backspacesCounter = 0;
    data.forEach((byte) {
      if (byte == 8 || byte == 127) {
        backspacesCounter++;
      }
    });
    Uint8List buffer = Uint8List(data.length - backspacesCounter);
    int bufferIndex = buffer.length;

    // Apply backspace control character
    backspacesCounter = 0;
    for (int i = data.length - 1; i >= 0; i--) {
      if (data[i] == 8 || data[i] == 127) {
        backspacesCounter++;
      } else {
        if (backspacesCounter > 0) {
          backspacesCounter--;
        } else {
          buffer[--bufferIndex] = data[i];
        }
      }
    }

    // Create message if there is new line character
    String dataString = String.fromCharCodes(buffer);
    int index = buffer.indexOf(13);
    if (~index != 0) {
      setState(() {
        messages.add(
          _Message(
            1,
            backspacesCounter > 0
                ? _messageBuffer.substring(
                0, _messageBuffer.length - backspacesCounter)
                : _messageBuffer + dataString.substring(0, index),
          ),
        );
        _messageBuffer = dataString.substring(index);
      });
    } else {
      _messageBuffer = (backspacesCounter > 0
          ? _messageBuffer.substring(
          0, _messageBuffer.length - backspacesCounter)
          : _messageBuffer + dataString);
    }
  }

  void _sendMessage() async {
    origin = "${currentLocation!.latitude!},${currentLocation!.longitude!}";
    destination = _controller1.text;
    await getRoute();
    String message = ''; // Combine the message into a single string

    // Add the data to the message string
    for (int i = 0; i < maneuver.length; i++) {
      message += maneuver[i];
    }

    try {
      BluetoothConnection connection =
      await BluetoothConnection.toAddress("Bluetooth Device Address");
      print('Connected to the device');
      Uint8List bytes = Uint8List.fromList(utf8.encode(message)); // Convert the message to bytes
      connection.output.add(bytes);
      await connection.output.allSent;
      await connection.finish();
      print('Data sent over Bluetooth');
    } catch (e) {
      print('Error sending data over Bluetooth: $e');
    }
  }
}
