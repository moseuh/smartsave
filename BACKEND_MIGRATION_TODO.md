# IMPORTANT: Backend Separation Required

## Current Issue
The PHP backend file (`lib/api.php`) is currently located inside the Flutter project structure. This violates separation of concerns and creates security risks.

## Required Action
**This file must be moved to a separate backend repository and deployed on a secure server.**

### Steps:
1. Create a new repository for the backend API
2. Move `lib/api.php` to the backend repository
3. Set up a proper PHP server environment (Apache/Nginx + PHP)
4. Configure environment variables using a `.env` file on the server
5. Deploy the backend to a secure hosting environment
6. Update the Flutter app to call the backend API via HTTPS endpoints

### Environment Variables Setup
On your PHP server, create a `.env` file with the actual credentials (use `.env.example` as a template).

You can use a library like `vlucas/phpdotenv` to load environment variables in PHP:

```bash
composer require vlucas/phpdotenv
```

Then in your `api.php`:
```php
<?php
require 'vendor/autoload.php';
$dotenv = Dotenv\Dotenv::createImmutable(__DIR__);
$dotenv->load();
```

## Security Reminder
- Never commit `.env` files to version control
- Never hardcode credentials in source code
- Use HTTPS for all API communications
- Implement proper authentication and authorization
- Use prepared statements for all database queries
