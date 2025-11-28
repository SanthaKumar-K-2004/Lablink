class RoutePaths {
  // Root
  static const String root = '/';

  // Auth
  static const String login = '/login';
  static const String signup = '/signup';
  static const String passwordReset = '/password-reset';

  // Admin
  static const String adminDashboard = '/admin/dashboard';
  static const String inventoryManagement = '/admin/inventory';
  static const String usersManagement = '/admin/users';
  static const String reports = '/admin/reports';

  // Staff
  static const String staffDashboard = '/staff/dashboard';
  static const String approvalQueue = '/staff/approval';
  static const String staffInventory = '/staff/inventory';

  // Student
  static const String studentDashboard = '/student/dashboard';
  static const String itemBrowser = '/student/items';
  static const String borrowRequest = '/student/request/:itemId';
  static const String myRequests = '/student/requests';

  // Error
  static const String notFound = '/404';
  static const String error = '/error';
}
