import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinbox/material.dart'; 

import 'package:firebase_core/firebase_core.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart' as fb_store;
import 'dart:convert' show utf8;
import 'dart:typed_data' show Uint8List;

import 'package:sched_x/globals.dart';

class XTimeZone {
  DropdownMenuItem ddItem;
  String offset;
  static int i = 0;

  XTimeZone(this.ddItem,this.offset);

  factory XTimeZone.fromJson(dynamic json) {
    String isoOffset = tzOffset(json['rawOffsetInMinutes']);
    return XTimeZone(DropdownMenuItem(child: Text(json['name'] as String), value: XTimeZone.i++), isoOffset);
  }

  static String tzOffset(double minutes) {
    int h = minutes.abs() ~/ 60;
    int m = (minutes.abs()-h*60).toInt();
    String sign = (minutes<0) ? "-" : "+";
    NumberFormat _f = NumberFormat("00");
    print("GMT"+sign+_f.format(h)+":"+_f.format(m));
    return "GMT"+sign+_f.format(h)+":"+_f.format(m);
  }
}

final List<String> _dayNames = ['Mo','Tu','We','Th','Fr','Sa','Su'];

class SettingsDialog extends StatefulWidget {

  //SettingsDialog({Key key}) : super(key: key);

  @override
  _SettingsDialogState createState() => new _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {

  bool isBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_){_showDialog();});
  }

  BuildContext dialogContext;

  _showDialog() async {
    await showDialog<String>(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {dialogContext = context;
        return AlertDialog(
          titlePadding: EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 12.0),
          title: Text("Settings for "+xConfiguration.user),
          content: SingleChildScrollView(
            child: Material(
              child: SettingsDialogContent(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Ok'),
              onPressed: () { _saveSettings(); 
                              Navigator.of(context).pushNamedAndRemoveUntil('/itemList', (Route<dynamic> route) => false);
              },
            ),
          ],
      );}
    );}

  void _saveSettings () {
    setState(() { isBusy = true; });
    String text = json.encode(xConfiguration.toJson());
    List<int> encoded = utf8.encode(text);
    Uint8List data = Uint8List.fromList(encoded);    
    fb_store.FirebaseStorage fbStorage = fb_store.FirebaseStorage.instance;
    fb_store.Reference fbStorageRef = fbStorage.ref(xConfiguration.fbRootFolder+'/config.json');
    try {
      fbStorageRef.putData(data);
      setState(() { isBusy = false; });
    } on fb.FirebaseException catch (e) {
        consolePrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class SettingsDialogContent extends StatefulWidget {
  @override
  _SettingsDialogContentState createState() => new _SettingsDialogContentState();
}

class _SettingsDialogContentState extends State<SettingsDialogContent> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_){_getContent();});
  }

  //   Manual dummy in config file
  //   timeZone = 'GMT+01:00';

  _getContent(){
    // final TextEditingController _controller = TextEditingController();
    // _controller.text = xConfiguration.user;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Dropdown for scheduling algorithm
        Container(
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.only(left: 10.0),
          child: TextButton(child: Text("schedule items as "+xConfiguration.scheduling.substring(0,4)+" as possible",
                            style: TextStyle(color: Colors.grey[800])),
          onPressed: () async {await _displaySchedulingDropdown(context); setState(() {});},
          )),
        // Dropdown for overdue scheduling rule
        Container(
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.only(left: 10.0),
          child: TextButton(child: Text((xConfiguration.overdueScheduling=="none" ? "don't " : "")+"schedule overdue items "+
                                        (xConfiguration.overdueScheduling!="none" ? xConfiguration.overdueScheduling : ""),
                                        style: TextStyle(color: Colors.grey[800])),
          onPressed: () async {await _displayOverdueDropdown(context); setState(() {});},
          )),
        const Divider(height: 20, thickness: 5, indent: 20, endIndent: 20,),          
        // Array of switches for working days
        Container(
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.only(left: 10.0),
          child: Row(children: [Text("schedule on these days: ", style: TextStyle(color: Colors.grey[800])),
                                TextButton(child: Text(_buildWorkingdayString(),style: TextStyle(color: Colors.grey[800])),
                                           onPressed: () { _displayWorkingdaysPicker(context); setState(() {});},)
          ])),
        // Time pickers for start and end of day
        Container(
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.only(left: 10.0),
          child: Row(children: [TextButton(child: Text("schedule items between "+xConfiguration.workdayStart,
                                           style: TextStyle(color: Colors.grey[800])),
                                           onPressed: () async {await _displayWorkingtimePicker(context,true); setState(() {});},),
                                TextButton(child: Text(" and "+xConfiguration.workdayEnd,
                                           style: TextStyle(color: Colors.grey[800])),
                                           onPressed: () async {await _displayWorkingtimePicker(context,false); setState(() {});},),
        ])),
        Container(
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.only(left: 10.0),
          child: TextButton(child: Text("in the time zone "+xConfiguration.timeZoneName,
                                        style: TextStyle(color: Colors.grey[800])),
                            onPressed: () async {await _displayTimezoneDropdown(context); setState(() {});},
          )),
        const Divider(height: 20, thickness: 5, indent: 20, endIndent: 20,),
        Container(
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.only(left: 10.0),
          child: TextButton(child: (xConfiguration.dailyReserve >0) ?
                                        Text("leave at least "+xConfiguration.dailyReserve.toString()+" minutes free daily",
                                        style: TextStyle(color: Colors.grey[800])) :
                                        Text("do not reserve daily free minutes",
                                        style: TextStyle(color: Colors.grey[800])),
                            onPressed: () async {await _displayReserveCounter(context); setState(() {});},
          )),
          Container(
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.only(left: 10.0),
          child: Row(
              children: [Container(
              padding: EdgeInsets.zero,
              child: (xConfiguration.minimumSession > 0) ?
                        IconButton(
                          icon: Icon(IconData(Icons.highlight_remove.codePoint, fontFamily: 'MaterialIcons')),
                          tooltip: "Remove minimum session length",
                          onPressed: () {xConfiguration.minimumSession = -1; setState(() {});},
                        ) : null, 
            ),
            Container(
              alignment: Alignment.centerLeft,
//              padding: EdgeInsets.only(left: 10.0),
              child: TextButton(
                child: (xConfiguration.minimumSession > 0) ?
                        Text("sessions are at least "+xConfiguration.minimumSession.toString()+" minutes long",
                            style: TextStyle(color: Colors.grey[800])) : 
                        Text("Set minimum session length", style: TextStyle(color: Colors.lightBlue)),
                onPressed: () async {await _displaySessionlengthCounter(context); setState(() {});}, 
            ))]),
          ),
        const Divider(height: 20, thickness: 5, indent: 20, endIndent: 20,),          
        Container(
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.only(left: 10.0),
          child: TextButton(child: Text("use "+xConfiguration.calendarType+" calendar",
                                        style: TextStyle(color: Colors.grey[800])),
                            onPressed: () async {await _displayCalendartypeDropdown(context); setState(() {});},
          ),
        ),
      ],
    );
  }

  String _buildWorkingdayString () {
    String _wDays = "";
    for (int i=0; i<7; i++) {
      _wDays += xConfiguration.workingDays[i] ? _dayNames[i]+" " : "";
    }
    return _wDays;
  }

  Future<void> _displayReserveCounter (BuildContext context) async {
    double _spinnerValue = xConfiguration.dailyReserve as double;
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Reserved Minutes per Day'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SpinBox(
                min: 0,
                max: 1440,
                step: 15,
                decimals: 0,
                value: _spinnerValue,
                onChanged: (value) => setState((){xConfiguration.dailyReserve = value as int; _spinnerValue = value;}),
              )],
          ),);
      },
    );  
  }


  Future<void> _displaySessionlengthCounter (BuildContext context) async {
    double _spinnerValue = (xConfiguration.minimumSession<0 ? 30 : xConfiguration.minimumSession) as double;
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Minimum Session Lnegth'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SpinBox(
                min: 30,
                max: 1440,
                step: 30,
                decimals: 0,
                value: _spinnerValue,
                onChanged: (value) => setState((){xConfiguration.minimumSession = value as int; _spinnerValue = value;}),
              )],
          ),);
      },
    );  
  }

  Future<void> _displaySchedulingDropdown (BuildContext context) {
    String _dropdownValue = xConfiguration.scheduling;
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Scheduling Rule'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [DropdownButton(
                value: _dropdownValue,
                items: [DropdownMenuItem(child: Text("as soon as possible"), value: "soonest"),
                        DropdownMenuItem(child: Text("as late as possible"), value: "latest"),],
                onChanged: (value) {
                  setState(() {xConfiguration.scheduling = value;
                  _dropdownValue = value;
                  Navigator.of(context).maybePop(); 
                  });
              }),
          ]));
        });
  }

  Future<void> _displayOverdueDropdown (BuildContext context) {
    String _dropdownValue = xConfiguration.overdueScheduling;
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Scheduling Rule'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [DropdownButton(
                value: _dropdownValue,
                items: [DropdownMenuItem(child: Text("before other items"), value: "first"),
                        DropdownMenuItem(child: Text("after other items"), value: "last"),
                        DropdownMenuItem(child: Text("don't schedule overdue items"), value: "none"),],
                onChanged: (value) {
                  setState(() {xConfiguration.overdueScheduling = value;
                  _dropdownValue = value;
                  Navigator.of(context).pop(); 
                  });
              }),
          ]));
        });
  }

  Future<void> _displayTimezoneDropdown (BuildContext context) async {
    // Read the time zone database
    final String response = await rootBundle.loadString('data/raw-time-zones.json');
    final _tzData = await json.decode(response);
    // Extract and transform data for use in the dropdown
    List<DropdownMenuItem> _tzListData = [];
    List _tzOffsetData = [];
    List<XTimeZone> _xTzList = [];
    for (final tz in _tzData) {
      _xTzList.add(XTimeZone.fromJson(tz));
    }
    _xTzList.sort((x,y) => x.ddItem.child.toString().compareTo(y.ddItem.child.toString()));
    for (final tz in _xTzList) {
      _tzListData.add(tz.ddItem);
      _tzOffsetData.add({"offset": tz.offset, "value": tz.ddItem.value});
    }
    // !!!
    int _dropdownValue = _tzListData.firstWhere((element) => (element.child as Text).data == xConfiguration.timeZoneName).value;
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Time Zone'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [DropdownButton(
                value: _dropdownValue,
                items: _tzListData,
                onChanged: (value) { setState(() {
                  xConfiguration.timeZoneName = ((_tzListData.firstWhere((element) => element.value == value)).child as Text).data;
                  xConfiguration.timeZone = (_tzOffsetData.firstWhere((element) => element["value"] == value))["offset"];
                  _dropdownValue = value;
                  Navigator.of(context).pop(); 
                  });
              }),
          ]));
        });
  }

  Future<void> _displayWorkingtimePicker (BuildContext context, bool isStart) async {
    TimeOfDay _pickerValue = isStart ? TimeOfDay(hour: int.parse(xConfiguration.workdayStart.substring(0,2)),
                                                 minute: int.parse(xConfiguration.workdayStart.substring(3))) :
                                       TimeOfDay(hour: int.parse(xConfiguration.workdayEnd.substring(0,2)),
                                                 minute: int.parse(xConfiguration.workdayEnd.substring(3)));
    TimeOfDay pickedTime = await showTimePicker(
      context: context,
      initialTime: _pickerValue,
      builder: (BuildContext context, Widget child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child,
      );
      },
    );
    if (pickedTime != null) {
      NumberFormat _f = NumberFormat("00");
      if (isStart) {
        xConfiguration.workdayStart = _f.format(pickedTime.hour)+":"+_f.format(pickedTime.minute);
      } else {
        xConfiguration.workdayEnd = _f.format(pickedTime.hour)+":"+_f.format(pickedTime.minute);
      }
      _pickerValue = pickedTime;
    }
  }

  Future<void> _displayWorkingdaysPicker (BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (__) => 
                   WorkingdaysDialog(), maintainState: true, fullscreenDialog: false))
                   .then((value) => setState(() {}));
    return null;
  }

  Future<void> _displayCalendartypeDropdown (BuildContext context) {
    String _dropdownValue = xConfiguration.calendarType;
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Calendar Type'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [DropdownButton(
                value: _dropdownValue,
                items: [DropdownMenuItem(child: Text("use Google calendar"), value: "google"),
                        DropdownMenuItem(child: Text("simulate a calendar"), value: "simulated"),],
                onChanged: (value) {
                  setState(() {xConfiguration.calendarType = value;
                  _dropdownValue = value;
                  Navigator.of(context).pop(); 
                  });
              }),
          ]));
        });
  }

  @override
  Widget build(BuildContext context) {
    return _getContent();
  }

}

