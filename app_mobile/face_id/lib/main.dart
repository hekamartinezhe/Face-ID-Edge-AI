import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'services/api_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Chequeo rápido del estado de la API antes de iniciar la UI.
  final ok = await ApiClient.instance.checkStatus();
  if (ok) {
    final info = ApiClient.instance.serverInfo;
    // Puedes hacer logging aquí si quieres
    // print('API online: $info');
  } else {
    // Si no está, dejamos la app correr pero con serverOnline=false
    // print('API offline o inaccesible');
  }

  runApp(const FaceIDApp());
}

class FaceIDApp extends StatelessWidget {
  const FaceIDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face-ID Edge AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      // Aquí conectamos tu nueva interfaz
      home: LoginScreen(),
    );
  }
}
