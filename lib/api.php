<?php
header("Access-Control-Allow-Origin: http://localhost:53627");
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");
header("Access-Control-Allow-Methods: GET, POST, PATCH, DELETE");
header("Access-Control-Allow-Headers: Content-Type, Accept");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    error_log("Handling OPTIONS request for {$_SERVER['REQUEST_URI']}");
    http_response_code(200);
    header("Content-Type: text/plain");
    header("Access-Control-Allow-Origin: *");
    header("Access-Control-Allow-Methods: GET, POST, OPTIONS, PATCH, DELETE");
    header("Access-Control-Allow-Headers: Content-Type, Accept");
    exit;
}

// Database configuration
// Load from environment variables for security
const DB_HOST = getenv('DB_HOST') ?: 'localhost';
const DB_USER = getenv('DB_USER') ?: '';
const DB_PASS = getenv('DB_PASS') ?: '';
const DB_NAME = getenv('DB_NAME') ?: '';
const DEBUG = getenv('DEBUG') === 'true';

// Validate required database credentials
if (empty(DB_USER) || empty(DB_PASS) || empty(DB_NAME)) {
    error_log('CRITICAL: Database credentials not configured in environment variables');
    http_response_code(500);
    echo json_encode(['error' => 'Server configuration error']);
    exit;
}

// Informa API configuration
const INFORMA_API_KEY = getenv('INFORMA_API_KEY') ?: '';
const INFORMA_LIVE_ENDPOINT = 'https://api.informa.co.ke';
const INFORMA_SANDBOX_ENDPOINT = 'https://sandbox.informa.co.ke';
const INFORMA_USE_SANDBOX = getenv('INFORMA_USE_SANDBOX') === 'true';
const INFORMA_API_BASE = INFORMA_USE_SANDBOX ? INFORMA_SANDBOX_ENDPOINT : INFORMA_LIVE_ENDPOINT;

// Validate Informa API key
if (empty(INFORMA_API_KEY)) {
    error_log('WARNING: Informa API key not configured in environment variables');
}

// Safaricom M-PESA API configuration
const MPESA_B2B_SECURITY_CREDENTIAL = getenv('MPESA_B2B_SECURITY_CREDENTIAL') ?: '';
const MPESA_B2B_SHORTCODE = getenv('MPESA_B2B_SHORTCODE') ?: '';
const MPESA_CALLBACK_URL = getenv('MPESA_CALLBACK_URL') ?: '';
const MPESA_CONSUMER_KEY = getenv('MPESA_CONSUMER_KEY') ?: '';
const MPESA_CONSUMER_SECRET = getenv('MPESA_CONSUMER_SECRET') ?: '';
const MPESA_PASSKEY = getenv('MPESA_PASSKEY') ?: '';
const MPESA_SHORTCODE = getenv('MPESA_SHORTCODE') ?: '';
const MPESA_ENV = getenv('MPESA_ENV') ?: 'sandbox';

// Validate M-PESA credentials
if (empty(MPESA_CONSUMER_KEY) || empty(MPESA_CONSUMER_SECRET) || empty(MPESA_PASSKEY) || empty(MPESA_SHORTCODE)) {
    error_log('WARNING: M-PESA credentials not fully configured in environment variables');
}
// Firebase configuration
const FIREBASE_PROJECT_ID = getenv('FIREBASE_PROJECT_ID') ?: '';

// Validate Firebase configuration
if (empty(FIREBASE_PROJECT_ID)) {
    error_log('WARNING: Firebase project ID not configured in environment variables');
}

// Helper function to verify Firebase ID token
function verifyFirebaseIdToken($idToken) {
    $parts = explode('.', $idToken);
    if (count($parts) !== 3) {
        return ['status' => 'error', 'message' => 'Invalid token format'];
    }
    
    $header = json_decode(base64_decode(str_replace(['-', '_'], ['+', '/'], $parts[0])), true);
    $payload = json_decode(base64_decode(str_replace(['-', '_'], ['+', '/'], $parts[1])), true);
    $signature = base64_decode(str_replace(['-', '_'], ['+', '/'], $parts[2]));
    
    if (!$header || !$payload) {
        return ['status' => 'error', 'message' => 'Invalid token structure'];
    }

    if (!isset($payload['exp']) || $payload['exp'] < time()) {
        return ['status' => 'error', 'message' => 'Token expired'];
    }

    if (!isset($payload['aud']) || $payload['aud'] !== FIREBASE_PROJECT_ID) {
        return ['status' => 'error', 'message' => 'Token audience mismatch'];
    }

    if (!isset($payload['iss']) || $payload['iss'] !== 'https://securetoken.google.com/' . FIREBASE_PROJECT_ID) {
        return ['status' => 'error', 'message' => 'Invalid issuer'];
    }

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, 'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com');
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    if (curl_errno($ch) || $httpCode !== 200) {
        curl_close($ch);
        return ['status' => 'error', 'message' => 'Failed to fetch public keys'];
    }
    curl_close($ch);
    $publicKeys = json_decode($response, true);

    if (!isset($header['kid']) || !isset($publicKeys[$header['kid']])) {
        return ['status' => 'error', 'message' => 'Invalid key ID'];
    }

    $data = $parts[0] . '.' . $parts[1];
    $publicKey = $publicKeys[$header['kid']];
    $isValid = openssl_verify(
        $data,
        $signature,
        $publicKey,
        OPENSSL_ALGO_SHA256
    );

    if ($isValid !== 1) {
        return ['status' => 'error', 'message' => 'Invalid signature'];
    }

    return [
        'status' => 'success',
        'email' => $payload['email'] ?? '',
        'name' => $payload['name'] ?? '',
        'google_id' => $payload['sub'] ?? ''
    ];
}

// Create required tables
// Create required tables
function createRequiredTables() {
    $conn = getDbConnection();
    
    $usersTableQuery = "
        CREATE TABLE IF NOT EXISTS users (
            id INT AUTO_INCREMENT PRIMARY KEY,
            full_name VARCHAR(255) NOT NULL,
            date_of_birth DATE,
            email VARCHAR(255) NOT NULL UNIQUE,
            phone_number VARCHAR(20) NOT NULL UNIQUE,
            national_id VARCHAR(20) NOT NULL UNIQUE,
            password VARCHAR(255) NOT NULL,
            selfie_path VARCHAR(255) DEFAULT '',
            id_document_path VARCHAR(255) DEFAULT '',
            face_verified BOOLEAN DEFAULT FALSE,
            google_id VARCHAR(255) DEFAULT NULL UNIQUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB
    ";
    $conn->query($usersTableQuery) ? error_log("Users table created or already exists") : error_log("Error creating users table: " . $conn->error);
    
    $transactionsTableQuery = "
        CREATE TABLE IF NOT EXISTS transactions (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            phone_number VARCHAR(15) NOT NULL,
            total_amount DECIMAL(10,2) NOT NULL,
            service_charge DECIMAL(10,2) NOT NULL,
            savings_amount DECIMAL(10,2) NOT NULL,
            merchant_amount DECIMAL(10,2) NOT NULL,
            merchant_paybill VARCHAR(20) NOT NULL,
            merchant_account VARCHAR(50) DEFAULT '',
            transaction_type ENUM('pay_bill', 'buy_goods') DEFAULT 'pay_bill',
            status ENUM('pending', 'completed', 'failed') DEFAULT 'pending',
            merchant_status ENUM('pending', 'completed', 'failed') DEFAULT 'pending',
            checkout_request_id VARCHAR(50) DEFAULT NULL,
            mpesa_receipt VARCHAR(20) DEFAULT NULL,
            merchant_reference VARCHAR(50) DEFAULT NULL,
            error_message TEXT DEFAULT NULL,
            merchant_error TEXT DEFAULT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            validated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        ) ENGINE=InnoDB
    ";
    $conn->query($transactionsTableQuery) ? error_log("Transactions table created or already exists") : error_log("Error creating transactions table: " . $conn->error);
    
    $favoritesTableQuery = "
        CREATE TABLE IF NOT EXISTS favorites (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            name VARCHAR(100) NOT NULL,
            till_number VARCHAR(20) NOT NULL,
            account_number VARCHAR(50) DEFAULT '',
            type ENUM('buy_goods', 'pay_bill') NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            UNIQUE KEY unique_till_user (user_id, till_number, type),
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        ) ENGINE=InnoDB
    ";
    $conn->query($favoritesTableQuery) ? error_log("Favorites table created or already exists") : error_log("Error creating favorites table: " . $conn->error);
    
    $mpesaUsageTableQuery = "
        CREATE TABLE IF NOT EXISTS mpesa_usage (
            user_id INT PRIMARY KEY,
            total_spent DECIMAL(15,2) DEFAULT 0,
            weekly_avg DECIMAL(15,2) DEFAULT 0,
            monthly_avg DECIMAL(15,2) DEFAULT 0,
            yearly_avg DECIMAL(15,2) DEFAULT 0,
            usage_band VARCHAR(50) DEFAULT '',
            transaction_count INT DEFAULT 0,
            last_updated DATETIME,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        ) ENGINE=InnoDB
    ";
    $conn->query($mpesaUsageTableQuery) ? error_log("Mpesa_usage table created or already exists") : error_log("Error creating mpesa_usage table: " . $conn->error);
    
    $roundupSettingsTableQuery = "
        CREATE TABLE IF NOT EXISTS roundup_settings (
            user_id INT PRIMARY KEY,
            is_enabled BOOLEAN DEFAULT FALSE,
            pay_bill_round_up BOOLEAN DEFAULT FALSE,
            buy_goods_round_up BOOLEAN DEFAULT FALSE,
            retail_purchases_round_up BOOLEAN DEFAULT FALSE,
            rounding_value VARCHAR(10) DEFAULT 'KSh 1',
            max_round_up DECIMAL(10,2) DEFAULT NULL,
            monthly_cap DECIMAL(10,2) DEFAULT NULL,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        ) ENGINE=InnoDB
    ";
    $conn->query($roundupSettingsTableQuery) ? error_log("Roundup_settings table created or already exists") : error_log("Error creating roundup_settings table: " . $conn->error);
    
    $verificationLogsTableQuery = "
        CREATE TABLE IF NOT EXISTS verification_logs (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            verification_type VARCHAR(50) NOT NULL,
            request_id VARCHAR(50) DEFAULT NULL,
            status VARCHAR(20) NOT NULL,
            message TEXT DEFAULT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        ) ENGINE=InnoDB
    ";
    $conn->query($verificationLogsTableQuery) ? error_log("Verification_logs table created or already exists") : error_log("Error creating verification_logs table: " . $conn->error);
    
    $passwordResetTokensTableQuery = "
        CREATE TABLE IF NOT EXISTS password_reset_tokens (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            token VARCHAR(255) NOT NULL,
            expires_at DATETIME NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            UNIQUE KEY unique_token (token)
        ) ENGINE=InnoDB
    ";
    $conn->query($passwordResetTokensTableQuery) ? error_log("Password_reset_tokens table created or already exists") : error_log("Error creating password_reset_tokens table: " . $conn->error);
    
    $conn->close();
}

// Helper function to send password reset email
function sendPasswordResetEmail($email, $token) {
    $resetLink = "hhttp://apis.gnmprimesource.co.ke/apis/reset-password?token=$token"; // Replace with your front-end reset password URL
    $subject = "Password Reset Request";
    $message = "Hello,\n\nYou requested a password reset. Click the link below to reset your password:\n$resetLink\n\nThis link will expire in 1 hour.\n\nIf you did not request a password reset, please ignore this email.\n\nBest regards,\nSaveApp Team";
    $headers = "From: no-reply@your-app-domain.com\r\n";
    
    if (mail($email, $subject, $message, $headers)) {
        return ['status' => 'success', 'message' => 'Password reset email sent successfully'];
    } else {
        return ['status' => 'error', 'message' => 'Failed to send password reset email'];
    }
}
// Connect to MySQL
function getDbConnection() {
    $conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);
    if ($conn->connect_error) {
        http_response_code(500);
        echo json_encode(['status' => 'error', 'message' => 'Database connection failed: ' . $conn->connect_error]);
        exit;
    }
    return $conn;
}

