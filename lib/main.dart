import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/racket_provider.dart';
import 'providers/shop_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/auth/login_register_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GearSportsApp());
}

class GearSportsApp extends StatelessWidget {
  const GearSportsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RacketProvider()),
        ChangeNotifierProvider(create: (_) => ShopProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp(
        title: 'Gear Sports - Trợ Lý Cầu Lông & Đan Vợt',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const LoginRegisterScreen(),
      ),
    );
  }
}
