# API Documentation

Base URL: `https://secured-agora-calling-app.onrender.com`

## Authentication Endpoints

### Login
**Endpoint:** `POST /api/auth/login`

**Request Body:**
```json
{
  "email": "string",
  "password": "string"
}
```

**Response:**
```json
{
  "token": "string",
  "user": {
    "uid": "string",
    "email": "string",
    "role": "string"
  }
}
```

**Dart Example:**
```dart
Future<void> login(String email, String password) async {
  final response = await http.post(
    Uri.parse('https://secured-agora-calling-app.onrender.com/api/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'password': password,
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final token = data['token'];
    // Store token for future requests
  } else {
    throw Exception('Failed to login');
  }
}
```

### Create User
**Endpoint:** `POST /api/auth/create-user`

**Headers:**
```
Authorization: Bearer <token>
```

**Request Body:**
```json
{
  "email": "string",
  "password": "string",
  "role": "string" // "admin" or "member"
}
```

**Response:**
```json
{
  "uid": "string",
  "email": "string",
  "role": "string"
}
```

**Dart Example:**
```dart
Future<void> createUser(String email, String password, String role, String token) async {
  final response = await http.post(
    Uri.parse('https://secured-agora-calling-app.onrender.com/api/auth/create-user'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode({
      'email': email,
      'password': password,
      'role': role,
    }),
  );

  if (response.statusCode != 201) {
    throw Exception('Failed to create user');
  }
}
```

### Reset Password
**Endpoint:** `POST /api/auth/reset-password`

**Headers:**
```
Authorization: Bearer <token>
```

**Request Body:**
```json
{
  "email": "string",
  "newPassword": "string"
}
```

**Response:**
```json
{
  "message": "string"
}
```

**Dart Example:**
```dart
Future<void> resetPassword(String email, String newPassword, String token) async {
  final response = await http.post(
    Uri.parse('https://secured-agora-calling-app.onrender.com/api/auth/reset-password'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode({
      'email': email,
      'newPassword': newPassword,
    }),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to reset password');
  }
}
```

## Agora Integration Endpoints

### Generate Token
**Endpoint:** `POST /api/agora/token`

**Headers:**
```
Authorization: Bearer <token>
```

**Request Body:**
```json
{
  "channelName": "string",
  "uid": "string",
  "role": "string", // "publisher" or "subscriber"
  "tokenType": "string" // "rtc" or "rtm"
}
```

**Response:**
```json
{
  "token": "string"
}
```

**Dart Example:**
```dart
Future<String> generateAgoraToken(String channelName, String uid, String role, String tokenType, String token) async {
  final response = await http.post(
    Uri.parse('https://secured-agora-calling-app.onrender.com/api/agora/token'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode({
      'channelName': channelName,
      'uid': uid,
      'role': role,
      'tokenType': tokenType,
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['token'];
  } else {
    throw Exception('Failed to generate token');
  }
}
```

### Start Cloud Recording
**Endpoint:** `POST /api/agora/recording/start`

**Headers:**
```
Authorization: Bearer <token>
```

**Request Body:**
```json
{
  "channelName": "string",
  "uid": "string",
  "token": "string"
}
```

**Response:**
```json
{
  "resourceId": "string",
  "sid": "string"
}
```

**Dart Example:**
```dart
Future<Map<String, String>> startRecording(String channelName, String uid, String agoraToken, String authToken) async {
  final response = await http.post(
    Uri.parse('https://secured-agora-calling-app.onrender.com/api/agora/recording/start'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $authToken',
    },
    body: jsonEncode({
      'channelName': channelName,
      'uid': uid,
      'token': agoraToken,
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return {
      'resourceId': data['resourceId'],
      'sid': data['sid'],
    };
  } else {
    throw Exception('Failed to start recording');
  }
}
```

### Stop Cloud Recording
**Endpoint:** `POST /api/agora/recording/stop`

**Headers:**
```
Authorization: Bearer <token>
```

**Request Body:**
```json
{
  "channelName": "string",
  "uid": "string",
  "resourceId": "string",
  "sid": "string"
}
```

**Response:**
```json
{
  "serverId": "string",
  "fileList": ["string"]
}
```

**Dart Example:**
```dart
Future<void> stopRecording(String channelName, String uid, String resourceId, String sid, String token) async {
  final response = await http.post(
    Uri.parse('https://secured-agora-calling-app.onrender.com/api/agora/recording/stop'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode({
      'channelName': channelName,
      'uid': uid,
      'resourceId': resourceId,
      'sid': sid,
    }),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to stop recording');
  }
}
```

### Query Recording Status
**Endpoint:** `POST /api/agora/recording/status`

**Headers:**
```
Authorization: Bearer <token>
```

**Request Body:**
```json
{
  "channelName": "string",
  "uid": "string",
  "resourceId": "string",
  "sid": "string"
}
```

**Response:**
```json
{
  "serverResponse": {
    "status": "string",
    "resourceId": "string",
    "sid": "string",
    "fileList": ["string"]
  }
}
```

**Dart Example:**
```dart
Future<Map<String, dynamic>> queryRecordingStatus(
  String channelName,
  String uid,
  String resourceId,
  String sid,
  String token,
) async {
  final response = await http.post(
    Uri.parse('https://secured-agora-calling-app.onrender.com/api/agora/recording/status'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode({
      'channelName': channelName,
      'uid': uid,
      'resourceId': resourceId,
      'sid': sid,
    }),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to query recording status');
  }
}
```

## Error Responses

All endpoints may return the following error responses:

```json
{
  "error": {
    "code": "string",
    "message": "string"
  }
}
```

Common HTTP status codes:
- 400: Bad Request
- 401: Unauthorized
- 403: Forbidden
- 404: Not Found
- 500: Internal Server Error

## Dart HTTP Client Setup

For better reusability, you might want to create an API client class:

```dart
class ApiClient {
  final String baseUrl;
  String? _token;

  ApiClient({
    this.baseUrl = 'https://secured-agora-calling-app.onrender.com',
    String? token,
  }) : _token = token;

  void setToken(String token) {
    _token = token;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      throw ApiException(
        response.statusCode,
        jsonDecode(response.body)['error']['message'],
      );
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException: $statusCode - $message';
}
```

Usage example:
```dart
final api = ApiClient();

try {
  // Login
  final loginResponse = await api.post('/api/auth/login', {
    'email': 'user@example.com',
    'password': 'password123',
  });
  
  // Set token for subsequent requests
  api.setToken(loginResponse['token']);
  
  // Create user
  await api.post('/api/auth/create-user', {
    'email': 'newuser@example.com',
    'password': 'newpassword123',
    'role': 'member',
  });
} on ApiException catch (e) {
  print('API Error: ${e.message}');
} catch (e) {
  print('Unexpected error: $e');
}
```