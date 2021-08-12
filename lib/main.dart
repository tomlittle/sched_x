// import 'dart:html';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_login/flutter_login.dart';

import 'package:firebase_core/firebase_core.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart' as fb_store;
import 'dart:typed_data' show Uint8List;

import 'package:sched_x/globals.dart';
import 'package:sched_x/editItem.dart';
import 'package:sched_x/showItemSessions.dart';
import 'package:sched_x/editSettings.dart';
import 'package:sched_x/localAuth.dart';
import 'items.dart' as items;

const String appTitle = 'Scheduler';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final Future<fb.FirebaseApp> _fbFApp = fb.Firebase.initializeApp();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _fbFApp,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // !!! do something
        }
        // Once complete, show your application
        if (snapshot.connectionState == ConnectionState.done) {
          return MaterialApp(
            title: appTitle,
            theme: ThemeData(
              primarySwatch: Colors.lightGreen,
              accentColor: Colors.orange,
              dividerTheme: DividerThemeData(color: Colors.grey, indent: 6, endIndent: 6)              
            ),
            home: LoginPage(),
            routes: {
              '/login': (context) => LoginPage(),
              '/itemList': (context) => IssueListPage(title: 'Scheduler'),
            },
          );
        }
        // Otherwise, show something whilst waiting for initialization to complete
        return CircularProgressIndicator(); // !!! this may not work (still loading)
      },
    );
  }
}

class LoginPage extends StatelessWidget {
  Duration get loginTime => Duration(milliseconds: 2250);

  @override
  Widget build(BuildContext context) {
    return FlutterLogin(
      title: 'Scheduler',
      logo: 'images/BAB_Logo_RZ.png',
      onLogin: userAuth.authUser,
      onSignup: userAuth.createUser,
      onSubmitAnimationCompleted: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => IssueListPage(title: 'Scheduler'),
          ));
      },
      onRecoverPassword: userAuth.recoverPassword,
    );
  }}

class IssueListPage extends StatefulWidget {
  IssueListPage({Key key, this.title}) : super(key: key);
  final String title;
  @override
  _IssueListPageState createState() => _IssueListPageState();
}

class _IssueListPageState extends State<IssueListPage> {
  bool isBusy = false;
  bool showComplete = true;
  bool showIncomplete = true;
  List<TextEditingController> listEditors = [];

