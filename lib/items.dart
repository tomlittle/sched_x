library sched_x.global;

import 'package:flutter/material.dart';

// Type definitions and global varaibles
enum dueType { HARD, SOFT }

enum importance {VERY_HIGH, HIGH, NORMAL, LOW}
final List<String> importanceText = ['very high','high','normal','low'];
final List<IconData> importanceIcon = [
  IconData(58804, fontFamily: 'MaterialIcons'),
  IconData(61565, fontFamily: 'MaterialIcons'),
  IconData(61571, fontFamily: 'MaterialIcons'),
  IconData(61566, fontFamily: 'MaterialIcons'),
];
final List<DropdownMenuItem> importanceList = [
  DropdownMenuItem(
    child: Text('very high'),
    value: importance.VERY_HIGH,
  ),
  DropdownMenuItem(
    child: Text('high'),
    value: importance.HIGH,
  ),
  DropdownMenuItem(
    child: Text('normal'),
    value: importance.NORMAL,
  ),
  DropdownMenuItem(
    child: Text('low'),
    value: importance.LOW,
  ),
];

 class Session {
  int date;
  int startTime;
  int endTime;
}

class Item {
  String name;
  double duration;
  int dueDate;
  // dueType deadlineType;
  importance priority;
  // int earliestStart;
  // bool indivisible;
  // List<Session> sessions;

  Item({this.name, this.duration, this.dueDate, this.priority});

  Item.fromJson(Map<String, dynamic> json)
      : name = json['name'] as String,
        duration = json['duration'] as double,
        dueDate = json['dueDate'] as int,
        priority = importance.values[json['priority']];

  Map<String, dynamic> toJson() =>
    {
      'name': name,
      'duration': duration,
      'dueDate': dueDate,
      // 'deadlineType': null,
      'priority': priority.index,
      // 'earliestStart': null,
      // 'indivisible': null,
      // 'sessions': null,
    };
}

List<Item> xItems = [];
