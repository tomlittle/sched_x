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
  int _counter = 0;
  List<TextEditingController> listEditors = [];

  @override
  Widget build(BuildContext context) {
    List<Widget> listWidget = [];

  _performItemAction (String action, int index) async {
    consolePrint('action is $action on '+items.xItems[index].name);
    switch (action) {
      case 'show':
        Navigator.push(context, MaterialPageRoute(builder: (__) => ShowSessionsDialog(thisItem: items.xItems[index]),
          maintainState: true, fullscreenDialog: true)).then((value) => setState(() {}));
      break;
      case "edit":
        Navigator.push(context, MaterialPageRoute(builder: (__) => EditItemDialog(thisItem: items.xItems[index]),
          maintainState: true, fullscreenDialog: true)).then((value) => setState(() {}));
        items.itemListUnsaved = true;
        break;
      case "copy":
        items.Item _x = items.Item.copy(items.xItems[index]);
        items.xItems.insert(index,_x);
        items.itemListUnsaved = true;
        setState(() {});
        break;
      case "delete":
        items.xItems.remove(items.xItems[index]);
        items.itemListUnsaved = true;
        setState(() {});
        break;
      default:
        break;
    }
  }

    // Set properties for the ListTiles
    for (var n=0; n<items.xItems.length; n++) {
      // Assign text controller for name
      final TextEditingController _controller = TextEditingController();
      _controller.text = items.xItems[n].name;
      listEditors.add(_controller);
      // Translate epoch due date to date string
      String _dueDate = DateFormat('dd MMMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(items.xItems[n].dueDate));
      // Build a subtitle string with schedlued session if it exists
      String subTitle = 'lasts '+(items.xItems[n].duration/ONE_HOUR).toString()+'h, due on '+_dueDate+'\n';
      if ((items.xItems[n].sessions != null) && (items.xItems[n].sessions.length>0)) {
        int _nSess = items.xItems[n].sessions.length;
        if (_nSess>1) {
          subTitle += _nSess.toString()+" sessions, ";
        }
        subTitle += 'completed on '+
                  DateFormat('dd MMMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(items.xItems[n].sessions[_nSess-1].startTime+
                                                                                        items.xItems[n].sessions[_nSess-1].duration))+
                  ' at '+
                  DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(items.xItems[n].sessions[_nSess-1].startTime+
                                                                                        items.xItems[n].sessions[_nSess-1].duration));
      } else {
        subTitle += '\nNOT SCHEDULED';
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
                        child: Table(  
                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,                    
                          children: [
                            TableRow(children: [Icon(items.scheduledIcon[items.xItems[n].status.index]["icon"],
                                                     color: items.scheduledIcon[items.xItems[n].status.index]["color"]),
                                                Icon(IconData(60131, fontFamily: 'MaterialIcons'), color: Colors.transparent),
                                                ]),
                            TableRow(children: [Icon(IconData(60131, fontFamily: 'MaterialIcons'), color: Colors.transparent),
                                                Icon(items.importanceIcon[items.xItems[n].priority.index]),
                                                ]),
                            TableRow(children: [Icon(IconData(60131, fontFamily: 'MaterialIcons'), color: Colors.transparent),
                                                (items.xItems[n].indivisible ? Icon(IconData(60131, fontFamily: 'MaterialIcons'), color: Colors.transparent) :
                                                                               Icon(IconData(59327, fontFamily: 'MaterialIcons')))
                                                // Icon(items.urgencyIcon[1]["icon"],
                                                //      color: items.scheduledIcon[1]["color"]),
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
      items.itemListUnsaved = false;
      items.calendarUnsaved = true;
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
      _removes.add(items.xItems[i].removeFromCalendar());
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
        items.calendarUnsaved = false;
        setState(() { isBusy = false; });
      });
    });
  }

  _createNewItem() async {
    setState(() { isBusy = true; });
    _counter++;
    items.Item i = items.Item();
    i.id = 'bapp'+DateTime.now().microsecondsSinceEpoch.toString();
    i.name = "New Item $_counter";
    i.duration = _counter * ONE_HOUR;
    DateTime _d = DateTime.now();
    i.dueDate = DateTime(_d.year,_d.month,_d.day,17,0,0).add(const Duration(days: 2)).millisecondsSinceEpoch;
    i.priority = items.importance.NORMAL;
    i.status = items.scheduled.NOTYET;
    i.indivisible = true;
    i.completed = false;
    items.xItems.add(i);
    items.itemListUnsaved = true;
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
      _removes.add(items.xItems[i].removeFromCalendar());
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
          consolePrint('Add requests complete, save');
          consolePrint(value.toString());
          _saveItems();
          consolePrint('Save complete');
          items.calendarUnsaved = false;
          setState(() { isBusy = false; });
        });  // _saves
      });  // reschedule
    });  // _removes
    items.itemListUnsaved = true;
  }

  void _settings() {
    Navigator.push(context, MaterialPageRoute(builder: (__) => 
                   SettingsDialog(), maintainState: true, fullscreenDialog: false));
    setState(() {});
  }

  void _sortItems (String action) async {
    consolePrint('sort field is $action');
    switch (action) {
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

  void _logout () {
    if (items.itemListUnsaved) {
      // !!! Warn user
    }
    userAuth.deauthUser();
    Navigator.of(context).pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
  }

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
            IconButton(
              icon: Icon( Icons.add_circle_outline_outlined ),
              tooltip: "New",
              onPressed: _createNewItem,
            ),


            PopupMenuButton<String>(
              icon: Icon( Icons.sort ),
              tooltip: "Sort",
              onSelected: _sortItems,
              itemBuilder: (BuildContext context) {
                var _list = <PopupMenuEntry<String>>[];
                  _list.add(PopupMenuItem(
                      value: "name",
                      child: Text('Name')));
                  _list.add(PopupMenuItem(
                      value: "startdate",
                      child: Text('Starting time')));
                  _list.add(PopupMenuItem(
                      value: "duedate",
                      child: Text('Deadline')));
                  _list.add(PopupMenuItem(
                      value: "donedate",
                      child: Text('Completion time')));
                  _list.add(PopupMenuItem(
                      value: "duration",
                      child: Text('Duration')));
                  _list.add(PopupMenuItem(
                      value: "priority",
                      child: Text('Priority')));
                  return _list;
              },
            ),
            IconButton(
              icon: Icon( Icons.download_rounded ),
              tooltip: "Load",
              onPressed: _loadItems,
            ),
            IconButton(
              icon: Icon( Icons.upload_rounded ),
              color: items.itemListUnsaved ? Colors.red : Colors.black,
              tooltip: "Save",
              onPressed: _saveItems,
            ),
            IconButton(
              icon: Icon( Icons.calendar_today ),
              color: items.calendarUnsaved ? Colors.red : Colors.black,
              tooltip: "Update calendar",
              onPressed: _updateCalendar,
            ),
            IconButton(
              icon: Icon( Icons.settings),
              tooltip: "Settings",
              onPressed: _settings,
            ),
            IconButton(
              icon: Icon( Icons.logout),
              tooltip: "Logout",
              onPressed: _logout,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: listWidget,
          )),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Schedule all items',
        child: Icon(Icons.quickreply, color: Colors.white),
        onPressed: _schedule,
        ),
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