class WorkingdaysDialog extends StatefulWidget {
  @override
  _WorkingdaysDialogState createState() => new _WorkingdaysDialogState();
}

class _WorkingdaysDialogState extends State<WorkingdaysDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_){_showDialog();});
  }

   _showDialog() async {
    await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          titlePadding: EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 12.0),
          title: Text("Working Days"),
          content: SingleChildScrollView(
            child: Material(
              child: WorkingdaysDialogContent(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Ok'),
                onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            ),
          ],
      );}
    );}

 @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class WorkingdaysDialogContent extends StatefulWidget {
  @override
  _WorkingdaysDialogContentState createState() => new _WorkingdaysDialogContentState();
}

class _WorkingdaysDialogContentState extends State<WorkingdaysDialogContent> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_){_getContent();});
  }
 
  _getContent(){
    List<SwitchListTile> _switches = [];
    List<bool> _values = xConfiguration.workingDays;
    for (int i=0; i<7; i++) {
      SwitchListTile _s = SwitchListTile(title:
                            Text(_dayNames[i]),
                            value: _values[i],
                            onChanged: (bool value) { _values[i] = value; xConfiguration.workingDays[i] = value; 
                                        setState(() {});},
                          );
      _switches.add(_s);
    }
   return Column(mainAxisSize: MainAxisSize.min, children: _switches);
  }

  @override
  Widget build(BuildContext context) {
    return _getContent();
  }

}