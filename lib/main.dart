import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// AHORA USAMOS PLUGINS EN VEZ DE PLATFORM CHANNELS
import 'features/auth/data/datasources/biometric_datasource.dart';
import 'features/auth/domain/usecases/authenticate_user.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/steps/presentation/widgets/step_counter_widget.dart';
import 'features/tracking/presentation/widgets/route_map_widget.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FitnessApp());
}

class FitnessApp extends StatelessWidget {
  const FitnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    
    // MIGRACIÓN COMPLETA A PLUGINS 
    // local_auth → Biometría
    // sensors_plus → Acelerómetro
    // geolocator → GPS
    // flutter_local_notifications → Notificaciones
    
    final biometricDataSource = BiometricDataSourceImpl();
    final authenticateUser = AuthenticateUser(biometricDataSource);

    return MaterialApp(
      title: 'Fitness Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6366F1)),
        useMaterial3: true,
      ),
      home: BlocProvider(
        create: (_) => AuthBloc(authenticateUser),
        child: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isAuthenticated = false;

  void _onAuthSuccess() {
    setState(() {
      _isAuthenticated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticated) {
      return const HomePage();
    }
    return LoginPage(onAuthSuccess: _onAuthSuccess);
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.fitness_center, size: 24),
            SizedBox(width: 8),
            Text('Fitness Tracker'),
            Spacer(),
            Chip(
              label: Text(
                'Plugins',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              backgroundColor: Colors.green,
              padding: EdgeInsets.symmetric(horizontal: 4),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Banner informativo
            Card(
              color: Color(0xFFE0F2FE),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF0284C7)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🎉 Migración completada',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Ahora usa plugins nativos en vez de Platform Channels',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF0369A1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            
            StepCounterWidget(),
            SizedBox(height: 16),
            RouteMapWidget(),
          ],
        ),
      ),
    );
  }
}