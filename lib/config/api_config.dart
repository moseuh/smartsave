/// Centralized API Configuration
/// Change this to switch between local and remote servers
class ApiConfig {
  // Toggle between local and remote
  static const bool useLocalServer = true;
  
  // Server URLs
  static const String localBaseUrl = 'http://192.168.100.29/apis';
  static const String remoteBaseUrl = 'http://apis.nebo.co.ke/apis';
  
  // Active base URL based on configuration
  static String get baseUrl => useLocalServer ? localBaseUrl : remoteBaseUrl;
  
  // Full API URL getter
  static String getUrl(String endpoint) {
    // Remove leading slash if present
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    return '$baseUrl/$cleanEndpoint';
  }
  
  // Common endpoints
  static String get register => getUrl('register');
  static String get login => getUrl('login');
  static String user(String userId) => getUrl('user/$userId');
  static String get userDetails => getUrl('user-details');
  static String userDetailsById(String userId) => getUrl('user-details/$userId');
  static String get mpesaUsage => getUrl('mpesa-usage');
  static String mpesaUsageById(String userId) => getUrl('mpesa-usage/$userId');
  static String get userSavings => getUrl('user-savings');
  static String userSavingsById(String userId) => getUrl('user-savings/$userId');
  static String get savingsHistory => getUrl('savings-history');
  static String savingsHistoryById(String userId) => getUrl('savings-history/$userId');
  static String get lastPayment => getUrl('last-payment');
  static String lastPaymentById(String userId) => getUrl('last-payment/$userId');
  static String get roundupSettings => getUrl('roundup-settings');
  static String roundupSettingsById(String userId) => getUrl('roundup-settings/$userId');
  static String get leaderboard => getUrl('leaderboard');
  static String get leaderboardTopWeekly => getUrl('leaderboard/top-10-weekly');
  static String get savingsRecent => getUrl('savings-recent');
  static String savingsRecentById(String userId) => getUrl('savings-recent/$userId');
  static String get goalsCreate => getUrl('goalscreate');
  static String get goalsList => getUrl('goalslist');
  static String goalsListById(String userId) => getUrl('goalslist/$userId');
  static String get challengesJoin => getUrl('challengesjoin');
  static String get challengesContribute => getUrl('challengescontribute');
  static String get loans => getUrl('loans');
  static String loansById(String userId) => getUrl('loans/$userId');
  static String get loanEligibility => getUrl('loan-eligibility');
  static String loanEligibilityById(String userId) => getUrl('loan-eligibility/$userId');
  static String get applyLoan => getUrl('apply-loan');
  static String get repayLoan => getUrl('repay-loan');
  static String get bankLoanRequest => getUrl('bank-loan-request');
  static String get pendingLoans => getUrl('pending-loans');
  static String get jobs => getUrl('jobs');
  static String get favourites => getUrl('favourites');
  static String favouritesById(String userId) => getUrl('favourites/$userId');
  static String deleteFavourite(String id) => getUrl('favourites/$id');
  static String get buyGoodsPayments => getUrl('buy-goods-payments');
  static String get processPaybillPayment => getUrl('process-paybill-payment');
  static String transactionStatus(String transactionId) => getUrl('transaction-status/$transactionId');
  static String get uploadProfilePicture => getUrl('upload-profile-picture');
  static String uploadProfilePictureById(String userId) => getUrl('upload-profile-picture/$userId');
  static String get wallet => getUrl('wallet');
  static String walletById(String userId) => getUrl('wallet/$userId');
  static String get remittance => getUrl('remittance');
  static String get transactions => getUrl('transactions');
  static String transactionsById(String userId) => getUrl('transactions/$userId');
}
