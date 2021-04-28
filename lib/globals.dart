import 'dart:convert';

import 'package:firebase_core/firebase_core.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart' as fb_store;
import 'dart:convert' show utf8;

// Handy constants

const int ONE_MINUTE = 60000;
const int ONE_HOUR = 3600000;
const int ONE_DAY = 86400000;

// Global classes

// Calendar class, to date "simulated" and "Google" implemented
abstract class XCalendar {
    bool initialize();
    Future<List<OpenBlock>> getFreeBlocks(DateTime startAt, DateTime endAt);
}

// Blocks of available time in the calendar
class OpenBlock {
  int startTime;
  int duration;
}

// Configuration data
XConfiguration xConfiguration = XConfiguration();

class XConfiguration {
  String timeZone;
  // Calendar provider
  String calendarType;  // "google" or "simulated"
  // Scheduling algorithm
  String scheduling;  // "soonest" or "latest"
  // Scheduling algorithm for overdue items
  String overdueScheduling;  // "first", "last" or "none"
  // Authorization stuff
  String user;
  // Scheduling constraints - should come from calendar but there is no Google API
  String workdayStart;
  String workdayEnd;
  List<bool> workingDays;

  static final XConfiguration _config = XConfiguration.internal();

  factory XConfiguration() {
    return _config;
  }

  XConfiguration.internal() {
    fb_store.FirebaseStorage fbStorage = fb_store.FirebaseStorage.instance;
    fb_store.Reference fbStorageRef = fbStorage.ref('test/config.003');
    try {
      fbStorageRef.getData(1000000).then((data) {
        String dataAsString = utf8.decode(data);
        xConfiguration = XConfiguration.fromJson(json.decode(dataAsString));
      });
    } on fb.FirebaseException catch (e) {
        print(e.toString());
    }
  }

  // XConfiguration.internal() {
  //   // Assign values - dummy until config by user possible
  //   timeZone = 'GMT+01:00';
  //   calendarType = "google";
  //   scheduling="soonest";
  //   overdueScheduling = "first";
  //   user = "tom@tomlittle.com";
  //   workingDays = [true, true, true, true, true, false, false];
  //   workdayStart = "09:00";
  //   workdayEnd   = "17:00";
  // }
 
  XConfiguration.fromJson(Map<String, dynamic> jsonString)
      : timeZone = jsonString['timeZone'] as String,
        calendarType = jsonString['calendarType'] as String,
        scheduling = jsonString['scheduling'] as String,
        overdueScheduling = jsonString['overdueScheduling'] as String,
        user = jsonString['user'] as String,
        workingDays = (jsonString['workingDays'] as List).cast<bool>(),
        workdayStart = jsonString['workdayStart'] as String,
        workdayEnd = jsonString['workdayEnd'] as String
      ;
        
  Map<String, dynamic> toJson() =>
    {
      'timeZone': timeZone, 
      'calendarType': calendarType, 
      'scheduling': scheduling, 
      'overdueScheduling': overdueScheduling, 
      'user': user, 
      'workingDays': workingDays, 
      'workdayStart': workdayStart, 
      'workdayEnd': workdayEnd, 
    };

}