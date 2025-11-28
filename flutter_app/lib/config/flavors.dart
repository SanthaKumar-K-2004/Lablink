enum Flavor {
  dev,
  staging,
  prod,
}

class FlavorConfig {
  static const Flavor currentFlavor = Flavor.dev;

  static FlavorConfig? _instance;
  final Flavor flavor;
  final String name;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String sentryDsn;
  final bool enableSentry;

  FlavorConfig._internal({
    required this.flavor,
    required this.name,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.sentryDsn,
    required this.enableSentry,
  });

  factory FlavorConfig.dev() {
    return FlavorConfig._internal(
      flavor: Flavor.dev,
      name: 'Development',
      supabaseUrl: 'http://localhost:54321',
      supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9',
      sentryDsn: '',
      enableSentry: false,
    );
  }

  factory FlavorConfig.staging() {
    return FlavorConfig._internal(
      flavor: Flavor.staging,
      name: 'Staging',
      supabaseUrl: 'https://staging-project.supabase.co',
      supabaseAnonKey: 'staging-anon-key',
      sentryDsn: 'https://staging-sentry-dsn@sentry.io/project',
      enableSentry: true,
    );
  }

  factory FlavorConfig.prod() {
    return FlavorConfig._internal(
      flavor: Flavor.prod,
      name: 'Production',
      supabaseUrl: 'https://prod-project.supabase.co',
      supabaseAnonKey: 'prod-anon-key',
      sentryDsn: 'https://prod-sentry-dsn@sentry.io/project',
      enableSentry: true,
    );
  }

  static FlavorConfig get instance {
    _instance ??= FlavorConfig.dev();
    return _instance!;
  }

  static void setInstance(FlavorConfig config) {
    _instance = config;
  }

  bool get isDev => flavor == Flavor.dev;
  bool get isStaging => flavor == Flavor.staging;
  bool get isProd => flavor == Flavor.prod;
}