// Handle selfie upload
function uploadSelfie($file) {
    $uploadDir = 'Uploads/Selfies/';
    if (!is_dir($uploadDir)) {
        mkdir($uploadDir, 0777, true);
    }
    $fileName = time() . '-' . uniqid() . '.' . pathinfo($file['name'], PATHINFO_EXTENSION);
    $uploadPath = $uploadDir . $fileName;
    if (move_uploaded_file($file['tmp_name'], $uploadPath)) {
        return $fileName;
    }
    return null;
}

// Handle ID document upload
function uploadIdDocument($file) {
    $uploadDir = 'Uploads/ID/';
    if (!is_dir($uploadDir)) {
        mkdir($uploadDir, 0777, true);
    }
    $fileName = time() . '-' . uniqid() . '.' . pathinfo($file['name'], PATHINFO_EXTENSION);
    $uploadPath = $uploadDir . $fileName;
    if (move_uploaded_file($file['tmp_name'], $uploadPath)) {
        return $fileName;
    }
    return null;
}

// Informa API helper function
function callInformaApi($endpoint, $method = 'GET', $params = [], $isFileUpload = false) {
    $url = INFORMA_API_BASE . $endpoint;
    $ch = curl_init();
    $headers = [
        'Authorization: Bearer ' . INFORMA_API_KEY,
        'Accept: application/vnd.informa.v1+json'
    ];
    if (!$isFileUpload) {
        $headers[] = 'Content-Type: application/json';
    }
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
    if ($method === 'POST') {
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $isFileUpload ? $params : json_encode($params));
    } elseif ($method === 'GET' && !empty($params)) {
        $url .= '?' . http_build_query($params);
        curl_setopt($ch, CURLOPT_URL, $url);
    }
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    if (DEBUG) {
        error_log("Informa API Request: $url");
        error_log("Informa API Response: $response");
    }
    if (curl_errno($ch)) {
        curl_close($ch);
        return ['status' => 'error', 'message' => 'API request failed: ' . curl_error($ch)];
    }
    curl_close($ch);
    $data = json_decode($response, true);
    if ($httpCode >= 400) {
        return ['status' => 'error', 'message' => $data['error']['message'] ?? 'Unknown API error', 'code' => $httpCode];
    }
    return $data;
}

// Verify identity with Informa (face comparison)
function verifyIdentityWithInforma($selfiePath, $idPath) {
    $selfieFullPath = __DIR__ . '/Uploads/Selfies/' . $selfiePath;
    $idFullPath = __DIR__ . '/Uploads/ID/' . $idPath;
    if (!file_exists($selfieFullPath) || !file_exists($idFullPath)) {
        return ['status' => 'error', 'message' => 'Required image files not found'];
    }
    $requestId = time() . uniqid();
    $cFile1 = new CURLFile($selfieFullPath, mime_content_type($selfieFullPath), 'photo_one');
    $cFile2 = new CURLFile($idFullPath, mime_content_type($idFullPath), 'photo_two');
    $postData = [
        'photo_one' => $cFile1,
        'photo_two' => $cFile2,
        'request_id' => $requestId
    ];
    return callInformaApi('/verify/compare-faces', 'POST', $postData, true);
}

// Log verification attempt
function logVerification($userId, $verificationType, $requestId, $status, $message = null) {
    $conn = getDbConnection();
    $stmt = $conn->prepare(
        "INSERT INTO verification_logs (user_id, verification_type, request_id, status, message) 
         VALUES (?, ?, ?, ?, ?)"
    );
    $stmt->bind_param("issss", $userId, $verificationType, $requestId, $status, $message);
    $stmt->execute();
    $stmt->close();
    $conn->close();
}

// Format phone number to required format (2547XXXXXXXX)
function formatPhoneNumber($phone) {
    $phone = preg_replace('/\D/', '', $phone);
    if (substr($phone, 0, 1) == '0') {
        $phone = '254' . substr($phone, 1);
    }
    if (strlen($phone) == 9) {
        $phone = '254' . $phone;
    }
    return $phone;
}

// Parse rounding value from string (e.g., "KSh 10" to 10)
function parseRoundingValue($roundingValue) {
    return (float)preg_replace('/[^0-9.]/', '', $roundingValue);
}

// Calculate round-up amount based on transaction amount and rounding value
function calculateRoundUpAmount($amount, $roundingValue) {
    $roundedAmount = ceil($amount / $roundingValue) * $roundingValue;
    return $roundedAmount - $amount;
}

// Get M-PESA access token
function getMpesaAccessToken() {
    $url = (MPESA_ENV == 'live') ?
        'https://api.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials' :
        'https://sandbox.safaricom.co.ke/oauth/v1/generate?grant_type=client_credentials';
    $credentials = base64_encode(MPESA_CONSUMER_KEY . ':' . MPESA_CONSUMER_SECRET);
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Authorization: Basic ' . $credentials,
        'Content-Type: application/json'
    ]);
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    if (curl_errno($ch)) {
        curl_close($ch);
        error_log("Failed to get M-PESA access token: " . curl_error($ch));
        return null;
    }
    curl_close($ch);
    $data = json_decode($response, true);
    if ($httpCode !== 200 || !isset($data['access_token'])) {
        error_log("Failed to get M-PESA access token: " . json_encode($data));
        return null;
    }
    return $data['access_token'];
}

// Initiate M-PESA STK Push
function initiateSTKPush($phoneNumber, $amount, $transactionId) {
    $accessToken = getMpesaAccessToken();
    if (!$accessToken) {
        return ['ResponseCode' => '1', 'ResponseDescription' => 'Failed to get access token'];
    }
    $url = (MPESA_ENV == 'live') ?
        'https://api.safaricom.co.ke/mpesa/stkpush/v1/processrequest' :
        'https://sandbox.safaricom.co.ke/mpesa/stkpush/v1/processrequest';
    $timestamp = date('YmdHis');
    $password = base64_encode(MPESA_SHORTCODE . MPESA_PASSKEY . $timestamp);
    $data = [
        'BusinessShortCode' => MPESA_SHORTCODE,
        'Password' => $password,
        'Timestamp' => $timestamp,
        'TransactionType' => 'CustomerPayBillOnline', // For STK Push
        'Amount' => (int)$amount,
        'PartyA' => $phoneNumber,
        'PartyB' => MPESA_SHORTCODE,
        'PhoneNumber' => $phoneNumber,
        'CallBackURL' => MPESA_CALLBACK_URL . '/mpesa-callback', // Updated to explicit callback
        'AccountReference' => 'SaveApp-' . $transactionId,
        'TransactionDesc' => 'Payment with savings'
    ];
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Authorization: Bearer ' . $accessToken,
        'Content-Type: application/json'
    ]);
    $response = curl_exec($ch);
    if (curl_errno($ch)) {
        curl_close($ch);
        return ['ResponseCode' => '1', 'ResponseDescription' => 'STK Push request failed: ' . curl_error($ch)];
    }
    curl_close($ch);
    $result = json_decode($response, true);
    if (DEBUG) {
        error_log("STK Push Response: " . json_encode($result));
    }
    return $result;
}

// Initiate M-PESA B2B Payment
function initiateB2BPayment($transactionId, $merchantPaybill, $merchantAccount, $amount, $transactionType) {
    $accessToken = getMpesaAccessToken();
    if (!$accessToken) {
        return [
            'status' => 'error',
            'message' => 'Failed to obtain M-PESA access token for B2B payment',
            'reference' => null
        ];
    }

    $url = (MPESA_ENV == 'live') ?
        'https://api.safaricom.co.ke/mpesa/b2b/v1/paymentrequest' :
        'https://sandbox.safaricom.co.ke/mpesa/b2b/v1/paymentrequest';

    $receiverPartyType = ($transactionType === 'buy_goods') ? 4 : 4; // 4 for both Paybill and Till Number in B2B

    $data = [
        'Initiator' => MPESA_B2B_INITIATOR_NAME,
        'SecurityCredential' => MPESA_B2B_SECURITY_CREDENTIAL,
        'CommandID' => ($transactionType === 'buy_goods') ? 'BusinessBuyGoods' : 'BusinessPayBill',
        'SenderIdentifierType' => 4, // Shortcode
        'ReceiverIdentifierType' => $receiverPartyType,
        'Amount' => (int)$amount,
        'PartyA' => MPESA_B2B_SHORTCODE,
        'PartyB' => $merchantPaybill,
        'AccountReference' => $merchantAccount ?: 'SaveApp-' . $transactionId,
        'Remarks' => 'Payment to merchant via SaveApp',
        'QueueTimeOutURL' => MPESA_CALLBACK_URL . '/b2b-timeout',
        'ResultURL' => MPESA_CALLBACK_URL . '/b2b-result/' . $transactionId
    ];

    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Authorization: Bearer ' . $accessToken,
        'Content-Type: application/json'
    ]);
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    if (curl_errno($ch)) {
        curl_close($ch);
        error_log("B2B Payment request failed: " . curl_error($ch));
        return [
            'status' => 'error',
            'message' => 'B2B Payment request failed: ' . curl_error($ch),
            'reference' => null
        ];
    }
    curl_close($ch);
    $result = json_decode($response, true);
    if (DEBUG) {
        error_log("B2B Payment Response: " . json_encode($result));
    }

    if ($httpCode >= 400 || !isset($result['ResponseCode']) || $result['ResponseCode'] != '0') {
        $errorMsg = $result['errorMessage'] ?? 'Unknown B2B API error';
        return [
            'status' => 'error',
            'message' => 'B2B Payment initiation failed: ' . $errorMsg,
            'reference' => null
        ];
    }

    return [
        'status' => 'success',
        'message' => 'B2B Payment initiated successfully',
        'reference' => $result['ConversationID'] ?? null,
        'originatorConversationID' => $result['OriginatorConversationID'] ?? null
    ];
}

// Forward payment to merchant
function forwardToMerchant($transactionId, $merchantPaybill, $merchantAccount, $amount) {
    $conn = getDbConnection();
    $stmt = $conn->prepare("SELECT transaction_type FROM transactions WHERE id = ?");
    $stmt->bind_param("i", $transactionId);
    $stmt->execute();
    $result = $stmt->get_result();
    $transaction = $result->fetch_assoc();
    $stmt->close();
    $conn->close();

    if (!$transaction) {
        return [
            'status' => 'error',
            'message' => 'Transaction not found',
            'reference' => null
        ];
    }

    $transactionType = $transaction['transaction_type'] ?? 'pay_bill';
    return initiateB2BPayment($transactionId, $merchantPaybill, $merchantAccount, $amount, $transactionType);
}

// Create required tables on script load
createRequiredTables();

// Routing extraction (replace existing $requestUri / $endpoint block with this)
$method = $_SERVER['REQUEST_METHOD'];
$rawPath = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$requestPath = trim($rawPath, '/');
$requestSegments = array_values(array_filter(explode('/', $requestPath)));

