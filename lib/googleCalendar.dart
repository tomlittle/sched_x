import 'dart:async';
import 'package:intl/intl.dart';

import 'package:googleapis/calendar/v3.dart';
import 'package:googleapis_auth/auth_io.dart';

import 'package:sched_x/globals.dart';
import 'package:sched_x/googleAccountSecrets.dart';
import 'package:sched_x/openBlocks.dart';

class GoogleCalendar extends XCalendar {

  static ServiceAccountCredentials _accountCredentials;

  static var _scopes;
  // static final GoogleCalendar _thisCal = GoogleCalendar.internal();
  static GoogleCalendar _thisCal;
  static CalendarApi _calendar;

  factory GoogleCalendar() {
    if (_thisCal==null) {
      _accountCredentials = getSecrets(xConfiguration.user);
      _scopes = [CalendarApi.calendarScope];
      _thisCal = GoogleCalendar.internal();
    }
    return _thisCal;
  }

  GoogleCalendar.internal() {
    initCalendar();
  }

  // bool initialize() {return (true);}

  Future<CalendarApi> initCalendar() async {
    if (_calendar==null) {
      var httpClient = await clientViaServiceAccount(_accountCredentials, _scopes);
      try {
        _calendar = CalendarApi(httpClient);
      } catch(e) {
        print('$e');
      } finally {
        httpClient.close();
        consolePrint('Got Google calendar',category: 'calendar');
      }
    }
    return _calendar;
  }    

  Future<FreeBusyResponse> getFreeBusy (DateTime startAt, DateTime endAt) async {
    FreeBusyResponse _freeBusyInfo;
    consolePrint("Waiting for calendar", category: 'freebusy');
    await initCalendar().then((_cal) async {
      final request = FreeBusyRequest()
              ..timeMin = startAt.toUtc()
              ..timeMax = endAt.toUtc()
              ..timeZone = xConfiguration.timeZone
              ..items = [ FreeBusyRequestItem()
              ..id=xConfiguration.user];
      consolePrint("Waiting for free/busy", category: 'freebusy');
      _freeBusyInfo = await _cal.freebusy.query(request);
      consolePrint ("Got free/busy", category: 'freebusy');
    });
    return _freeBusyInfo;
  }

  Future<List<OpenBlock>> getFreeBlocks (DateTime startAt, DateTime endAt) async {
    int _startHour = int.parse(xConfiguration.workdayStart.substring(0,2));
    int _startMinute = int.parse(xConfiguration.workdayStart.substring(3));
    int _endHour = int.parse(xConfiguration.workdayEnd.substring(0,2));
    int _endMinute = int.parse(xConfiguration.workdayEnd.substring(3));
    // Set the calendar span to search for free blocks
    // Start at midnight to catch busy times that begin before the working day starts
    startAt = DateTime(startAt.year,startAt.month,startAt.day,0,0,0,0,0);
    endAt = DateTime(endAt.year,endAt.month,endAt.day,_endHour,_endMinute,0,0,0);  
    // Start the free block search at midnight to catch blocks beginning before start of working day
    int _dailyDuration = (_endHour*60 + _endMinute) * ONE_MINUTE;
    // Iterate the list of calendars and in each calendar the list of "busy blocks"
    consolePrint("Asking for free/busy", category: 'freebusy');
    List<OpenBlock> _slots = [];
    await getFreeBusy(startAt,endAt).then((_freeBusyInfo) {
      if (_freeBusyInfo!=null) {
        _freeBusyInfo.calendars.forEach((key, value) {
          consolePrint("Calendar: "+key.toString(),category: 'freebusy');
          _slots = OpenBlockList.create(startAt, endAt, _dailyDuration);
          _slots.showBlocks('Start with all day every day');
          for (int i=0; i<value.busy.length; i++) {
            consolePrint("    Busy: "+value.busy[i].start.toString()+" - "+value.busy[i].end.toString(),category: 'freebusy');
            // Create a time block (start & duration) from the busy block
            OpenBlock _fbSlot = new OpenBlock();
            DateTime _utcStart = DateFormat("yyyy-MM-dd HH:mm:ssZ").parse(value.busy[i].start.toString(), true);
            DateTime _utcEnd   = DateFormat("yyyy-MM-dd HH:mm:ssZ").parse(value.busy[i].end.toString(), true);
            _fbSlot.startTime = _utcStart.toLocal().millisecondsSinceEpoch;
            _fbSlot.duration = _utcEnd.toLocal().millisecondsSinceEpoch - _fbSlot.startTime;
            // Find the free block containing the busy block
            for (int j=0; j<_slots.length; j++) {
              if ((_slots[j].startTime <= _fbSlot.startTime) &&
                  (_slots[j].startTime+_slots[j].duration >= _fbSlot.startTime+_fbSlot.duration)) {
                _fbSlot.dayID = _slots[j].dayID;
                _slots.subtractBlockFromList(j,_fbSlot);
                // // If the whole slot was used, remove it, otherwise shorten it
                // if (_slots[j].duration==_fbSlot.duration) {
                //   _slots.remove(_slots[j]);
                // } else {
                //   if (_slots[j].startTime == _fbSlot.startTime) {
                //     // Remove from start
                //     _slots[j].startTime += _fbSlot.duration;
                //     // !!! ADDDED - Reduce the duration of the slot
                //     _slots[j].duration -= _fbSlot.duration;
                //     // !!! CHANGED - end times equal, not <=
                //   } else if (_slots[j].startTime+_slots[j].duration == _fbSlot.startTime+_fbSlot.duration) {
                //     // Remove from end
                //     _slots[j].duration -= _fbSlot.duration;
                //   } else {
                //     // Remove from the middle
                //     int _temp = _slots[j].duration;
                //     _slots[j].duration = _fbSlot.startTime-_slots[j].startTime;
                //     OpenBlock _newSlot = new OpenBlock();
                //     _newSlot.startTime = _fbSlot.startTime+_fbSlot.duration;
                //     _newSlot.duration = _temp+_slots[j].startTime-_newSlot.startTime;
                //     _newSlot.dayID = _fbSlot.dayID;
                //     _slots.insert(j+1,_newSlot);
                //   }
                // }
                break;
              }
            }
          }
      });
      _slots..showBlocks('After removing free/busy');
      consolePrint("Created slots", category: 'freebusy');
      // Clean up (1): remove any slots that are in the past
      _slots.removePastBlocks(startAt);
      _slots..showBlocks('After removing past');
      // Clean up (2): remove any slots that are before the start of the working day
      _slots.removeEarlyBlocks(startAt,_startHour,_startMinute);
      _slots.showBlocks('After checking start of day');
    }
    consolePrint("Returning slots", category: 'slots');
    return _slots;
    });
  return Future.value(_slots);
  }

