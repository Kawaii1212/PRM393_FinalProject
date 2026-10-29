import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/racket_provider.dart';
import 'providers/shop_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/order_provider.dart';
import 'providers/injury_provider.dart';
import 'screens/auth/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization warning: $e');
  }
  runApp(const GearSportsApp());
}

class GearSportsApp extends StatelessWidget {
  const GearSportsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProxyProvider<AuthProvider, RacketProvider>(
          create: (_) => RacketProvider(),
          update: (_, auth, racketProv) {
            final provider = racketProv ?? RacketProvider();
            provider.syncForUser(auth.currentUser?.uid);
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => ShopProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (_) => ChatProvider(),
          update: (_, auth, chatProv) {
            final provider = chatProv ?? ChatProvider();
            provider.syncForUser(auth.currentUser?.uid);
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProxyProvider<AuthProvider, InjuryProvider>(
          create: (_) => InjuryProvider(),
          update: (_, auth, injuryProv) {
            final provider = injuryProv ?? InjuryProvider();
            provider.syncForUser(auth.currentUser?.uid);
            return provider;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Gear Sports - Trợ Lý Cầu Lông & Đan Vợt',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
