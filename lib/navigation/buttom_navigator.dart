import 'package:absensi_san/view/attendance_history_page.dart';
import 'package:absensi_san/view/home_screen.dart';
import 'package:absensi_san/view/profile_screen.dart';
import 'package:flutter/material.dart';

class ButtomNavigator extends StatefulWidget {
  const ButtomNavigator({Key? key}) : super(key: key);

  @override
  State<ButtomNavigator> createState() => _ButtomNavigatorState();
}

class _ButtomNavigatorState extends State<ButtomNavigator> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(), // halaman dashboard kamu
    AttendanceHistoryPage(), // halaman attendance history kamu
    ProfileScreen(), // halaman profile kamu
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
