import 'dart:convert';

import 'package:firebase_core/firebase_core.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart' as fb_store;
import 'dart:convert' show utf8;
import 'dart:typed_data' show Uint8List;

import 'package:flutter_login/flutter_login.dart';
import 'items.dart' as items;

// Handy constants
const int ONE_MINUTE = 60000;
const int ONE_HOUR = 3600000;
const int ONE_DAY = 86400000;

// Global classes

// Authorization class for user access
abstract class XAuthorize {
  static UserData currentUser;
  Future<String> createUser(LoginData data);
  Future<String> authUser(LoginData data);
  Future<String> deauthUser();
  Future<String> recoverPassword(String name);
}

// User data
class UserData {
  String name;
  String password;
  String dataLocation;
  bool isLoggedIn;
}

// Calendar class, to date "simulated" and "Google" implemented
class WorldTime {
  String dateTime;
  String timeZone;
}

abstract class XCalendar {
    bool initialize();
    Future<List<OpenBlock>> getFreeBlocks(DateTime startAt, DateTime endAt);
    Future<bool> createCalendarEntry(items.Item event);
    Future removeCalendarSession(items.Item event, int index);
    Future removeCalendarEntry(items.Item event);
}

// Blocks of available time in the calendar
class OpenBlock {
  int startTime;
  int duration;

  OpenBlock copy () {
    OpenBlock _copy = new OpenBlock();
    _copy.startTime = this.startTime;
    _copy.duration  = this.duration;
    return _copy;
  }
}

// Configuration data
XConfiguration xConfiguration;

class XConfiguration {
  String timeZone;
  // Firebase configuration
  String fbRootFolder;
  // Calendar provider
  String calendarType;  // "google" or "simulated"
  // Scheduling algorithm
  String scheduling;  // "soonest" or "latest"
  // Scheduling algorithm for overdue items
  String overdueScheduling;  // "first", "last" or "none"
  int minimumSession;  // minimum session length in minutes, -1 for no minimum
  // Authorization stuff
  String user;  // Email address
  // Scheduling constraints - should come from calendar but there is no Google API
  String workdayStart;
  String workdayEnd;
  List<bool> workingDays;

  static final XConfiguration _config = XConfiguration();

  factory XConfiguration() {
    return _config;
  }

  XConfiguration.newConfigForUser(String userName) {
    XConfiguration _config = XConfiguration();
    _config.timeZone = 'GMT+01:00';    
    _config.fbRootFolder = userName;
    _config.calendarType = 'simulated';
    _config.scheduling = 'soonest';
    _config.overdueScheduling = 'first';
    _config.minimumSession = 30;
    _config.user = userName;
    _config.workdayStart = '09:00';
    _config.workdayEnd = '17:00';
    _config.workingDays = [true,true,true,true,true,false,false];
    String text = json.encode(_config.toJson());
    List<int> encoded = utf8.encode(text);
    Uint8List data = Uint8List.fromList(encoded);    
    fb_store.FirebaseStorage fbStorage = fb_store.FirebaseStorage.instance;
    fb_store.Reference fbStorageRef = fbStorage.ref(_config.fbRootFolder+'/config.json');
    try {
      fbStorageRef.putData(data);
    } on fb.FirebaseException catch (e) {
        consolePrint(e.toString());
    }
  } 

  XConfiguration.readConfigForUser(String dataLocation) {
    fb_store.FirebaseStorage fbStorage = fb_store.FirebaseStorage.instance;
    fb_store.Reference fbStorageRef = fbStorage.ref(dataLocation+'/config.json');
    try {
      fbStorageRef.getData(1000000).then((data) {
        String dataAsString = utf8.decode(data);
        xConfiguration = XConfiguration.fromJson(json.decode(dataAsString));
      });
    } on fb.FirebaseException catch (e) {
        print(e.toString());
    }
  }

  XConfiguration.fromJson(Map<String, dynamic> jsonString)
      : timeZone = jsonString['timeZone'] as String,
        fbRootFolder = jsonString['fbRootFolder'] as String,
        calendarType = jsonString['calendarType'] as String,
        scheduling = jsonString['scheduling'] as String,
        overdueScheduling = jsonString['overdueScheduling'] as String,
        minimumSession = jsonString['minimumSession'] as int,
        user = jsonString['user'] as String,
        workingDays = (jsonString['workingDays'] as List).cast<bool>(),
        workdayStart = jsonString['workdayStart'] as String,
        workdayEnd = jsonString['workdayEnd'] as String
      ;
        
  Map<String, dynamic> toJson() =>
    {
      'timeZone': timeZone, 
      'fbRootFolder': fbRootFolder,
      'calendarType': calendarType, 
      'scheduling': scheduling, 
      'overdueScheduling': overdueScheduling, 
      'minimumSession': minimumSession,
      'user': user, 
      'workingDays': workingDays, 
      'workdayStart': workdayStart, 
      'workdayEnd': workdayEnd, 
    };

}

final bool inDebugMode = true;
// Categories: slots, freebusy, calendar, schedule
final List<String> activeCategories = [''];
void consolePrint (String s, {String category}) {
  if (inDebugMode) {
    if ((category==null) || activeCategories.contains(category)) {
      print('-> '+s);
    }
  }
}