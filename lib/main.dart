// import 'dart:html';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sched_x/editItem.dart';

import 'package:firebase_core/firebase_core.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart' as fb_store;
import 'dart:convert' show utf8;
import 'dart:typed_data' show Uint8List;

import 'items.dart' as items;

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
            title: 'Schedule X',
            theme: ThemeData(
              primarySwatch: Colors.grey,
            ),
            routes: {
              '/': (context) => IssueListPage(title: 'Current Items'),
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
  int _counter = 0;
  List<TextEditingController> listEditors = [];

  _loadItems() {
    fb_store.FirebaseStorage fbStorage = fb_store.FirebaseStorage.instance;
    fb_store.Reference fbStorageRef = fbStorage.ref('test/test.003');
    try {
      fbStorageRef.getData(1000000).then((data) {
        String dataAsString = utf8.decode(data);
        Iterable i = json.decode(dataAsString);
        items.xItems = List<items.Item>.from(i.map((dataAsString)=> items.Item.fromJson(dataAsString)));
        print (items.xItems.toString());
        setState(() {});
      });
    } on fb.FirebaseException catch (e) {
        print(e.toString());
    }
  }

  _saveItems() {
    String text = json.encode(items.xItems);
    List<int> encoded = utf8.encode(text);
    Uint8List data = Uint8List.fromList(encoded);
    
    fb_store.FirebaseStorage fbStorage = fb_store.FirebaseStorage.instance;
    fb_store.Reference fbStorageRef = fbStorage.ref('test/test.003');
    try {
      fbStorageRef.putData(data);
    } on fb.FirebaseException catch (e) {
        print(e.toString());
    }
  }

  _createNewItem() {
    _counter++;
    items.Item i = items.Item();
    i.name = "Item $_counter";
    i.duration = _counter as double;
    i.dueDate = DateTime.now().add(const Duration(days: 2)).millisecondsSinceEpoch;
    i.priority = items.importance.NORMAL;
    items.xItems.add(i);
    setState(() {});
  }

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
      String _dueDate = DateFormat('dd. MMMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(items.xItems[n].dueDate));
      // Build list tile for this entry
      var _temp = Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 80,vertical: 8,),
                    child: ListTile(
                      onTap: () async {await Navigator.push(context, MaterialPageRoute(builder: (__) => 
                                                                     EditItemDialog(thisItem: items.xItems[n]),
                                                                     maintainState: true, fullscreenDialog: true));
                                       setState(() {});},
                      leading: Icon(items.importanceIcon[items.xItems[n].priority.index]),
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
                      subtitle: Text(_dueDate),
                      trailing: Text(items.xItems[n].duration.toString()+"h"),
                    )
                  );
      listWidget.add(_temp);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: listWidget,
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Spacer(),
          Align(
            alignment: Alignment.bottomCenter,
            child: FloatingActionButton(
              onPressed: _saveItems,
              tooltip: 'Save',
              child: Icon(Icons.save),
            ),
          ),
          Spacer(),
          Align(
            alignment: Alignment.bottomLeft,
            child: FloatingActionButton(
              onPressed: _loadItems,
              tooltip: 'Load',
              child: Icon(Icons.folder_open),
            ),
          ),
          Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: FloatingActionButton(
              onPressed: _createNewItem,
              tooltip: 'New',
              child: Icon(Icons.add),
            ),
          ),
        ]), 
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