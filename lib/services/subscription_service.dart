import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:micro_habit_runner/models/user_model.dart';

class SubscriptionService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  // Check if trial period is still valid
  bool isTrialValid(UserModel user) {
    if (user.subscriptionStatus != SubscriptionStatus.trial) return false;
    if (user.trialStartDate == null) return false;
    
    // Trial is valid for 7 days
    DateTime trialEndDate = user.trialStartDate!.add(const Duration(days: 7));
    return DateTime.now().isBefore(trialEndDate);
  }
  
  // Check if user can start a trial
  bool canStartTrial(UserModel user) {
    return !user.trialUsed && user.subscriptionStatus == SubscriptionStatus.free;
  }
  
  // Start free trial
  Future<void> startFreeTrial() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      if (_auth.currentUser == null) return;
      
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'subscriptionStatus': 'trial',
        'trialStartDate': Timestamp.fromDate(DateTime.now()),
        'trialUsed': true,
      });
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      if (kDebugMode) {
        print('Error starting free trial: $e');
      }
      rethrow;
    }
  }
  
  // End trial and revert to free plan
  Future<void> endTrial() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      if (_auth.currentUser == null) return;
      
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'subscriptionStatus': 'free',
      });
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      if (kDebugMode) {
        print('Error ending trial: $e');
      }
      rethrow;
    }
  }
  
  // Upgrade to premium subscription
  // Note: In a real app, this would integrate with Stripe or another payment processor
  Future<void> upgradeToPremium() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      if (_auth.currentUser == null) return;
      
      // This is a placeholder for actual payment processing
      // In a real app, you would integrate with Stripe here
      
      // After successful payment, update user status
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'subscriptionStatus': 'premium',
      });
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      if (kDebugMode) {
        print('Error upgrading to premium: $e');
      }
      rethrow;
    }
  }
  
  // Cancel premium subscription
  Future<void> cancelSubscription() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      if (_auth.currentUser == null) return;
      
      // This is a placeholder for actual subscription cancellation
      // In a real app, you would integrate with Stripe here
      
      // After successful cancellation, update user status
      await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
        'subscriptionStatus': 'free',
      });
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      if (kDebugMode) {
        print('Error canceling subscription: $e');
      }
      rethrow;
    }
  }
  
  // Check if trial has expired and update status if needed
  Future<void> checkTrialStatus(UserModel user) async {
    try {
      if (user.subscriptionStatus != SubscriptionStatus.trial) return;
      if (user.trialStartDate == null) return;
      
      // Trial is valid for 7 days
      DateTime trialEndDate = user.trialStartDate!.add(const Duration(days: 7));
      
      // If trial has expired, revert to free plan
      if (DateTime.now().isAfter(trialEndDate)) {
        await _firestore.collection('users').doc(user.id).update({
          'subscriptionStatus': 'free',
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking trial status: $e');
      }
    }
  }
}
