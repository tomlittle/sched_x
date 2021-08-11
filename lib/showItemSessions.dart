import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'globals.dart';
import 'items.dart' as items;

class ShowSessionsDialog extends StatefulWidget {
  final items.Item thisItem;
  ShowSessionsDialog({Key key, this.thisItem}) : super(key: key);
  @override
  _ShowSessionsDialogState createState() => new _ShowSessionsDialogState(thisItem);
}

class _ShowSessionsDialogState extends State<ShowSessionsDialog> {
  items.Item thisItem;
  _ShowSessionsDialogState(items.Item thisItem) {
    this.thisItem = thisItem;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_){_showDialog(this.thisItem);});
  }

  _showDialog(thisItem) async {
    List<Widget> sessionsWidget = [];
    for (int i=0; i<this.thisItem.sessions.length; i++) {
      DateTime _finish = DateTime.fromMillisecondsSinceEpoch(this.thisItem.sessions[i].startTime);
      int _h = (thisItem.sessions[i].duration / ONE_HOUR).truncate();
      int _m = ((thisItem.sessions[i].duration - _h*ONE_HOUR) / ONE_MINUTE).truncate();
      String _mS = '0'+_m.toString();
      Text _t = Text(_h.toString()+':'+_mS.substring(_mS.length-2)+' on '+
                     DateFormat('dd MMMM yyyy').format(_finish)+' at '+DateFormat('HH:mm').format(_finish));
      sessionsWidget.add(_t);
    }

    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
                return AlertDialog(
          titlePadding: EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 12.0),
          title: Text('Schedule for '+thisItem.name),
           content: SingleChildScrollView(
            child: Material(
              child: Column(
                children: sessionsWidget,
                ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Ok'),
              onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil('/itemList', (Route<dynamic> route) => false);
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
