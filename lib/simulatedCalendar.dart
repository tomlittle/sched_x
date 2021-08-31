import 'package:sched_x/globals.dart';
import 'package:sched_x/openBlocks.dart';

class SimCalendar extends XCalendar {
  static final SimCalendar _simCal = SimCalendar.internal();

  factory SimCalendar() {
    return _simCal;
  }

  SimCalendar.internal();

  bool initialize() {return (true);}

  List<OpenBlock> fakeFreeBlocks (DateTime startAt, DateTime endAt) {
    // Get the starting and ending times for a working day
    int _startHour = int.parse(xConfiguration.workdayStart.substring(0,2));
    int _startMinute = int.parse(xConfiguration.workdayStart.substring(3));
    int _endHour = int.parse(xConfiguration.workdayEnd.substring(0,2));
    int _endMinute = int.parse(xConfiguration.workdayEnd.substring(3));
    // Create a list of free blocks, one per day, with start and end set by workday (from config)
    startAt = DateTime(startAt.year,startAt.month,startAt.day,_startHour,_startMinute);
    endAt = DateTime(endAt.year,endAt.month,endAt.day,_endHour,_endMinute);  
    int _dailyDuration = ((_endHour-_startHour)*60+(_endMinute-_startMinute)) * ONE_MINUTE;
    List<OpenBlock> _slots = OpenBlockList.create(startAt,endAt,_dailyDuration);
    return _slots;
  }

  Future<List<OpenBlock>> getFreeBlocks (DateTime startAt, DateTime endAt) async {
    // Code to fake free blocks of time for PoC
    startAt = DateTime(startAt.year,startAt.month,startAt.day);
    endAt = DateTime(endAt.year,endAt.month,endAt.day);  
    var _slots = fakeFreeBlocks(startAt,endAt);
    return _slots;
  }

  Future<bool> createCalendarEntry (event) {
    int nSessions = event.sessions.length;
    for (int i=0; i<nSessions; i++) {
      consolePrint('Creating '+event.name+' - '+(i+1).toString()+' of '+nSessions.toString());
    }
    return Future.value(true);
  }

  Future removeCalendarSession (event, index) async {
    consolePrint('Removing '+event.name+' session'+index.toString()+' from calendar');
    return true;
  }

  Future removeCalendarEntry (event) async {
    consolePrint('Removing '+event.name+' from calendar');
    return true;
  }
}
