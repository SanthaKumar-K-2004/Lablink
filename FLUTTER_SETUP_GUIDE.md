# Flutter App Setup Guide

## Phase 2: Professional Flutter Project Setup

This guide covers the complete Flutter project setup for LabLink, including architecture, design system, and all production-ready components.

## 📋 Checklist

### ✅ Project Structure
- [x] Feature-first clean architecture
- [x] Organized by feature (auth, admin, staff, student)
- [x] Core layer for shared utilities
- [x] Domain layer for business logic
- [x] Data layer for API/database
- [x] Presentation layer for UI

### ✅ Design System
- [x] Professional color palette (8+ colors with shades)
- [x] Complete typography system (heading1-3, body, labels)
- [x] Spacing system (8px baseline, xs-4xl)
- [x] Shadow/elevation system (subtle to extra)
- [x] Border radius tokens (xs to full)
- [x] Responsive breakpoints (mobile/tablet/desktop)

### ✅ Base Widget Library (25+ Components)
- [x] **Buttons**: Primary, Secondary, Danger, Ghost
- [x] **Inputs**: Text, Email, Password
- [x] **Cards**: Base, Stat
- [x] **Status**: Badges with color coding
- [x] **States**: Loading, Empty, Error
- [x] **Navigation**: AppBar, Navigation widgets
- [x] **Layout**: AppShell, ResponsiveLayout

### ✅ Configuration & Setup
- [x] Three build flavors (dev, staging, prod)
- [x] Environment variable support (.env files)
- [x] Flavor-specific entry points
- [x] Supabase integration ready
- [x] Web configuration

### ✅ State Management
- [x] Riverpod 2.x integration
- [x] Providers for app state
- [x] Theme provider
- [x] Authentication state
- [x] Loading/error states

### ✅ Routing
- [x] GoRouter configuration
- [x] Named routes
- [x] Deep linking ready
- [x] Role-based navigation structure
- [x] Error handling

### ✅ Core Infrastructure
- [x] Custom exception hierarchy
- [x] Failure types for error handling
- [x] String, DateTime, BuildContext extensions
- [x] Constants and error messages
- [x] API endpoints configuration

### ✅ Testing Infrastructure
- [x] Unit tests for utilities
- [x] Widget tests for components
- [x] Test structure and organization

### ✅ Documentation
- [x] Comprehensive README
- [x] Architecture overview
- [x] Component examples
- [x] Configuration guide

## 🏃 Quick Start

