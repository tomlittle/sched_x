import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:firebase_core/firebase_core.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart' as fb_store;
import 'dart:convert' show utf8;
import 'dart:typed_data' show Uint8List;

import 'package:sched_x/globals.dart';

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

  _showDialog() async {
    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {return AlertDialog(
          titlePadding: EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 12.0),
          title: Text("Settings"),
          content: SingleChildScrollView(
            child: Material(
              child: SettingsDialogContent(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Ok'),
              onPressed: () { _saveSettings(); Navigator.popUntil(context, ModalRoute.withName('/'));
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
    fb_store.Reference fbStorageRef = fbStorage.ref('test/config.003');
    try {
      fbStorageRef.putData(data);
      setState(() { isBusy = false; });
    } on fb.FirebaseException catch (e) {
        print(e.toString());
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

  _getContent(){
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Dropdown for scheduling algorithm
        Container(
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.only(left: 10.0),
          child: TextButton(
            child: Text("schedule items as "+xConfiguration.scheduling.substring(0,4)+" as possible",
                        style: TextStyle(color: Colors.grey[800])),
          onPressed: () async {await _displaySchedulingDropdown(context); setState(() {});},
          )),
        // Dropdown for overdue scheduling rule
        Container(
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.only(left: 10.0),
          child: TextButton(
            child: Text("schedule overdue items "+xConfiguration.overdueScheduling,
                        style: TextStyle(color: Colors.grey[800])),
          onPressed: () async {await _displayOverdueDropdown(context); setState(() {});},
          )),
          const Divider(
              height: 20,
              thickness: 5,
              indent: 20,
              endIndent: 20,
            ),          
        // Array of switches for working days
        Row(
          children: [
            Text("schedule on these days: ", style: TextStyle(color: Colors.grey[800])),
            TextButton(
              child: Text(_buildWorkingdayString(),
                          style: TextStyle(color: Colors.grey[800])),
            onPressed: () async {await _displayWorkingdaysPicker(context); setState(() {});},
            )]),
        // Time pickers for start and end of day
        Row(
          children: [
          TextButton(
            child: Text("schedule items between "+xConfiguration.workdayStart,
                        style: TextStyle(color: Colors.grey[800])),
          onPressed: () async {await _displayWorkingtimePicker(context,true); setState(() {});},
          ),
          TextButton(
            child: Text(" and "+xConfiguration.workdayEnd,
                        style: TextStyle(color: Colors.grey[800])),
          onPressed: () async {await _displayWorkingtimePicker(context,false); setState(() {});},
          )]),
      ],
    );
  }

  final List<String> _dayNames = ['Mo','Tu','We','Th','Fr','Sa','Su'];

  String _buildWorkingdayString () {
    String _wDays = "";
    for (int i=0; i<7; i++) {
      _wDays += xConfiguration.workingDays[i] ? _dayNames[i] : "";
    }
    return _wDays;
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
                  Navigator.of(context).pop(); 
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
                        DropdownMenuItem(child: Text("after other items"), value: "last"),],
                onChanged: (value) {
                  setState(() {xConfiguration.overdueScheduling = value;
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
    List<SwitchListTile> _switches = [];
    List<bool> _values = xConfiguration.workingDays;
    for (int i=0; i<7; i++) {
      SwitchListTile _s = SwitchListTile(title: Text(_dayNames[i]),
                                         value: _values[i],
                                         onChanged: (bool value) { _values[i] = value; xConfiguration.workingDays[i] = value; },
                          );                
      _switches.add(_s);
    }
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Working Days'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: _switches));
        });
  }

  @override
  Widget build(BuildContext context) {
    return _getContent();
  }

}