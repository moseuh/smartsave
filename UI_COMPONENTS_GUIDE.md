# 🎨 SmartSave UI Components Library

## Beautiful, Production-Ready Flutter Widgets

### 🎯 Quick Start

All widgets are located in `lib/widgets/` and follow Material Design 3 principles with custom styling.

---

## 📦 Available Components

### 1. GradientButton
**Location:** `lib/widgets/gradient_button.dart`

Beautiful gradient button with press animation.

```dart
GradientButton(
  text: 'Sign In',
  onPressed: () {},
  isLoading: false,
  icon: Icons.login,
  gradient: AppTheme.primaryGradient,
)
```

**Props:**
- `text` - Button label
- `onPressed` - Callback function
- `isLoading` - Shows loading spinner
- `icon` - Optional leading icon
- `gradient` - Custom gradient (defaults to primary)
- `width` - Custom width
- `height` - Height (default: 56)

---

### 2. BalanceCard
**Location:** `lib/widgets/balance_card.dart`

Stunning balance display with animated numbers.

```dart
BalanceCard(
  balance: 25000.50,
  title: 'Total Balance',
  icon: Icons.account_balance_wallet,
  onTap: () {},
  isLoading: false,
)
```

**Features:**
- Gradient background
- Animated number counting
- Growth percentage display
- Tap gesture support

---

### 3. StatCard
**Location:** `lib/widgets/stat_card.dart`

Compact statistics card with icon.

```dart
StatCard(
  title: 'Active Goals',
  value: '5',
  icon: Icons.flag,
  color: AppTheme.accentColor,
  onTap: () {},
)
```

**Use Cases:**
- Dashboard statistics
- Quick metrics display
- Feature highlights

---

### 4. FeatureCard
**Location:** `lib/widgets/feature_card.dart`

Interactive feature card with press animation.

```dart
FeatureCard(
  title: 'Savings Goals',
  icon: Icons.savings,
  onTap: () {},
  color: AppTheme.accentColor,
  badge: 'New',
)
```

**Features:**
- Press animation
- Optional badge
- Custom colors
- Shadow effects

---

### 5. TransactionItem
**Location:** `lib/widgets/transaction_item.dart`

Beautiful transaction list item.

```dart
TransactionItem(
  title: 'Salary Deposit',
  subtitle: 'Monthly income',
  amount: 50000,
  date: DateTime.now(),
  isIncome: true,
  icon: Icons.work,
  onTap: () {},
)
```

**Features:**
- Income/expense colors
- Date formatting
- Currency formatting (KSh)
- Custom icons

---

### 6. AnimatedCard
**Location:** `lib/widgets/animated_card.dart`

Card with hover and press animations.

```dart
AnimatedCard(
  onTap: () {},
  padding: EdgeInsets.all(16),
  elevation: 2,
  child: YourContent(),
)
```

---

### 7. CustomButton
**Location:** `lib/widgets/custom_button.dart`

Standard button with loading state.

```dart
CustomButton(
  text: 'Submit',
  onPressed: () {},
  isLoading: false,
  icon: Icons.send,
  backgroundColor: AppTheme.primaryColor,
)
```

---

### 8. CustomTextField
**Location:** `lib/widgets/custom_text_field.dart`

Styled text input with validation.

```dart
CustomTextField(
  controller: controller,
  labelText: 'Email',
  hintText: 'Enter your email',
  validator: ValidationUtils.validateEmail,
  keyboardType: TextInputType.emailAddress,
  prefixIcon: Icon(Icons.email),
)
```

---

### 9. LoadingOverlay
**Location:** `lib/widgets/common_widgets.dart`

Full-screen loading overlay.

```dart
LoadingOverlay(
  isLoading: true,
  message: 'Processing...',
  child: YourWidget(),
)
```

---

### 10. EmptyState
**Location:** `lib/widgets/empty_state.dart`

Beautiful empty state with icon and action.

```dart
EmptyState(
  icon: Icons.inbox,
  title: 'No Transactions',
  message: 'Start saving to see your transactions here',
  actionLabel: 'Add Money',
  onAction: () {},
)
```

---

### 11. ShimmerLoading
**Location:** `lib/widgets/shimmer_loading.dart`

Skeleton loading animation.

```dart
// Single shimmer
ShimmerLoading(
  width: 200,
  height: 20,
  borderRadius: BorderRadius.circular(8),
)

// Pre-built card
ShimmerCard()
```

---

### 12. GradientAppBar
**Location:** `lib/widgets/gradient_app_bar.dart`

App bar with gradient background.

```dart
GradientAppBar(
  title: 'Dashboard',
  gradient: AppTheme.primaryGradient,
  actions: [
    IconButton(icon: Icon(Icons.notifications), onPressed: () {}),
  ],
)
```

---

## 🎨 Theme System

### Using App Theme
**Location:** `lib/constants/app_theme.dart`

```dart
// In main.dart
MaterialApp(
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
)

// Access colors
Container(color: AppTheme.primaryColor)
Container(color: AppTheme.accentColor)
Container(color: AppTheme.successColor)

// Use gradients
Container(
  decoration: BoxDecoration(
    gradient: AppTheme.primaryGradient,
  ),
)
```

