import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/racket_provider.dart';
import 'providers/shop_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/injury_provider.dart';
import 'providers/subscription_provider.dart';
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
        ChangeNotifierProxyProvider2<AuthProvider, ShopProvider, ChatProvider>(
          create: (_) => ChatProvider(),
          update: (_, auth, shopProv, chatProv) {
            final provider = chatProv ?? ChatProvider();
            final myShop = shopProv.shops
                .where((s) => s.ownerUid == auth.currentUser?.uid)
                .firstOrNull;
            provider.syncForUser(
              auth.currentUser?.uid,
              role: auth.currentUser?.role,
              shopId: myShop?.id,
            );
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider(),
          update: (_, auth, notifProv) {
            final provider = notifProv ?? NotificationProvider();
            provider.syncForUser(auth.currentUser?.uid);
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
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
