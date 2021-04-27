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
  static String calendarType;  // "google" or "simulated"
  // Scheduling algorithm
  static String scheduling;  // "soonest" or "latest"
  // Scheduling algorithm for overdue items
  static String overdueScheduling;  // "first", "last" or "none"
  // Authorization stuff
  static String user;
  // Scheduling constraints - should come from calendar but there is no Google API
  static TimeOfDay workdayStart;
  static TimeOfDay workdayEnd;
  static List<bool> workingDays;

  static final XConfiguration _config = XConfiguration.internal();

  factory XConfiguration() {
    return _config;
  }

  XConfiguration.internal() {
    // Assign values - dummy until config by user possible
    timeZone = 'GMT+01:00';
    calendarType = "google";
    scheduling="soonest";
    overdueScheduling = "first";
    user = "tom@tomlittle.com";
    workingDays = [true, true, true, true, true, false, false];
    workdayStart = TimeOfDay(hour: 9, minute: 0);
    workdayEnd   = TimeOfDay(hour: 17, minute: 0);
  }
 
}