### 1. Navigate to Flutter App
```bash
cd flutter_app
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Run Development Build
```bash
flutter run -t lib/main_dev.dart
```

### 4. Run on Web
```bash
flutter run -d chrome -t lib/main_dev.dart
```

## 📁 File Structure Overview

```
flutter_app/
├── lib/
│   ├── main.dart ........................ Dev entry point
│   ├── main_dev.dart ................... Development flavor
│   ├── main_staging.dart ............... Staging flavor
│   ├── main_prod.dart .................. Production flavor
│   │
│   ├── config/ ......................... Configuration
│   │   ├── app_config.dart
│   │   ├── flavors.dart
│   │   └── environment.dart
│   │
│   ├── core/ ........................... Shared layer
│   │   ├── constants/
│   │   │   ├── app_constants.dart
│   │   │   ├── api_endpoints.dart
│   │   │   └── error_messages.dart
│   │   ├── extensions/
│   │   │   ├── string_extensions.dart
│   │   │   ├── datetime_extensions.dart
│   │   │   └── build_context_extensions.dart
│   │   ├── errors/
│   │   │   ├── exceptions.dart
│   │   │   └── failure.dart
│   │   ├── theme/
│   │   │   ├── app_colors.dart ......... Professional palette
│   │   │   ├── app_typography.dart .... Font system
│   │   │   ├── app_spacing.dart ....... Spacing tokens
│   │   │   ├── app_shadows.dart ....... Elevation system
│   │   │   ├── app_radius.dart ........ Border radius
│   │   │   └── app_theme_data.dart .... ThemeData
│   │   ├── services/
│   │   ├── utils/
│   │   └── network/
│   │
│   ├── domain/ ......................... Business Logic
│   │   ├── entities/
│   │   ├── repositories/
│   │   └── usecases/
│   │
│   ├── data/ ........................... Data Layer
│   │   ├── datasources/
│   │   ├── models/
│   │   └── repositories/
│   │
│   ├── presentation/ ................... UI Layer
│   │   ├── app.dart ................... Main app widget
│   │   │
│   │   ├── auth/
│   │   │   ├── screens/
│   │   │   ├── widgets/
│   │   │   └── providers/
│   │   │
│   │   ├── admin/
│   │   │   ├── screens/
│   │   │   │   ├── admin_dashboard_screen.dart
│   │   │   │   ├── inventory_management_screen.dart
│   │   │   │   ├── users_management_screen.dart
│   │   │   │   └── reports_screen.dart
│   │   │   ├── widgets/
│   │   │   └── providers/
│   │   │
│   │   ├── staff/
│   │   │   ├── screens/
│   │   │   ├── widgets/
│   │   │   └── providers/
│   │   │
│   │   ├── student/
│   │   │   ├── screens/
│   │   │   ├── widgets/
│   │   │   └── providers/
│   │   │
│   │   ├── common/
│   │   │   ├── screens/
│   │   │   │   ├── splash_screen.dart
│   │   │   │   ├── error_screen.dart
│   │   │   │   └── not_found_screen.dart
│   │   │   │
│   │   │   ├── widgets/
│   │   │   │   ├── buttons/
│   │   │   │   │   ├── primary_button.dart
│   │   │   │   │   ├── secondary_button.dart
│   │   │   │   │   ├── danger_button.dart
│   │   │   │   │   └── ghost_button.dart
│   │   │   │   ├── inputs/
│   │   │   │   │   ├── text_input.dart
│   │   │   │   │   ├── email_input.dart
│   │   │   │   │   └── password_input.dart
│   │   │   │   ├── cards/
│   │   │   │   │   ├── base_card.dart
│   │   │   │   │   ├── stat_card.dart
│   │   │   │   │   └── item_card.dart
│   │   │   │   ├── navigation/
│   │   │   │   ├── status/
│   │   │   │   │   └── status_badge.dart
│   │   │   │   ├── states/
│   │   │   │   │   ├── loading_widget.dart
│   │   │   │   │   ├── empty_state_widget.dart
│   │   │   │   │   └── error_state_widget.dart
│   │   │   │   ├── app_shell.dart
│   │   │   │   └── responsive_layout.dart
│   │   │   │
│   │   │   ├── providers/
│   │   │   └── viewmodels/
│   │   │
│   │   ├── routing/
│   │   │   ├── app_router.dart
│   │   │   ├── route_names.dart
│   │   │   ├── route_paths.dart
│   │   │   └── route_guards.dart
│   │   │
│   │   └── providers/
│   │       └── app_providers.dart
│   │
│   └── l10n/ ........................... Localization
│       ├── app_en.arb
│       ├── app_es.arb
│       └── app_fr.arb
│
├── test/
│   ├── unit/ ........................... Unit tests
│   ├── widget/ ......................... Widget tests
│   └── integration/ .................... Integration tests
│
├── web/ ............................... Web configuration
├── android/ ........................... Android config
├── ios/ ............................... iOS config
├── pubspec.yaml ....................... Dependencies
├── .env ............................... Dev environment
├── .env.staging ....................... Staging environment
└── .env.prod .......................... Production environment
```

## 🎨 Design Tokens

### Color System (9 Core Colors + Neutrals)
```dart
// Primary: Teal
AppColors.primary = #0891B2
AppColors.primaryDark = #065F73
AppColors.primaryLight = #06D6D0

// Secondary: Navy
AppColors.secondary = #1E3A8A

// Status Colors
AppColors.success = #10B981 (Emerald)
AppColors.warning = #F59E0B (Amber)
AppColors.error = #DC2626 (Rose)
AppColors.info = #0EA5E9 (Sky)

// Neutrals (50, 100, 200, 400, 600, 700, 900)
```

### Typography Hierarchy
```dart
displayLarge = 32px Bold
displayMedium = 24px Bold
displaySmall = 20px Semibold
headlineLarge = 18px Semibold
bodyLarge = 16px Regular
bodyMedium = 14px Regular
bodySmall = 12px Regular
labelLarge = 14px Medium
```

### Spacing Scale (8px baseline)
```dart
xs = 4px    (tight)
sm = 8px    (small)
md = 12px   (default)
lg = 16px   (comfortable)
xl = 24px   (generous)
xxl = 32px  (large)
xxxl = 48px (extra large)
xxxxl = 64px (section)
```

## 🧩 Component Examples

### Using Theme Colors
```dart
Container(
  color: AppColors.primary,
  child: Text(
    'Hello',
    style: AppTypography.headlineLarge,
  ),
)
```

### Button Components
```dart
PrimaryButton(
  label: 'Save',
  onPressed: () {},
  size: Size.medium,
  isLoading: false,
)

SecondaryButton(
  label: 'Cancel',
  onPressed: () {},
)

DangerButton(
  label: 'Delete',
  onPressed: () {},
)

