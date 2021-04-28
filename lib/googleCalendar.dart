import "package:intl/intl.dart";

import 'package:googleapis/calendar/v3.dart';
import 'package:googleapis_auth/auth_io.dart';

import 'package:sched_x/globals.dart';

class GoogleCalendar extends XCalendar {
  // Service Account Credentials (schedule X calendar account)
  final _accountCredentials = new ServiceAccountCredentials.fromJson({
    "private_key_id": "e586bbf1b57fb50be886fc6d9209775c2c83bde3",
    "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQDITg1QXlmv9HW9\nWZ0H2O7IRMgH+vuFtSwziRl+rBYN7FHqTLCSRsDruBRjFKWtxn3ezSSI5CWtcskC\nVByhbVJ48Fg1mMRFdA7PSmJZ2x++2aWRg5vQYNIG+E2uSA3Xht93i3fgL26KvK7u\nQ9CttE2tqD/NOF4LDld0Gz2qTVl3g+kySb956uu2mM1YOlczVVf+8w9YGaYDPMVQ\nb6csuWA5XTMdrDtQ0FeyzqnQRY8t111KZvo5GkSlYVbGgkiTD4IXDP93eflfEqUT\nIJ3kCZcki9SCdW4cSGdX1mRWCdcu6LSVivGC1zolYzSYvzSpc0+3vOXbnolujEcr\nUxy4zCPFAgMBAAECggEAEdHLyNLgxLc8dqNo+M0/21L78dkBex3ChTUue1pUCsBz\npLxWcWgk+o0H5BNup9aCoe/hghVV4SfW7qn/80AWa0odqgSUrwV9QDJPkv6o+AgR\nyclWpin7ruengkuVTtxU6tdeZNqjYwLlLXvP+twRYW0YSMM5rpJQjZsGZROrhwCH\na/runP/nuGHwjp6ixwzOj/qSAm68m5AtKnV+8reIaWEGeLTD40a4VRn0AP27Mfx6\nEgvd560BnXwfwRFm5+bCssK8fwGGBgk0MKhVKH2wTz4bJCBo5l+OOBDDtgIsCjpK\nd3Gp+yZP8L3UIvSosxZ+Pu+286bHihapXEAAt+rU8wKBgQDmDD9vF24H6ZpbK6vd\nH5k+//H+6zV+WCy7uO68jlgAnHNDE0hQRIHB6cxHDF4P0yIsQTSC77qs1nFk72PY\n0z3DtRJj16p8iNq/XlaJtN7AYhtwoDBhIG/2CeNfJWrtbvx+GgHZY2H+41lS49FF\n/C2IJpnxkXzxohEExGRd6w1LOwKBgQDe5tThyVaixvHxiFbBzWTZztXFVlQ4kZDO\niaORnHDA3q7Mph+fgYieX21uIrgHTr5x6gd6LIZmV2PhDM7L3WknTj/SpgpOZYD/\n3l2JRi2BDrUd1csHF4yhZGekdMj+L0ueGK7QoWEVEF7gXATqgOPgDI5xYdKp0fqR\n8ADnJD9c/wKBgEy4CO+jgK5i2XdOOSKlRxYbhTjeeBiKj2CLbBK15eNOSaI07AjY\nz+07a0TGexgL8XmQxVJlYHwDiA2BSGsnB5Ic8OUbJ2Agw9LOQ03pY+AE1+HXikrZ\n5nzHD2zLrb1BJjNnuPYmjqfSaheaolAUqZqeRPiq7GApDEPquw4XNXfBAoGAZ8eP\nXCRyqsz3vp3cztTDXMl5LCy6f6/+fLsGpffxY0sKlYvO82PK6PnDKGEPz48xCjaN\nDqwGU0Xi4dglvDM1DzDWdEwMRl3qBrdQU2aSLyFa4C43HfEv78CgpKgfIIGCsnQJ\niGdqnPUHR2xweYJTFnCiLVX/UEPMZwAYW4W73p8CgYAX5rLTqOjwMcoztTkPUETN\nBOrQ8p6MlYyku9dNwE4ZdRkv1+MEkr70grq8qJ17dovVQMmNOxGwqUXvL7pP3R9B\nsZ2wzfAJHqAh6qyi/vmSn/PrtW3H5n9FgRiBNMepwW7oFI8lE66pK4f6tRCTy0/2\n+kLRAd2KF42olUzJ4mH5cg==\n-----END PRIVATE KEY-----\n",
    "client_email": "schedx-calendar-test@schedulex-f1d2b.iam.gserviceaccount.com",
    "client_id": "107771459703128251441",
    "impersonatedUser": xConfiguration.user,
    "type": "service_account",
  });
  final _scopes = [CalendarApi.calendarScope];
  CalendarApi _calendar;

