import 'package:flutter/material.dart';

class TripsPage extends StatefulWidget {
  const TripsPage({super.key});

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  final List<String> trips = ["Goa Trip", "Manali Adventure"];

  void _addTrip() {
    TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add New Trip"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Trip name",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  trips.add(controller.text);
                });
              }
              Navigator.pop(context);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Trips ✈️")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: trips.length,
        itemBuilder: (context, index) => Card(
          child: ListTile(
            leading: const Icon(Icons.location_on),
            title: Text(trips[index]),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTrip,
        child: const Icon(Icons.add),
      ),
    );
  }
}

