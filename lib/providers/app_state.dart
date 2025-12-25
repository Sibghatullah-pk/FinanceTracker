import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/transaction.dart' as app;
import '../models/user_model.dart';
import '../models/household.dart';
import '../models/comment.dart';
import '../models/savings_goal.dart';
import '../services/openai_service.dart';

class AppState extends ChangeNotifier {
  /// Returns 'success', 'invalid', 'full', or 'error'
  Future<String> joinHouseholdWithReason(String inviteCode) async {
    try {
      final query = await _db
          .collection('households')
          .where('inviteCode', isEqualTo: inviteCode)
          .get();
      if (query.docs.isEmpty) {
        debugPrint('Join household error: Invalid code');
        return 'invalid';
      }

      final householdDoc = query.docs.first;
      final householdId = householdDoc.id;
      // No member limit now

      try {
        await _db.collection('households').doc(householdId).update({
          'memberIds': FieldValue.arrayUnion([_currentUser!.uid]),
          'roles.${_currentUser!.uid}': 'contributor',
        });

        await _db.collection('users').doc(_currentUser!.uid).update({
          'householdId': householdId,
        });

        _startSync();
        await _subscribeToHousehold(householdId);
        await _subscribeToTransactions(householdId);
        await _loadGoals();
        notifyListeners();
        return 'success';
      } on FirebaseException catch (e) {
        debugPrint('Join household update failed: ${e.code} ${e.message}');
        if (e.code == 'permission-denied') {
          // Create join request instead
          await _db.collection('join_requests').add({
            'userId': _currentUser!.uid,
            'name': _currentUser!.name,
            'email': _currentUser!.email,
            'householdId': householdId,
            'inviteCode': inviteCode,
            'status': 'pending',
            'createdAt': Timestamp.now(),
          });

          // Update user doc with householdId so UI can show household context
          await _db.collection('users').doc(_currentUser!.uid).update({
            'householdId': householdId,
          });

          _currentUser = _currentUser!.copyWith(householdId: householdId);
          _startSync();
          await _subscribeToHousehold(householdId);
          await _loadTransactions();
          await _loadGoals();
          notifyListeners();
          return 'pending';
        }
        return 'error';
      }
    } catch (e) {
      debugPrint('Join household error: $e');
      return 'error';
    }
  }