// Try to find the segment that contains the api script name (api.php) so we can read segments after it
$apiIndex = null;
foreach ($requestSegments as $i => $seg) {
    if (stripos($seg, 'api.php') !== false) {
        $apiIndex = $i;
        break;
    }
}

// endpoint = first segment after api.php, resource = second segment after [api.php](http://_vscodecontentref_/1)
if ($apiIndex !== null) {
    $endpoint = $requestSegments[$apiIndex + 1] ?? '';
    $resource = $requestSegments[$apiIndex + 2] ?? '';
} else {
    // fallback: common hosting setups (endpoint might be at index 1)
    $endpoint = $requestSegments[1] ?? $requestSegments[0] ?? '';
    $resource = $requestSegments[2] ?? '';
}

// Normalize endpoint (remove query-like parts)
$endpoint = trim($endpoint);
$resource = trim($resource);

if (defined('DEBUG') && DEBUG) {
    error_log("Routing -> method=$method, rawPath=$rawPath, segments=" . json_encode($requestSegments) . ", endpoint=$endpoint, resource=$resource");
}

// Basic routing
switch ($method . ' ' . $endpoint) {
    case 'POST register':
        if (isset($_SERVER['CONTENT_TYPE']) && strpos($_SERVER['CONTENT_TYPE'], 'multipart/form-data') !== false) {
            $data = $_POST;
            $selfie = isset($_FILES['selfie']) ? $_FILES['selfie'] : null;
            $idDocument = isset($_FILES['id_document']) ? $_FILES['id_document'] : null;
        } else {
            $data = json_decode(file_get_contents('php://input'), true) ?: [];
            $selfie = null;
            $idDocument = null;
        }

        $full_name = $data['full_name'] ?? '';
        $date_of_birth = $data['date_of_birth'] ?? '';
        $email = $data['email'] ?? '';
        $phone_number = $data['phone_number'] ?? '';
        $national_id = $data['national_id'] ?? '';
        $password = $data['password'] ?? '';
        $google_id_token = $data['google_id_token'] ?? '';
        $is_google_sign_in = filter_var($data['is_google_sign_in'] ?? false, FILTER_VALIDATE_BOOLEAN);

        if ($is_google_sign_in && !empty($google_id_token)) {
            if (empty($full_name) || empty($email) || empty($phone_number) || empty($national_id)) {
                http_response_code(400);
                echo json_encode(['status' => 'error', 'message' => 'Full name, email, phone number, and national ID required']);
                exit;
            }

            $tokenResult = verifyFirebaseIdToken($google_id_token);
            if ($tokenResult['status'] !== 'success') {
                http_response_code(401);
                echo json_encode(['status' => 'error', 'message' => $tokenResult['message']]);
                exit;
            }

            if ($tokenResult['email'] !== $email) {
                http_response_code(400);
                echo json_encode(['status' => 'error', 'message' => 'Email mismatch with Google account']);
                exit;
            }

            $selfiePath = $selfie ? uploadSelfie($selfie) : '';
            $idPath = $idDocument ? uploadIdDocument($idDocument) : '';
            $faceVerified = false;

            if ($selfiePath && $idPath) {
                $verifyResult = verifyIdentityWithInforma($selfiePath, $idPath);
                $faceVerified = ($verifyResult['status'] === 'success');
                $requestId = $verifyResult['request_id'] ?? '';
                $verifyStatus = $faceVerified ? 'success' : 'failed';
                $verifyMessage = $faceVerified ? 'Face verification successful' : ($verifyResult['error']['message'] ?? 'Face verification failed');
            } else {
                $requestId = null;
                $verifyStatus = 'pending';
                $verifyMessage = 'Selfie and ID document not provided';
            }

            $conn = getDbConnection();
            $stmt = $conn->prepare("SELECT id FROM users WHERE email = ? OR google_id = ?");
            $stmt->bind_param("ss", $email, $tokenResult['google_id']);
            $stmt->execute();
            $result = $stmt->get_result();
            if ($result->num_rows > 0) {
                http_response_code(400);
                echo json_encode(['status' => 'error', 'message' => 'User already exists']);
                $stmt->close();
                $conn->close();
                exit;
            }
            $stmt->close();

            $stmt = $conn->prepare(
                "INSERT INTO users (full_name, date_of_birth, email, phone_number, national_id, password, selfie_path, id_document_path, face_verified, google_id) 
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
            );
            $emptyPassword = '';
            $googleId = $tokenResult['google_id'];
            $stmt->bind_param("ssssssssis", $full_name, $date_of_birth, $email, $phone_number, $national_id, $emptyPassword, $selfiePath, $idPath, $faceVerified, $googleId);

            if ($stmt->execute()) {
                $userId = $conn->insert_id;
                if ($selfiePath && $idPath) {
                    logVerification($userId, 'face_comparison', $requestId, $verifyStatus, $verifyMessage);
                }
                echo json_encode([
                    'status' => 'success',
                    'message' => 'User registered successfully via Google Sign-In',
                    'userId' => $userId,
                    'faceVerified' => $faceVerified
                ]);
            } else {
                http_response_code(500);
                echo json_encode(['status' => 'error', 'message' => 'Registration failed: ' . $conn->error]);
            }
            $stmt->close();
            $conn->close();
        } else {
            if (empty($full_name) || empty($email) || empty($password) || empty($national_id) || empty($phone_number)) {
                http_response_code(400);
                echo json_encode(['status' => 'error', 'message' => 'Required fields missing']);
                exit;
            }
            if (!$selfie || !$idDocument) {
                http_response_code(400);
                echo json_encode(['status' => 'error', 'message' => 'Both selfie and ID document are required']);
                exit;
            }
            $selfiePath = uploadSelfie($selfie);
            $idPath = uploadIdDocument($idDocument);
            if (!$selfiePath || !$idPath) {
                http_response_code(500);
                echo json_encode(['status' => 'error', 'message' => 'Failed to upload images']);
                exit;
            }
            $phoneVerify = callInformaApi('/search/person/byPhone', 'GET', [
                'phone' => $phone_number,
                'associated_id' => $national_id
            ]);
            if (DEBUG) {
                error_log("Phone Verify Response: " . json_encode($phoneVerify));
            }
            if ($phoneVerify['status'] !== 'success') {
                $errorMessage = 'Unknown error';
                if (isset($phoneVerify['message'])) {
                    $errorMessage = is_array($phoneVerify['message']) ? implode(', ', $phoneVerify['message']) : $phoneVerify['message'];
                } elseif (isset($phoneVerify['error']['message'])) {
                    $errorMessage = is_array($phoneVerify['error']['message']) ? implode(', ', $phoneVerify['error']['message']) : $phoneVerify['error']['message'];
                }
                http_response_code(400);
                echo json_encode(['status' => 'error', 'message' => "Phone number verification failed: $errorMessage"]);
                exit;
            }
            $idVerify = callInformaApi('/search/person/byID', 'GET', [
                'id_number' => $national_id,
                'citizenship' => 'Kenyan'
            ]);
            if (DEBUG) {
                error_log("ID Verify Response: " . json_encode($idVerify));
            }
            if ($idVerify['status'] !== 'success') {
                $errorMessage = 'Unknown error';
                if (isset($idVerify['message'])) {
                    $errorMessage = is_array($idVerify['message']) ? implode(', ', $idVerify['message']) : $idVerify['message'];
                } elseif (isset($idVerify['error']['message'])) {
                    $errorMessage = is_array($idVerify['error']['message']) ? implode(', ', $idVerify['error']['message']) : $idVerify['error']['message'];
                }
                http_response_code(400);
                echo json_encode(['status' => 'error', 'message' => "ID verification failed: $errorMessage"]);
                exit;
            }
            $verifyResult = verifyIdentityWithInforma($selfiePath, $idPath);
            $faceVerified = ($verifyResult['status'] === 'success');
            if (DEBUG) {
                error_log("Face Verify Response: " . json_encode($verifyResult));
            }
            $requestId = isset($verifyResult['request_id']) ? $verifyResult['request_id'] : null;
            $verifyStatus = $faceVerified ? 'success' : 'failed';
            $verifyMessage = $faceVerified ? 'Face verification successful' : 
                            (isset($verifyResult['error']['message']) ? $verifyResult['error']['message'] : 'Face verification failed');
            $hashedPassword = password_hash($password, PASSWORD_DEFAULT);
            $conn = getDbConnection();
            $stmt = $conn->prepare(
                "INSERT INTO users (full_name, date_of_birth, email, phone_number, national_id, password, selfie_path, id_document_path, face_verified) 
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
            );
            $stmt->bind_param("ssssssssi", $full_name, $date_of_birth, $email, $phone_number, $national_id, $hashedPassword, $selfiePath, $idPath, $faceVerified);
            if ($stmt->execute()) {
                $userId = $conn->insert_id;
                logVerification($userId, 'face_comparison', $requestId, $verifyStatus, $verifyMessage);
                if ($faceVerified) {
                    echo json_encode([
                        'status' => 'success',
                        'message' => 'User registered successfully with verified identity',
                        'userId' => $userId
                    ]);
                } else {
                    echo json_encode([
                        'status' => 'warning',
                        'message' => 'User registered but identity verification failed: ' . $verifyMessage,
                        'userId' => $userId
                    ]);
                }
            } else {
                http_response_code(500);
                echo json_encode(['status' => 'error', 'message' => 'Registration failed: ' . $conn->error]);
            }
            $stmt->close();
            $conn->close();
        }
        break;
    case 'POST forgot-password':
        $data = json_decode(file_get_contents('php://input'), true) ?: $_POST;
        $email = $data['email'] ?? '';

        if (empty($email)) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Email is required']);
            exit;
        }

        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT id, google_id FROM users WHERE email = ?");
        $stmt->bind_param("s", $email);
        $stmt->execute();
        $result = $stmt->get_result();
        $user = $result->fetch_assoc();
        $stmt->close();

        if (!$user) {
            http_response_code(404);
            echo json_encode(['status' => 'error', 'message' => 'User not found']);
            $conn->close();
            exit;
        }

        if (!empty($user['google_id'])) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'This account uses Google Sign-In. Password reset is not applicable.']);
            $conn->close();
            exit;
        }

        // Generate a unique token
        $token = bin2hex(random_bytes(32));
        $expiresAt = date('Y-m-d H:i:s', strtotime('+1 hour')); // Token expires in 1 hour

        // Store the token
        $stmt = $conn->prepare("INSERT INTO password_reset_tokens (user_id, token, expires_at) VALUES (?, ?, ?)");
        $stmt->bind_param("iss", $user['id'], $token, $expiresAt);
        if ($stmt->execute()) {
            $emailResult = sendPasswordResetEmail($email, $token);
            if ($emailResult['status'] === 'success') {
                echo json_encode(['status' => 'success', 'message' => 'Password reset link sent to your email']);
            } else {
                http_response_code(500);
                echo json_encode(['status' => 'error', 'message' => $emailResult['message']]);
            }
        } else {
            http_response_code(500);
            echo json_encode(['status' => 'error', 'message' => 'Failed to generate reset token: ' . $conn->error]);
        }
        $stmt->close();
        $conn->close();
        break;

    case 'POST reset_password':
        $data = json_decode(file_get_contents('php://input'), true) ?: $_POST;
        $token = $data['token'] ?? '';
        $new_password = $data['new_password'] ?? '';

        if (empty($token) || empty($new_password)) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Token and new password are required']);
            exit;
        }

        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT user_id, expires_at FROM password_reset_tokens WHERE token = ?");
        $stmt->bind_param("s", $token);
        $stmt->execute();
        $result = $stmt->get_result();
        $tokenData = $result->fetch_assoc();
        $stmt->close();

        if (!$tokenData) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Invalid or expired token']);
            $conn->close();
            exit;
        }

        if (strtotime($tokenData['expires_at']) < time()) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Token has expired']);
            $conn->close();
            exit;
        }

        $userId = $tokenData['user_id'];
        $hashedPassword = password_hash($new_password, PASSWORD_DEFAULT);

        $stmt = $conn->prepare("UPDATE users SET password = ? WHERE id = ?");
        $stmt->bind_param("si", $hashedPassword, $userId);
        if ($stmt->execute()) {
            // Delete the used token
            $stmt = $conn->prepare("DELETE FROM password_reset_tokens WHERE token = ?");
            $stmt->bind_param("s", $token);
            $stmt->execute();
            $stmt->close();
            echo json_encode(['status' => 'success', 'message' => 'Password reset successfully']);
        } else {
            http_response_code(500);
            echo json_encode(['status' => 'error', 'message' => 'Failed to reset password: ' . $conn->error]);
        }
        $stmt->close();
        $conn->close();
        break;
        case 'GET last-payment':
    $userId = $requestUri[2] ?? '';
    if (empty($userId) || !is_numeric($userId)) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'Valid userId required']);
        exit;
    }
    $conn = getDbConnection();
    $stmt = $conn->prepare(
        "SELECT id, total_amount, merchant_paybill, merchant_account, status, created_at, transaction_type 
         FROM transactions 
         WHERE user_id = ? AND status = 'completed' 
         ORDER BY created_at DESC 
         LIMIT 3"
    );
    $stmt->bind_param("i", $userId);
    $stmt->execute();
    $result = $stmt->get_result();
    $transactions = [];
    while ($row = $result->fetch_assoc()) {
        $transactions[] = [
            'id' => (int)$row['id'],
            'business_name' => $row['merchant_account'] ?: $row['merchant_paybill'],
            'transaction_status' => $row['status'],
            'total_amount' => (float)$row['total_amount'],
            'type' => $row['transaction_type'],
            'created_at' => $row['created_at']
        ];
    }
    if (empty($transactions)) {
        echo json_encode(['status' => 'success', 'message' => 'No completed transactions found', 'data' => []]);
    } else {
        echo json_encode(['status' => 'success', 'data' => $transactions]);
    }
    $stmt->close();
    $conn->close();
    break;
    case 'POST login':
        $data = json_decode(file_get_contents('php://input'), true) ?: $_POST;
        $email = $data['email'] ?? '';
        $password = $data['password'] ?? '';
        $google_id_token = $data['google_id_token'] ?? '';
        $is_google_sign_in = filter_var($data['is_google_sign_in'] ?? false, FILTER_VALIDATE_BOOLEAN);

        if ($is_google_sign_in && !empty($google_id_token)) {
            if (empty($email)) {
                http_response_code(400);
                echo json_encode(['status' => 'error', 'message' => 'Email required']);
                exit;
            }

            $tokenResult = verifyFirebaseIdToken($google_id_token);
            if ($tokenResult['status'] !== 'success') {
                http_response_code(401);
                echo json_encode(['status' => 'error', 'message' => $tokenResult['message']]);
                exit;
            }

            if ($tokenResult['email'] !== $email) {
                http_response_code(400);
                echo json_encode(['status' => 'error', 'message' => 'Email mismatch with Google account']);
                exit;
            }

            $conn = getDbConnection();
            $stmt = $conn->prepare("SELECT id, face_verified FROM users WHERE email = ? OR google_id = ?");
            $googleId = $tokenResult['google_id'];
            $stmt->bind_param("ss", $email, $googleId);
            $stmt->execute();
            $result = $stmt->get_result();
            $user = $result->fetch_assoc();
            $stmt->close();
            $conn->close();

            if (!$user) {
                http_response_code(404);
                echo json_encode(['status' => 'error', 'message' => 'User not found']);
                exit;
            }

            echo json_encode([
                'status' => 'success',
                'message' => 'Login successful via Google Sign-In',
                'userId' => $user['id'],
                'faceVerified' => $user['face_verified']
            ]);
        } else {
            if (empty($email) || empty($password)) {
                http_response_code(400);
                echo json_encode(['status' => 'error', 'message' => 'Email and password required']);
                exit;
            }
            $conn = getDbConnection();
            $stmt = $conn->prepare("SELECT id, password, face_verified FROM users WHERE email = ?");
            $stmt->bind_param("s", $email);
            $stmt->execute();
            $result = $stmt->get_result();
            $user = $result->fetch_assoc();
            if (!$user) {
                http_response_code(401);
                echo json_encode(['status' => 'error', 'message' => 'User not found']);
            } elseif (password_verify($password, $user['password'])) {
                if ($user['face_verified']) {
                    echo json_encode([
                        'status' => 'success',
                        'message' => 'Login successful',
                        'userId' => $user['id'],
                        'faceVerified' => true
                    ]);
                } else {
                    echo json_encode([
                        'status' => 'warning',
                        'message' => 'Login successful but identity not verified',
                        'userId' => $user['id'],
                        'faceVerified' => false
                    ]);
                }
            } else {
                http_response_code(401);
                echo json_encode(['status' => 'error', 'message' => 'Invalid password']);
            }
            $stmt->close();
            $conn->close();
        }
        break;

    case 'GET user-savings':
        $userId = $requestUri[2] ?? $_GET['user_id'] ?? '';
        if (empty($userId) || !is_numeric($userId)) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Valid user_id required']);
            exit;
        }

        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT id, full_name, email FROM users WHERE id = ?");
        $stmt->bind_param("i", $userId);
        $stmt->execute();
        $result = $stmt->get_result();
        $user = $result->fetch_assoc();
        $stmt->close();

        if (!$user) {
            http_response_code(404);
            echo json_encode(['status' => 'error', 'message' => 'User not found']);
            $conn->close();
            exit;
        }

        $stmt = $conn->prepare("
            SELECT COALESCE(SUM(savings_amount), 0) as total_savings
            FROM transactions
            WHERE user_id = ?
        ");
        $stmt->bind_param("i", $userId);
        $stmt->execute();
        $result = $stmt->get_result();
        $row = $result->fetch_assoc();
        $stmt->close();
        $conn->close();

        $totalSavings = (float)$row['total_savings'];

        echo json_encode([
            'status' => 'success',
            'message' => $totalSavings > 0 ? 'Savings retrieved successfully' : 'No savings found',
            'data' => [
                'user_id' => (int)$userId,
                'full_name' => $user['full_name'],
                'email' => $user['email'],
                'total_savings' => $totalSavings
            ]
        ]);
        break;

    case 'POST verify-face':
        $userId = $requestUri[2] ?? '';
        if (empty($userId) || !is_numeric($userId)) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Valid userId required']);
            exit;
        }
        if (!isset($_FILES['selfie'])) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Selfie required for verification']);
            exit;
        }
        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT id_document_path FROM users WHERE id = ?");
        $stmt->bind_param("i", $userId);
        $stmt->execute();
        $result = $stmt->get_result();
        $user = $result->fetch_assoc();
        if (!$user) {
            http_response_code(404);
            echo json_encode(['status' => 'error', 'message' => 'User not found']);
            $stmt->close();
            $conn->close();
            exit;
        }
        if (empty($user['id_document_path'])) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'User does not have an ID document uploaded']);
            $stmt->close();
            $conn->close();
            exit;
        }
        $selfiePath = uploadSelfie($_FILES['selfie']);
        if (!$selfiePath) {
            http_response_code(500);
            echo json_encode(['status' => 'error', 'message' => 'Failed to upload selfie']);
            $stmt->close();
            $conn->close();
            exit;
        }
        $verifyResult = verifyIdentityWithInforma($selfiePath, $user['id_document_path']);
        $faceVerified = ($verifyResult['status'] === 'success');
        $requestId = isset($verifyResult['request_id']) ? $verifyResult['request_id'] : null;
        $verifyStatus = $faceVerified ? 'success' : 'failed';
        $verifyMessage = $faceVerified ? 'Face verification successful' : 
                        (isset($verifyResult['error']['message']) ? $verifyResult['error']['message'] : 'Face verification failed');
        logVerification($userId, 'face_comparison', $requestId, $verifyStatus, $verifyMessage);
        $stmt = $conn->prepare("UPDATE users SET face_verified = ?, selfie_path = ? WHERE id = ?");
        $stmt->bind_param("isi", $faceVerified, $selfiePath, $userId);
        $stmt->execute();
        if ($faceVerified) {
            echo json_encode([
                'status' => 'success',
                'message' => 'Face verification successful',
                'faceVerified' => true
            ]);
        } else {
            echo json_encode([
                'status' => 'error',
                'message' => 'Face verification failed: ' . $verifyMessage,
                'faceVerified' => false
            ]);
        }
        $stmt->close();
        $conn->close();
        break;

    case 'GET transactions':
        $userId = $requestUri[2] ?? '';
        if (empty($userId)) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'userId required']);
            exit;
        }
        $conn = getDbConnection();
        $stmt = $conn->prepare(
            "SELECT id, total_amount, merchant_paybill, merchant_account, status, created_at, transaction_type 
             FROM transactions 
             WHERE user_id = ? 
             ORDER BY created_at DESC"
        );
        $stmt->bind_param("i", $userId);
        $stmt->execute();
        $result = $stmt->get_result();
        $transactions = [];
        while ($row = $result->fetch_assoc()) {
            $transactions[] = [
                'id' => (int)$row['id'],
                'business_name' => $row['merchant_account'] ?: $row['merchant_paybill'],
                'transaction_status' => $row['status'],
                'total_amount' => (float)$row['total_amount'],
                'type' => $row['transaction_type'],
                'created_at' => $row['created_at']
            ];
        }
        if (empty($transactions)) {
            echo json_encode(['status' => 'success', 'message' => 'No transactions found', 'data' => []]);
        } else {
            echo json_encode(['status' => 'success', 'data' => $transactions]);
        }
        $stmt->close();
        $conn->close();
        break;
