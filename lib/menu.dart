import 'package:flutter/material.dart';

class MenuChoice {
  const MenuChoice({this.id, this.title, this.icon});

  final int id;
  final String title;
  final IconData icon;
}

const List<MenuChoice> popupChoices = const <MenuChoice>[
  const MenuChoice(id: 0, title: 'New', icon: Icons.add_circle_outline_outlined),
  const MenuChoice(id: 1, title: 'Load', icon: Icons.download_rounded),
  const MenuChoice(id: 2, title: 'Save', icon: Icons.upload_rounded),
];