  /// Creates a new household and assigns the current user as admin.
  Future<bool> createHousehold({double monthlyBudget = 0}) async {
    if (_currentUser == null) return false;
    try {
      final householdId = _db.collection('households').doc().id;
      final inviteCode = _generateId(length: 6);
      await _db.collection('households').doc(householdId).set({
        'memberIds': [_currentUser!.uid],
        'roles': {_currentUser!.uid: 'admin'},
        'monthlyLimit': monthlyBudget,
        'inviteCode': inviteCode,
      });
      await _db.collection('users').doc(_currentUser!.uid).update({
        'householdId': householdId,
      });
      _household = Household(
        id: householdId,
        memberIds: [_currentUser!.uid],
        roles: {_currentUser!.uid: 'admin'},
        monthlyLimit: monthlyBudget,
        inviteCode: inviteCode,
      );
      _householdMembers[_currentUser!.uid] = _currentUser!;
      // Ensure we subscribe to realtime updates for this household and its transactions
      await _subscribeToHousehold(householdId);
      await _subscribeToTransactions(householdId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Create household error: $e');
      return false;
    }
  }

  // Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // App State
  UserModel? _currentUser;
  Household? _household;
  // Realtime listeners
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _householdListener;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _transactionsListener;

  // Sync state for showing a short-lived loading modal while subscriptions initialize
  bool _isSyncing = false;
  bool _householdSynced = false;
  bool _transactionsSynced = false;

  // Caches
  final List<app.Transaction> _transactions = [];
  final Map<String, List<Comment>> _comments =
      {}; // transactionId -> List<Comment>
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _commentsListeners = {};
  final Map<String, UserModel> _householdMembers = {};
  final List<SavingsGoal> _goals = [];

  // ================= GETTERS =================
  UserModel? get currentUser => _currentUser;
  Household? get household => _household;
  List<app.Transaction> get transactions => _transactions;
  List<SavingsGoal> get goals => _goals;

  bool get isSyncing => _isSyncing;

  bool get isLoggedIn => _currentUser != null;
  bool get hasHousehold => _household != null;
  bool get isAdmin => _household?.roles[_currentUser?.uid] == 'admin';

  double get totalSpent => _transactions
      .where((t) => t.type == app.TransactionType.expense)
      .fold(0.0, (acc, t) => acc + t.amount);

  double get totalIncome => _transactions
      .where((t) => t.type == app.TransactionType.income)
      .fold(0.0, (acc, t) => acc + t.amount);

  double get monthlyLimit => _household?.monthlyLimit ?? 0;
  double get remaining => monthlyLimit - totalSpent;
  double get balance => totalIncome - totalSpent;

  List<UserModel> get members => _householdMembers.values.toList();

  // Aggregations for charts
  double get totalExpenses => _transactions
      .where((t) => t.type == app.TransactionType.expense)
      .fold(0.0, (s, t) => s + t.amount);

  double get totalIncomes => _transactions
      .where((t) => t.type == app.TransactionType.income)
      .fold(0.0, (s, t) => s + t.amount);

  /// Category -> total amount (expenses only)
  Map<String, double> get categoryTotals {
    final Map<String, double> map = {};
    for (final t in _transactions) {
      if (t.type != app.TransactionType.expense) continue;
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return map;
  }

  /// Member contributions map: userId -> net amount (income positive, expense negative)
  Map<String, double> get memberContributions {
    final Map<String, double> map = {};
    for (final t in _transactions) {
      final id = t.createdBy;
      final delta = t.type == app.TransactionType.income ? t.amount : -t.amount;
      map[id] = (map[id] ?? 0) + delta;
    }
    return map;
  }

  // ================= HELPERS =================
  String _generateId({int length = 8}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)])
        .join();
  }

  void _startSync() {
    _isSyncing = true;
    _householdSynced = false;
    _transactionsSynced = false;
    notifyListeners();
  }

  void _updateSyncState() {
    if (!_isSyncing) return;
    if (_householdSynced && _transactionsSynced) {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ================= AUTH =================
  Future<String?> login(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = result.user!;
      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return 'User document not found';

      _currentUser = UserModel.fromJson(user.uid, userDoc.data()!);

      // Recovery: If user is admin in any household but missing householdId, fix it
      if (_currentUser!.householdId == null) {
        final adminQuery = await _db
            .collection('households')
            .where('roles.${_currentUser!.uid}', isEqualTo: 'admin')
            .get();
        if (adminQuery.docs.isNotEmpty) {
          final householdId = adminQuery.docs.first.id;
          await _db.collection('users').doc(_currentUser!.uid).update({
            'householdId': householdId,
          });
          _currentUser = _currentUser!.copyWith(householdId: householdId);
        }
      }
      if (_currentUser!.householdId != null) {
        _startSync();
        _startSync();
        await _subscribeToHousehold(_currentUser!.householdId!);
        await _subscribeToTransactions(_currentUser!.householdId!);
        await _loadGoals();
      }

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signup(
    String name,
    String email,
    String password,
    double monthlyBudget, {
    String? inviteCode,
  }) async {
    try {
      // If inviteCode provided, validate household exists and has space
      String? targetHouseholdId;
      if (inviteCode != null && inviteCode.trim().isNotEmpty) {
        final q = await _db
            .collection('households')
            .where('inviteCode', isEqualTo: inviteCode.trim())
            .get();
        if (q.docs.isEmpty) return 'Invalid invite code';
        final householdDoc = q.docs.first;
        // No member limit now
        targetHouseholdId = householdDoc.id;
      }

      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = result.user!;

      // Create user document
      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name,
        'email': email,
        'householdId': targetHouseholdId,
        'monthlyBudget': monthlyBudget,
        'createdAt': Timestamp.now(),
      });

      if (targetHouseholdId != null) {
        // Join existing household as contributor. If updating household is
        // forbidden by security rules, create a join request instead.
        try {
          await _db.collection('households').doc(targetHouseholdId).update({
            'memberIds': FieldValue.arrayUnion([user.uid]),
            'roles.${user.uid}': 'contributor',
          });

          _currentUser = UserModel(
            uid: user.uid,
            name: name,
            email: email,
            householdId: targetHouseholdId,
          );

          _startSync();
          await _subscribeToHousehold(targetHouseholdId);
        } on FirebaseException catch (e) {
          if (e.code == 'permission-denied') {
            // Create a join request document so the household admin can accept.
            await _db.collection('join_requests').add({
              'userId': user.uid,
              'name': name,
              'email': email,
              'householdId': targetHouseholdId,
              'inviteCode': inviteCode,
              'status': 'pending',
              'createdAt': Timestamp.now(),
            });

            // Update user's householdId locally and in users collection so
            // app shows the correct household context where possible.
            await _db.collection('users').doc(user.uid).update({
              'householdId': targetHouseholdId,
            });

            _currentUser = UserModel(
              uid: user.uid,
              name: name,
              email: email,
              householdId: targetHouseholdId,
            );

            // Load household data (the user may not yet be listed in members)
            _startSync();
            await _subscribeToHousehold(targetHouseholdId);

            // Indicate pending join to the caller
            return 'PENDING_JOIN';
          }
          rethrow;
        }
      } else {
        // Create new household and assign admin
        final householdId = _db.collection('households').doc().id;
        final newInvite = _generateId();
        await _db.collection('households').doc(householdId).set({
          'memberIds': [user.uid],
          'roles': {user.uid: 'admin'},
          'monthlyLimit': monthlyBudget,
          'inviteCode': newInvite,
        });

        _currentUser = UserModel(
          uid: user.uid,
          name: name,
          email: email,
          householdId: householdId,
        );

        _household = Household(
          id: householdId,
          memberIds: [user.uid],
          roles: {user.uid: 'admin'},
          monthlyLimit: monthlyBudget,
          inviteCode: newInvite,
        );

        _householdMembers[user.uid] = _currentUser!;
        // When creating via signup, subscribe to realtime updates as well
        await _subscribeToHousehold(householdId);
        await _subscribeToTransactions(householdId);
      }

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    _currentUser = null;
    _household = null;
    _transactions.clear();
    _comments.clear();
    _householdMembers.clear();
    _goals.clear();
    await _householdListener?.cancel();
    _householdListener = null;
    await _transactionsListener?.cancel();
    _transactionsListener = null;
    await _cancelAllCommentListeners();
    notifyListeners();
  }

  // ================= HOUSEHOLD =================
  // ignore: unused_element
  Future<void> _loadHousehold(String householdId) async {
    final doc = await _db.collection('households').doc(householdId).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    _household = Household(
      id: householdId,
      memberIds: List<String>.from(data['memberIds']),
      roles: Map<String, String>.from(data['roles']),
      monthlyLimit: (data['monthlyLimit'] as num).toDouble(),
      inviteCode: data['inviteCode'],
    );

    // Load member details
    _householdMembers.clear();
    for (final uid in _household!.memberIds) {
      final userDoc = await _db.collection('users').doc(uid).get();
      if (userDoc.exists) {
        _householdMembers[uid] = UserModel.fromJson(uid, userDoc.data()!);
      }
    }
  }

  Future<void> updateBudgetLimit(double amount) async {
    if (_household == null) return;
    await _db.collection('households').doc(_household!.id).update({
      'monthlyLimit': amount,
    });
    _household = Household(
      id: _household!.id,
      memberIds: _household!.memberIds,
      roles: _household!.roles,
      monthlyLimit: amount,
      inviteCode: _household!.inviteCode,
    );
    notifyListeners();
  }

  Future<bool> joinHousehold(String inviteCode) async {
    try {
      final query = await _db
          .collection('households')
          .where('inviteCode', isEqualTo: inviteCode)
          .get();
      if (query.docs.isEmpty) {
        debugPrint('Join household error: Invalid code');
        return false;
      }

      final householdDoc = query.docs.first;
      final householdId = householdDoc.id;
      final userId = _currentUser!.uid;
      // Use a Firestore batch to update both user and household atomically
      final batch = _db.batch();
      final householdRef = _db.collection('households').doc(householdId);
      final userRef = _db.collection('users').doc(userId);
      batch.update(householdRef, {
        'memberIds': FieldValue.arrayUnion([userId]),
        'roles.$userId': 'contributor',
      });
      batch.update(userRef, {
        'householdId': householdId,
      });
      await batch.commit();
      debugPrint(
          '[JoinHousehold] batch commit successful for household $householdId user $userId');

      _startSync();
      await _subscribeToHousehold(householdId);
      await _subscribeToTransactions(householdId);
      await _loadGoals();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Join household error: $e');
      return false;
    }
  }

  void leaveHousehold() {
    if (_currentUser == null || _household == null) return;
    final userId = _currentUser!.uid;
    final householdId = _household!.id;
    final isAdmin = _household!.roles[userId] == 'admin';
    final memberIds = List<String>.from(_household!.memberIds);
    final roles = Map<String, String>.from(_household!.roles);
    // Remove user from household's memberIds and roles
    _db.collection('households').doc(householdId).update({
      'memberIds': FieldValue.arrayRemove([userId]),
      'roles.$userId': FieldValue.delete(),
    });
    // Remove householdId from user
    _db.collection('users').doc(userId).update({
      'householdId': FieldValue.delete(),
    });
    // If admin leaves, handle admin transfer or household deletion
    if (isAdmin) {
      // Remove admin from local roles and memberIds
      memberIds.remove(userId);
      roles.remove(userId);
      if (memberIds.length == 1) {
        // Only one member left, delete household
        final lastUserId = memberIds.first;
        _db.collection('households').doc(householdId).delete();
        _db.collection('users').doc(lastUserId).update({
          'householdId': FieldValue.delete(),
        });
      } else if (memberIds.length > 1) {
        // Assign new admin (first contributor)
        final newAdminId = memberIds.first;
        _db.collection('households').doc(householdId).update({
          'roles.$newAdminId': 'admin',
        });
      }
    }
    _household = null;
    _transactions.clear();
    _householdMembers.clear();
    // cancel any active comments listeners for transactions
    _cancelAllCommentListeners();
    notifyListeners();
  }

  /// Admin: accept a pending join request and add user to household
  Future<bool> acceptJoinRequest(
      String requestId, String userId, String householdId) async {
    try {
      final householdRef = _db.collection('households').doc(householdId);
      await householdRef.update({
        'memberIds': FieldValue.arrayUnion([userId]),
        'roles.$userId': 'contributor',
      });
      await _db
          .collection('users')
          .doc(userId)
          .update({'householdId': householdId});
      await _db.collection('join_requests').doc(requestId).update({
        'status': 'accepted',
        'handledAt': Timestamp.now(),
      });
      debugPrint(
          '[AcceptJoin] request $requestId accepted for user $userId into $householdId');
      _startSync();
      await _subscribeToHousehold(householdId);
      await _subscribeToTransactions(householdId);
      await _loadGoals();
      notifyListeners();
      return true;
    } on FirebaseException catch (e) {
      debugPrint('acceptJoinRequest failed: $e');
      return false;
    }
  }

  /// Admin: reject a pending join request (marks as rejected or deletes)
  Future<bool> rejectJoinRequest(String requestId) async {
    try {
      await _db.collection('join_requests').doc(requestId).update({
        'status': 'rejected',
        'handledAt': Timestamp.now(),
      });
      return true;
    } on FirebaseException catch (e) {
      debugPrint('rejectJoinRequest failed: $e');
      try {
        await _db.collection('join_requests').doc(requestId).delete();
        return true;
      } catch (e2) {
        debugPrint('rejectJoinRequest delete fallback failed: $e2');
      }
      return false;
    }
  }

  // ================= TRANSACTIONS =================
  Future<void> _loadTransactions() async {
    if (_household == null) return;
    final snap = await _db
        .collection('households')
        .doc(_household!.id)
        .collection('transactions')
        .orderBy('date', descending: true)
        .get();

    _transactions
      ..clear()
      ..addAll(snap.docs.map((d) => app.Transaction.fromMap(d.id, d.data())));

    notifyListeners();
  }

  Future<void> addTransaction(app.Transaction transaction) async {
    if (_household == null || _currentUser == null) return;

    final enriched = transaction.copyWith(
      createdBy: _currentUser!.uid,
      createdByName: _currentUser!.name,
    );

    try {
      final docRef = await _db
          .collection('households')
          .doc(_household!.id)
          .collection('transactions')
          .add(enriched.toMap());

      debugPrint(
          '[AddTransaction] created ${docRef.id} in household ${_household!.id} by ${_currentUser!.uid}');
      _transactions.add(enriched.copyWith(id: docRef.id));
      notifyListeners();
    } on FirebaseException catch (e) {
      debugPrint('[AddTransaction] failed: ${e.code} ${e.message}');
      if (e.code == 'permission-denied') {
        // Fallback: create a transaction request so admins can approve it
        await _db
            .collection('households')
            .doc(_household!.id)
            .collection('transaction_requests')
            .add({
          ...enriched.toMap(),
          'status': 'pending',
          'createdAt': Timestamp.now(),
        });

        // Add a local pending transaction so contributor sees it immediately
        final pendingId = 'pending-${DateTime.now().millisecondsSinceEpoch}';
        final pending = enriched.copyWith(
          id: pendingId,
          note: '${enriched.note ?? ''} (Pending approval)',
        );
        _transactions.add(pending);
        notifyListeners();
        return;
      }
      rethrow;
    }
  }

  /// Manually refresh household-related data (transactions, goals, members)
  Future<void> refresh() async {
    if (_household == null) return;
    try {
      // Re-fetch household doc to refresh members/roles
      final doc = await _db.collection('households').doc(_household!.id).get();
      if (doc.exists) {
        final data = doc.data()!;
        _household = Household(
          id: _household!.id,
          memberIds: List<String>.from(data['memberIds'] ?? []),
          roles: Map<String, String>.from(data['roles'] ?? {}),
          monthlyLimit: (data['monthlyLimit'] as num?)?.toDouble() ?? 0,
          inviteCode: data['inviteCode'],
        );
        _householdMembers.clear();
        for (final uid in _household!.memberIds) {
          final userDoc = await _db.collection('users').doc(uid).get();
          if (userDoc.exists) {
            _householdMembers[uid] = UserModel.fromJson(uid, userDoc.data()!);
          }
        }
      }

      await _loadTransactions();
      await _loadGoals();
      notifyListeners();
    } catch (e) {
      debugPrint('Refresh failed: $e');
    }
  }

  Future<void> deleteTransaction(String transactionId) async {
    if (_household == null) return;
    await _db
        .collection('households')
        .doc(_household!.id)
        .collection('transactions')
        .doc(transactionId)
        .delete();
    _transactions.removeWhere((t) => t.id == transactionId);
    notifyListeners();
  }

  // ================= COMMENTS =================
  List<Comment> getComments(String transactionId) =>
      _comments[transactionId] ?? [];

  Future<void> loadComments(String transactionId) async {
    if (_household == null) return;
    final snap = await _db
        .collection('households')
        .doc(_household!.id)
        .collection('transactions')
        .doc(transactionId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .get();

    final list =
        snap.docs.map((d) => Comment.fromJson(d.id, d.data())).toList();
    _comments[transactionId] = list;
    notifyListeners();
  }

  Future<void> addComment(String transactionId, String text) async {
    if (_household == null || _currentUser == null) return;
    final commentCol = _db
        .collection('households')
        .doc(_household!.id)
        .collection('transactions')
        .doc(transactionId)
        .collection('comments');

    final docRef = commentCol.doc();

    final commentData = {
      'userId': _currentUser!.uid,
      'userName': _currentUser!.name,
      'text': text,
      'timestamp': Timestamp.now(),
    };

    await docRef.set(commentData);

    // local update will arrive via realtime listener, but add optimistic UI now
    final newComment = Comment(
      id: docRef.id,
      userId: _currentUser!.uid,
      userName: _currentUser!.name,
      text: text,
      timestamp: DateTime.now(),
    );

    final list = _comments[transactionId] ?? [];
    list.add(newComment);
    _comments[transactionId] = list;
    notifyListeners();
  }

  /// Subscribe to real-time comments for a given transaction.
  Future<void> subscribeToComments(String transactionId) async {
    if (_household == null) return;
    // cancel existing
    await _commentsListeners[transactionId]?.cancel();
    final sub = _db
        .collection('households')
        .doc(_household!.id)
        .collection('transactions')
        .doc(transactionId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snap) {
      _comments[transactionId] =
          snap.docs.map((d) => Comment.fromJson(d.id, d.data())).toList();
      notifyListeners();
    }, onError: (e) {
      debugPrint('[Comments Listener] error for $transactionId: $e');
    });
    _commentsListeners[transactionId] = sub;
  }

  Future<void> unsubscribeFromComments(String transactionId) async {
    await _commentsListeners[transactionId]?.cancel();
    _commentsListeners.remove(transactionId);
  }

  Future<void> _cancelAllCommentListeners() async {
    for (final sub in _commentsListeners.values) {
      await sub.cancel();
    }
    _commentsListeners.clear();
  }

  // ================= SAVINGS GOALS =================
  Future<void> _loadGoals() async {
    if (_household == null) return;
    final snap = await _db
        .collection('households')
        .doc(_household!.id)
        .collection('savingsGoals')
        .orderBy('createdAt', descending: true)
        .get();

    _goals
      ..clear()
      ..addAll(snap.docs.map((d) => SavingsGoal.fromMap(d.id, d.data())));
    notifyListeners();
  }

  // ================= AI INSIGHTS =================
  /// Request AI-driven advisory insight for the household.
  /// Returns the assistant text or throws on error.
  Future<String> requestAIPrediction({bool store = true}) async {
    if (_household == null) throw StateError('Not in a household');
    if (!OpenAIService.instance.isConfigured) {
      throw StateError('OpenAI API key not configured');
    }

    // Build prompt from household state and recent transactions
    final buffer = StringBuffer();
    buffer.writeln('You are a helpful financial assistant.');
    buffer.writeln('Household monthly budget: Rs. ${_household!.monthlyLimit}');
    buffer.writeln('Total income: Rs. ${totalIncome.toStringAsFixed(2)}');
    buffer.writeln('Total expenses: Rs. ${totalSpent.toStringAsFixed(2)}');
    buffer.writeln('Remaining: Rs. ${remaining.toStringAsFixed(2)}');
    buffer.writeln('\nCategory breakdown:');
    categoryTotals.forEach((k, v) {
      buffer.writeln('- $k: Rs. ${v.toStringAsFixed(2)}');
    });

    buffer.writeln('\nRecent transactions (most recent first):');
    for (final t in _transactions.take(10)) {
      buffer.writeln(
          '- ${t.date.toIso8601String()} | ${t.title} | ${t.category} | ${t.type == app.TransactionType.expense ? 'Expense' : 'Income'} | Rs. ${t.amount.toStringAsFixed(2)} | by ${t.createdByName}');
    }

    buffer.writeln(
        '\nPlease provide:\n1) A short summary of the household financial status.\n2) Top 3 actionable suggestions to improve budget or reduce expenses.\n3) A simple 3-point projection for next month (spend/income) based on recent trends.');

    final prompt = buffer.toString();

    final result = await OpenAIService.instance.chat(prompt);

    if (store) {
      try {
        final doc = await _db
            .collection('households')
            .doc(_household!.id)
            .collection('ai_insights')
            .add({
          'text': result,
          'createdAt': Timestamp.now(),
          'source': 'manual',
        });
        debugPrint(
            '[AI] Stored insight ${doc.id} for household ${_household!.id}');
      } catch (e) {
        debugPrint('[AI] Failed to store insight: $e');
      }
    }

    return result;
  }

  /// Fetch the latest AI insight for the current household (or null)
  Future<String?> fetchLatestAIPrediction() async {
    if (_household == null) return null;
    final snap = await _db
        .collection('households')
        .doc(_household!.id)
        .collection('ai_insights')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data()['text'] as String?;
  }

  Future<String?> createGoal({
    required String title,
    required double targetAmount,
    required DateTime deadline,
    String? notes,
  }) async {
    if (_household == null || _currentUser == null) return 'Not in a household';

    final goalsCol = _db
        .collection('households')
        .doc(_household!.id)
        .collection('savingsGoals');

    final docRef = goalsCol.doc();

    final goal = SavingsGoal(
      id: docRef.id,
      title: title,
      targetAmount: targetAmount,
      currentAmount: 0,
      deadline: deadline,
      createdBy: _currentUser!.uid,
      createdAt: DateTime.now(),
      notes: notes,
      archived: false,
    );

    await docRef.set({
      'title': goal.title,
      'targetAmount': goal.targetAmount,
      'currentAmount': goal.currentAmount,
      'deadline': Timestamp.fromDate(goal.deadline),
      'createdBy': goal.createdBy,
      'createdAt': Timestamp.fromDate(goal.createdAt),
      'notes': goal.notes,
      'archived': goal.archived,
    });

    _goals.insert(0, goal);
    notifyListeners();
    return null;
  }

  Future<String?> updateGoal(
    SavingsGoal goal, {
    String? title,
    double? targetAmount,
    DateTime? deadline,
    String? notes,
    bool? archived,
  }) async {
    if (_household == null) return 'Not in a household';

    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (targetAmount != null) updates['targetAmount'] = targetAmount;
    if (deadline != null) updates['deadline'] = Timestamp.fromDate(deadline);
    if (notes != null) updates['notes'] = notes;
    if (archived != null) updates['archived'] = archived;

    await _db
        .collection('households')
        .doc(_household!.id)
        .collection('savingsGoals')
        .doc(goal.id)
        .update(updates);

    final idx = _goals.indexWhere((g) => g.id == goal.id);
    if (idx != -1) {
      _goals[idx] = SavingsGoal(
        id: goal.id,
        title: title ?? goal.title,
        targetAmount: targetAmount ?? goal.targetAmount,
        currentAmount: goal.currentAmount,
        deadline: deadline ?? goal.deadline,
        createdBy: goal.createdBy,
        createdAt: goal.createdAt,
        notes: notes ?? goal.notes,
        archived: archived ?? goal.archived,
      );
      notifyListeners();
    }
    return null;
  }

  Future<String?> allocateToGoal(String goalId, double amount) async {
    if (_household == null || amount <= 0) return 'Invalid amount';

    final docRef = _db
        .collection('households')
        .doc(_household!.id)
        .collection('savingsGoals')
        .doc(goalId);

    await _db.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      if (!snap.exists) throw Exception('Goal not found');

      final data = snap.data()!;
      final current = (data['currentAmount'] as num).toDouble();
      final newAmount = current + amount;
      txn.update(docRef, {'currentAmount': newAmount});
    });

    final idx = _goals.indexWhere((g) => g.id == goalId);
    if (idx != -1) {
      final g = _goals[idx];
      _goals[idx] = SavingsGoal(
        id: g.id,
        title: g.title,
        targetAmount: g.targetAmount,
        currentAmount: g.currentAmount + amount,
        deadline: g.deadline,
        createdBy: g.createdBy,
        createdAt: g.createdAt,
        notes: g.notes,
        archived: g.archived,
      );
      notifyListeners();
    }
    return null;
  }

  Future<void> archiveGoal(String goalId) async {
    if (_household == null) return;

    await _db
        .collection('households')
        .doc(_household!.id)
        .collection('savingsGoals')
        .doc(goalId)
        .update({'archived': true});

    final idx = _goals.indexWhere((g) => g.id == goalId);
    if (idx != -1) {
      final g = _goals[idx];
      _goals[idx] = SavingsGoal(
        id: g.id,
        title: g.title,
        targetAmount: g.targetAmount,
        currentAmount: g.currentAmount,
        deadline: g.deadline,
        createdBy: g.createdBy,
        createdAt: g.createdAt,
        notes: g.notes,
        archived: true,
      );
      notifyListeners();
    }
  }

  // ================= REPORTS =================
  Future<void> exportMonthlyReport(int year, int month) async {
    if (_household == null) return;

    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1).subtract(const Duration(days: 1));

    final query = await _db
        .collection('households')
        .doc(_household!.id)
        .collection('transactions')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    final txns = query.docs
        .map((doc) => app.Transaction.fromMap(doc.id, doc.data()))
        .toList();

    final totalExpenses = txns
        .where((t) => t.type == app.TransactionType.expense)
        .fold(0.0, (acc, t) => acc + t.amount);

    final totalIncome = txns
        .where((t) => t.type == app.TransactionType.income)
        .fold(0.0, (acc, t) => acc + t.amount);

    final balance = totalIncome - totalExpenses;
    final remainingBudget = monthlyLimit - totalExpenses;

    final categoryBreakdown = <String, double>{};
    for (final t in txns.where((t) => t.type == app.TransactionType.expense)) {
      categoryBreakdown[t.category] =
          (categoryBreakdown[t.category] ?? 0) + t.amount;
    }

    // Per-user summary
    final userSummary =
        <String, Map<String, double>>{}; // uid -> {income, expense}
    for (final t in txns) {
      final uid = t.createdBy;
      userSummary.putIfAbsent(uid, () => {'income': 0.0, 'expense': 0.0});
      if (t.type == app.TransactionType.income) {
        userSummary[uid]!['income'] = userSummary[uid]!['income']! + t.amount;
      } else {
        userSummary[uid]!['expense'] = userSummary[uid]!['expense']! + t.amount;
      }
    }
    // Get user names
    final userNames = <String, String>{};
    for (final member in _householdMembers.values) {
      userNames[member.uid] = member.name;
    }

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Monthly Financial Report',
                style:
                    pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.Text('Month: $month/$year',
                style: const pw.TextStyle(fontSize: 16)),
            pw.Text('Household Code: ${_household!.inviteCode}',
                style: const pw.TextStyle(fontSize: 16)),
            pw.SizedBox(height: 20),
            pw.Text('Summary',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['Metric', 'Amount'],
              data: [
                ['Total Budget', 'Rs. ${monthlyLimit.toStringAsFixed(2)}'],
                ['Total Income', 'Rs. ${totalIncome.toStringAsFixed(2)}'],
                ['Total Expenses', 'Rs. ${totalExpenses.toStringAsFixed(2)}'],
                [
                  'Remaining Budget',
                  'Rs. ${remainingBudget.toStringAsFixed(2)}'
                ],
                [
                  'Balance (Income - Expense)',
                  'Rs. ${balance.toStringAsFixed(2)}'
                ],
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text('Contributors Breakdown',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['Name', 'Role', 'Income', 'Expense'],
              data: userSummary.entries.map((e) {
                final uid = e.key;
                final name = userNames[uid] ?? uid;
                final role = _household!.roles[uid] ?? '';
                return [
                  name,
                  role[0].toUpperCase() + role.substring(1),
                  'Rs. ${e.value['income']!.toStringAsFixed(2)}',
                  'Rs. ${e.value['expense']!.toStringAsFixed(2)}',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Spending by Category',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['Category', 'Amount'],
              data: categoryBreakdown.entries
                  .map((e) => [e.key, 'Rs. ${e.value.toStringAsFixed(2)}'])
                  .toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Text('All Transactions',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Title', 'Category', 'Type', 'Amount', 'By'],
              data: txns
                  .map((t) => [
                        t.date.toString().split(' ').first,
                        t.title,
                        t.category,
                        t.type == app.TransactionType.expense
                            ? 'Expense'
                            : 'Income',
                        'Rs. ${t.amount.toStringAsFixed(2)}',
                        userNames[t.createdBy] ?? t.createdBy,
                      ])
                  .toList(),
            ),
          ],
        ),
      ),
    );

    final bytes = await pdf.save();

    if (kIsWeb) {
      await Printing.layoutPdf(onLayout: (format) async => bytes);
      return;
    }

    Directory? targetDir;
    try {
      targetDir = await getDownloadsDirectory();
    } catch (_) {
      targetDir = null;
    }
    targetDir ??= await getApplicationDocumentsDirectory();

    final filePath = '${targetDir.path}/monthly_report_${month}_$year.pdf';
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    try {
      await Printing.sharePdf(
          bytes: bytes, filename: 'monthly_report_${month}_$year.pdf');
    } catch (_) {}
  }

  // ================= DEMO =================
  Future<void> demoLogin() async {
    await signup(
      'Demo User',
      'demo${_generateId()}@mail.com',
      'password',
      50000,
    );
  }

  Future<void> _subscribeToHousehold(String householdId) async {
    // Cancel previous listener if any
    await _householdListener?.cancel();
    _householdListener = _db
        .collection('households')
        .doc(householdId)
        .snapshots()
        .listen((doc) async {
      debugPrint('[Household Listener] Household updated for $householdId');
      if (!_householdSynced) {
        _householdSynced = true;
        _updateSyncState();
      }
      if (!doc.exists) {
        _household = null;
        _householdMembers.clear();
        notifyListeners();
        return;
      }
      final data = doc.data()!;
      _household = Household(
        id: householdId,
        memberIds: List<String>.from(data['memberIds']),
        roles: Map<String, String>.from(data['roles']),
        monthlyLimit: (data['monthlyLimit'] as num).toDouble(),
        inviteCode: data['inviteCode'],
      );
      // Load member details
      _householdMembers.clear();
      for (final uid in _household!.memberIds) {
        final userDoc = await _db.collection('users').doc(uid).get();
        if (userDoc.exists) {
          _householdMembers[uid] = UserModel.fromJson(uid, userDoc.data()!);
        }
      }
      debugPrint(
          '[Household Listener] Members: ${_householdMembers.keys.join(", ")}');
      notifyListeners();
    });
  }

  Future<void> _subscribeToTransactions(String householdId) async {
    await _transactionsListener?.cancel();
    _transactionsListener = _db
        .collection('households')
        .doc(householdId)
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots()
        .listen((snap) {
      if (!_transactionsSynced) {
        _transactionsSynced = true;
        _updateSyncState();
      }
      _transactions
        ..clear()
        ..addAll(snap.docs.map((d) => app.Transaction.fromMap(d.id, d.data())));
      notifyListeners();
    });
  }
}