case 'POST loan/request':
        $data = json_decode(file_get_contents('php://input'), true) ?: $_POST;
        $user_id = $data['user_id'] ?? '';
        $amount = (float)($data['amount'] ?? 0);
        $tenure = (int)($data['tenure_months'] ?? 0);

        if (empty($user_id) || $amount <= 0 || $tenure <= 0) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'user_id, amount, and tenure_months are required']);
            break;
        }

        $conn = getDbConnection();

        // Verify user exists
        $stmt = $conn->prepare("SELECT id FROM users WHERE id = ?");
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        if ($stmt->get_result()->num_rows === 0) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'User not found']);
            $stmt->close();
            $conn->close();
            break;
        }
        $stmt->close();

        // Get total completed savings for eligibility
        $stmt = $conn->prepare("SELECT COALESCE(SUM(savings_amount), 0) AS total_savings FROM transactions WHERE user_id = ? AND status = 'completed'");
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        $totalSavings = (float)$stmt->get_result()->fetch_assoc()['total_savings'];
        $stmt->close();

        // Max loan = 2× savings
        if ($amount > $totalSavings * 2) {
            http_response_code(400);
            echo json_encode([
                'status' => 'error',
                'message' => 'Loan amount exceeds limit',
                'max_allowed' => $totalSavings * 2,
                'your_savings' => $totalSavings
            ]);
            $conn->close();
            break;
        }

        // Default interest rate
        $interest_rate = 12.00; // percent per year

        $stmt = $conn->prepare("
            INSERT INTO loans (user_id, amount_requested, interest_rate, tenure_months, status) 
            VALUES (?, ?, ?, ?, 'pending')
        ");
        // types: i (user_id), d (amount), d (interest_rate), i (tenure)
        $stmt->bind_param("iddi", $user_id, $amount, $interest_rate, $tenure);

        if ($stmt->execute()) {
            $loan_id = $conn->insert_id;
            echo json_encode([
                'status' => 'success',
                'message' => 'Loan application submitted',
                'loan_id' => $loan_id,
                'max_loan_limit' => $totalSavings * 2
            ]);
        } else {
            http_response_code(500);
            echo json_encode(['status' => 'error', 'message' => 'Failed to save loan request: ' . $conn->error]);
        }
        $stmt->close();
        $conn->close();
        break;

    case 'GET user-loans':
        // $resource holds the user id (third segment)
        $userId = $resource;
        if (empty($userId) || !is_numeric($userId)) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Valid userId required']);
            break;
        }

        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT id, user_id, amount_requested, amount_approved, interest_rate, tenure_months, status, applied_at FROM loans WHERE user_id = ? ORDER BY applied_at DESC");
        $stmt->bind_param("i", $userId);
        $stmt->execute();
        $res = $stmt->get_result();
        $loans = [];
        while ($r = $res->fetch_assoc()) {
            $r['amount_requested'] = (float)$r['amount_requested'];
            $r['amount_approved'] = isset($r['amount_approved']) ? (float)$r['amount_approved'] : null;
            $loans[] = $r;
        }
        echo json_encode(['status' => 'success', 'data' => $loans]);
        $stmt->close();
        $conn->close();
        break;

    case 'GET loan-details':
        $loanId = $resource;
        if (empty($loanId) || !is_numeric($loanId)) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Valid loanId required']);
            break;
        }
        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT l.*, u.full_name, u.phone_number FROM loans l JOIN users u ON u.id = l.user_id WHERE l.id = ?");
        $stmt->bind_param("i", $loanId);
        $stmt->execute();
        $loan = $stmt->get_result()->fetch_assoc();
        if (!$loan) {
            http_response_code(404);
            echo json_encode(['status' => 'error', 'message' => 'Loan not found']);
        } else {
            $loan['amount_requested'] = (float)$loan['amount_requested'];
            $loan['amount_approved'] = isset($loan['amount_approved']) ? (float)$loan['amount_approved'] : null;
            echo json_encode(['status' => 'success', 'data' => $loan]);
        }
        $stmt->close();
        $conn->close();
        break;

    case 'POST loan-repayment':
        $data = json_decode(file_get_contents('php://input'), true) ?: $_POST;
        $loan_id = $data['loan_id'] ?? '';
        $amount = (float)($data['amount'] ?? 0);
        $phone = formatPhoneNumber($data['phone_number'] ?? '');

        if (empty($loan_id) || $amount <= 0 || empty($phone)) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Invalid input']);
            break;
        }

        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT status, amount_approved FROM loans WHERE id = ?");
        $stmt->bind_param("i", $loan_id);
        $stmt->execute();
        $loan = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        if (!$loan || $loan['status'] !== 'disbursed') {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Loan not disbursed or not found']);
            $conn->close();
            break;
        }

        $stmt = $conn->prepare("INSERT INTO loan_repayments (loan_id, amount) VALUES (?, ?)");
        $stmt->bind_param("id", $loan_id, $amount);
        $stmt->execute();
        $repayId = $conn->insert_id;
        $stmt->close();

        $stk = initiateSTKPush($phone, $amount, "REPAY-$repayId");
        if (($stk['ResponseCode'] ?? '') === '0') {
            $chk = $stk['CheckoutRequestID'];
            $stmt = $conn->prepare("UPDATE loan_repayments SET checkout_request_id = ? WHERE id = ?");
            $stmt->bind_param("si", $chk, $repayId);
            $stmt->execute();
            $stmt->close();
            echo json_encode(['status' => 'success', 'repayment_id' => $repayId, 'checkout' => $chk]);
        } else {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => $stk['ResponseDescription'] ?? 'STK failed']);
        }
        $conn->close();
        break;

    case 'POST loan-callback':
        $payload = json_decode(file_get_contents('php://input'), true);
        $code = $payload['Body']['stkCallback']['ResultCode'] ?? null;
        $chk = $payload['Body']['stkCallback']['CheckoutRequestID'] ?? '';
        $receipt = '';
        foreach (($payload['Body']['stkCallback']['CallbackMetadata']['Item'] ?? []) as $i) {
            if ($i['Name'] === 'MpesaReceiptNumber') $receipt = $i['Value'];
        }

        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT id, loan_id, amount FROM loan_repayments WHERE checkout_request_id = ?");
        $stmt->bind_param("s", $chk);
        $stmt->execute();
        $repay = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$repay) {
            http_response_code(404);
            echo json_encode(['status' => 'error', 'message' => 'Repayment record not found']);
            $conn->close();
            break;
        }

        if ($code == 0) {
            $stmt = $conn->prepare("UPDATE loan_repayments SET mpesa_receipt = ?, paid_at = NOW() WHERE id = ?");
            $stmt->bind_param("si", $receipt, $repay['id']);
            $stmt->execute();
            $stmt->close();

            $stmt = $conn->prepare("UPDATE loans SET amount_approved = amount_approved - ? WHERE id = ? AND amount_approved >= ?");
            $stmt->bind_param("ddi", $repay['amount'], $repay['loan_id'], $repay['amount']);
            $stmt->execute();
            $stmt->close();

            // mark loan repaid if amount_approved <= 0
            $stmt = $conn->prepare("SELECT amount_approved FROM loans WHERE id = ?");
            $stmt->bind_param("i", $repay['loan_id']);
            $stmt->execute();
            $rem = (float)$stmt->get_result()->fetch_assoc()['amount_approved'] ?? 0;
            $stmt->close();

            if ($rem <= 0) {
                $stmt = $conn->prepare("UPDATE loans SET status = 'repaid', amount_approved = 0 WHERE id = ?");
                $stmt->bind_param("i", $repay['loan_id']);
                $stmt->execute();
                $stmt->close();
            }

            echo json_encode(['status' => 'success', 'message' => 'Repayment recorded']);
        } else {
            echo json_encode(['status' => 'error', 'message' => 'Payment failed']);
        }
        $conn->close();
        break;

    case 'GET loan-status':
        $loanId = $resource;
        if (!is_numeric($loanId)) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Valid loanId']);
            break;
        }
        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT status, amount_requested, amount_approved FROM loans WHERE id = ?");
        $stmt->bind_param("i", $loanId);
        $stmt->execute();
        $loan = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        $conn->close();
        if (!$loan) {
            http_response_code(404);
            echo json_encode(['status' => 'error', 'message' => 'Loan not found']);
            break;
        }
        $loan['amount_approved'] = isset($loan['amount_approved']) ? (float)$loan['amount_approved'] : null;
        echo json_encode(['status' => 'success', 'data' => $loan]);
        break;

    case 'POST mpesa-usage':
        $data = json_decode(file_get_contents('php://input'), true) ?: $_POST;
        $user_id = $data['user_id'] ?? '';
        $total_spent = $data['total_spent'] ?? 0;
        $weekly_avg = $data['weekly_avg'] ?? 0;
        $monthly_avg = $data['monthly_avg'] ?? 0;
        $yearly_avg = $data['yearly_avg'] ?? 0;
        $usage_band = $data['usage_band'] ?? '';
        $transaction_count = $data['transaction_count'] ?? 0;
        $last_updated = $data['last_updated'] ?? date('c');
        if (empty($user_id)) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'user_id is required']);
            exit;
        }
        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT phone_number FROM users WHERE id = ?");
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        $result = $stmt->get_result();
        $user = $result->fetch_assoc();
        $stmt->close();
        if (!$user) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Invalid user_id: User does not exist']);
            $conn->close();
            exit;
        }
        $mpesaVerify = callInformaApi('/verify/mpesa-phone-number', 'GET', [
            'phone' => substr($user['phone_number'], -10)
        ]);
        if ($mpesaVerify['status'] !== 'success' || $mpesaVerify['is_mpesa_number'] !== true) {
            $errorMessage = isset($mpesaVerify['error']['message']) ? (is_array($mpesaVerify['error']['message']) ? implode(', ', $mpesaVerify['error']['message']) : $mpesaVerify['error']['message']) : 'Phone number is not an M-Pesa number';
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => "M-Pesa verification failed: $errorMessage"]);
            $conn->close();
            exit;
        }
        $stmt = $conn->prepare(
            "INSERT INTO mpesa_usage (user_id, total_spent, weekly_avg, monthly_avg, yearly_avg, usage_band, transaction_count, last_updated) 
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE 
            total_spent = ?, weekly_avg = ?, monthly_avg = ?, yearly_avg = ?, usage_band = ?, transaction_count = ?, last_updated = ?"
        );
        $stmt->bind_param(
            "iddddssiddddssi",
            $user_id, $total_spent, $weekly_avg, $monthly_avg, $yearly_avg, $usage_band, $transaction_count, $last_updated,
            $total_spent, $weekly_avg, $monthly_avg, $yearly_avg, $usage_band, $transaction_count, $last_updated
        );
        if ($stmt->execute()) {
            echo json_encode(['status' => 'success', 'message' => 'M-Pesa usage data saved']);
        } else {
            http_response_code(500);
            echo json_encode(['status' => 'error', 'message' => 'Failed to save M-Pesa data: ' . $conn->error]);
        }
        $stmt->close();
        $conn->close();
        break;

    case 'GET user':
        $userId = $requestUri[2] ?? '';
        if (empty($userId)) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'userId required']);
            exit;
        }
        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT full_name, selfie_path FROM users WHERE id = ?");
        $stmt->bind_param("i", $userId);
        $stmt->execute();
        $result = $stmt->get_result();
        $user = $result->fetch_assoc();
        if (!$user) {
            http_response_code(404);
            echo json_encode(['status' => 'error', 'message' => 'User not found']);
        } else {
            $selfiePath = $user['selfie_path'] ? str_replace('Uploads/Selfies/', '', $user['selfie_path']) : '';
            echo json_encode([
                'status' => 'success',
                'name' => $user['full_name'],
                'selfie_path' => $selfiePath
            ]);
        }
        $stmt->close();
        $conn->close();
        break;
