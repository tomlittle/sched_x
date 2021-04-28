import 'package:sched_x/globals.dart';

class SimCalendar extends XCalendar {
  static final SimCalendar _simCal = SimCalendar.internal();

  factory SimCalendar() {
    return _simCal;
  }

  SimCalendar.internal();

  bool initialize() {return (true);}

  List<OpenBlock> fakeFreeBlocks (DateTime startAt, DateTime endAt) {
    int nDays = (endAt.difference(startAt)).inDays;
    List<OpenBlock> _slots = [];
    for (int _n=0; _n<=nDays; _n++) {
      _slots.add(new OpenBlock());
      _slots[_n].startTime = (startAt.add(Duration(days: _n))).millisecondsSinceEpoch;
      _slots[_n].duration = ONE_HOUR * 4;
    }
    return _slots;
  }

  Future<List<OpenBlock>> getFreeBlocks (DateTime startAt, DateTime endAt) async {
    // Code to fake free blocks of time for PoC
    // 4 hours from 1 PM every day
    startAt = DateTime(startAt.year,startAt.month,startAt.day,int.parse(xConfiguration.workdayStart.substring(0,2)));
    endAt = DateTime(endAt.year,endAt.month,endAt.day,int.parse(xConfiguration.workdayEnd.substring(0,2)));  
    var _slots = fakeFreeBlocks(startAt,endAt);
    return _slots;
  }

}