  Future<bool> createCalendarEntry (event) async {
    bool retval;
    consolePrint('Creating '+event.name, category: 'calendar');
    // Create Google event object
    Event entry = Event();
    entry.summary = event.name;
    int nSessions = event.sessions.length;
    await initCalendar().then((_cal) async {
    for (int i=0; i<nSessions; i++) {
      entry.description = event.name+' - '+(i+1).toString()+' of '+nSessions.toString();
      EventDateTime start = new EventDateTime();
      start.dateTime = DateTime.fromMillisecondsSinceEpoch(event.sessions[i].startTime);
      String _tz = DateTime.now().timeZoneOffset.toString();
      start.timeZone = 'UTC';
      start.timeZone += ('${_tz[0]}'=='-') ? '' : '+';
      start.timeZone += _tz;
      entry.start = start;
      EventDateTime end = new EventDateTime();
      end.dateTime = DateTime.fromMillisecondsSinceEpoch(event.sessions[i].startTime+event.sessions[i].duration);
      end.timeZone = start.timeZone;
      entry.end = end;
      // Create calendar entry
      await _cal.events.insert(entry,xConfiguration.user).then((value) {
          if (value.status == "confirmed") {
            consolePrint('Event '+value.description+' added to google calendar', category: 'calendar');
            event.sessions[i].calId = value.id;
            retval = true;
          } else {
            consolePrint('Unable to add event '+value.description+' to google calendar', category: 'calendar');
            retval = false;
          }      
        });
        Future.delayed(Duration(milliseconds: 500));
      }
    });
    return retval;
  }

  Future<bool> removeCalendarSession(event,i) async {
    bool retval;
    await initCalendar().then((_cal) async {
      if (event.sessions[i].calId!=null) {
        // Get item by ID
        // await getCalendar().then((_cal) async {
        consolePrint("Looking for "+event.sessions[i].calId,category: 'calendar');
        await _cal.events.get(xConfiguration.user,event.sessions[i].calId).then((entry) {
          if (entry.status == "confirmed") {
            consolePrint('Event '+entry.summary+' found in google calendar', category: 'calendar');
            _cal.events.delete(xConfiguration.user,event.sessions[i].calId).then((retval) {
              retval = true;
              consolePrint('Return from calendar', category: 'calendar');
            });
          } else {
            consolePrint('Event '+entry.summary+' NOT found in google calendar', category: 'calendar');
            retval = false;
          }      
        });
      }
    });
    return retval;
  }

  Future<bool> removeCalendarEntry (event) async {
    bool retval;
    await initCalendar().then((_cal) async {
      for (int i=0; i<event.sessions.length; i++) {
        if (event.sessions[i].calId!=null) {
          // Get item by ID
          // await getCalendar().then((_cal) async {
          consolePrint("Looking for "+event.sessions[i].calId,category: 'calendar');
          await _cal.events.get(xConfiguration.user,event.sessions[i].calId).then((entry) {
            if (entry.status == "confirmed") {
              consolePrint('Event '+entry.summary+' found in google calendar', category: 'calendar');
              _cal.events.delete(xConfiguration.user,event.sessions[i].calId).then((retval) {
                retval = true;
                consolePrint('Return from calendar', category: 'calendar');
              });
            } else {
              consolePrint('Event '+entry.summary+' NOT found in google calendar', category: 'calendar');
              retval = false;
            }      
          });
        Future.delayed(Duration(milliseconds: 500));
        }
      }
    });
    return retval;
  }
}
