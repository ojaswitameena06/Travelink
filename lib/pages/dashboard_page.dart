import 'package:flutter/material.dart';
import 'home_page.dart';
import 'trips_page.dart';
import 'places_page.dart';
import 'packages_page.dart';
import 'ai_chatbot_page.dart';
import 'chat_list_page.dart';
import 'profile_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    TripsPage(),
    PlacesPage(),
    PackagesPage(),
    AIChatbotPage(),
    ChatListPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 11,
        unselectedFontSize: 10,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: "Explore",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flight_takeoff),
            label: "My Trips",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.place),
            label: "Places",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.card_travel),
            label: "Packages",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy),
            label: "AI Assist",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble),
            label: "Messages",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}