case 'GET last-payment':
    $userId = $requestUri[2] ?? '';
    if (empty($userId)) {
        http_response_code(400);
        echo json_encode(['status' => 'error', 'message' => 'userId required']);
        exit;
    }
    $conn = getDbConnection();
    $stmt = $conn->prepare(
        "SELECT id, total_amount, merchant_paybill, merchant_account, status, created_at, transaction_type 
         FROM transactions 
         WHERE user_id = ? AND status = 'completed' 
         ORDER BY created_at DESC 
         LIMIT 3"
    );
    $stmt->bind_param("i", $userId);
    $stmt->execute();
    $result = $stmt->get_result();
    $transactions = [];
    while ($row = $result->fetch_assoc()) {
        $transactions[] = [
            'id' => (int)$row['id'],
            'business_name' => $row['merchant_account'] ?: $row['merchant_paybill'],
            'till_number' => $row['merchant_paybill'],
            'transaction_status' => $row['status'],
            'total_amount' => (float)$row['total_amount'],
            'type' => $row['transaction_type'],
            'created_at' => $row['created_at']
        ];
    }
    echo json_encode([
        'status' => 'success',
        'message' => empty($transactions) ? 'No transactions found' : 'Transactions retrieved successfully',
        'data' => $transactions
    ]);
    $stmt->close();
    $conn->close();
    break;
    case 'GET mpesa-usage':
        $userId = $requestUri[2] ?? '';
        if (empty($userId)) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'userId required']);
            exit;
        }
        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT * FROM mpesa_usage WHERE user_id = ?");
        $stmt->bind_param("i", $userId);
        $stmt->execute();
        $result = $stmt->get_result();
        $data = $result->fetch_assoc();
        if (!$data) {
            http_response_code(404);
            echo json_encode(['status' => 'error', 'message' => 'No M-Pesa data found']);
        } else {
            echo json_encode([
                'total_spent' => (float)$data['total_spent'],
                'weekly_avg' => (float)$data['weekly_avg'],
                'monthly_avg' => (float)$data['monthly_avg'],
                'yearly_avg' => (float)$data['yearly_avg'],
                'usage_band' => $data['usage_band'],
                'transaction_count' => (int)$data['transaction_count'],
                'last_updated' => $data['last_updated']
            ]);
        }
        $stmt->close();
        $conn->close();
        break;

    case 'GET roundup-settings':
        $userId = $requestUri[2] ?? '';
        if (empty($userId)) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'userId required']);
            exit;
        }
        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT * FROM roundup_settings WHERE user_id = ?");
        $stmt->bind_param("i", $userId);
        $stmt->execute();
        $result = $stmt->get_result();
        $data = $result->fetch_assoc();
        if (!$data) {
            echo json_encode([
                'is_enabled' => false,
                'pay_bill_round_up' => false,
                'buy_goods_round_up' => false,
                'retail_purchases_round_up' => false,
                'rounding_value' => 'KSh 1',
                'max_round_up' => null,
                'monthly_cap' => null
            ]);
        } else {
            echo json_encode($data);
        }
        $stmt->close();
        $conn->close();
        break;

    case 'GET user-details':
        $userId = $requestUri[2] ?? '';
        if (empty($userId)) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'userId required']);
            exit;
        }
        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT full_name, email, phone_number, date_of_birth, selfie_path FROM users WHERE id = ?");
        $stmt->bind_param("i", $userId);
        $stmt->execute();
        $result = $stmt->get_result();
        $user = $result->fetch_assoc();
        if (!$user) {
            http_response_code(404);
            echo json_encode(['status' => 'error', 'message' => 'User not found']);
        } else {
            $selfieUrl = $user['selfie_path'] ? 'https://apis.gnmprimesource.co.ke/apis/selfie/' . $user['selfie_path'] : null;
            echo json_encode([
                'status' => 'success',
                'data' => [
                    'full_name' => $user['full_name'],
                    'email' => $user['email'],
                    'phone_number' => $user['phone_number'],
                    'date_of_birth' => $user['date_of_birth'],
                    'selfie_path' => $selfieUrl
                ]
            ]);
        }
        $stmt->close();
        $conn->close();
        break;

    case 'POST upload-profile-picture':
        $userId = $requestUri[2] ?? '';
        if (empty($userId)) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'userId required']);
            exit;
        }
        if (!isset($_FILES['profile_picture'])) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Profile picture file required']);
            exit;
        }
        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT id FROM users WHERE id = ?");
        $stmt->bind_param("i", $userId);
        $stmt->execute();
        $result = $stmt->get_result();
        if ($result->num_rows === 0) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Invalid user_id: User does not exist']);
            $stmt->close();
            $conn->close();
            exit;
        }
        $stmt->close();
        $selfiePath = uploadSelfie($_FILES['profile_picture']);
        if (!$selfiePath) {
            http_response_code(500);
            echo json_encode(['status' => 'error', 'message' => 'Failed to upload profile picture']);
            $conn->close();
            exit;
        }
        $stmt = $conn->prepare("UPDATE users SET selfie_path = ? WHERE id = ?");
        $stmt->bind_param("si", $selfiePath, $userId);
        if ($stmt->execute()) {
            echo json_encode([
                'status' => 'success',
                'message' => 'Profile picture updated successfully',
                'selfie_path' => 'https://apis.gnmprimesource.co.ke/apis/selfie/' . $selfiePath
            ]);
        } else {
            http_response_code(500);
            echo json_encode(['status' => 'error', 'message' => 'Failed to update profile picture: ' . $conn->error]);
        }
        $stmt->close();
        $conn->close();
        break;

    case 'POST roundup-settings':
        $data = json_decode(file_get_contents('php://input'), true) ?: $_POST;
        $user_id = $data['user_id'] ?? '';
        $is_enabled = $data['is_enabled'] ?? 0;
        $pay_bill_round_up = $data['pay_bill_round_up'] ?? 0;
        $buy_goods_round_up = $data['buy_goods_round_up'] ?? 0;
        $retail_purchases_round_up = $data['retail_purchases_round_up'] ?? 0;
        $rounding_value = $data['rounding_value'] ?? 'KSh 1';
        $max_round_up = $data['max_round_up'] ?? null;
        $monthly_cap = $data['monthly_cap'] ?? null;
        if (empty($user_id)) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'user_id required']);
            exit;
        }
        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT id FROM users WHERE id = ?");
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        $result = $stmt->get_result();
        if ($result->num_rows === 0) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Invalid user_id: User does not exist']);
            $stmt->close();
            $conn->close();
            exit;
        }
        $stmt->close();
        $stmt = $conn->prepare(
            "INSERT INTO roundup_settings (user_id, is_enabled, pay_bill_round_up, buy_goods_round_up, retail_purchases_round_up, rounding_value, max_round_up, monthly_cap) 
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE 
             is_enabled = ?, pay_bill_round_up = ?, buy_goods_round_up = ?, retail_purchases_round_up = ?, rounding_value = ?, max_round_up = ?, monthly_cap = ?"
        );
        $stmt->bind_param(
            "iiiiisddiiiiidd",
            $user_id, $is_enabled, $pay_bill_round_up, $buy_goods_round_up, $retail_purchases_round_up, $rounding_value, $max_round_up, $monthly_cap,
            $is_enabled, $pay_bill_round_up, $buy_goods_round_up, $retail_purchases_round_up, $rounding_value, $max_round_up, $monthly_cap
        );
        if ($stmt->execute()) {
            echo json_encode(['status' => 'success', 'message' => 'Round-Up settings saved']);
        } else {
            http_response_code(500);
            echo json_encode(['status' => 'error', 'message' => 'Failed to save settings: ' . $conn->error]);
        }
        $stmt->close();
        $conn->close();
        break;

    case 'POST buy-goods-payment':
        $data = json_decode(file_get_contents('php://input'), true) ?: $_POST;
        $user_id = $data['user_id'] ?? '';
        $till_number = $data['till_number'] ?? '';
        $account_number = $data['account_number'] ?? '';
        $amount = (float)($data['amount'] ?? 0.0);
        $round_up_savings = (float)($data['round_up_savings'] ?? 0.0);
        $total_amount = (float)($data['total_amount'] ?? $amount);
        $transaction_type = $data['transaction_type'] ?? 'buy_goods';
        $timestamp = $data['timestamp'] ?? date('c');

        if (empty($user_id) || empty($till_number) || empty($amount) || empty($transaction_type)) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'user_id, till_number, amount, and transaction_type required']);
            exit;
        }
        if ($transaction_type === 'pay_bill' && empty($account_number)) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'account_number required for Pay Bill']);
            exit;
        }

        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT phone_number FROM users WHERE id = ?");
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        $result = $stmt->get_result();
        if ($result->num_rows === 0) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Invalid user_id: User does not exist']);
            $stmt->close();
            $conn->close();
            exit;
        }
        $user = $result->fetch_assoc();
        $phone_number = $user['phone_number'];
        $stmt->close();

        $service_charge = 0.0; // Adjust as needed
        $merchant_amount = $amount - $service_charge - $round_up_savings;
        $merchant_paybill = $till_number;
        $merchant_account = $account_number;

        $stmt = $conn->prepare(
            "INSERT INTO transactions (user_id, phone_number, total_amount, service_charge, savings_amount, merchant_amount, merchant_paybill, merchant_account, status, merchant_status, created_at, transaction_type) 
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending', 'pending', ?, ?)"
        );
        $stmt->bind_param(
            "isddddssss",
            $user_id,
            $phone_number,
            $total_amount,
            $service_charge,
            $round_up_savings,
            $merchant_amount,
            $merchant_paybill,
            $merchant_account,
            $timestamp,
            $transaction_type
        );

        if ($stmt->execute()) {
            $transaction_id = $conn->insert_id;
            $stkPushResponse = initiateSTKPush($phone_number, $total_amount, $transaction_id);
            if (isset($stkPushResponse['ResponseCode']) && $stkPushResponse['ResponseCode'] == '0') {
                $checkoutRequestId = $stkPushResponse['CheckoutRequestID'];
                $stmt = $conn->prepare("UPDATE transactions SET checkout_request_id = ? WHERE id = ?");
                $stmt->bind_param("si", $checkoutRequestId, $transaction_id);
                $stmt->execute();
                $stmt->close();
                echo json_encode([
                    'status' => 'success',
                    'message' => 'Payment initiated successfully',
                    'transactionId' => $transaction_id,
                    'checkoutRequestId' => $checkoutRequestId
                ]);
            } else {
                $stmt = $conn->prepare("UPDATE transactions SET status = 'failed', error_message = ? WHERE id = ?");
                $errorMsg = $stkPushResponse['ResponseDescription'] ?? 'STK Push failed';
                $stmt->bind_param("si", $errorMsg, $transaction_id);
                $stmt->execute();
                $stmt->close();
                http_response_code(400);
                echo json_encode([
                    'status' => 'error',
                    'message' => 'Failed to initiate payment: ' . $errorMsg
                ]);
            }
        } else {
            http_response_code(500);
            echo json_encode(['status' => 'error', 'message' => 'Failed to save payment data: ' . $conn->error]);
        }
        $stmt->close();
        $conn->close();
        break;

    case 'POST process-paybill-payment':
        $data = json_decode(file_get_contents('php://input'), true) ?: $_POST;
        $user_id = $data['user_id'] ?? '';
        $phone_number = $data['phone_number'] ?? '';
        $amount = $data['amount'] ?? 0;
        $merchant_paybill = $data['merchant_paybill'] ?? '';
        $merchant_account = $data['merchant_account'] ?? '';
        $transaction_type = 'pay_bill';

        if (empty($user_id) || empty($phone_number) || empty($amount) || empty($merchant_paybill)) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Required fields missing']);
            exit;
        }
        $phone_number = formatPhoneNumber($phone_number);
        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT * FROM roundup_settings WHERE user_id = ?");
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        $result = $stmt->get_result();
        $roundupSettings = $result->fetch_assoc();
        $stmt->close();
        $serviceChargeRate = 0.01;
        $savingsRate = 0;
        if ($roundupSettings && $roundupSettings['is_enabled']) {
            if ($roundupSettings['pay_bill_round_up']) {
                $roundingValue = parseRoundingValue($roundupSettings['rounding_value']);
                $savingsAmount = calculateRoundUpAmount($amount, $roundingValue);
                if ($roundupSettings['max_round_up'] && $savingsAmount > $roundupSettings['max_round_up']) {
                    $savingsAmount = $roundupSettings['max_round_up'];
                }
                $savingsRate = $savingsAmount / $amount;
            }
        }
        $serviceCharge = $amount * $serviceChargeRate;
        $savingsAmount = $amount * $savingsRate;
        $merchantAmount = $amount - $serviceCharge - $savingsAmount;
        $stmt = $conn->prepare(
            "INSERT INTO transactions (user_id, phone_number, total_amount, service_charge, savings_amount, merchant_amount, merchant_paybill, merchant_account, status, transaction_type) 
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?)"
        );
        $stmt->bind_param("isddddsss", $user_id, $phone_number, $amount, $serviceCharge, $savingsAmount, $merchantAmount, $merchant_paybill, $merchant_account, $transaction_type);
        if (!$stmt->execute()) {
            http_response_code(500);
            echo json_encode(['status' => 'error', 'message' => 'Failed to record transaction: ' . $conn->error]);
            $stmt->close();
            $conn->close();
            exit;
        }
        $transactionId = $conn->insert_id;
        $stkPushResponse = initiateSTKPush($phone_number, $amount, $transactionId);
        if (isset($stkPushResponse['ResponseCode']) && $stkPushResponse['ResponseCode'] == '0') {
            $checkoutRequestId = $stkPushResponse['CheckoutRequestID'];
            $stmt->prepare("UPDATE transactions SET checkout_request_id = ? WHERE id = ?");
            $stmt->bind_param("si", $checkoutRequestId, $transactionId);
            $stmt->execute();
            $stmt->close();
            echo json_encode([
                'status' => 'success',
                'message' => 'Payment initiated successfully',
                'transactionId' => $transactionId,
                'checkoutRequestId' => $checkoutRequestId
            ]);
        } else {
            $stmt = $conn->prepare("UPDATE transactions SET status = 'failed', error_message = ? WHERE id = ?");
            $errorMsg = $stkPushResponse['ResponseDescription'] ?? 'STK Push failed';
            $stmt->bind_param("si", $errorMsg, $transactionId);
            $stmt->execute();
            $stmt->close();
            http_response_code(400);
            echo json_encode([
                'status' => 'error',
                'message' => 'Failed to initiate payment: ' . $errorMsg
            ]);
        }
        $conn->close();
        break;

    case 'POST favourites':
        $data = json_decode(file_get_contents('php://input'), true) ?: $_POST;
        $user_id = $data['user_id'] ?? '';
        $name = $data['name'] ?? '';
        $till_number = $data['till_number'] ?? '';
        $account_number = $data['account_number'] ?? '';
        $type = $data['type'] ?? '';
        if (empty($user_id) || empty($name) || empty($till_number) || empty($type)) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'user_id, name, till_number, and type are required']);
            exit;
        }
        if (!in_array($type, ['buy_goods', 'pay_bill'])) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Invalid type: must be buy_goods or pay_bill']);
            exit;
        }
        if ($type === 'pay_bill' && empty($account_number)) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'account_number required for Pay Bill']);
            exit;
        }
        if (!preg_match('/^\d{6}$/', $till_number)) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Till number must be 6 digits']);
            exit;
        }
        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT id FROM users WHERE id = ?");
        $stmt->bind_param("i", $user_id);
        $stmt->execute();
        $result = $stmt->get_result();
        if ($result->num_rows === 0) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Invalid user_id: User does not exist']);
            $stmt->close();
            $conn->close();
            exit;
        }
        $stmt->close();
        $stmt = $conn->prepare(
            "INSERT INTO favorites (user_id, name, till_number, account_number, type) VALUES (?, ?, ?, ?, ?)"
        );
        $stmt->bind_param("issss", $user_id, $name, $till_number, $account_number, $type);
        if ($stmt->execute()) {
            $favorite_id = $conn->insert_id;
            echo json_encode([
                'status' => 'success',
                'message' => 'Favorite saved successfully',
                'data' => [
                    'id' => $favorite_id,
                    'user_id' => $user_id,
                    'name' => $name,
                    'till_number' => $till_number,
                    'account_number' => $account_number,
                    'type' => $type
                ]
            ]);
        } else {
            $error = $conn->error;
            if (strpos($error, 'Duplicate entry') !== false) {
                http_response_code(409);
                echo json_encode(['status' => 'error', 'message' => 'This till/paybill is already saved as a favorite']);
            } else {
                http_response_code(500);
                echo json_encode(['status' => 'error', 'message' => 'Failed to save favorite: ' . $error]);
            }
        }
        $stmt->close();
        $conn->close();
        break;

    case 'GET favourites':
        $userId = $requestUri[2] ?? '';
        if (empty($userId) || !is_numeric($userId)) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Valid userId required']);
            exit;
        }
        $conn = getDbConnection();
        $stmt = $conn->prepare(
            "SELECT id, name, till_number, account_number, type, created_at 
             FROM favorites 
             WHERE user_id = ? 
             ORDER BY created_at DESC"
        );
        $stmt->bind_param("i", $userId);
        $stmt->execute();
        $result = $stmt->get_result();
        $favorites = [];
        while ($row = $result->fetch_assoc()) {
            $favorites[] = [
                'id' => (int)$row['id'],
                'name' => $row['name'],
                'till_number' => $row['till_number'],
                'account_number' => $row['account_number'],
                'type' => $row['type'],
                'created_at' => $row['created_at']
            ];
        }
        echo json_encode([
            'status' => 'success',
            'message' => empty($favorites) ? 'No favorites found' : 'Favorites retrieved successfully',
            'data' => $favorites
        ]);
        $stmt->close();
        $conn->close();
        break;

    case 'PATCH favourites':
        $favoriteId = $requestUri[2] ?? '';
        if (empty($favoriteId) || !is_numeric($favoriteId)) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Valid favorite id required']);
            exit;
        }
        $data = json_decode(file_get_contents('php://input'), true) ?: $_POST;
        $name = $data['name'] ?? null;
        $till_number = $data['till_number'] ?? null;
        $account_number = $data['account_number'] ?? null;
        $type = $data['type'] ?? null;
        if (!$name && !$till_number && !$account_number && !$type) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'At least one field (name, till_number, account_number, type) must be provided']);
            exit;
        }
        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT user_id, type FROM favorites WHERE id = ?");
        $stmt->bind_param("i", $favoriteId);
        $stmt->execute();
        $result = $stmt->get_result();
        if ($result->num_rows === 0) {
            http_response_code(404);
            echo json_encode(['status' => 'error', 'message' => 'Favorite not found']);
            $stmt->close();
            $conn->close();
            exit;
        }
        $favorite = $result->fetch_assoc();
        $stmt->close();
        if ($type && !in_array($type, ['buy_goods', 'pay_bill'])) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Invalid type: must be buy_goods or pay_bill']);
            $conn->close();
            exit;
        }
        if ($till_number && !preg_match('/^\d{6}$/', $till_number)) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Till number must be 6 digits']);
            $conn->close();
            exit;
        }
        if ($account_number === '' && ($type === 'pay_bill' || $favorite['type'] === 'pay_bill')) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'account_number required for Pay Bill']);
            $conn->close();
            exit;
        }
        $updateFields = [];
        $params = [];
        $types = '';

        if ($name !== null) {
            $updateFields[] = 'name = ?';
            $params[] = $name;
            $types .= 's';
        }
        if ($till_number !== null) {
            $updateFields[] = 'till_number = ?';
            $params[] = $till_number;
            $types .= 's';
        }
        if ($account_number !== null) {
            $updateFields[] = 'account_number = ?';
            $params[] = $account_number;
            $types .= 's';
        }
        if ($type !== null) {
            $updateFields[] = 'type = ?';
                        $params[] = $type;
            $types .= 's';
        }
        $params[] = $favoriteId;
        $types .= 'i';

        $query = "UPDATE favorites SET " . implode(', ', $updateFields) . " WHERE id = ?";
        $stmt = $conn->prepare($query);
        $stmt->bind_param($types, ...$params);

        if ($stmt->execute()) {
            echo json_encode(['status' => 'success', 'message' => 'Favorite updated successfully']);
        } else {
            http_response_code(500);
            echo json_encode(['status' => 'error', 'message' => 'Failed to update favorite: ' . $conn->error]);
        }
        $stmt->close();
        $conn->close();
        break;

    case 'DELETE favourites':
        $favoriteId = $requestUri[2] ?? '';
        if (empty($favoriteId) || !is_numeric($favoriteId)) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Valid favorite id required']);
            exit;
        }
        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT id FROM favorites WHERE id = ?");
        $stmt->bind_param("i", $favoriteId);
        $stmt->execute();
        $result = $stmt->get_result();
        if ($result->num_rows === 0) {
            http_response_code(404);
            echo json_encode(['status' => 'error', 'message' => 'Favorite not found']);
            $stmt->close();
            $conn->close();
            exit;
        }
        $stmt->close();
        $stmt = $conn->prepare("DELETE FROM favorites WHERE id = ?");
        $stmt->bind_param("i", $favoriteId);
        if ($stmt->execute()) {
            echo json_encode(['status' => 'success', 'message' => 'Favorite deleted successfully']);
        } else {
            http_response_code(500);
            echo json_encode(['status' => 'error', 'message' => 'Failed to delete favorite: ' . $conn->error]);
        }
        $stmt->close();
        $conn->close();
        break;

    case 'POST mpesa-callback':
        $callbackData = json_decode(file_get_contents('php://input'), true);
        if (DEBUG) {
            error_log("M-PESA Callback Data: " . json_encode($callbackData));
        }
        if (!isset($callbackData['Body']['stkCallback']['ResultCode'])) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Invalid callback data']);
            exit;
        }
        $resultCode = $callbackData['Body']['stkCallback']['ResultCode'];
        $resultDesc = $callbackData['Body']['stkCallback']['ResultDesc'] ?? 'No description provided';
        $checkoutRequestId = $callbackData['Body']['stkCallback']['CheckoutRequestID'] ?? '';
        $mpesaReceipt = '';
        $transactionDate = '';
        if (isset($callbackData['Body']['stkCallback']['CallbackMetadata']['Item'])) {
            foreach ($callbackData['Body']['stkCallback']['CallbackMetadata']['Item'] as $item) {
                if ($item['Name'] === 'MpesaReceiptNumber') {
                    $mpesaReceipt = $item['Value'];
                }
                if ($item['Name'] === 'TransactionDate') {
                    $transactionDate = $item['Value'];
                }
            }
        }
        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT id, user_id, merchant_paybill, merchant_account, merchant_amount, transaction_type FROM transactions WHERE checkout_request_id = ?");
        $stmt->bind_param("s", $checkoutRequestId);
        $stmt->execute();
        $result = $stmt->get_result();
        $transaction = $result->fetch_assoc();
        $stmt->close();
        if (!$transaction) {
            http_response_code(404);
            echo json_encode(['status' => 'error', 'message' => 'Transaction not found for CheckoutRequestID']);
            $conn->close();
            exit;
        }
        $transactionId = $transaction['id'];
        $merchantPaybill = $transaction['merchant_paybill'];
        $merchantAccount = $transaction['merchant_account'];
        $merchantAmount = $transaction['merchant_amount'];
        $transactionType = $transaction['transaction_type'];
        if ($resultCode == '0') {
            $b2bResult = forwardToMerchant($transactionId, $merchantPaybill, $merchantAccount, $merchantAmount);
            if ($b2bResult['status'] === 'success') {
                $stmt = $conn->prepare(
                    "UPDATE transactions SET status = 'completed', mpesa_receipt = ?, validated_at = ?, merchant_reference = ? WHERE id = ?"
                );
                $stmt->bind_param("sssi", $mpesaReceipt, $transactionDate, $b2bResult['reference'], $transactionId);
                $stmt->execute();
                $stmt->close();
                echo json_encode(['status' => 'success', 'message' => 'Payment processed successfully']);
            } else {
                $stmt = $conn->prepare("UPDATE transactions SET status = 'failed', error_message = ? WHERE id = ?");
                $errorMsg = $b2bResult['message'];
                $stmt->bind_param("si", $errorMsg, $transactionId);
                $stmt->execute();
                $stmt->close();
                http_response_code(500);
                echo json_encode(['status' => 'error', 'message' => 'Failed to forward payment to merchant: ' . $errorMsg]);
            }
        } else {
            $stmt = $conn->prepare("UPDATE transactions SET status = 'failed', error_message = ? WHERE id = ?");
            $stmt->bind_param("si", $resultDesc, $transactionId);
            $stmt->execute();
            $stmt->close();
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Payment failed: ' . $resultDesc]);
        }
        $conn->close();
        break;

    case 'POST b2b-result':
        $transactionId = $requestUri[2] ?? '';
        if (empty($transactionId)) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Transaction ID required']);
            exit;
        }
        $callbackData = json_decode(file_get_contents('php://input'), true);
        if (DEBUG) {
            error_log("B2B Callback Data for Transaction $transactionId: " . json_encode($callbackData));
        }
        if (!isset($callbackData['Result']['ResultCode'])) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Invalid B2B callback data']);
            exit;
        }
        $resultCode = $callbackData['Result']['ResultCode'];
        $resultDesc = $callbackData['Result']['ResultDesc'] ?? 'No description provided';
        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT id FROM transactions WHERE id = ?");
        $stmt->bind_param("i", $transactionId);
        $stmt->execute();
        $result = $stmt->get_result();
        if ($result->num_rows === 0) {
            http_response_code(404);
            echo json_encode(['status' => 'error', 'message' => 'Transaction not found']);
            $stmt->close();
            $conn->close();
            exit;
        }
        $stmt->close();
        if ($resultCode == '0') {
            $stmt = $conn->prepare("UPDATE transactions SET merchant_status = 'completed' WHERE id = ?");
            $stmt->bind_param("i", $transactionId);
            $stmt->execute();
            $stmt->close();
            echo json_encode(['status' => 'success', 'message' => 'B2B payment processed successfully']);
        } else {
            $stmt = $conn->prepare("UPDATE transactions SET merchant_status = 'failed', merchant_error = ? WHERE id = ?");
            $stmt->bind_param("si", $resultDesc, $transactionId);
            $stmt->execute();
            $stmt->close();
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'B2B payment failed: ' . $resultDesc]);
        }
        $conn->close();
        break;

    case 'POST b2b-timeout':
        $callbackData = json_decode(file_get_contents('php://input'), true);
        if (DEBUG) {
            error_log("B2B Timeout Callback Data: " . json_encode($callbackData));
        }
        if (!isset($callbackData['Result']['ResultCode'])) {
            http_response_code(400);
            echo json_encode(['status' => 'error', 'message' => 'Invalid B2B timeout callback data']);
            exit;
        }
        $resultDesc = $callbackData['Result']['ResultDesc'] ?? 'No description provided';
        $transactionId = null;
        if (isset($callbackData['Result']['TransactionID'])) {
            $conn = getDbConnection();
            $stmt = $conn->prepare("SELECT id FROM transactions WHERE merchant_reference = ?");
            $stmt->bind_param("s", $callbackData['Result']['TransactionID']);
            $stmt->execute();
            $result = $stmt->get_result();
            $transaction = $result->fetch_assoc();
            $stmt->close();
            if ($transaction) {
                $transactionId = $transaction['id'];
                $stmt = $conn->prepare("UPDATE transactions SET merchant_status = 'failed', merchant_error = ? WHERE id = ?");
                $stmt->bind_param("si", $resultDesc, $transactionId);
                $stmt->execute();
                $stmt->close();
            }
            $conn->close();
        }
        echo json_encode(['status' => 'success', 'message' => 'B2B timeout processed']);
        break;