GhostButton(
  label: 'Learn More',
  onPressed: () {},
)
```

### Form Inputs
```dart
EmailInput(
  label: 'Email',
  placeholder: 'your@email.com',
  controller: _emailController,
)

PasswordInput(
  label: 'Password',
  controller: _passwordController,
)

TextInput(
  label: 'Full Name',
  placeholder: 'Enter your full name',
  maxLines: 1,
)
```

### Cards & Status
```dart
BaseCard(
  child: Text('Card content'),
)

StatCard(
  label: 'Total Items',
  value: '1,234',
  icon: Icons.inventory,
  trend: '+12%',
  isTrendPositive: true,
)

StatusBadge(
  label: 'Active',
  status: StatusType.success,
  icon: Icons.check_circle,
)
```

### States & Layouts
```dart
LoadingWidget(
  message: 'Loading...',
)

EmptyStateWidget(
  title: 'No items found',
  description: 'Try adjusting your filters',
  icon: Icons.inbox,
)

ErrorStateWidget(
  title: 'Error',
  message: 'Something went wrong',
  onRetry: () {},
)

ResponsiveLayout(
  mobile: MobileView(),
  tablet: TabletView(),
  desktop: DesktopView(),
)
```

## 🔧 Configuration

### Build Flavors
```bash
# Development
flutter run -t lib/main_dev.dart

# Staging
flutter run -t lib/main_staging.dart

# Production
flutter run -t lib/main_prod.dart
```

### Environment Variables
Edit `.env`, `.env.staging`, `.env.prod`:
```
SUPABASE_URL=http://localhost:54321
SUPABASE_ANON_KEY=your-key-here
APP_ENV=development
```

### Supabase Integration
Located in: `lib/core/network/supabase_client.dart`

## 🧪 Testing

### Run Tests
```bash
# All tests
flutter test

# Unit tests only
flutter test test/unit/

# Widget tests only
flutter test test/widget/

# With coverage
flutter test --coverage
```

### Test Example
```dart
testWidgets('PrimaryButton calls onPressed', (WidgetTester tester) async {
  bool pressed = false;
  
  await tester.pumpWidget(
    MaterialApp(
      home: PrimaryButton(
        label: 'Test',
        onPressed: () => pressed = true,
      ),
    ),
  );
  
  await tester.tap(find.byType(PrimaryButton));
  expect(pressed, true);
});
```

## 📦 Dependencies Overview

| Package | Purpose | Version |
|---------|---------|---------|
| flutter_riverpod | State management | 2.4.0+ |
| go_router | Routing & navigation | 9.0.0+ |
| supabase_flutter | Backend integration | 1.10.0+ |
| hive_flutter | Local storage | 1.1.0+ |
| flutter_secure_storage | Secure token storage | 9.0.0+ |
| freezed | Code generation | 2.4.0+ |
| logger | Structured logging | 2.0.0+ |
| sentry_flutter | Error tracking | 7.14.0+ |

## 🚀 Running on Different Platforms

### Web
```bash
flutter run -d chrome -t lib/main_dev.dart
```

### Android Emulator
```bash
flutter emulators --launch pixel_5
flutter run -t lib/main_dev.dart
```

### iOS Simulator
```bash
flutter run -d iPhone_14 -t lib/main_dev.dart
```

## 📊 Performance Tips

1. **Use `const`** for widgets that don't change
2. **Implement `shouldRebuild`** in providers
3. **Cache images** with `CachedNetworkImage`
4. **Use `ListView.builder`** for large lists
5. **Profile** with DevTools: `flutter pub global activate devtools`

## 🔐 Security

1. **Never commit `.env` files** with secrets
2. **Use Secure Storage** for tokens
3. **Validate inputs** on client and server
4. **Use HTTPS** for all API calls
5. **Implement CSRF** protection

## 📚 Next Steps

1. **Implement authentication** in auth layer
2. **Create domain entities** for data models
3. **Build repository** interfaces and implementations
4. **Implement use cases** for business logic
5. **Add more screens** for each role
6. **Integrate Supabase** real-time subscriptions
7. **Set up CI/CD** with GitHub Actions
8. **Add Firebase** for push notifications

## 🤝 Contributing

1. Follow the existing architecture
2. Use consistent naming conventions
3. Add tests for new features
4. Document complex logic
5. Keep components small and focused

## 📞 Support & Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Riverpod Documentation](https://riverpod.dev)
- [GoRouter Documentation](https://pub.dev/packages/go_router)
- [Supabase Documentation](https://supabase.com/docs)
- [Clean Architecture](https://medium.com/flutter-community/clean-architecture-with-flutter)

---

**Project**: LabLink Flutter App
**Version**: 1.0.0
**Last Updated**: 2024
