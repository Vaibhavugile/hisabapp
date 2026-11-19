
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'expense.dart';

class ExpenseProvider {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ExpenseProvider({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // ------------------------------------------------------------
  // FIRESTORE COLLECTION
  // ------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> get _expensesCollection {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Please login to access expenses.');
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('expenses');
  }

  // ------------------------------------------------------------
  // WATCH EXPENSES
  // ------------------------------------------------------------

  Stream<List<Expense>> watchExpenses() {
    return _expensesCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Expense.fromFirestore(doc))
          .toList();
    });
  }

  // ------------------------------------------------------------
  // ADD EXPENSE
  // ------------------------------------------------------------

  Future<String> addExpense({
    required int amountPaise,
    String note = '',
    DateTime? date,
  }) async {
    if (amountPaise <= 0) {
      throw Exception('Expense amount must be greater than zero.');
    }

    final now = date ?? DateTime.now();

    final doc = await _expensesCollection.add({
      'amountPaise': amountPaise,
      'note': note.trim(),
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  // ------------------------------------------------------------
  // UPDATE EXPENSE
  // ------------------------------------------------------------

  Future<void> updateExpense({
    required String expenseId,
    required int amountPaise,
    required String note,
    required DateTime date,
  }) async {
    if (amountPaise <= 0) {
      throw Exception('Expense amount must be greater than zero.');
    }

    await _expensesCollection.doc(expenseId).update({
      'amountPaise': amountPaise,
      'note': note.trim(),
      'createdAt': Timestamp.fromDate(date),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ------------------------------------------------------------
  // DELETE EXPENSE
  // ------------------------------------------------------------

  Future<void> deleteExpense(String expenseId) async {
    await _expensesCollection.doc(expenseId).delete();
  }

  // ------------------------------------------------------------
  // GET SINGLE EXPENSE
  // ------------------------------------------------------------

  Future<Expense?> getExpense(String expenseId) async {
    final doc = await _expensesCollection.doc(expenseId).get();

    if (!doc.exists) return null;

    return Expense.fromFirestore(doc);
  }
}
