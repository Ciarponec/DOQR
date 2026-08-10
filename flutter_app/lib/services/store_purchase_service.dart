import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'doqr_api.dart';

class StorePurchaseService extends ChangeNotifier {
  StorePurchaseService._();

  static final instance = StorePurchaseService._();
  static const proAnnualProductId = 'doqr_pro_annual';

  final InAppPurchase _store = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? _product;
  bool _initialized = false;
  bool _storeAvailable = false;
  bool _loading = false;
  bool _processing = false;
  bool _entitlementActivated = false;
  String? _error;

  ProductDetails? get product => _product;
  bool get storeAvailable => _storeAvailable;
  bool get loading => _loading;
  bool get processing => _processing;
  String? get error => _error;
  String get displayPrice => _product?.price ?? r'$14.99';

  bool takeEntitlementActivated() {
    if (!_entitlementActivated) return false;
    _entitlementActivated = false;
    return true;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    _subscription = _store.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object error) {
        _processing = false;
        _error = 'Mağaza bağlantısı kesildi. Lütfen tekrar deneyin.';
        notifyListeners();
      },
    );
    await loadProduct();
  }

  Future<void> loadProduct() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _storeAvailable = await _store.isAvailable();
      if (!_storeAvailable) {
        _error = 'Cihazdaki mağaza şu anda kullanılamıyor.';
        return;
      }
      final response = await _store.queryProductDetails({proAnnualProductId});
      if (response.error != null) {
        _error = 'Abonelik bilgisi mağazadan alınamadı.';
        return;
      }
      if (response.productDetails.isEmpty) {
        _error = defaultTargetPlatform == TargetPlatform.iOS
            ? 'DOQR Pro, App Store üzerinde yakında açılacak.'
            : 'DOQR Pro ürünü Google Play üzerinde henüz etkin değil.';
        return;
      }
      _product = response.productDetails.first;
    } catch (_) {
      _error = 'Mağaza bağlantısı kurulamadı.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> buyPro() async {
    _error = null;
    _entitlementActivated = false;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      _error = 'Satın almak için host hesabıyla giriş yapın.';
      notifyListeners();
      return;
    }
    if (_product == null) await loadProduct();
    if (_product == null) return;
    _processing = true;
    notifyListeners();
    try {
      final started = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(
          productDetails: _product!,
          applicationUserName: _accountHash(user.id),
        ),
      );
      if (!started) {
        _processing = false;
        _error = 'Satın alma ekranı açılamadı.';
        notifyListeners();
      }
    } catch (_) {
      _processing = false;
      _error = 'Satın alma başlatılamadı.';
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      _error = 'Geri yüklemek için host hesabıyla giriş yapın.';
      notifyListeners();
      return;
    }
    _processing = true;
    _error = null;
    notifyListeners();
    try {
      await _store.restorePurchases(applicationUserName: _accountHash(user.id));
    } catch (_) {
      _processing = false;
      _error = 'Satın almalar geri yüklenemedi.';
      notifyListeners();
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != proAnnualProductId) continue;
      if (purchase.status == PurchaseStatus.pending) {
        _processing = true;
        _error = null;
        notifyListeners();
        continue;
      }
      if (purchase.status == PurchaseStatus.error) {
        _processing = false;
        _error = purchase.error?.message ?? 'Satın alma tamamlanamadı.';
        notifyListeners();
        continue;
      }
      if (purchase.status == PurchaseStatus.canceled) {
        _processing = false;
        _error = null;
        notifyListeners();
        continue;
      }
      if (purchase.status != PurchaseStatus.purchased &&
          purchase.status != PurchaseStatus.restored) {
        continue;
      }

      try {
        final provider =
            defaultTargetPlatform == TargetPlatform.iOS ? 'apple' : 'google';
        await DoqrApi(Supabase.instance.client).verifyStorePurchase(
          provider: provider,
          productId: purchase.productID,
          verificationData: purchase.verificationData.serverVerificationData,
        );
        if (purchase.pendingCompletePurchase) {
          await _store.completePurchase(purchase);
        }
        _processing = false;
        _error = null;
        _entitlementActivated = true;
        notifyListeners();
      } catch (error) {
        // Do not acknowledge an unverified purchase. Google Play will redeliver
        // it so the server verification can be retried without losing payment.
        _processing = false;
        _error = _friendlyError(error);
        notifyListeners();
      }
    }
  }

  String _accountHash(String userId) =>
      sha256.convert(utf8.encode(userId)).toString();

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('ACCOUNT_MISMATCH') || text.contains('ait değil')) {
      return 'Bu satın alma farklı bir DOQR hesabına bağlı.';
    }
    if (text.contains('STORE_NOT_READY')) {
      return 'Bu mağazada DOQR Pro henüz etkin değil.';
    }
    return 'Ödeme doğrulanamadı. Ücret alındıysa “Satın almayı geri yükle” ile tekrar deneyin.';
  }

  @visibleForTesting
  Future<void> disposeForTesting() async {
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }
}