### Available Colors
- `primaryColor` - #6C63FF (Purple)
- `accentColor` - #00D4AA (Teal)
- `successColor` - #2ECC71 (Green)
- `warningColor` - #F39C12 (Orange)
- `errorColor` - #E74C3C (Red)
- `infoColor` - #3498DB (Blue)

---

## 🎬 Animations

### Page Transitions
**Location:** `lib/utils/page_animations.dart`

```dart
// Slide transition
Navigator.push(
  context,
  SlidePageRoute(page: NextScreen()),
);

// Fade transition
Navigator.push(
  context,
  FadePageRoute(page: NextScreen()),
);

// Scale transition
Navigator.push(
  context,
  ScalePageRoute(page: NextScreen()),
);
```

### Animated Page Wrapper

```dart
AnimatedPage(
  duration: Duration(milliseconds: 300),
  child: YourPageContent(),
)
```

### Staggered List Animation

```dart
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return StaggeredListItem(
      index: index,
      delay: Duration(milliseconds: 100),
      child: TransactionItem(...),
    );
  },
)
```

---

## 📱 Responsive Design

### Using Responsive Utils
**Location:** `lib/utils/responsive.dart`

```dart
// Check device type
if (Responsive.isMobile(context)) {
  // Mobile layout
} else if (Responsive.isTablet(context)) {
  // Tablet layout
} else {
  // Desktop layout
}

// Get responsive value
final columns = Responsive.getValue(
  context,
  mobile: 1,
  tablet: 2,
  desktop: 3,
);

// Get responsive padding
Padding(
  padding: Responsive.getPadding(context),
  child: child,
)

// Grid count
GridView.count(
  crossAxisCount: Responsive.getGridCount(context, mobile: 2),
  children: items,
)
```

---

## 🎯 Dialog Helpers

### Error Dialog
```dart
showErrorDialog(context, 'Something went wrong!');
```

### Success Dialog
```dart
showSuccessDialog(
  context,
  'Account created successfully!',
  onClose: () {
    Navigator.pop(context);
  },
);
```

### Confirmation Dialog
```dart
final confirmed = await showConfirmDialog(
  context,
  title: 'Delete Account',
  message: 'Are you sure?',
  confirmText: 'Delete',
  cancelText: 'Cancel',
);

if (confirmed) {
  // Proceed with deletion
}
```

---

## 💡 Example: Complete Screen

```dart
import 'package:flutter/material.dart';
import '../widgets/gradient_app_bar.dart';
import '../widgets/balance_card.dart';
import '../widgets/stat_card.dart';
import '../widgets/feature_card.dart';
import '../widgets/transaction_item.dart';
import '../constants/app_theme.dart';
import '../utils/responsive.dart';
import '../utils/page_animations.dart';

class DashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: 'Dashboard',
        gradient: AppTheme.primaryGradient,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications),
            onPressed: () {},
          ),
        ],
      ),
      body: AnimatedPage(
        child: SingleChildScrollView(
          padding: Responsive.getPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balance Card
              BalanceCard(
                balance: 25000.50,
                title: 'Total Savings',
                icon: Icons.savings,
                onTap: () {},
              ),
              
              SizedBox(height: 24),
              
              // Statistics Grid
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: Responsive.getGridCount(context),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  StatCard(
                    title: 'Active Goals',
                    value: '5',
                    icon: Icons.flag,
                    color: AppTheme.accentColor,
                  ),
                  StatCard(
                    title: 'Completed',
                    value: '12',
                    icon: Icons.check_circle,
                    color: AppTheme.successColor,
                  ),
                ],
              ),
              
              SizedBox(height: 24),
              
              // Features
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(height: 16),
              
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  FeatureCard(
                    title: 'Add Money',
                    icon: Icons.add,
                    onTap: () {},
                  ),
                  FeatureCard(
                    title: 'Send',
                    icon: Icons.send,
                    onTap: () {},
                  ),
                  FeatureCard(
                    title: 'Loans',
                    icon: Icons.monetization_on,
                    onTap: () {},
                    badge: 'New',
                  ),
                ],
              ),
              
              SizedBox(height: 24),
              
              // Recent Transactions
              Text(
                'Recent Transactions',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(height: 16),
              
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: 3,
                itemBuilder: (context, index) {
                  return StaggeredListItem(
                    index: index,
                    child: TransactionItem(
                      title: 'Salary Deposit',
                      subtitle: 'Monthly income',
                      amount: 50000,
                      date: DateTime.now(),
                      isIncome: true,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## 🚀 Best Practices

1. **Always use theme colors** instead of hardcoded values
2. **Wrap lists with StaggeredListItem** for smooth animations
3. **Use Responsive.getValue()** for device-specific layouts
4. **Show loading states** with LoadingOverlay or ShimmerLoading
5. **Handle empty states** gracefully with EmptyState widget
6. **Use GradientButton** for primary actions
7. **Apply consistent spacing** (8px, 16px, 24px)
8. **Validate inputs** with ValidationUtils
9. **Log errors** with ErrorLogger
10. **Use page transitions** for better UX

---

## 📚 Resources

- Material Design 3: https://m3.material.io/
- Flutter Animations: https://docs.flutter.dev/ui/animations
- Responsive Design: https://docs.flutter.dev/ui/layout/responsive

---

**Made with 💜 by the SmartSave Team**
