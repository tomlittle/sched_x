import 'package:firebase_core/firebase_core.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart' as fb_store;
import 'dart:convert' show json, utf8;
import 'dart:typed_data' show Uint8List;

import 'package:flutter_login/flutter_login.dart';
import 'package:sched_x/globals.dart';
import 'items.dart' as items;

class LocalAuth extends XAuthorize {

  static final LocalAuth _auth = LocalAuth.setUser(name: '', password: '', dataLocation: '', isLoggedIn: false);

  factory LocalAuth() {
    return _auth;
  }

  static UserData currentUser = UserData();

  LocalAuth.setUser({String name, String password, String dataLocation, bool isLoggedIn}) {    
    currentUser.name = name;
    currentUser.password = password;
    currentUser.dataLocation = dataLocation;
    currentUser.isLoggedIn = isLoggedIn;
  }

  Future<String> createUser(LoginData data) async {
    consolePrint('NEW Name: ${data.name}, Password: ${data.password}');
    // Get user list from FB
    return await getUserList().then((_users) {
      // Check whether user already exists
      if (_users.containsKey(data.name)) {
        LocalAuth.setUser(name: data.name, password: data.password, dataLocation: data.name, isLoggedIn: false);
        return 'Username already exists';
      }
      // Create user and add to list, write list to FB
      UserData _ud = UserData();
      _ud.name = data.name;
      _ud.password = data.password;
      _ud.dataLocation = data.name;
      _ud.isLoggedIn = false;
      var _u = {data.name: _ud};
      _users.addAll(_u);
      putUserList(_users);
      // Create & write default configuration
      XConfiguration.newConfigForUser(data.name);
      return null;
    });
  }

  Future<String> authUser(LoginData data) async {
    consolePrint('Name: ${data.name}, Password: ${data.password}');
    return await getUserList().then((_users) {
      // Check whether user already exists
      if (!_users.containsKey(data.name)) {
        return 'Username does not exist';
      }
      if (_users[data.name]['password'] != data.password) {
        return 'Password incorrect';
      }
      LocalAuth.setUser(name: data.name, password: data.password, dataLocation: data.name, isLoggedIn: true);
      XConfiguration.readConfigForUser(_users[data.name]['dataLocation']);
      return null;
    });
  }

  Future<String> deauthUser() {
    LocalAuth.setUser(name: '', password: '', dataLocation: '', isLoggedIn: false);
    items.xItems = [];
    return null;
  }

  Future<String> recoverPassword(String name) async {
    consolePrint('Recover for name: $name');
    return await getUserList().then((_users) {
      if (!_users.containsKey(name)) {
        return 'Username does not exist';
      }
      return null;
    });
  }

  Future<Map<String,dynamic>> getUserList() async {
    Map<String,dynamic> _users = {};
    fb_store.FirebaseStorage fbStorage = fb_store.FirebaseStorage.instance;
    fb_store.Reference fbStorageRef = fbStorage.ref('users.json');
    try {
      Uint8List data = await fbStorageRef.getData(1000000); //.then((data) {
        String dataAsString = utf8.decode(data);
        _users = json.decode(dataAsString);
        if (_users==null) {
          _users = {};
        }
        return _users;
    } on fb.FirebaseException catch (e) {
        print(e.toString());
        return _users;
    }
  }

  void putUserList(Map<String,UserData> _users) async {
    String encodedText = '{';
    _users.forEach((key, value) { 
      String _encodedUd = '"'+key+'": {"name": "'+value.name+'", "password": "'+value.password+
                          '", "dataLocation" : "'+value.dataLocation+'", "isLoggedIn": false}';
      encodedText += _encodedUd;
    });
    encodedText += '}';
    List<int> encoded = utf8.encode(encodedText);
    Uint8List data = Uint8List.fromList(encoded);
    fb_store.FirebaseStorage fbStorage = fb_store.FirebaseStorage.instance;
    fb_store.Reference fbStorageRef = fbStorage.ref('users.json');
    try {
      fbStorageRef.putData(data);
    } on fb.FirebaseException catch (e) {
        print(e.toString());
    }
  }
}

LocalAuth userAuth = LocalAuth();