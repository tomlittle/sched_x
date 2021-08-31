import 'package:intl/intl.dart';
import 'package:sched_x/globals.dart';

// Blocks of available time in the calendar
class OpenBlock {
  int startTime;
  int duration;
  int dayID;

  OpenBlock({this.startTime,this.duration});

  static OpenBlock create (start, duration, id) {
    OpenBlock b = OpenBlock();
    b.startTime = start;
    b.duration = duration;
    b.dayID = id;
    return b;
  }

  OpenBlock copy () {
    OpenBlock _copy = new OpenBlock();
    _copy.startTime = this.startTime;
    _copy.duration  = this.duration;
    _copy.dayID     = this.dayID;
    return _copy;
  }
}

extension OpenBlockList on List {

  static List<OpenBlock> create(DateTime start, DateTime end, int duration) {
    List<OpenBlock> _slots = [];
    int _nDays = (end.difference(start)).inDays+1;
    int _weekday = start.weekday-1;
    for (int _n=0; _n<=_nDays; _n++, (_weekday=(_weekday+1) % 7)) {
      // Return free blocks only if this is a working day
      if (xConfiguration.workingDays[_weekday]) {
        _slots.add(OpenBlock.create((start.add(Duration(days: _n))).millisecondsSinceEpoch,duration,_n));
      }
    }
    return _slots;
  }

  void removePastBlocks (DateTime start) {
    if (start.isBefore(DateTime.now())) {
      int _notBefore = DateTime.now().millisecondsSinceEpoch+ONE_HOUR;
      for (int i=this.length-1; i>=0; i--) {
        if (this[i].startTime<_notBefore) {
          consolePrint('Removing ${i+1} slots that occur in the past',category: 'slots');
          this.removeRange(0,i+1);
          break;
        }
      }
    }
  }

  void removeEarlyBlocks(DateTime start, int startHour, int startMinute) {
    for (int i=this.length-1; i>=0; i--) {
      DateTime _slotStart = DateTime.fromMillisecondsSinceEpoch(this[i].startTime);
      int _sh = _slotStart.hour;
      int _sm = _slotStart.minute;
      if ((_sh<startHour) || ((_sh==startHour) && (_sm<startMinute))) {
        int _eh = DateTime.fromMillisecondsSinceEpoch(this[i].startTime+this[i].duration).hour;
        int _em = DateTime.fromMillisecondsSinceEpoch(this[i].startTime+this[i].duration).minute;
        // if the slot ends before start of day, delete it
        // else change start time to start of day
        if ((_eh<startHour) || ((_eh==startHour) && (_em<startMinute))) {
          this.remove(this[i]);
          consolePrint('Removing 1 slot that occurs before start of working day',category: 'slots');
        } else {
          // Start of today's working time
          int _sod = DateTime(_slotStart.year,_slotStart.month,_slotStart.day,startHour,startMinute).millisecondsSinceEpoch;
          this[i].duration -= (_sod-this[i].startTime);
          this[i].startTime = _sod;
          consolePrint('Shortening 1 slot that begins before start of working day', category: 'slots');
        }
      }
    }
  }

  void subtractBlockFromList (int atPos, OpenBlock block) {
    // If the whole block was used, remove it, otherwise shorten it or split it
    if (this[atPos].duration==block.duration) {
      this.remove(this[atPos]);
    } else {
      if (this[atPos].startTime == block.startTime) {
        // Starting points identical - shorten by removing from start
        this[atPos].startTime += block.duration;
        // !!! ADDDED - Reduce the duration of the slot
        this[atPos].duration -= block.duration;
        // End points equal - shorten by removing from end
        // !!! CHANGED - end times equal, not <=
      } else if (this[atPos].startTime+this[atPos].duration == block.startTime+block.duration) {
        // Remove from end
        this[atPos].duration -= block.duration;
      } else {
        // Block contained in list element - shrink from start and create new block from end
        int _temp = this[atPos].duration;
        this[atPos].duration = block.startTime-this[atPos].startTime;
        OpenBlock _newSlot = new OpenBlock();
        _newSlot.startTime = block.startTime+block.duration;
        _newSlot.duration = _temp+this[atPos].startTime-_newSlot.startTime;
        _newSlot.dayID = block.dayID;
        this.insert(atPos+1,_newSlot);
      }
    }
  }

  int getFreeTimeForDay (int dayID) {
    int freeTime = 0;
    for (int i=0; i<this.length; i++) {
      if (this[i].dayID==dayID) {
        freeTime += this[i].duration;
      }
    }
    return freeTime;
  }

  void showBlocks (String title) {
    consolePrint(title,category: 'slots');
    if (this.length==0) {
      consolePrint('  No blocks in list ',category: 'slots');
      return;
    }
    for (int i=0; i<this.length; i++) {
      if (this[i].startTime!=null) {
        String _s = '  '+DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(this[i].startTime))+' on '+
                    DateFormat('dd MMMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(this[i].startTime));
        consolePrint('${this[i].duration/ONE_HOUR} hours at '+_s,category: 'slots');
      } else {
        consolePrint('  Null block',category: 'slots');
      } 
    }
  }

}

