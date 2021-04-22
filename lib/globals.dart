// Handy constants
import 'package:flutter/material.dart';

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
class XConfiguration {
  static String timeZone;
  // Calendar provider
  static String calendarType;
  // Authorization stuff
  static String user;
  // Scheduling stuff
  static TimeOfDay workdayStart;
  static TimeOfDay workdayEnd;

  static final XConfiguration _config = XConfiguration.internal();

  factory XConfiguration() {
    return _config;
  }

  XConfiguration.internal() {
    timeZone = 'GMT+01:00';
    calendarType = "google";
    // Assign values - dummy until config by user possible
    user = "tom@tomlittle.com";
    workdayStart = TimeOfDay(hour: 13, minute: 0);
    workdayEnd   = TimeOfDay(hour: 17, minute: 0);
  }
 
}