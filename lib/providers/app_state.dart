// lib/providers/app_state.dart
import 'dart:math';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

import '../models/transaction.dart' as app;
import '../models/user_model.dart';
import '../models/household.dart';
import '../models/comment.dart';

class AppState extends ChangeNotifier {
  // Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // App State
  UserModel? _currentUser;
  Household? _household;

  // Strongly typed
  final List<app.Transaction> _transactions = [];
  final Map<String, List<Comment>> _comments = {};
  final Map<String, UserModel> _householdMembers = {};

  // ================= GETTERS =================
  UserModel? get currentUser => _currentUser;
  Household? get household => _household;
  List<app.Transaction> get transactions => _transactions;

  bool get isLoggedIn => _currentUser != null;
  bool get hasHousehold => _household != null;
  bool get isAdmin => _household?.roles[_currentUser?.uid] == 'admin';
  double get totalSpent => _transactions
      .where((t) => t.type == app.TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);
  double get totalIncome => _transactions
      .where((t) => t.type == app.TransactionType.income)
      .fold(0.0, (sum, t) => sum + t.amount);
  double get monthlyLimit => _household?.monthlyLimit ?? 0;
  double get remaining => monthlyLimit - totalSpent;
  List<UserModel> get members => _householdMembers.values.toList();

  // ================= HELPERS =================
  String _generateId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _storeFCMToken() async {
    if (_currentUser == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _db.collection('users').doc(_currentUser!.uid).update({
          'fcmToken': token,
        });
      }
    } catch (e) {
      debugPrint("FCM token error ignored: $e");
    }
  }

  Future<void> _sendNotificationToHousehold(String title, String body) async {
    if (_household == null || _currentUser == null) return;

    final serverKey = 'YOUR_FCM_SERVER_KEY'; // Replace with actual key

    for (final memberId in _household!.memberIds) {
      if (memberId == _currentUser!.uid) continue;

      final memberDoc = await _db.collection('users').doc(memberId).get();
      final token = memberDoc.data()?['fcmToken'];
      if (token != null) {
        await http.post(
          Uri.parse('https://fcm.googleapis.com/fcm/send'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'key=$serverKey',
          },
          body: jsonEncode({
            'to': token,
            'notification': {'title': title, 'body': body},
          }),
        );
      }
    }
  }

  // ================= AUTH =================
  Future<String?> login(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = result.user!;
      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return "User document not found";

      _currentUser = UserModel.fromJson(user.uid, userDoc.data()!);

      if (_currentUser!.householdId != null) {
        await _loadHousehold(_currentUser!.householdId!);
        await _loadTransactions();
      }

      _storeFCMToken(); // Do not await

      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signup(
      String name, String email, String password, double monthlyBudget) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = result.user!;
      final householdId = _db.collection('households').doc().id;
      final inviteCode = _generateId();

      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name,
        'email': email,
        'householdId': householdId,
        'monthlyBudget': monthlyBudget,
        'createdAt': Timestamp.now(),
      });

      await _db.collection('households').doc(householdId).set({
        'memberIds': [user.uid],
        'roles': {user.uid: 'admin'},
        'monthlyLimit': monthlyBudget,
        'inviteCode': inviteCode,
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
        inviteCode: inviteCode,
      );

      _householdMembers[user.uid] = _currentUser!;

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
    notifyListeners();
  }

  // ================= HOUSEHOLD =================
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

    // Load members
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
      if (query.docs.isEmpty) return false;

      final householdDoc = query.docs.first;
      final householdId = householdDoc.id;

      await _db.collection('households').doc(householdId).update({
        'memberIds': FieldValue.arrayUnion([_currentUser!.uid]),
        'roles.${_currentUser!.uid}': 'member',
      });

      await _db.collection('users').doc(_currentUser!.uid).update({
        'householdId': householdId,
      });

      await _loadHousehold(householdId);
      await _loadTransactions();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Join household error: $e");
      return false;
    }
  }

  void leaveHousehold() {
    // TODO: implement leave logic
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
      ..addAll(snap.docs.map((d) {
        final data = d.data();
        final rawDate = data['date'];
        final parsedDate = rawDate is Timestamp ? rawDate.toDate() : DateTime.now();
        final parsedType =
            data['type'] == 'income' ? app.TransactionType.income : app.TransactionType.expense;

        return app.Transaction(
          id: d.id,
          title: data['title'],
          amount: (data['amount'] as num).toDouble(),
          category: data['category'],
          type: parsedType,
          date: parsedDate,
          createdBy: data['createdBy'] ?? '',
          createdByName: data['createdByName'] ?? '',
          note: data['note'],
        );
      }));

    notifyListeners();
  }

  Future<void> addTransaction(app.Transaction transaction) async {
    if (_household == null || _currentUser == null) return;

    final enriched = transaction.copyWith(
      createdBy: _currentUser!.uid,
      createdByName: _currentUser!.name,
    );

    final docRef = await _db
        .collection('households')
        .doc(_household!.id)
        .collection('transactions')
        .add(enriched.toMap());

    _transactions.add(enriched.copyWith(id: docRef.id));
    notifyListeners();

    final type = transaction.type == app.TransactionType.expense ? 'Expense' : 'Income';
    await _sendNotificationToHousehold(
        'New $type Added', '${_currentUser!.name} added Rs. ${transaction.amount} for ${transaction.title}');
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
  List<Comment> getComments(String transactionId) => _comments[transactionId] ?? [];
  void addComment(String transactionId, String text) {
    // TODO: implement comment
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

    final transactions = query.docs.map((doc) {
      final data = doc.data();
      final rawDate = data['date'];
      final parsedDate = rawDate is Timestamp ? rawDate.toDate() : DateTime.now();
      final parsedType =
          data['type'] == 'income' ? app.TransactionType.income : app.TransactionType.expense;

      return app.Transaction(
        id: doc.id,
        title: data['title'],
        amount: (data['amount'] as num).toDouble(),
        category: data['category'],
        type: parsedType,
        date: parsedDate,
        note: data['note'],
        createdBy: data['createdBy'] ?? '',
        createdByName: data['createdByName'] ?? '',
      );
    }).toList();

    // Totals
    final totalExpenses =
        transactions.where((t) => t.type == app.TransactionType.expense).fold(0.0, (sum, t) => sum + t.amount);
    final totalIncome =
        transactions.where((t) => t.type == app.TransactionType.income).fold(0.0, (sum, t) => sum + t.amount);
    final savings = _household!.monthlyLimit - totalExpenses;

    // Category breakdown
    final categoryBreakdown = <String, double>{};
    for (final t in transactions.where((t) => t.type == app.TransactionType.expense)) {
      categoryBreakdown[t.category] = (categoryBreakdown[t.category] ?? 0) + t.amount;
    }

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Monthly Financial Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.Text('Month: $month/$year', style: pw.TextStyle(fontSize: 16)),
            pw.Text('Household: ${_household!.inviteCode}', style: pw.TextStyle(fontSize: 16)),
            pw.SizedBox(height: 20),
            pw.Text('Summary', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Metric', 'Amount'],
              data: [
                ['Total Budget', 'Rs. ${_household!.monthlyLimit}'],
                ['Total Income', 'Rs. ${totalIncome.toStringAsFixed(2)}'],
                ['Total Expenses', 'Rs. ${totalExpenses.toStringAsFixed(2)}'],
                ['Savings', 'Rs. ${savings.toStringAsFixed(2)}'],
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text('Spending by Category', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Category', 'Amount'],
              data: categoryBreakdown.entries.map((e) => [e.key, 'Rs. ${e.value.toStringAsFixed(2)}']).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Text('All Transactions', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Date', 'Title', 'Category', 'Type', 'Amount'],
              data: transactions
                  .map((t) => [t.date.toString().split(' ')[0], t.title, t.category, t.type == app.TransactionType.expense ? 'Expense' : 'Income', 'Rs. ${t.amount.toStringAsFixed(2)}'])
                  .toList(),
            ),
          ],
        ),
      ),
    );

    if (kIsWeb) {
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } else {
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/monthly_report_${month}_${year}.pdf');
      await file.writeAsBytes(await pdf.save());
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'monthly_report_${month}_${year}.pdf');
    }
  }

  // ================= DEMO =================
  Future<void> demoLogin() async {
    await signup('Demo User', 'demo${_generateId()}@mail.com', 'password', 50000);
  }
}
