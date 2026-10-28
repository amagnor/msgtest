import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info_plus/device_info_plus.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSignUp = false;
  bool _isVerificationStep = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  String? _pendingEmail;

  final _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (_isSignUp) {
        await _supabase.auth.signUp(email: email, password: password);

        // Nach erfolgreicher Registrierung in den Bestätigungsmodus wechseln
        setState(() {
          _pendingEmail = email;
          _isVerificationStep = true;
          _successMessage = 'Registrierung erfolgreich!\nBitte den Code eingeben, der in der Bestätigungsmail angezeigt wird.';
        });
      } else {
        await _supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );

        // Nach erfolgreichem Login FCM Token in Supabase speichern
        await _saveFcmTokenToDatabase();
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ein unerwarteter Fehler ist aufgetreten: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    final token = _otpController.text.trim();
    if (token.isEmpty || _pendingEmail == null) {
      setState(() {
        _errorMessage = 'Bitte gib den Bestätigungscode ein.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _supabase.auth.verifyOTP(
        email: _pendingEmail!,
        token: token,
        type: OtpType.signup,
      );

      // Nach erfolgreicher Verifizierung FCM Token in Supabase speichern
      await _saveFcmTokenToDatabase();
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ungültiger Code oder Fehler bei der Bestätigung: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, String>> _getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    String deviceType = 'Unknown';
    String osVersion = 'Unknown';
    String deviceName = 'Unknown';

    try {
      if (!kIsWeb && Platform.isAndroid) {
        final info = await deviceInfoPlugin.androidInfo;
        deviceType = 'Android';
        osVersion =
            'Android ${info.version.release} (API ${info.version.sdkInt})';
        deviceName = '${info.manufacturer} ${info.model}';
      } else if (!kIsWeb && Platform.isIOS) {
        final info = await deviceInfoPlugin.iosInfo;
        deviceType = 'iOS';
        osVersion = 'iOS ${info.systemVersion}';
        deviceName = '${info.modelName} (${info.utsname.machine})';
      } else if (kIsWeb) {
        deviceType = 'Web';
        osVersion = 'Web Browser';
        deviceName = 'Web Client';
      }
    } catch (e) {
      debugPrint('Fehler beim Abrufen der Geräteinformationen: $e');
    }

    return {
      'device_type': deviceType,
      'os_version': osVersion,
      'device_name': deviceName,
    };
  }

  Future<void> _saveFcmTokenToDatabase() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (e) {
        debugPrint('Konnte FCM Token nicht abrufen: $e');
      }

      // Fallback für Simulator/Emulator, falls kein FCM-Token generiert werden konnte
      fcmToken ??= 'simulator_fcm_token_${user.id}';
      final deviceInfo = await _getDeviceInfo();

      // In die 'user_profiles' Tabelle speichern (Upsert)
      await _supabase.from('user_profiles').upsert({
        'id': user.id,
        'email': user.email,
        'fcm_token': fcmToken,
        'device_type': deviceInfo['device_type'],
        'os_version': deviceInfo['os_version'],
        'device_name': deviceInfo['device_name'],
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Fehler beim Speichern des FCM Tokens in Supabase: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            color: const Color(0xFF1B263B),
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isVerificationStep
                          ? 'E-Mail bestätigen'
                          : (_isSignUp ? 'Registrierung' : 'Anmeldung'),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_successMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.greenAccent),
                        ),
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(color: Colors.greenAccent),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_isVerificationStep) ...[
                      // OTP Bestätigungscode Feld
                      TextFormField(
                        controller: _otpController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Bestätigungscode (OTP)',
                          labelStyle: const TextStyle(color: Colors.white70),
                          prefixIcon: const Icon(
                            Icons.verified,
                            color: Colors.greenAccent,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0D1B2A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Bitte gib den Code ein';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Code bestätigen Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _verifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Code bestätigen',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),

                      // Zurück zum Login
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isVerificationStep = false;
                            _isSignUp = false;
                            _errorMessage = null;
                            _successMessage = null;
                          });
                        },
                        child: const Text(
                          'Zurück zur Anmeldung',
                          style: TextStyle(color: Colors.greenAccent),
                        ),
                      ),
                    ] else ...[
                      // E-Mail Feld
                      TextFormField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'E-Mail',
                          labelStyle: const TextStyle(color: Colors.white70),
                          prefixIcon: const Icon(
                            Icons.email,
                            color: Colors.greenAccent,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0D1B2A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.isEmpty ||
                              !value.contains('@')) {
                            return 'Bitte eine gültige E-Mail eingeben';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Passwort Feld
                      TextFormField(
                        controller: _passwordController,
                        style: const TextStyle(color: Colors.white),
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Passwort',
                          labelStyle: const TextStyle(color: Colors.white70),
                          prefixIcon: const Icon(
                            Icons.lock,
                            color: Colors.greenAccent,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF0D1B2A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return 'Das Passwort muss mindestens 6 Zeichen lang sein';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _authenticate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _isSignUp ? 'Registrieren' : 'Anmelden',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),

                      // Toggle Button zwischen Login und Registrierung
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isSignUp = !_isSignUp;
                            _errorMessage = null;
                            _successMessage = null;
                          });
                        },
                        child: Text(
                          _isSignUp
                              ? 'Bereits ein Konto? Anmelden'
                              : 'Noch kein Konto? Hier registrieren',
                          style: const TextStyle(color: Colors.greenAccent),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
