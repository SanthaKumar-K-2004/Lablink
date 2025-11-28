import 'package:flutter_riverpod/flutter_riverpod.dart';

// Theme Provider
final themeProvider = StateProvider<bool>((ref) {
  return false; // false = light mode, true = dark mode
});

// Loading Provider
final loadingProvider = StateProvider<bool>((ref) {
  return false;
});

// Error Provider
final errorProvider = StateProvider<String?>((ref) {
  return null;
});

// User Role Provider
enum UserRole { admin, staff, student, guest }

final userRoleProvider = StateProvider<UserRole>((ref) {
  return UserRole.guest;
});

// Authentication State
final isAuthenticatedProvider = StateProvider<bool>((ref) {
  return false;
});
