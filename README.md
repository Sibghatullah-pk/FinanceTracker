
# 💰 Finance Tracker

A modern Flutter app for **household finance management**. Perfect for couples or families to track shared expenses, manage budgets, and discuss transactions together.

![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.0+-blue?logo=dart)
![License](https://img.shields.io/badge/License-MIT-green)

## ✨ Features

### 👥 Household Management
- **Link accounts** with your family or group using invite codes
- **Role-based permissions** (Admin & Contributor)
- Admin can edit budgets and delete transactions
- Multiple contributors supported per household (no member limit)

### 💵 Expense & Income Tracking
- Add expenses and income with categories
- Track who added each transaction
- Pakistani Rupee (Rs.) currency support
- Real-time budget tracking

### 💬 Mini Chat on Expenses
- Comment/discuss on any expense
- Perfect for asking "What was this for?" 
- See conversation history per transaction

### 📊 Statistics & Analytics
- Monthly budget progress bar
- Income vs Expense breakdown
- Spending by category visualization
- Visual spending insights

### 🎨 Modern UI
- Clean Material Design 3 interface
- Purple accent theme
- Responsive layout for all devices
- Smooth animations

## 📱 Screenshots

| Login | Dashboard | Add Expense | Statistics |
|-------|-----------|-------------|------------|
| Email/Password auth | Budget overview | Category selection | Spending charts |

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK
- Android Studio / VS Code with Flutter extensions

### Installation

```bash
# Clone the repository
git clone https://github.com/Sibghatullah-pk/FinanceTracker.git

# Navigate to project directory
cd FinanceTracker

# Install dependencies
flutter pub get

# Run on Chrome (Web)
flutter run -d chrome

# Run on Windows
flutter run -d windows

# Build APK
flutter build apk --release
```

## 📁 Project Structure

```
lib/
├── main.dart                 # App entry point with Provider setup
├── models/
│   ├── user_model.dart       # User data model
│   ├── household.dart        # Household with members & budget
│   ├── transaction.dart      # Expense/Income model
│   ├── comment.dart          # Chat message model
│   ├── category.dart         # Expense categories
│   └── budget.dart           # Budget tracking
├── providers/
│   └── app_state.dart        # Central state management
├── screens/
│   ├── login_screen.dart     # Email/password login
│   ├── signup_screen.dart    # New user registration
│   ├── main_screen.dart      # Bottom navigation
│   ├── dashboard_screen.dart # Home with budget overview
│   ├── transactions_screen.dart # All expenses list
│   ├── add_expense_screen.dart  # Add new transaction
│   ├── expense_detail_screen.dart # Details + mini chat
│   ├── statistics_screen.dart    # Charts & analytics
│   ├── settings_screen.dart      # Profile & household settings
│   └── join_household_screen.dart # Join via invite code
├── widgets/
│   ├── balance_card.dart     # Income/Expense summary
│   ├── transaction_item.dart # Transaction list tile
│   ├── category_card.dart    # Category selection
│   └── budget_card.dart      # Budget progress
└── utils/
    ├── app_theme.dart        # Colors & styling
    └── format_helper.dart    # Currency formatting
```

## 📦 Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.1        # State management
  intl: ^0.18.1           # Date/number formatting
  fl_chart: ^0.65.0       # Charts and graphs
  shared_preferences: ^2.2.2  # Local storage
```

## 🔥 Firebase Integration (Coming Soon)

The app is designed to be **Firebase-ready**. Current implementation uses local mock data. To add Firebase:

1. Add Firebase dependencies to `pubspec.yaml`
2. Configure Firebase project
3. Replace mock methods in `app_state.dart` with Firebase calls

### Planned Firestore Structure:
```
users/
  └── {userId}/
households/
  └── {householdId}/
      └── transactions/
          └── {transactionId}/
              └── comments/
```

## 🤝 How Household Linking Works

1. **User A** signs up → Becomes **Admin** of new household
2. **User A** shares invite code from Settings
3. Other users sign up → Go to "Join Household"
4. Each user enters the code → Joins as **Contributor**
5. All members share the same budget & transactions!
6. If the admin leaves, a new admin is automatically assigned. If only one member remains, the household is deleted.

## 🎯 Roadmap

- [x] Basic expense tracking
- [x] Household linking with invite codes
- [x] Mini chat on expenses
- [x] Budget management
- [x] Statistics dashboard
- [x] Firebase backend integration
- [x] Push notifications for new expenses //not done
- [x] Monthly reports export
- [x] Savings goals feature
- [x] Dark mode theme
- [x] Goals,analysis,Summary (report) add krna


## 👨‍💻 Author

**Sibghatullah**
- GitHub: [@Sibghatullah-pk](https://github.com/Sibghatullah-pk)
 **Noorulain**
 -Github: [@noorulain924] (https://github.com/NOORULAIN924)

## 📄 License

This project is open source and available under the [MIT License](LICENSE).
