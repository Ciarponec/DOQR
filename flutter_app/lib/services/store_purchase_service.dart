import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_language.dart';
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
  Locale _locale = const Locale('tr');
  String? _error;

  ProductDetails? get product => _product;
  bool get storeAvailable => _storeAvailable;
  bool get loading => _loading;
  bool get processing => _processing;
  String? get error => _error;
  String get displayPrice =>
      _product?.price ?? _message('Mağazada gösterilir', 'Shown in the store');

  void setLocale(Locale locale) {
    _locale = locale;
  }

  String _message(String turkish, String english, [String? russian]) =>
      switch (_locale.languageCode) {
        'en' => english,
        'ru' => russian ?? russianText(english),
        _ => turkish,
      };

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
        _error = _message('Mağaza bağlantısı kesildi. Lütfen tekrar deneyin.',
            'The store connection was interrupted. Please try again.');
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
        _error = _message('Cihazdaki mağaza şu anda kullanılamıyor.',
            'The store is currently unavailable on this device.');
        return;
      }
      final response = await _store.queryProductDetails({proAnnualProductId});
      if (response.error != null) {
        _error = _message('Abonelik bilgisi mağazadan alınamadı.',
            'Subscription information could not be retrieved from the store.');
        return;
      }
      if (response.productDetails.isEmpty) {
        _error = defaultTargetPlatform == TargetPlatform.iOS
            ? _message('DOQR Pro, App Store üzerinde yakında açılacak.',
                'DOQR Pro will be available on the App Store soon.')
            : _message('DOQR Pro ürünü Google Play üzerinde henüz etkin değil.',
                'DOQR Pro is not active on Google Play yet.');
        return;
      }
      _product = response.productDetails.first;
    } catch (_) {
      _error = _message(
          'Mağaza bağlantısı kurulamadı.', 'Could not connect to the store.');
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
      _error = _message(
          'Satın almak için kapı yöneticisi hesabıyla giriş yapın.',
          'Sign in with a door manager account to make a purchase.',
          'Войдите в учётную запись управляющего дверью, чтобы совершить покупку.');
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
          applicationUserName: _storeAccountIdentifier(user.id),
        ),
      );
      if (!started) {
        _processing = false;
        _error = _message('Satın alma ekranı açılamadı.',
            'The purchase screen could not be opened.');
        notifyListeners();
      }
    } catch (_) {
      _processing = false;
      _error = _message(
          'Satın alma başlatılamadı.', 'The purchase could not be started.');
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      _error = _message(
          'Geri yüklemek için kapı yöneticisi hesabıyla giriş yapın.',
          'Sign in with a door manager account to restore purchases.',
          'Войдите в учётную запись управляющего дверью, чтобы восстановить покупки.');
      notifyListeners();
      return;
    }
    _processing = true;
    _error = null;
    notifyListeners();
    try {
      await _store.restorePurchases(
        applicationUserName: _storeAccountIdentifier(user.id),
      );
    } catch (_) {
      _processing = false;
      _error = _message('Satın almalar geri yüklenemedi.',
          'Purchases could not be restored.');
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
        _error = purchase.error?.message ??
            _message('Satın alma tamamlanamadı.',
                'The purchase could not be completed.');
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
        // Do not finish an unverified transaction. The store will redeliver it
        // so server verification can be retried without losing the purchase.
        _processing = false;
        _error = _friendlyError(error);
        notifyListeners();
      }
    }
  }

  String _storeAccountIdentifier(String userId) {
    // StoreKit 2 only accepts a UUID for appAccountToken. Supabase user IDs are
    // UUIDs already, so Apple can return the same privacy-safe identifier in
    // signed transactions and server notifications. Google Play expects an
    // obfuscated account ID and therefore keeps the SHA-256 representation.
    if (defaultTargetPlatform == TargetPlatform.iOS) return userId;
    return sha256.convert(utf8.encode(userId)).toString();
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('ACCOUNT_MISMATCH') || text.contains('ait değil')) {
      return _message('Bu satın alma farklı bir DOQR hesabına bağlı.',
          'This purchase is linked to a different DOQR account.');
    }
    if (text.contains('STORE_NOT_READY')) {
      return _message('Bu mağazada DOQR Pro henüz etkin değil.',
          'DOQR Pro is not active in this store yet.');
    }
    return _message(
        'Ödeme doğrulanamadı. Ücret alındıysa “Satın almayı geri yükle” ile tekrar deneyin.',
        'Payment could not be verified. If you were charged, try again with “Restore purchases”.');
  }

  @visibleForTesting
  Future<void> disposeForTesting() async {
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }
}