  static final GoogleCalendar _thisCal = GoogleCalendar.internal();

  factory GoogleCalendar() {
    return _thisCal;
  }

  GoogleCalendar.internal() {
    getCalendar();
  }

  bool initialize() {return (true);}

  Future<CalendarApi> getCalendar() async {
    if (_calendar==null) {
      final httpClient = await clientViaServiceAccount(_accountCredentials, _scopes);
      try {
        _calendar = CalendarApi(httpClient);
      } catch(e) {
        print('$e');
      } finally {
        httpClient.close();
      }
    }
    return _calendar;
  }    

  Future<FreeBusyResponse> getFreeBusy (DateTime startAt, DateTime endAt) async {
    FreeBusyResponse _freeBusyInfo;
    print("Waiting for calendar");
    await getCalendar().then((_cal) async {
      final request = FreeBusyRequest()
              ..timeMin = startAt.toUtc()
              ..timeMax = endAt.toUtc()
              ..timeZone = xConfiguration.timeZone
              ..items = [ FreeBusyRequestItem()..id=xConfiguration.user];
      print("Waiting for free/busy");
      _freeBusyInfo = await _cal.freebusy.query(request);
      print ("Got free/busy");
    });
    return _freeBusyInfo;
  }

  Future<List<OpenBlock>> getFreeBlocks (DateTime startAt, DateTime endAt) async {
    int _startHour = int.parse(xConfiguration.workdayStart.substring(0,2));
    int _startMinute = int.parse(xConfiguration.workdayStart.substring(3));
    int _endHour = int.parse(xConfiguration.workdayEnd.substring(0,2));
    int _endMinute = int.parse(xConfiguration.workdayEnd.substring(3));
    // Create a list of free blocks, one per day, with start and end set by workday (from config)
    startAt = DateTime(startAt.year,startAt.month,startAt.day,_startHour,_startMinute);
    endAt = DateTime(endAt.year,endAt.month,endAt.day,_endHour,_endMinute);  
    int _nDays = (endAt.difference(startAt)).inDays+1;
    int _dailyDuration = ((_endHour-_startHour)*60+(_endMinute-_startMinute)) * ONE_MINUTE;
    // Iterate the list of calendars and in each calendar the list of "busy blocks"
    print("Asking for free/busy");
    List<OpenBlock> _slots = [];
    await getFreeBusy(startAt,endAt).then((_freeBusyInfo) {
      if (_freeBusyInfo!=null) {
        _freeBusyInfo.calendars.forEach((key, value) {
          print(key.toString());
        for (int _n=0; _n<=_nDays; _n++) {
          _slots.add(new OpenBlock());
          _slots[_n].startTime = (startAt.add(Duration(days: _n))).millisecondsSinceEpoch;
          _slots[_n].duration = _dailyDuration;
        }
        for (int i=0; i<value.busy.length; i++) {
          print("    "+value.busy[i].start.toString()+" - "+value.busy[i].end.toString());
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
              // If the whole slot was used, remove it, otherwise shorten it
              if (_slots[j].duration==_fbSlot.duration) {
                _slots.remove(_slots[j]);
              } else {
                if (_slots[j].startTime == _fbSlot.startTime) {
                  // Remove from start
                  _slots[j].startTime += _fbSlot.duration;
                } else if (_slots[j].startTime+_slots[j].duration <= _fbSlot.startTime+_fbSlot.duration) {
                  // Remove from end
                  _slots[j].duration -= _fbSlot.duration;
                } else {
                  // Remove from the middle
                  int _temp = _slots[j].duration;
                  _slots[j].duration = _fbSlot.startTime-_slots[j].startTime;
                  OpenBlock _newSlot = new OpenBlock();
                  _newSlot.startTime = _fbSlot.startTime+_fbSlot.duration;
                  _newSlot.duration = _temp+_slots[j].startTime-_newSlot.startTime;
                  _slots.insert(j+1,_newSlot);
                }
              }
              break;
            }
          }
        }
      });
      print("Created slots");
      return _slots;
    }
    });
    print("Returning slots");
    return _slots;
  }
}