  @override
  Widget build(BuildContext context) {
    List<Widget> listWidget = [];

  // This routine handles actions started from the item menu (vertical ellipsis)
  _performItemAction (String action, int index) async {
    consolePrint('action is $action on '+items.xItems[index].name);
    switch (action) {
      case 'finish':
        setState(() { isBusy = true; });
        int rightNow = DateTime.now().millisecondsSinceEpoch;
        for(int i=items.xItems[index].sessions.length-1; i>=0; i--) {
          if (items.xItems[index].sessions[i].startTime > rightNow) {
            // Delete session
            items.xItems[index].removeSessionFromCalendar(i);
            items.xItems[index].sessions.remove(items.xItems[index].sessions[i]);
          } else {
            if (items.xItems[index].sessions[i].startTime+items.xItems[index].sessions[i].duration > rightNow) {
              // !!! Trim session
            } else {
              break;
            }
          }
        }
        items.xItems[index].completed = true;
        items.itemListUnsaved = true;
        items.calendarUnsaved = true;
        setState(() { isBusy = false; });
        break;
      case 'show':
        Navigator.push(context, MaterialPageRoute(builder: (__) => ShowSessionsDialog(thisItem: items.xItems[index]),
          maintainState: true, fullscreenDialog: true)).then((value) => setState(() {}));
      break;
      case "edit":
        Navigator.push(context, MaterialPageRoute(builder: (__) => EditItemDialog(thisItem: items.xItems[index]),
          maintainState: true, fullscreenDialog: true)).then((value) => setState(() {}));
        items.itemListUnsaved = true;
        items.calendarUnsaved = true;
        break;
      case "copy":
        items.Item _x = items.Item.copy(items.xItems[index]);
        items.xItems.insert(index,_x);
        items.itemListUnsaved = true;
        items.calendarUnsaved = true;
        setState(() {});
        break;
      case "delete":
        items.xItems.remove(items.xItems[index]);
        items.itemListUnsaved = true;
        // !!! Remove entries from calendar
        items.calendarUnsaved = true;
        setState(() {});
        break;
      default:
        break;
    }
  }

    // Set properties for the ListTiles
    for (var n=0; n<items.xItems.length; n++) {
      // Skip this item according to display filter
      if ((!showComplete && items.xItems[n].completed) || (!showIncomplete && !items.xItems[n].completed)) {
        continue;
      }
      // Assign text controller for name
      final TextEditingController _controller = TextEditingController();
      _controller.text = items.xItems[n].name;
      listEditors.add(_controller);
      String subTitle;
      if (items.xItems[n].completed) {
        subTitle = 'COMPLETED';
      } else {
        // Translate epoch due date to date string
        String _dueDate = DateFormat('dd MMMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(items.xItems[n].dueDate));
        // Build a subtitle string with schedlued session if it exists
        subTitle = 'lasts '+(items.xItems[n].duration/ONE_HOUR).toString()+'h, due on '+_dueDate+'\n';
        if ((items.xItems[n].sessions != null) && (items.xItems[n].sessions.length>0)) {
          int _nSess = items.xItems[n].sessions.length;
          if (_nSess>1) {
            subTitle += _nSess.toString()+" sessions, ";
          }
          subTitle += 'to be completed on '+
                    DateFormat('dd MMMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(items.xItems[n].sessions[_nSess-1].startTime+
                                                                                          items.xItems[n].sessions[_nSess-1].duration))+
                    ' at '+
                    DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(items.xItems[n].sessions[_nSess-1].startTime+
                                                                                          items.xItems[n].sessions[_nSess-1].duration));
        } else {
          subTitle += '\nNOT SCHEDULED';
        }
    }
      // Build list tile for this entry
      var _temp = Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40,vertical: 4,),
                    child: ListTile(
                      onTap: () async {await Navigator.push(context, MaterialPageRoute(builder: (__) => 
                                                                     EditItemDialog(thisItem: items.xItems[n]),
                                                                     maintainState: true, fullscreenDialog: true));
                                       setState(() {});},
                      leading: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                          maxWidth: 44,
                          maxHeight: 44,
                        ),
                        child: items.xItems[n].completed ?
                          // Completed items display only a "finish line" icon
                          Tooltip(message: "Completed", child: Icon(Icons.sports_score, color: Colors.greenAccent)) :
                          // Incomplete items display a number of status icons
                          Table(  
                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,                    
                          children: [
                            // Row 1: Scheduled status, empty
                            TableRow(children: [Tooltip(message: items.scheduledIcon[items.xItems[n].status.index]["tooltip"], 
                                                  child: Icon(items.scheduledIcon[items.xItems[n].status.index]["icon"],
                                                              color: items.scheduledIcon[items.xItems[n].status.index]["color"])
                                                ),
                                                Icon(IconData(60131, fontFamily: 'MaterialIcons'), color: Colors.transparent),
                                                ]),
                            // Row 2: empty, importance (priority)
                            TableRow(children: [Tooltip(message: items.urgencyIcon[(items.xItems[n].urgent ? 0 :1)]["tooltip"], 
                                                  child: Icon(items.urgencyIcon[(items.xItems[n].urgent ? 0 : 1)]["icon"],
                                                              color:items.urgencyIcon[(items.xItems[n].urgent ? 0 : 1)]["color"])
                                                ),
                                                Tooltip(message: items.importanceText[items.xItems[n].priority.index]+' priority', 
                                                  child: Icon(items.importanceIcon[items.xItems[n].priority.index]),
                                                )
                                                ]),
                            // Row 3: empty, divisibility
                            TableRow(children: [Icon(IconData(60131, fontFamily: 'MaterialIcons'), color: Colors.transparent),
                                                items.xItems[n].indivisible ? 
                                                  Icon(IconData(60131, fontFamily: 'MaterialIcons'), color: Colors.transparent) :
                                                  Tooltip(message: 'Multi-session allowed',
                                                    child: Icon(IconData(59327, fontFamily: 'MaterialIcons'))
                                                  )
                                                ]),
                          ],
                        ),
                      ),
                      title: TextField(
                        onChanged: (String value) {items.xItems[n].name = _controller.text;},
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: "Description",
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                        ),
                      ),
                      subtitle: Text(subTitle),
                      trailing:
                        PopupMenuButton(
                          initialValue: "show",
                          child: Icon(Icons.more_vert),
                          itemBuilder: (context) {
                              var _list = <PopupMenuEntry<Object>>[];
                              _list.add(PopupMenuItem(
                                  value: "finish",
                                  child: Text('Mark as completed')));
                              _list.add(PopupMenuDivider(height: 10));
                              _list.add(PopupMenuItem(
                                  value: "show",
                                  child: Text('Show schedule')));
                              _list.add(PopupMenuItem(
                                  value: "edit",
                                  child: Text('Edit item')));
                              _list.add(PopupMenuItem(
                                  value: "copy",
                                  child: Text('Copy item')));
                              _list.add(PopupMenuDivider(height: 10));
                              _list.add(PopupMenuItem(
                                  value: "delete",
                                  child: Text('Delete item')));
                              return _list;
                          },
                          onSelected: (value) { _performItemAction(value,n); },
                          ),                      
                    )
                  );
      listWidget.add(_temp);
    }

  _loadItems() async {
    setState(() { isBusy = true; });
    fb_store.FirebaseStorage fbStorage = fb_store.FirebaseStorage.instance;
    fb_store.Reference fbStorageRef = fbStorage.ref(xConfiguration.fbRootFolder+'/items.json');
    try {
      fbStorageRef.getData(1000000).then((data) {
        String dataAsString = utf8.decode(data);
        Iterable i = json.decode(dataAsString);
        items.xItems = List<items.Item>.from(i.map((dataAsString)=> items.Item.fromJson(dataAsString)));
        items.itemListUnsaved = false;
        setState(() { isBusy = false; });
      });
    } on fb.FirebaseException catch (e) {
        print(e.toString());
    }
  }

  _saveItems() async {
    setState(() { isBusy = true; });
    String text = json.encode(items.xItems);
    List<int> encoded = utf8.encode(text);
    Uint8List data = Uint8List.fromList(encoded);
        fb_store.FirebaseStorage fbStorage = fb_store.FirebaseStorage.instance;
    fb_store.Reference fbStorageRef = fbStorage.ref(xConfiguration.fbRootFolder+'/items.json');
    try {
      fbStorageRef.putData(data);
      setState(() { isBusy = false; });
    } on fb.FirebaseException catch (e) {
        print(e.toString());
    }
  }

  _updateCalendar() async {
    setState(() { isBusy = true; });
    await new Future.delayed(const Duration(seconds : 1));
    List<Future> _removes = [];
    for (int i=0; i<items.xItems.length; i++) {
      _removes.add(items.xItems[i].removeEntryFromCalendar());
    }
    await Future.wait(_removes).then((removeValue) async {
      List<Future> _saves = [];
      for (int i=0; i<items.xItems.length; i++) {
        items.Item _item = items.xItems[i];
        if ((_item.status==items.scheduled.SCHEDULED_OK) || (_item.status==items.scheduled.SCHEDULED_LATE)) {
          _saves.add(_item.addToCalendar());
        }
      }
      await Future.wait(_saves).then((value) {
        _saveItems();
        setState(() { isBusy = false; });
      });
    });
  }

  _createNewItem() async {
    setState(() { isBusy = true; });
    items.Item i = items.Item.create();
    items.xItems.add(i);
    setState(() { isBusy = false; });
  }

  void _schedule() async {
    if ((items.xItems==null) || (items.xItems.length==0)) {
      // !!! Warn user
      return;
    }
    setState(() { isBusy = true; });
    await new Future.delayed(const Duration(seconds : 1));
    List<Future> _removes = [];
    consolePrint('Create remove requests');
    for (int i=0; i<items.xItems.length; i++) {
      _removes.add(items.xItems[i].removeEntryFromCalendar());
    }
    await Future.wait(_removes).then((removeValue) async {
      consolePrint('Remove requests complete, rescheduling');
      await items.reschedule().then((value) async {
        consolePrint('Reschedule complete');
        List<Future> _saves = [];
        consolePrint('Creating add requests');
        for (int i=0; i<items.xItems.length; i++) {
          items.Item _item = items.xItems[i];
          if ((_item.status==items.scheduled.SCHEDULED_OK) || (_item.status==items.scheduled.SCHEDULED_LATE)) {
            _saves.add(_item.addToCalendar());
          }
        }
        await Future.wait(_saves).then((value) {
          items.calendarUnsaved = false;
          consolePrint('Add requests complete, save');
          consolePrint(value.toString());
          _saveItems();
          items.itemListUnsaved = false;
          consolePrint('Save complete');
          setState(() { isBusy = false; });
        });  // _saves
      });  // reschedule
    });  // _removes
  }

  void _settings() {
    Navigator.push(context, MaterialPageRoute(builder: (__) => 
                   SettingsDialog(), maintainState: true, fullscreenDialog: false));
    setState(() {});
  }

  void _logout () {
    if ((items.itemListUnsaved) || (items.calendarUnsaved)) {
      showLogoutAlertDialog(context);
    } else {
      userAuth.deauthUser();
      Navigator.of(context).pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
    }
  }

  void _itemsPopupMenu (action) async {
    consolePrint('Items action is $action');
    switch (action) {
      case 'new':
        _createNewItem();
        items.itemListUnsaved = true;
        items.calendarUnsaved = true;
        break;
      case 'load':
        _loadItems();
        items.itemListUnsaved = false;
        items.calendarUnsaved = false;
        break;
      case 'save':
        _saveItems();
        items.itemListUnsaved = true;
        break;
      case 'startdate':
        items.xItems.sortByStart();
        setState(() {});
        break;
      case 'duedate':
        items.xItems.sort((x,y) => x.dueDate.compareTo(y.dueDate));
        setState(() {});
        break;
      case 'donedate':
        items.xItems.sortByFinish();
        setState(() {});
        break;
      case 'name':
        items.xItems.sort((x,y) => x.name.compareTo(y.name));
        setState(() {});
        break;
      case 'duration':
        items.xItems.sort((x,y) => x.duration.compareTo(y.duration));
        setState(() {});
        break;
      case 'priority':
        items.xItems.sort((x,y) => x.priority.compareTo(y.priority));
        setState(() {});
        break;
      default:
        break;
    }
  }

  void _visibilityPopupMenu (action) async {
    consolePrint('Calendar action is $action');
    switch (action) {
      case 'show_all':
        showComplete = true;
        showIncomplete = true;
        break;
      case 'show_completed':
        showComplete = true;
        showIncomplete = false;
        break;
      case 'hide_completed':
        showComplete = false;
        showIncomplete = true;
        break;
      default:
        break;
    }
    setState(() {});
  }

  void _calendarPopupMenu (action) async {
    consolePrint('Calendar action is $action');
    switch (action) {
      case 'update':
        _updateCalendar();
        items.calendarUnsaved = false;
        break;
      case 'clean':
        setState(() { isBusy = true; });
        await new Future.delayed(const Duration(seconds : 1));
        List<Future> _removes = [];
        consolePrint('Create remove requests');
        for (int i=0; i<items.xItems.length; i++) {
          _removes.add(items.xItems[i].removeEntryFromCalendar());
        }
        await Future.wait(_removes).then((removeValue) async {
          consolePrint('Remove requests complete');
        });
        setState(() { isBusy = false; });
        break;
      default:
        break;
    }
  }

  void _profilePopupMenu (action) async {
    consolePrint('Profile action is $action');
    switch (action) {
      case 'settings':
        _settings();
        break;
      case 'logout':
        _logout();
        break;
      default:
        break;
    }
  }

  double menuItemHeight = kMinInteractiveDimension*0.75;

  return isBusy ? 
    AlertDialog(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            child: CircularProgressIndicator(),
            height: 100.0,
            width: 100.0,
          )]),)
    :
    Scaffold(
      appBar: AppBar(
        title: Text(appTitle),
        centerTitle: false,
          actions: <Widget>[
            // Define app bar with icons and (sub)menus
            PopupMenuButton(
              icon: Icon( Icons.category),
              tooltip: "Items",
              onSelected: _itemsPopupMenu,
              itemBuilder: (BuildContext context) {
                var _list = <PopupMenuEntry>[];
                _list.add(PopupMenuItem(
                    height: menuItemHeight,
                    value: "new",
                    child: Text('Create new item')));
                _list.add(PopupMenuItem(
                    height: menuItemHeight,
                    value: "load",
                    child: Text('Load items')));
                _list.add(PopupMenuItem(
                    height: menuItemHeight,
                    value: "save",
                    child: Text('Save items')));
                _list.add(PopupMenuDivider(height: 10));
                _list.add(PopupMenuItem(
                    height: menuItemHeight,
                    value: null,
                    textStyle: TextStyle(color: Colors.black, fontSize: 18.0),
                   child: Row(children: [Icon(Icons.sort), Padding(padding: EdgeInsets.only(right: 20), child: Text('Sort items by...'))])));
                _list.add(PopupMenuItem(
                    height: menuItemHeight,
                    value: "name",
                    child: Text('...name')));
                _list.add(PopupMenuItem(
                    height: menuItemHeight,
                    value: "startdate",
                    child: Text('...starting time')));
                _list.add(PopupMenuItem(
                    height: menuItemHeight,
                    value: "duedate",
                    child: Text('...deadline')));
                _list.add(PopupMenuItem(
                    height: menuItemHeight,
                    value: "donedate",
                    child: Text('...completion time')));
                _list.add(PopupMenuItem(
                    height: menuItemHeight,
                    value: "duration",
                    child: Text('...duration')));
                _list.add(PopupMenuItem(
                    height: menuItemHeight,
                    value: "priority",
                    child: Text('...priority')));
                return _list;
              }
            ),
            PopupMenuButton(
              icon: Icon( Icons.visibility),
              tooltip: "Filter list view",
              onSelected: _visibilityPopupMenu,
              itemBuilder: (BuildContext context) {
                var _list = <PopupMenuEntry>[];
                _list.add(PopupMenuItem(
                    height: menuItemHeight,
                    value: "show_all",
                    child: Text('Show all items'),
                    textStyle: ((showComplete && showIncomplete) ? TextStyle(fontWeight: FontWeight.bold) : TextStyle(fontWeight: FontWeight.normal))));
                _list.add(PopupMenuItem(
                    height: menuItemHeight,
                    value: "show_completed",
                    child: Text('Show only completed items'),
                    textStyle: ((showComplete && !showIncomplete) ? TextStyle(fontWeight: FontWeight.bold) : TextStyle(fontWeight: FontWeight.normal))));
                _list.add(PopupMenuItem(
                    height: menuItemHeight,
                    value: "hide_completed",
                    child: Text('Show only incomplete items'),
                    textStyle: ((!showComplete && showIncomplete) ? TextStyle(fontWeight: FontWeight.bold) : TextStyle(fontWeight: FontWeight.normal))));
                    return _list;
              }
            ),
            PopupMenuButton(
              icon: Icon( Icons.calendar_today),
              tooltip: "Calendar",
              onSelected: _calendarPopupMenu,
              itemBuilder: (BuildContext context) {
                var _list = <PopupMenuEntry>[];
                _list.add(PopupMenuItem(
                    height: menuItemHeight,
                    value: "update",
                    child: Text('Update calendar')));
                _list.add(PopupMenuItem(
                    height: menuItemHeight,
                    value: "clean",
                    child: Text('Clean calendar')));
                    return _list;
              }
            ),
            PopupMenuButton(
              icon: Icon( Icons.account_circle),
              tooltip: "Profile",
              onSelected: _profilePopupMenu,
              itemBuilder: (BuildContext context) {
                var _list = <PopupMenuEntry>[];
                _list.add(PopupMenuItem(
                    height: menuItemHeight,
                    value: "settings",
                    child: Text('Settings')));
                _list.add(PopupMenuItem(
                    height: menuItemHeight,
                    value: "logout",
                    child: Text('Logout')));
                    return _list;
              }
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: listWidget,
          )),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Schedule all items',
        child: Icon(Icons.next_plan, color: Colors.white),
        onPressed: _schedule,
        ),
    );
  }

  void showLogoutAlertDialog(BuildContext context) async {
    Widget cancelButton = TextButton(
      child: Text("Cancel"),
      onPressed:  () { Navigator.of(context).pop(); },
    );
    Widget continueButton = TextButton(
      child: Text("Logout"),
      onPressed:  () { Navigator.of(context).pop();
                       userAuth.deauthUser();
                       Navigator.of(context).pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
                     },
    );
    AlertDialog alert = AlertDialog(
      title: Text("Unsaved changes!"),
      content: Text("You have unsaved changes to the item list and/or calendar."),
      actions: [
        cancelButton,
        continueButton,
      ],
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
}

@override
  void dispose() {
    for (var i=0; i<listEditors.length; i++) {
      listEditors[i].dispose();
    }
    super.dispose();
  }
}