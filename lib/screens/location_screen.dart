import 'package:flutter/material.dart';




class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Location')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Schloss Solitude',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Image(
                        image: AssetImage('images/solitude.jpg'),
                      ),
                      SizedBox(width: 8),
                      Image(
                        image: AssetImage('images/solitude1.jpg'),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Ort der Trauung!\n'
                    'Adresse: Solitude 1, 70197 Stuttgart-West\n'
                  ),

                  Text(
                    'Kleiner Kursaal Bad Cannstatt',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Image(
                        image: AssetImage('images/kursaal.jpg'),
                      ),
                      SizedBox(width: 8),
                      Image(
                        image: AssetImage('images/kursaal1.jpg'),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Ort der Feier!\n'
                    'Adresse: Königspl. 1, 70372 Stuttgart-Bad Cannstatt\n'
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}