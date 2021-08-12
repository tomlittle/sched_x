library sched_x.global;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sched_x/globals.dart';
import 'package:sched_x/simulatedCalendar.dart';
import 'package:sched_x/googleCalendar.dart';

// Global variables
List<Item> xItems = []; // List of items to be scheduled - this list drives EVERYTHING
bool itemListUnsaved = false;
bool calendarUnsaved = false;

// ------------------------ Type definitions ------------------------
// ------------------------ Status in schedule
enum scheduled {SCHEDULED_OK, SCHEDULED_LATE, NOT_SCHEDULED, NOTYET, ERROR}
final List scheduledIcon = [
  {"icon": IconData(Icons.check.codePoint, fontFamily: 'MaterialIcons'),"color": Colors.green,"tooltip":"will complete on time"},
  {"icon": IconData(Icons.check.codePoint, fontFamily: 'MaterialIcons'),"color": Colors.red,"tooltip":"will be late"},
  {"icon": IconData(Icons.watch_later_outlined .codePoint, fontFamily: 'MaterialIcons'),"color": Colors.red,"tooltip":"not scheduled"},
  {"icon": null,"color": null,"tooltip": ''},
  {"icon": IconData(Icons.dnd_forwardslash.codePoint, fontFamily: 'MaterialIcons'),"color": Colors.red,"tooltip":"Error!"},
];
// ------------------------ Urgency (how hard is the due date)
final List urgencyIcon = [
  {"icon": IconData(Icons.label_important_rounded.codePoint, fontFamily: 'MaterialIcons'),"color": Colors.red, "tooltip": 'hard deadline'},
  {"icon": IconData(Icons.label_off_outlined.codePoint, fontFamily: 'MaterialIcons'),"color": Colors.grey, "tooltip": 'soft deadline'},
];
// ------------------------ Importance (priority)
enum importance {VERY_HIGH, HIGH, NORMAL, LOW}
extension ImportanceExtension on importance {
  int compareTo (importance that) {
    return this.index.compareTo(that.index);
  }
}
// UI stuff
final List<String> importanceText = ['very high','high','normal','low'];
final List<IconData> importanceIcon = [
  IconData(Icons.star.codePoint, fontFamily: 'MaterialIcons'),
  IconData(Icons.arrow_circle_up.codePoint, fontFamily: 'MaterialIcons'),
  IconData(Icons.remove_circle_outline.codePoint, fontFamily: 'MaterialIcons'),
  IconData(Icons.arrow_circle_down.codePoint, fontFamily: 'MaterialIcons'),
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

// The classes that define items to be scheduled and their schedules
class Item {
  String id;
  String name;
  int duration;
  int dueDate;
  importance priority;
  bool urgent;
  int earliestStart;
  bool indivisible;
  List<Session> sessions;
  bool completed = false;
  double weight;
  scheduled status;

  Item({this.id, this.name, this.duration, this.dueDate, this.priority});

  static Item copy(Item oldItem) {
    Item i = Item();
    i.id = DateTime.now().millisecondsSinceEpoch.toString()+'-c';
    i.name = "COPY - "+oldItem.name;
    i.duration = oldItem.duration;
    i.dueDate = oldItem.dueDate;
    i.priority = oldItem.priority;
    i.urgent = oldItem.urgent;
    i.earliestStart = oldItem.earliestStart;
    i.indivisible = oldItem.indivisible;
    i.completed = false;
    i.status = scheduled.NOTYET;
    return i;
  }

  static Item create() {
    Item i = Item();
    i.id = 'bapp'+DateTime.now().microsecondsSinceEpoch.toString();
    i.name = "New Item "+i.id.substring(4,4) ;
    i.duration = ONE_HOUR;
    DateTime _d = DateTime.now();
    int _endHour = int.parse(xConfiguration.workdayEnd.substring(0,2));
    int _endMinute = int.parse(xConfiguration.workdayEnd.substring(3));
    i.dueDate = DateTime(_d.year,_d.month,_d.day,_endHour,_endMinute,0).add(const Duration(days: 2)).millisecondsSinceEpoch;
    i.priority = importance.NORMAL;
    i.urgent = false;
    i.status = scheduled.NOTYET;
    i.indivisible = true;
    i.completed = false;
    return i;
  }

  int totalDuration () {
    int tD = 0;
    for (int i=0; i<this.sessions.length; i++) {
      tD += this.sessions[i].duration;
    }
    return tD;
  }

  Future<void> addToCalendar() async {
    if (this.completed) {
      consolePrint('Skipping create for completed item '+this.name, category: 'calendar');
      return;
    }
    XCalendar xCalendar;
    switch (xConfiguration.calendarType) {
      case "google":
        xCalendar = GoogleCalendar();
        break;
      case "simulated":
        xCalendar = SimCalendar();
        break;
      default:
        xCalendar = SimCalendar();
        break;
    }
    consolePrint('Calling create', category: 'calendar');
    var x = xCalendar.createCalendarEntry(this);
    consolePrint('Returning from add', category: 'calendar');
    return x;
  }

  Future<void> removeSessionFromCalendar(int i) async {
    XCalendar xCalendar;
    switch (xConfiguration.calendarType) {
      case "google":
        xCalendar = GoogleCalendar();
        break;
      case "simulated":
        xCalendar = SimCalendar();
        break;
      default:
        xCalendar = SimCalendar();
        break;
    }
    consolePrint('Calling remove session for session '+i.toString(), category: 'calendar');
    var x = xCalendar.removeCalendarSession(this,i);
    consolePrint('Returning from remove session', category: 'calendar');
    return x;
  }

  Future<void> removeEntryFromCalendar() async {
    if (this.completed) {
      consolePrint('Skipping remove for completed item '+this.name, category: 'calendar');
      return;
    }
    XCalendar xCalendar;
    switch (xConfiguration.calendarType) {
      case "google":
        xCalendar = GoogleCalendar();
        break;
      case "simulated":
        xCalendar = SimCalendar();
        break;
      default:
        xCalendar = SimCalendar();
        break;
    }
    consolePrint('Calling remove entry', category: 'calendar');
    var x = xCalendar.removeCalendarEntry(this);
    consolePrint('Returning from remove', category: 'calendar');
    return x;
  }

  Item.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        name = json['name'] as String,
        duration = json['duration'] as int,
        dueDate = json['dueDate'] as int,
        priority = importance.values[json['priority']],
        urgent = json['urgent'] as bool,
        earliestStart = json['earliestStart'] as int,
        indivisible = json['indivisible'] as bool,
        completed = json['completed'] as bool,
        status = scheduled.values[json['status']],
        sessions = decodeSessions(json['sessions']);
        
  static List<Session> decodeSessions (List<dynamic> jsonList) {
    List<Session> retVal = [];
    if (jsonList != null) {
      for (int i=0; i<jsonList.length; i++) {
        Session s = Session.fromJson(jsonList[i]);
        retVal.add(s);
      }
    }
    return retVal;
  }

  Map<String, dynamic> toJson() =>
    {
      'id': id,
      'name': name,
      'duration': duration,
      'dueDate': dueDate,
      'priority': priority.index,
      'urgent': urgent,
      'earliestStart': earliestStart,
      'status': status.index,
      'indivisible': indivisible,
      'completed': completed,
      'sessions': sessions,
    };
}

extension ItemList on List {
  void sortByStart () {
    List<double> _save = [];
    // Save existing contents of "weight" and replace with starting date
    for(int _i=0; _i<xItems.length; _i++) {
      _save.add(xItems[_i].weight);
      xItems[_i].weight = (xItems[_i].sessions==null) ? 0 : xItems[_i].sessions[0].startTime;
    }
    // Sort
    xItems.sort((x,y) => x.weight.compareTo(y.weight));
    // Restore original contents of "weight"
    for(int _i=0; _i<xItems.length; _i++) {
      xItems[_i].weight = _save[_i];
    }
  }

  void sortByFinish () {
    List<double> _save = [];
    // Save existing contents of "weight" and replace with starting date
    for(int _i=0; _i<xItems.length; _i++) {
      _save.add(xItems[_i].weight);
      xItems[_i].weight = (xItems[_i].sessions==null) ? 4102444799000 : // 23.59.59 on 31.12.2099
        xItems[_i].sessions[xItems[_i].sessions.length-1].startTime+xItems[_i].sessions[xItems[_i].sessions.length-1].duration;
    }
    // Sort
    xItems.sort((x,y) => x.weight.compareTo(y.weight));
    // Restore original contents of "weight"
    for(int _i=0; _i<xItems.length; _i++) {
      xItems[_i].weight = _save[_i];
    }
  }
}

// "Items" are scheduled in one or more "Sessions"
 class Session {
  String calId;
  int startTime;
  int duration;

  Session();

  Session.fromJson(Map<String, dynamic> json)
    : calId = json['calId'] as String,
      startTime = json['startTime'] as int,
      duration = json['duration'] as int;
        
  Map<String, dynamic> toJson() =>
  {
    'calId': calId,
    'startTime': startTime,
    'duration': duration,
  };

}

// Helper properties during scheduling (helpful for debugging the algorithm)
class ItemScheduleProperties {
  double priorityFactor;
  double deadlineFactor;
}

Future<void> reschedule () async {
  XCalendar xCalendar;
  switch (xConfiguration.calendarType) {
    case "google":
      xCalendar = GoogleCalendar();
      break;
    case "simulated":
      xCalendar = SimCalendar();
      break;
    default:
      xCalendar = SimCalendar();
      break;
  }
  // Need to know when "now" is
  final int today = (DateTime.now()).millisecondsSinceEpoch;
  // List of items to be scheduled - copied and filtered from "xItems"
  List<Item> _sItems = [];
  // List of overdue items
  List<Item> _oItems = [];
  // Filter items to separate overdue items and remove completed items
  for (int i=0; i<xItems.length; i++) {
    if (!xItems[i].completed) {
      if (xItems[i].dueDate>=today) {
        _sItems.add(xItems[i]);
      } else {
        _oItems.add(xItems[i]);
      }
    }
  }
  // Additonal data for debugging scheduling (<-> _sItems)
  List<ItemScheduleProperties> _sProps = [];
  // Find latest due date to establish range for scheduling
  int lastDueDate = 0;
  for (int i=0; i<_sItems.length; i++) {
    if (_sItems[i].dueDate>lastDueDate) {
      lastDueDate = _sItems[i].dueDate;
    }
  }
  // Calculate size of range based on last due date, scale down
  // We'll use the range for both deadlines and priorities
  const scaleFactor = 1000000;
  double range = (lastDueDate-today) / scaleFactor;
  // Calculate properties of each item
  // "weight" controls scheduling order, "heaviest" item is scheduled first
  for (int i=0; i<_sItems.length; i++) {
    _sProps.add(new ItemScheduleProperties());
    _sProps[i].priorityFactor = (3-_sItems[i].priority.index) / 3 * range;
    _sProps[i].deadlineFactor = (lastDueDate-_sItems[i].dueDate) / scaleFactor;
    _sItems[i].weight = _sProps[i].priorityFactor + _sProps[i].deadlineFactor;
  }
  _sItems.sort((x,y) => -(x.weight.compareTo(y.weight)));
  // Blocks of free time avilable to scheduler - sorted earliest to latest
  DateTime startDate = DateTime.now();
  DateTime endDate = (startDate.millisecondsSinceEpoch >= lastDueDate) ? startDate.add(Duration(days: 30)) :
                      DateTime.fromMillisecondsSinceEpoch(lastDueDate+7*ONE_DAY);
  consolePrint("Requesting slots",category: 'schedule');
  await xCalendar.getFreeBlocks(startDate,endDate).then((_freeSlots) {
//  await xCalendar.getFreeBlocks(startDate,startDate.add(new Duration(days: 7))).then((_freeSlots) {
    consolePrint("Received slots",category: 'schedule');
    for (int i=0; i<_freeSlots.length; i++) {
      consolePrint("    "+DateTime.fromMillisecondsSinceEpoch(_freeSlots[i].startTime).toString()+" - "+(_freeSlots[i].duration/60000).toString()+" min",category:'schedule');
    }
    // If overdue scheduling is "first", do it
    if (xConfiguration.overdueScheduling=="first") {
      consolePrint('Doing overdue scheduling first',category: 'schedule');
      // Overdue items are always scheduled as early as possible
      _freeSlots.sort((x,y) => x.startTime.compareTo(y.startTime));
      _scheduleItems(_freeSlots,_oItems, durationOnly: true);
      // Try to resolve conflicts
      for (int i=0; i<_oItems.length; i++) {
        if (_oItems[i].status == scheduled.ERROR) {
          _scheduleConflictedItem(_freeSlots, _oItems[i]);
        }
      }
    }
    // Slots need to be in specified order
    if (xConfiguration.scheduling=="soonest") {
      _freeSlots.sort((x,y) => x.startTime.compareTo(y.startTime));
    } else {
      _freeSlots.sort((x,y) => -x.startTime.compareTo(y.startTime));
    }
    // Schedule items in order
    consolePrint('Scheduling items',category: 'schedule');
    _scheduleItems(_freeSlots,_sItems);
    // If overdue scheduling is "last", do it
    if (xConfiguration.overdueScheduling=="last") {
      consolePrint('Doing overdue scheduling last',category: 'schedule');
      // Overdue items are always scheduled as early as possible
      _freeSlots.sort((x,y) => x.startTime.compareTo(y.startTime));
      _scheduleItems(_freeSlots,_oItems, durationOnly: true);
      // Try to resolve conflicts
      for (int i=0; i<_oItems.length; i++) {
        if (_oItems[i].status == scheduled.ERROR) {
          _scheduleConflictedItem(_freeSlots, _oItems[i]);
        }
      }
    }
    // Check for unscheduled items and attempt to schedule them
    for (int i=0; i<_sItems.length; i++) {
      if (_sItems[i].status == scheduled.ERROR) {
        _scheduleConflictedItem(_freeSlots, _sItems[i]);
      }
    }
    // Change status of items that will complete after the due date from OK to SCHEDLUED_LATE
    for (int i=0; i<_sItems.length; i++) {
      if (_sItems[i].sessions!=null) {
        int j = _sItems[i].sessions.length-1;
        if (_sItems[i].sessions[j].startTime+_sItems[i].sessions[j].duration > _sItems[i].dueDate) {
          _sItems[i].status = scheduled.SCHEDULED_LATE;
        }
      }
    }
    for (int i=0; i<_oItems.length; i++) {
      if (_oItems[i].sessions!=null) {
        int j = _oItems[i].sessions.length-1;
        if (_oItems[i].sessions[j].startTime+_oItems[i].sessions[j].duration > _oItems[i].dueDate) {
          _oItems[i].status = scheduled.SCHEDULED_LATE;
        }
      }
    }
    // Move schedule entries to master list of items
    for (int i=0; i<_sItems.length; i++) {
      Item target = xItems.firstWhere((element) => 
            element.id == _sItems[i].id,
            orElse: () {
              return null;
            });
      if (target != null) {
        target.sessions =_sItems[i].sessions;
      }
    }
  });
}

  void _scheduleItems(List<OpenBlock> _slots, List<Item> _items, {durationOnly: false}) {
    for (int i=0; i<_items.length; i++) {
      consolePrint('  '+(_items[i].duration/ONE_MINUTE).toString()+'m for "'+_items[i].name+'" due at '+DateTime.fromMillisecondsSinceEpoch(_items[i].dueDate).toString(),category: 'schedule');
      _items[i].sessions = [];
      _items[i].status = scheduled.NOTYET;
      // Get first block that fits
      int _selectedSlot = -1;
      for (int j=0; j<_slots.length; j++) {
        if (_slots[j].duration >= _items[i].duration) {
          if (!durationOnly) {
            if (_slots[j].startTime+_slots[j].duration <= _items[i].dueDate) {
              // If the item has an earliest start, check it
              if (_items[i].earliestStart!=null) {
                if(_slots[j].startTime+_slots[j].duration-_items[i].duration>=_items[i].earliestStart) {
                  _selectedSlot = j;
                  break;
                }
              } else {
                _selectedSlot = j;
                break;
              }  // Earliest start
            } // Due date
          } // Duration only
          else {
            _selectedSlot = j;
            break;
          }
        }  // Duration 
      }
      // Leave session list empty (null) if no slot available
      if (_selectedSlot==-1) {
        consolePrint('    -> no slot found',category: 'schedule');
        _items[i].sessions = null;
        _items[i].status = scheduled.ERROR;
        continue;
      }
      consolePrint('    -> slot found at '+DateTime.fromMillisecondsSinceEpoch(_slots[_selectedSlot].startTime).toString(),category: 'schedule');
      // Add session to item
      _items[i].sessions.add(new Session());
      _items[i].status = scheduled.SCHEDULED_OK;
      // Schedule item, modify block list
      _items[i].sessions[0].duration = _items[i].duration;
      if (_items[i].earliestStart!=null) {
        _items[i].sessions[0].startTime= _slots[_selectedSlot].startTime < _items[i].earliestStart ?
                                          _items[i].earliestStart : _slots[_selectedSlot].startTime;
      } else {
        _items[i].sessions[0].startTime= _slots[_selectedSlot].startTime;
      }
      // If the whole slot was used, remove it, otherwise shorten or split it
      if (_slots[_selectedSlot].duration==_items[i].duration) {
        _slots.remove(_slots[_selectedSlot]);
      } else {
          // Remove from the start...
          if (_slots[_selectedSlot].startTime==_items[i].sessions[0].startTime) {
            _slots[_selectedSlot].startTime += _items[i].duration;
            _slots[_selectedSlot].duration -= _items[i].duration;
          // ...or from the end...
          } else if (_items[i].sessions[0].startTime+_items[i].sessions[0].duration==
                     _slots[_selectedSlot].startTime+_slots[_selectedSlot].duration) {
            _slots[_selectedSlot].duration -= _items[i].sessions[0].duration;
          // ...or split the slot into two remaining slots
          } else {
                  int _temp = _slots[_selectedSlot].duration;
                  _slots[_selectedSlot].duration = _slots[_selectedSlot].startTime-_items[i].sessions[0].startTime;
                  OpenBlock _newSlot = new OpenBlock();
                  _newSlot.startTime = _items[i].sessions[0].startTime+_items[i].sessions[0].duration;
                  _newSlot.duration = _temp+_slots[_selectedSlot].startTime-_newSlot.startTime;
                  _slots.insert(_selectedSlot+1,_newSlot);
          }
      }
    consolePrint("Remaining slots",category: 'schedule');
    for (int i=0; i<_slots.length; i++) {
      consolePrint("    "+DateTime.fromMillisecondsSinceEpoch(_slots[i].startTime).toString()+" - "+(_slots[i].duration/60000).toString()+" min",category: 'schedule');
    }
   }
}

void _scheduleConflictedItem (List<OpenBlock> _slots, Item item) {
  // Right now we can only try to break an item into multiple sessions which can be scheduled
  // If that isn't allowed (the "indivisble" property of the item is true), just return
  if (item.indivisible) {
    return;
  } else {
    item.status = scheduled.ERROR;
    consolePrint('    Attempting to resolve conflict',category: 'schedule');
    consolePrint('  '+(item.duration/ONE_MINUTE).toString()+'m for "'+item.name+'" due at '+DateTime.fromMillisecondsSinceEpoch(item.dueDate).toString(),category: 'schedule');
    // Shortest session per configuration or 30 minutes if not configured
    int _shortestSession = (xConfiguration.minimumSession > 0) ? xConfiguration.minimumSession : (30 * ONE_MINUTE);
    // Save a copy of the slots in case of rollback
    List<OpenBlock> _savedSlots = [];
    for (int i =0; i<_slots.length; i++) {
      _savedSlots.add(_slots[i].copy());
    }
    // Use slots starting from earliest
    _slots.sort((x,y) => x.startTime.compareTo(y.startTime));
    item.sessions = [];
    for (int restDuration=item.duration, i=0, sNumber=0; i<_slots.length; i++) {
      if (_slots[i].duration>=_shortestSession) {
        if (restDuration<_slots[i].duration) {
          item.sessions.add(new Session());
          item.sessions[sNumber].startTime = _slots[i].startTime;
          item.sessions[sNumber].duration = restDuration;
          if (_slots[i].duration == restDuration) {
            _slots.remove(_slots[i]);
            i--;
          } else {
            _slots[i].duration -= restDuration;
          }
          restDuration = 0;
        } else {
          item.sessions.add(new Session());
          item.sessions[sNumber].startTime = _slots[i].startTime;
          item.sessions[sNumber].duration = _slots[i].duration;
          restDuration -= _slots[i].duration;
          _slots[i].duration -= restDuration;
          _slots.remove(_slots[i]);
          i--;
        }
        sNumber++;
        // If no time remains in the item, we're done
        if (restDuration == 0) {
          item.status = scheduled.SCHEDULED_OK;
          consolePrint("    -> Resolved, "+item.sessions.length.toString()+" sessions",category:'schedule');
          break;
        }
      }
    }
    // Check whether resolution failed - roll back the changes
    if (item.status == scheduled.ERROR) {
      _slots = _savedSlots;
      item.sessions = null;
      consolePrint("    -> Resolution failed, no slots found",category: 'schedule');
    } else {
      for (int i=0; i<item.sessions.length; i++) {
        consolePrint('    -> slot at '+DateTime.fromMillisecondsSinceEpoch(item.sessions[i].startTime).toString(),category: 'schedule');
      }
    }
    consolePrint("Remaining slots",category: 'schedule');
    for (int i=0; i<_slots.length; i++) {
      consolePrint("    "+DateTime.fromMillisecondsSinceEpoch(_slots[i].startTime).toString()+" - "+(_slots[i].duration/60000).toString()+" min",category: 'schedule');
    }
 }
}