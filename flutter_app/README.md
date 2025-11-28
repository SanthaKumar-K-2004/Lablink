# LabLink Flutter App

Professional lab asset, compliance, and access management application built with Flutter.

## 📱 Project Overview

LabLink is a comprehensive flutter application designed for managing lab assets, compliance, and access control. It supports multiple user roles (Admin, Staff, Student) with role-based features and a professional design system.

## 🏗️ Architecture

This project follows **Clean Architecture** with a feature-first approach:

### Layers
- **Presentation**: UI, screens, widgets, providers
- **Domain**: Entities, repositories (abstract), use cases
- **Data**: Models, datasources, repository implementations
- **Core**: Theme, constants, extensions, errors, utilities

### State Management
- **Riverpod**: For state management, dependency injection, and async operations
- **Providers**: Immutable, cached, future, stream, and state notifier providers

### Routing
- **GoRouter**: Type-safe navigation with deep linking support

## 🎨 Design System

### Color Palette
- **Primary**: Teal #0891B2
- **Secondary**: Navy #1E3A8A
- **Success**: Emerald #10B981
- **Warning**: Amber #F59E0B
- **Error**: Rose #DC2626
- **Neutral**: 50-900 grayscale

### Typography
- **Font**: Inter (primary)
- **Sizes**: 12px (caption) → 32px (display)
- **Weights**: Regular (400) → Bold (700)

### Spacing
- **Base**: 8px
- **Scale**: xs (4px) → 4xl (64px)

### Components
- **Buttons**: Primary, Secondary, Danger, Ghost
- **Inputs**: Text, Email, Password, Date Picker, Dropdown
- **Cards**: Base, Stat, Item, Action
- **Status**: Badges with color coding
- **Layouts**: Responsive, Mobile-first

## 📁 Project Structure

```
flutter_app/
├── lib/
│   ├── main.dart                    # Dev entry point
│   ├── main_dev.dart               # Dev flavor
│   ├── main_staging.dart           # Staging flavor
│   ├── main_prod.dart              # Production flavor
│   ├── config/                     # Configuration
│   │   ├── flavors.dart           # Build flavors
│   │   ├── app_config.dart        # App settings
│   │   └── environment.dart       # Env config
│   ├── core/                       # Core layer
│   │   ├── constants/             # Constants
│   │   ├── extensions/            # Dart extensions
│   │   ├── errors/                # Error handling
│   │   ├── theme/                 # Design tokens
│   │   ├── services/              # Platform services
│   │   ├── utils/                 # Utilities
│   │   └── network/               # Network setup
│   ├── domain/                     # Domain layer (entities, repos, usecases)
│   ├── data/                       # Data layer (models, datasources)
│   ├── presentation/               # Presentation layer
│   │   ├── auth/                  # Auth feature
│   │   ├── admin/                 # Admin feature
│   │   ├── staff/                 # Staff feature
│   │   ├── student/               # Student feature
│   │   ├── common/                # Shared widgets
│   │   ├── routing/               # Navigation
│   │   ├── providers/             # Riverpod providers
│   │   └── app.dart               # Main app widget
│   └── l10n/                       # Localization
├── test/
│   ├── unit/                       # Unit tests
│   ├── widget/                     # Widget tests
│   └── integration/                # Integration tests
├── web/                            # Web configuration
├── android/                        # Android configuration
├── ios/                            # iOS configuration
├── pubspec.yaml                    # Dependencies
└── README.md
```

## 🚀 Getting Started

### Prerequisites
- Flutter 3.10.0+
- Dart 3.0.0+
- Supabase project set up
- IDE: VS Code / Android Studio / Xcode

### Installation

1. **Clone the repository**
   ```bash
   git clone <repo-url>
   cd flutter_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Set up environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your Supabase credentials
   ```

4. **Run the app**
   ```bash
   # Development
   flutter run -t lib/main.dart
   
   # Staging
   flutter run -t lib/main_staging.dart
   
   # Production
   flutter run -t lib/main_prod.dart
   
   # Web
   flutter run -d chrome --target lib/main.dart
   ```

### Development Flavors

The app supports three build flavors:

#### Development
- **Target**: `lib/main_dev.dart`
- **Supabase**: localhost:54321
- **Sentry**: Disabled
- **Command**: `flutter run -t lib/main_dev.dart`

#### Staging
- **Target**: `lib/main_staging.dart`
- **Supabase**: staging-project.supabase.co
- **Sentry**: Enabled
- **Command**: `flutter run -t lib/main_staging.dart`

#### Production
- **Target**: `lib/main_prod.dart`
- **Supabase**: prod-project.supabase.co
- **Sentry**: Enabled
- **Command**: `flutter run -t lib/main_prod.dart`

## 📦 Key Dependencies

### State Management & DI
- `flutter_riverpod: ^2.4.0` - State management
- `riverpod_generator: ^2.3.0` - Code generation

### Navigation
- `go_router: ^9.0.0` - Type-safe routing

### Backend
- `supabase_flutter: ^1.10.0` - Backend integration
- `supabase: ^2.0.0` - Dart client

### Storage & Caching
- `hive_flutter: ^1.1.0` - Local storage
- `flutter_secure_storage: ^9.0.0` - Secure token storage
- `shared_preferences: ^2.2.0` - App preferences

### Data Serialization
- `freezed: ^2.4.0` - Code generation for models
- `json_serializable: ^6.7.0` - JSON serialization

