import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinbox/material.dart'; 

import 'items.dart' as items;

class EditItemDialog extends StatefulWidget {
  final items.Item thisItem;
  EditItemDialog({Key key, this.thisItem}) : super(key: key);
  @override
  _EditItemDialogState createState() => new _EditItemDialogState(thisItem);
}

class _EditItemDialogState extends State<EditItemDialog> {
  items.Item thisItem;
  _EditItemDialogState(items.Item thisItem) {
    this.thisItem = thisItem;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_){_showDialog(this.thisItem);});
  }

  _showDialog(thisItem) async{
    // Assign text controller for name
    final TextEditingController _controller = TextEditingController();
    _controller.text = thisItem.name;
    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
                return AlertDialog(
          title: TextField(
                        onChanged: (String value) {thisItem.name = _controller.text;},
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: "Description",
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                        ),
                      ),
           content: SingleChildScrollView(
            child: Material(
              child: EditItemDialogContent(thisItem: thisItem),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Ok'),
              onPressed: () {
                Navigator.popUntil(context, ModalRoute.withName('/'));
              },
            ),
          ],
        );
      },
      barrierDismissible: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class EditItemDialogContent extends StatefulWidget {
  final items.Item thisItem;
  EditItemDialogContent({Key key, this.thisItem}) : super(key: key);
  @override
  _EditItemDialogContentState createState() => new _EditItemDialogContentState(thisItem);
}

class _EditItemDialogContentState extends State<EditItemDialogContent> {
  items.Item thisItem;
  _EditItemDialogContentState(items.Item thisItem) {
    this.thisItem = thisItem;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_){_getContent(this.thisItem);});
  }

  _getContent(thisItem){
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text("This item:", style: TextStyle(color: Colors.grey[800])),
        // Date picker for due date
        Container(
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.only(top:10, left: 10),
          child: TextButton(
            child: Text("is due on "+DateFormat('dd. MMMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(thisItem.dueDate)),
                        style: TextStyle(color: Colors.grey[800])),
            onPressed: () async {await _displayDuedatePicker(context,thisItem); setState(() {});}, 
        )),
        // Numeric field for duration
        Container(
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.only(top:10, left: 10),
          child: TextButton(
            child: Text("requires "+thisItem.duration.toString()+" hour(s) to complete",
                        style: TextStyle(color: Colors.grey[800])),
          onPressed: () async {await _displayDurationCounter(context,thisItem); setState(() {});},
        )),
        // Dropdown for priority
        Container(
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.only(top:10, left: 10),
          child: TextButton(
            child: Text("is of "+items.importanceText[thisItem.priority.index]+" importance",
                        style: TextStyle(color: Colors.grey[800])),
          onPressed: () async {await _displayPriorityDropdown(context,thisItem); setState(() {});},
          )),
      ],
    );
  }

  Future<void> _displayDurationCounter (BuildContext context, items.Item thisItem) async {
    double _spinnerValue = thisItem.duration;
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Duration of '+thisItem.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SpinBox(
                min: 0.5,
                max: 99.5,
                step: 0.5,
                decimals: 1,
                value: _spinnerValue,
                onChanged: (value) => setState((){thisItem.duration = value; _spinnerValue = value;}),
              )],
          ),);
      },
    );  
  }

  Future<void> _displayPriorityDropdown (BuildContext context, items.Item thisItem) {
    items.importance _dropdownValue = thisItem.priority;
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Importance of '+thisItem.name),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [DropdownButton(
                value: _dropdownValue,
                items: items.importanceList,
                onChanged: (value) {
                  setState(() {thisItem.priority = value as items.importance;
                  _dropdownValue = value;
                  Navigator.of(context).pop(); 
                  });
              }),
          ]));
        });
  }

  Future<void> _displayDuedatePicker (BuildContext context, items.Item thisItem) async {
    int _pickerValue = thisItem.dueDate;
    DateTime pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.fromMillisecondsSinceEpoch(_pickerValue),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030));
    if (pickedDate != null) {
      thisItem.dueDate = pickedDate.millisecondsSinceEpoch;
      _pickerValue = pickedDate.millisecondsSinceEpoch;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _getContent(this.thisItem);
  }
}