/* ==================== LOANS ==================== */
    case 'POST apply-loan':
        $data = json_decode(file_get_contents('php://input'), true) ?: $_POST;
        $user_id = $data['user_id'] ?? '';
        $amount = (float)($data['amount_requested'] ?? 0);
        $tenure = (int)($data['tenure_months'] ?? 0);

        if (empty($user_id)||$amount<=0||$tenure<=0) {
            http_response_code(400);
            echo json_encode(['status'=>'error','message'=>'Invalid input']);
            break;
        }

        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT COALESCE(SUM(savings_amount),0) AS total FROM transactions WHERE user_id=? AND status='completed'");
        $stmt->bind_param("i",$user_id);
        $stmt->execute();
        $totalSavings = (float)$stmt->get_result()->fetch_assoc()['total'];
        $stmt->close();

        if ($amount > $totalSavings*2) {
            http_response_code(400);
            echo json_encode(['status'=>'error','message'=>'Max 2× savings']);
            $conn->close();
            break;
        }

        $interest = 12.00;
        $stmt = $conn->prepare("INSERT INTO loans (user_id,amount_requested,interest_rate,tenure_months) VALUES (?,?,?,?)");
        $stmt->bind_param("iddi",$user_id,$amount,$interest,$tenure);
        if ($stmt->execute()) {
            echo json_encode(['status'=>'success','loan_id'=>$conn->insert_id]);
        } else {
            http_response_code(500);
            echo json_encode(['status'=>'error','message'=>'DB error']);
        }
        $stmt->close(); $conn->close();
        break;

    case 'GET user-loans':
        $userId = $resource;
        if (!is_numeric($userId)) {
            http_response_code(400);
            echo json_encode(['status'=>'error','message'=>'Valid userId']);
            break;
        }
        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT * FROM loans WHERE user_id=? ORDER BY applied_at DESC");
        $stmt->bind_param("i",$userId);
        $stmt->execute();
        $res = $stmt->get_result();
        $loans = [];
        while ($r = $res->fetch_assoc()) {
            $r['amount_requested'] = (float)$r['amount_requested'];
            $r['amount_approved'] = $r['amount_approved'] ? (float)$r['amount_approved'] : null;
            $loans[] = $r;
        }
        echo json_encode(['status'=>'success','data'=>$loans]);
        $stmt->close(); $conn->close();
        break;

    case 'GET loan-details':
        $loanId = $resource;
        if (!is_numeric($loanId)) {
            http_response_code(400);
            echo json_encode(['status'=>'error','message'=>'Valid loanId']);
            break;
        }
        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT l.*, u.full_name, u.phone_number FROM loans l JOIN users u ON u.id=l.user_id WHERE l.id=?");
        $stmt->bind_param("i",$loanId);
        $stmt->execute();
        $loan = $stmt->get_result()->fetch_assoc();
        if (!$loan) {
            http_response_code(404);
            echo json_encode(['status'=>'error','message'=>'Not found']);
        } else {
            $loan['amount_requested'] = (float)$loan['amount_requested'];
            $loan['amount_approved'] = $loan['amount_approved'] ? (float)$loan['amount_approved'] : null;
            echo json_encode(['status'=>'success','data'=>$loan]);
        }
        $stmt->close(); $conn->close();
        break;

    case 'POST loan-repayment':
        $data = json_decode(file_get_contents('php://input'), true) ?: $_POST;
        $loan_id = $data['loan_id'] ?? '';
        $amount = (float)($data['amount'] ?? 0);
        $phone = formatPhoneNumber($data['phone_number'] ?? '');

        if (empty($loan_id)||$amount<=0||empty($phone)) {
            http_response_code(400);
            echo json_encode(['status'=>'error','message'=>'Invalid input']);
            break;
        }

        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT status,amount_approved FROM loans WHERE id=?");
        $stmt->bind_param("i",$loan_id);
        $stmt->execute();
        $loan = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        if (!$loan || $loan['status']!=='disbursed') {
            http_response_code(400);
            echo json_encode(['status'=>'error','message'=>'Loan not disbursed']);
            $conn->close();
            break;
        }

        $stmt = $conn->prepare("INSERT INTO loan_repayments (loan_id,amount) VALUES (?,?)");
        $stmt->bind_param("id",$loan_id,$amount);
        $stmt->execute();
        $repayId = $conn->insert_id;
        $stmt->close();

        $stk = initiateSTKPush($phone,$amount,"REPAY-$repayId");
        if ($stk['ResponseCode']??'' === '0') {
            $chk = $stk['CheckoutRequestID'];
            $stmt = $conn->prepare("UPDATE loan_repayments SET checkout_request_id=? WHERE id=?");
            $stmt->bind_param("si",$chk,$repayId);
            $stmt->execute();
            $stmt->close();
            echo json_encode(['status'=>'success','repayment_id'=>$repayId,'checkout'=>$chk]);
        } else {
            http_response_code(400);
            echo json_encode(['status'=>'error','message'=>$stk['ResponseDescription']??'STK failed']);
        }
        $conn->close();
        break;

    case 'POST loan-callback':
        $payload = json_decode(file_get_contents('php://input'), true);
        $code = $payload['Body']['stkCallback']['ResultCode'] ?? null;
        $chk = $payload['Body']['stkCallback']['CheckoutRequestID'] ?? '';
        $receipt = '';
        foreach (($payload['Body']['stkCallback']['CallbackMetadata']['Item'] ?? []) as $i) {
            if ($i['Name'] === 'MpesaReceiptNumber') $receipt = $i['Value'];
        }

        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT id,loan_id,amount FROM loan_repayments WHERE checkout_request_id=?");
        $stmt->bind_param("s",$chk);
        $stmt->execute();
        $repay = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$repay) {
            http_response_code(404);
            echo json_encode(['status'=>'error','message'=>'Not found']);
            $conn->close();
            break;
        }

        if ($code==0) {
            $stmt = $conn->prepare("UPDATE loan_repayments SET mpesa_receipt=?,paid_at=NOW() WHERE id=?");
            $stmt->bind_param("si",$receipt,$repay['id']);
            $stmt->execute();
            $stmt->close();

            $stmt = $conn->prepare("UPDATE loans SET amount_approved=amount_approved-? WHERE id=? AND amount_approved>=?");
            $stmt->bind_param("ddi",$repay['amount'],$repay['loan_id'],$repay['amount']);
            $stmt->execute();
            $stmt->close();

            $stmt = $conn->prepare("SELECT amount_approved FROM loans WHERE id=?");
            $stmt->bind_param("i",$repay['loan_id']);
            $stmt->execute();
            $rem = (float)($stmt->get_result()->fetch_assoc()['amount_approved'] ?? 0);
            $stmt->close();

            if ($rem<=0) {
                $stmt = $conn->prepare("UPDATE loans SET status='repaid',amount_approved=0 WHERE id=?");
                $stmt->bind_param("i",$repay['loan_id']);
                $stmt->execute();
                $stmt->close();
            }

            echo json_encode(['status'=>'success','message'=>'Repayment recorded']);
        } else {
            echo json_encode(['status'=>'error','message'=>'Payment failed']);
        }
        $conn->close();
        break;

    case 'GET loan-status':
        $loanId = $resource;
        if (!is_numeric($loanId)) {
            http_response_code(400);
            echo json_encode(['status'=>'error','message'=>'Valid loanId']);
            break;
        }
        $conn = getDbConnection();
        $stmt = $conn->prepare("SELECT status,amount_ status,amount_approved FROM loans WHERE id=?");
        $stmt->bind_param("i",$loanId);
        $stmt->execute();
        $loan = $stmt->get_result()->fetch_assoc();
        $stmt->close(); $conn->close();
        if (!$loan) {
            http_response_code(404);
            echo json_encode(['status'=>'error','message'=>'Not found']);
            break;
        }
        $loan['amount_approved'] = $loan['amount_approved'] ? (float)$loan['amount_approved'] : null;
        echo json_encode(['status'=>'success','data'=>$loan]);
        break;

    default:
        http_response_code(404);
        echo json_encode(['status' => 'error', 'message' => 'Endpoint not found']);
        break;
}