### Utils & Logging
- `logger: ^2.0.0` - Structured logging
- `sentry_flutter: ^7.14.0` - Error tracking
- `connectivity_plus: ^5.0.0` - Network detection

## 🎯 Design System Usage

### Colors
```dart
import 'package:lablink/core/theme/app_colors.dart';

Container(
  color: AppColors.primary,  // Teal
  child: Text('Primary'),
);
```

### Typography
```dart
import 'package:lablink/core/theme/app_typography.dart';

Text(
  'Heading',
  style: AppTypography.displayMedium,
);
```

### Spacing
```dart
import 'package:lablink/core/theme/app_spacing.dart';

SizedBox(height: AppSpacing.lg);  // 16px
```

### Shadows
```dart
import 'package:lablink/core/theme/app_shadows.dart';

Container(
  boxShadow: AppShadows.medium,
);
```

## 🧩 Component Library

### Button Examples
```dart
// Primary Button
PrimaryButton(
  label: 'Save',
  onPressed: () {},
  size: Size.medium,
);

// Secondary Button
SecondaryButton(
  label: 'Cancel',
  onPressed: () {},
);

// Danger Button
DangerButton(
  label: 'Delete',
  onPressed: () {},
);

// Ghost Button
GhostButton(
  label: 'Learn More',
  onPressed: () {},
);
```

### Input Examples
```dart
// Text Input
TextInput(
  label: 'Name',
  placeholder: 'Enter your name',
  onChanged: (value) {},
);

// Email Input
EmailInput(
  label: 'Email',
  controller: _emailController,
);

// Password Input
PasswordInput(
  label: 'Password',
  controller: _passwordController,
);
```

### Card Examples
```dart
// Base Card
BaseCard(
  child: Text('Content'),
);

// Stat Card
StatCard(
  label: 'Total Items',
  value: '1,234',
  icon: Icons.inventory,
);
```

### Status Badge
```dart
StatusBadge(
  label: 'Active',
  status: StatusType.success,
  icon: Icons.check_circle,
);
```

## 🧪 Testing

### Running Tests
```bash
# Unit tests
flutter test test/unit/

# Widget tests
flutter test test/widget/

# All tests with coverage
flutter test --coverage

# Generate coverage report
lcov --list coverage/lcov.info
```

### Test Structure
```
test/
├── unit/              # Business logic tests
│   ├── core/
│   ├── domain/
│   └── data/
├── widget/            # UI component tests
│   ├── screens/
│   └── widgets/
└── integration/       # End-to-end tests
```

## 🔐 Security Best Practices

1. **Token Storage**: Use `flutter_secure_storage` for JWT tokens
2. **Environment Secrets**: Never commit `.env` files
3. **HTTPS**: Always use HTTPS for production APIs
4. **Validation**: Validate all user inputs
5. **Error Handling**: Don't expose sensitive info in error messages

## 📱 Responsive Design

### Breakpoints
- **Mobile**: < 600px (full-width, single column)
- **Tablet**: 600px - 1024px (2-3 columns)
- **Desktop**: ≥ 1024px (full layout, sidebars)

### Usage
```dart
ResponsiveLayout(
  mobile: MobileView(),
  tablet: TabletView(),
  desktop: DesktopView(),
);
```

## 🌐 Internationalization

Multi-language support with `.arb` files:

```
l10n/
├── app_en.arb  # English
├── app_es.arb  # Spanish
└── app_fr.arb  # French
```

## 📊 Performance Optimization

- **Lazy Loading**: Pagination and virtual lists
- **Image Caching**: Network + local caching
- **Memoization**: Riverpod memo() for expensive computations
- **Code Splitting**: Web deferred loading
- **Profiling**: Flutter DevTools

## 🐛 Debugging

### Enable Debug Logging
```dart
import 'package:logger/logger.dart';

final logger = Logger();
logger.d('Debug message');
logger.e('Error', error: exception, stackTrace: stack);
```

### Sentry Integration
```dart
import 'package:sentry_flutter/sentry_flutter.dart';

await SentryFlutter.init(
  (options) => options.dsn = AppConfig.sentryDsn,
  appRunner: () => runApp(const LabLinkApp()),
);
```

## 📚 Documentation

- [Architecture Guide](docs/ARCHITECTURE.md)
- [Widget Catalog](docs/WIDGET_CATALOG.md)
- [API Integration](docs/API_INTEGRATION.md)
- [Testing Guide](docs/TESTING_GUIDE.md)
- [Deployment Guide](docs/DEPLOYMENT_GUIDE.md)

## 🤝 Contributing

1. Create a feature branch: `git checkout -b feature/amazing-feature`
2. Commit changes: `git commit -m 'Add amazing feature'`
3. Push to branch: `git push origin feature/amazing-feature`
4. Open a Pull Request

### Code Style
- Use `dart format` for formatting
- Run `dart analyze` for linting
- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Add tests for new features

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 📞 Support

For support, issues, or questions:
- Open an issue on GitHub
- Check the [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
- Review existing documentation

## 🔄 CI/CD

The project uses GitHub Actions for:
- Automated testing on pull requests
- Code analysis and linting
- Build verification (web, Android, iOS)
- Code coverage tracking
- Release builds

## 🚢 Deployment

### Web
```bash
flutter build web --target lib/main_prod.dart --release
```

### Android
```bash
flutter build apk --target lib/main_prod.dart --release
flutter build appbundle --target lib/main_prod.dart --release
```

### iOS
```bash
flutter build ios --target lib/main_prod.dart --release
```

---

**Last Updated**: 2024
**Maintainer**: LabLink Team
