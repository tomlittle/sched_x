// import 'dart:html';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:firebase_core/firebase_core.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart' as fb_store;
import 'dart:convert' show utf8;
import 'dart:typed_data' show Uint8List;

import 'package:sched_x/globals.dart';
import 'package:sched_x/editItem.dart';
import 'package:sched_x/simulatedCalendar.dart';
import 'package:sched_x/googleCalendar.dart';
import 'items.dart' as items;

const String appTitle = 'Schedule X';

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
        // Get configuration data
        new XConfiguration();
        // Open calendar
        switch (XConfiguration.calendarType) {
          case "google":
            new GoogleCalendar();
            break;
          case "simulated":
            new SimCalendar();
            break;
          default:
            new SimCalendar();
            break;
        }
        if (snapshot.hasError) {
          // !!! do something
        }
        // Once complete, show your application
        if (snapshot.connectionState == ConnectionState.done) {
          return MaterialApp(
            title: appTitle,
            theme: ThemeData(
              primarySwatch: Colors.lightBlue,
            ),
            routes: {
              '/': (context) => IssueListPage(title: 'Schedule X'),
            },
          );
        }
        // Otherwise, show something whilst waiting for initialization to complete
        return CircularProgressIndicator(); // !!! this may not work (still loading)
      },
    );
  }
}

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

    // Set properties for the ListTiles
    for (var n=0; n<items.xItems.length; n++) {
      // Assign text controller for name
      final TextEditingController _controller = TextEditingController();
      _controller.text = items.xItems[n].name;
      listEditors.add(_controller);
      // Translate epoch due date to date string
      String _dueDate = DateFormat('dd MMMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(items.xItems[n].dueDate));
      // Build a subtitle string with schedlued session if it exists
      String subTitle = 'lasts '+(items.xItems[n].duration/ONE_HOUR).toString()+'h, due on '+_dueDate;
      if (items.xItems[n].sessions != null) {
        subTitle += '\nscheduled for '+
                    DateFormat('dd MMMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(items.xItems[n].sessions[0].startTime))+
                    ' at '+
                    DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(items.xItems[n].sessions[0].startTime));
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
                                                Icon(items.urgencyIcon[1]["icon"],
                                                     color: items.scheduledIcon[1]["color"]),
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
                      trailing: Icon(Icons.more_vert),
                    )
                  );
      listWidget.add(_temp);
    }

  _loadItems() async {
    setState(() { isBusy = true; });
    fb_store.FirebaseStorage fbStorage = fb_store.FirebaseStorage.instance;
    fb_store.Reference fbStorageRef = fbStorage.ref('test/test.003');
    try {
      fbStorageRef.getData(1000000).then((data) {
        String dataAsString = utf8.decode(data);
        Iterable i = json.decode(dataAsString);
        items.xItems = List<items.Item>.from(i.map((dataAsString)=> items.Item.fromJson(dataAsString)));
        setState(() { isBusy = false; });
      });
    } on fb.FirebaseException catch (e) {
        print(e.toString());
    }
  }

  _saveItems() {
    setState(() { isBusy = true; });
    String text = json.encode(items.xItems);
    List<int> encoded = utf8.encode(text);
    Uint8List data = Uint8List.fromList(encoded);
    
    fb_store.FirebaseStorage fbStorage = fb_store.FirebaseStorage.instance;
    fb_store.Reference fbStorageRef = fbStorage.ref('test/test.003');
    try {
      fbStorageRef.putData(data);
      setState(() { isBusy = false; });
    } on fb.FirebaseException catch (e) {
        print(e.toString());
    }
  }

  _createNewItem() {
    setState(() { isBusy = true; });
    _counter++;
    items.Item i = items.Item();
    i.id = DateTime.now().millisecondsSinceEpoch.toString()+'-$_counter';
    i.name = "Item $_counter";
    i.duration = _counter * ONE_HOUR;
    DateTime _d = DateTime.now();
    i.dueDate = DateTime(_d.year,_d.month,_d.day,17,0,0).add(const Duration(days: 2)).millisecondsSinceEpoch;
    i.priority = items.importance.NORMAL;
    i.status = items.scheduled.NOTYET;
    items.xItems.add(i);
    setState(() { isBusy = false; });
  }

  void _schedule() {
    setState(() { isBusy = true; });
    items.reschedule(false).then((value) => setState(() { isBusy = false; }));
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
            IconButton(
              icon: Icon( Icons.download_rounded ),
              tooltip: "Load",
              onPressed: _loadItems,
            ),
            IconButton(
              icon: Icon( Icons.upload_rounded ),
              tooltip: "Save",
              onPressed: _saveItems,
            ),
        ],
      ),
      body: Column(
        children: listWidget,
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Compute schedule',
        child: Icon(Icons.quickreply, color: Colors.white),
        onPressed: _schedule),
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