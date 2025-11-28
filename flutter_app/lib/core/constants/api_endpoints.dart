class ApiEndpoints {
  // Base URLs - configured via FlavorConfig

  // Auth Endpoints
  static const String signup = '/auth/v1/signup';
  static const String login = '/auth/v1/token?grant_type=password';
  static const String logout = '/auth/v1/logout';
  static const String refreshToken = '/auth/v1/token?grant_type=refresh_token';
  static const String me = '/auth/v1/user';

  // Inventory Endpoints
  static const String items = '/rest/v1/items';
  static const String itemDetail = '/rest/v1/items/:id';

  // User Endpoints
  static const String users = '/rest/v1/users';
  static const String userDetail = '/rest/v1/users/:id';

  // Request Endpoints
  static const String borrowRequests = '/rest/v1/borrow_requests';
  static const String borrowRequestDetail = '/rest/v1/borrow_requests/:id';

  // Audit Endpoints
  static const String auditLogs = '/rest/v1/audit_logs';
}
