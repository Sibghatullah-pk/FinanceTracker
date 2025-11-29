import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/household.dart';
import '../models/transaction.dart';
import '../models/comment.dart';
import 'dart:math';

class AppState extends ChangeNotifier {
  UserModel? _currentUser;
  Household? _household;
  List<Transaction> _transactions = [];
  Map<String, List<Comment>> _comments = {}; // transactionId: comments
  Map<String, UserModel> _householdMembers = {};

  // Getters
  UserModel? get currentUser => _currentUser;
  Household? get household => _household;
  List<Transaction> get transactions => _transactions;
  bool get isLoggedIn => _currentUser != null;
  bool get hasHousehold => _household != null;
  bool get isAdmin => _household?.roles[_currentUser?.uid] == 'admin';

  double get totalSpent => _transactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0, (sum, t) => sum + t.amount);

  double get totalIncome => _transactions
      .where((t) => t.type == TransactionType.income)
      .fold(0, (sum, t) => sum + t.amount);

  double get monthlyLimit => _household?.monthlyLimit ?? 0;
  double get remaining => monthlyLimit - totalSpent;

  List<UserModel> get members => _householdMembers.values.toList();

  // Generate random ID
  String _generateId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
  }

  // Auth Methods
  Future<bool> login(String email, String password) async {
    // Mock login - In production, use Firebase Auth
    await Future.delayed(const Duration(seconds: 1));
    
    // Demo user
    _currentUser = UserModel(
      uid: 'user_${_generateId()}',
      name: email.split('@')[0],
      email: email,
      householdId: null,
    );
    
    notifyListeners();
    return true;
  }

  Future<bool> signup(String name, String email, String password, double monthlyBudget) async {
    // Mock signup
    await Future.delayed(const Duration(seconds: 1));
    
    final uid = 'user_${_generateId()}';
    final householdId = 'hh_${_generateId()}';
    final inviteCode = _generateId();
    
    _currentUser = UserModel(
      uid: uid,
      name: name,
      email: email,
      householdId: householdId,
    );

    // Create household with user as admin
    _household = Household(
      id: householdId,
      memberIds: [uid],
      roles: {uid: 'admin'},
      monthlyLimit: monthlyBudget,
      inviteCode: inviteCode,
    );

    _householdMembers[uid] = _currentUser!;
    
    // Add sample transactions
    _addSampleTransactions();
    
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    _currentUser = null;
    _household = null;
    _transactions = [];
    _comments = {};
    _householdMembers = {};
    notifyListeners();
  }

  // Household Methods
  Future<bool> joinHousehold(String inviteCode) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Mock joining - check if invite code matches
    if (_household != null && _household!.inviteCode == inviteCode) {
      return false; // Already in this household
    }

    // In real app, query Firestore for household with this invite code
    // For demo, create a mock household
    final householdId = 'hh_${_generateId()}';
    
    _currentUser = _currentUser!.copyWith(householdId: householdId);
    
    _household = Household(
      id: householdId,
      memberIds: [_currentUser!.uid, 'member_admin'],
      roles: {
        _currentUser!.uid: 'contributor',
        'member_admin': 'admin',
      },
      monthlyLimit: 50000,
      inviteCode: inviteCode,
    );

    _householdMembers[_currentUser!.uid] = _currentUser!;
    _householdMembers['member_admin'] = UserModel(
      uid: 'member_admin',
      name: 'Admin',
      email: 'admin@email.com',
      householdId: householdId,
    );

    _addSampleTransactions();
    
    notifyListeners();
    return true;
  }

  Future<void> leaveHousehold() async {
    _currentUser = _currentUser!.copyWith(householdId: null);
    _household = null;
    _transactions = [];
    _comments = {};
    _householdMembers = {};
    notifyListeners();
  }

  Future<void> updateBudgetLimit(double newLimit) async {
    if (!isAdmin) return;
    
    _household = _household!.copyWith(monthlyLimit: newLimit);
    notifyListeners();
  }

  // Transaction Methods
  Future<void> addTransaction(Transaction transaction) async {
    _transactions.insert(0, transaction);
    notifyListeners();
  }

  Future<void> deleteTransaction(String transactionId) async {
    if (!isAdmin) return;
    
    _transactions.removeWhere((t) => t.id == transactionId);
    _comments.remove(transactionId);
    notifyListeners();
  }

  // Comment Methods
  List<Comment> getComments(String transactionId) {
    return _comments[transactionId] ?? [];
  }

  Future<void> addComment(String transactionId, String text) async {
    final comment = Comment(
      id: 'comment_${_generateId()}',
      oderId: _currentUser!.uid,
      text: text,
      timestamp: DateTime.now(),
      userName: _currentUser!.name,
    );

    if (_comments[transactionId] == null) {
      _comments[transactionId] = [];
    }
    _comments[transactionId]!.add(comment);
    notifyListeners();
  }

  // Sample Data
  void _addSampleTransactions() {
    final now = DateTime.now();
    _transactions = [
      Transaction(
        id: 'tx_1',
        title: 'Grocery Shopping',
        amount: 2500,
        category: 'Food & Dining',
        type: TransactionType.expense,
        date: now,
        note: 'Weekly groceries from supermarket',
        createdBy: _currentUser!.uid,
        createdByName: _currentUser!.name,
      ),
      Transaction(
        id: 'tx_2',
        title: 'Electricity Bill',
        amount: 3500,
        category: 'Bills & Utilities',
        type: TransactionType.expense,
        date: now.subtract(const Duration(days: 1)),
        note: 'Monthly electricity bill',
        createdBy: 'partner_123',
        createdByName: 'Partner',
      ),
      Transaction(
        id: 'tx_3',
        title: 'Monthly Salary',
        amount: 75000,
        category: 'Salary',
        type: TransactionType.income,
        date: now.subtract(const Duration(days: 2)),
        createdBy: _currentUser!.uid,
        createdByName: _currentUser!.name,
      ),
      Transaction(
        id: 'tx_4',
        title: 'Restaurant Dinner',
        amount: 1800,
        category: 'Food & Dining',
        type: TransactionType.expense,
        date: now.subtract(const Duration(days: 3)),
        note: 'Anniversary dinner',
        createdBy: 'partner_123',
        createdByName: 'Partner',
      ),
    ];

    // Sample comments
    _comments['tx_1'] = [
      Comment(
        id: 'c1',
        oderId: 'partner_123',
        text: 'Did you get the milk?',
        timestamp: now.subtract(const Duration(hours: 2)),
        userName: 'Partner',
      ),
      Comment(
        id: 'c2',
        oderId: _currentUser!.uid,
        text: 'Yes, got everything on the list!',
        timestamp: now.subtract(const Duration(hours: 1)),
        userName: _currentUser!.name,
      ),
    ];

    _comments['tx_4'] = [
      Comment(
        id: 'c3',
        oderId: _currentUser!.uid,
        text: 'Great choice of restaurant! ❤️',
        timestamp: now.subtract(const Duration(days: 2)),
        userName: _currentUser!.name,
      ),
    ];
  }

  // Demo login for quick testing
  Future<void> demoLogin() async {
    await signup('John', 'john@example.com', 'password', 50000);
    
    // Add member to household
    _household = _household!.copyWith(
      memberIds: [..._household!.memberIds, 'member_123'],
      roles: {..._household!.roles, 'member_123': 'contributor'},
    );
    
    _householdMembers['member_123'] = UserModel(
      uid: 'member_123',
      name: 'Sarah',
      email: 'sarah@example.com',
      householdId: _household!.id,
    );
    
    notifyListeners();
  }
}
