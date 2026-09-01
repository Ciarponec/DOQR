import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_language.dart';

class DoqrApiException implements Exception {
  final String code;
  final String technicalMessage;
  final int? status;

  const DoqrApiException(this.code, this.technicalMessage, {this.status});

  @override
  String toString() => 'DoqrApiException($code)';
}

String userErrorMessage(Object? error) {
  final code = switch (error) {
    DoqrApiException(:final code) => code,
    AuthException(:final code) => code,
    _ => null,
  };
  return switch (code) {
    'invalid_credentials' => appText(
        'E-posta veya şifre hatalı.',
        'The email or password is incorrect.',
        'Неверный адрес электронной почты или пароль.'),
    'email_not_confirmed' => appText(
        'E-posta adresi henüz doğrulanmamış.',
        'The email address has not been verified yet.',
        'Адрес электронной почты ещё не подтверждён.'),
    'user_already_exists' || 'email_exists' => appText(
        'Bu e-posta adresiyle zaten bir hesap var.',
        'An account already exists for this email address.',
        'Аккаунт с этим адресом электронной почты уже существует.'),
    'weak_password' => appText('Daha güçlü bir şifre belirleyin.',
        'Choose a stronger password.', 'Выберите более надёжный пароль.'),
    'over_email_send_rate_limit' => appText(
        'Yeni bir e-posta istemeden önce kısa bir süre bekleyin.',
        'Wait briefly before requesting another email.',
        'Подождите немного перед повторным запросом письма.'),
    'PRO_REQUIRED' => appText(
        'Bu özellik DOQR Pro gerektiriyor.',
        'This feature requires DOQR Pro.',
        'Для этой функции требуется DOQR Pro.'),
    'HOST_PLAN_LIMIT' => appText(
        'Bu kapı için paylaşım sınırına ulaşıldı.',
        'The sharing limit for this door has been reached.',
        'Достигнут лимит пользователей для этой двери.'),
    'DOOR_HAS_ACTIVE_SESSION' => appText(
        'Aktif ziyaret sona ermeden bu dijital zil silinemez.',
        'This doorbell cannot be deleted while a visit is active.',
        'Нельзя удалить звонок во время активного визита.'),
    'DOOR_PLAN_LIMIT' => appText(
        'Planınızdaki dijital zil sınırına ulaştınız.',
        'You reached the digital doorbell limit for your plan.',
        'Достигнут лимит цифровых звонков для вашего тарифа.'),
    'DOOR_NOT_FOUND' => appText(
        'Dijital zil bulunamadı veya artık erişiminiz yok.',
        'The doorbell was not found or you no longer have access.',
        'Звонок не найден или у вас больше нет доступа.'),
    'QR_NOT_FOUND' || 'QR_TOKEN_INVALID' || 'QR_TOKEN_REVOKED' => appText(
        'QR kodu bulunamadı veya artık geçerli değil.',
        'The QR code was not found or is no longer valid.',
        'QR-код не найден или больше не действует.'),
    'MEMBER_NOT_FOUND' || 'MEMBERSHIP_NOT_FOUND' => appText(
        'Paylaşım kaydı artık mevcut değil.',
        'The sharing record no longer exists.',
        'Запись о совместном доступе больше не существует.'),
    'INVITE_NOT_FOUND' || 'SHARE_TOKEN_INVALID' => appText(
        'Davet bulunamadı veya artık geçerli değil.',
        'The invite was not found or is no longer valid.',
        'Приглашение не найдено или больше не действует.'),
    'SHARE_TOKEN_EXPIRED' => appText('Davet bağlantısının süresi dolmuş.',
        'The invite has expired.', 'Срок действия приглашения истёк.'),
    'SHARE_PIN_INVALID' =>
      appText('PIN yanlış.', 'The PIN is incorrect.', 'Неверный PIN-код.'),
    'STATE_CONFLICT' || 'INVALID_TRANSITION' => appText(
        'Durum başka bir cihazda değişti. Sayfayı yenileyip tekrar deneyin.',
        'The status changed on another device. Refresh and try again.',
        'Состояние изменилось на другом устройстве. Обновите страницу.'),
    'TURN_UNAVAILABLE' || 'MEDIA_NOT_AVAILABLE' => appText(
        'Sesli ve görüntülü görüşme geçici olarak kullanılamıyor.',
        'Audio and video calling is temporarily unavailable.',
        'Аудио- и видеосвязь временно недоступна.'),
    'TURN_MONTHLY_LIMIT' ||
    'MEDIA_FAIR_USE_LIMIT' ||
    'MONTHLY_AUDIO_LIMIT' ||
    'MONTHLY_VIDEO_LIMIT' =>
      appText(
          'Bu ayki görüşme kullanım hakkı doldu.',
          'This month’s calling allowance has been used.',
          'Месячный лимит звонков исчерпан.'),
    'RING_NOT_FOUND' => appText(
        'Ziyaret kaydı bulunamadı.',
        'The visitor session could not be found.',
        'Сеанс посетителя не найден.'),
    'RING_CLOSED' || 'SESSION_EXPIRED' || 'MEDIA_SESSION_EXPIRED' => appText(
        'Bu ziyaret oturumu sona ermiş.',
        'This visitor session has ended.',
        'Сеанс посетителя завершён.'),
    'MODE_DISABLED' || 'NO_MODES_ENABLED' => appText(
        'Seçilen görüşme türü bu kapıda kapalı.',
        'The selected response type is disabled for this door.',
        'Выбранный тип ответа отключён для этой двери.'),
    'FORBIDDEN' || 'UNAUTHORIZED' => appText(
        'Bu işlem için yetkiniz yok.',
        'You do not have permission for this operation.',
        'У вас нет прав для этой операции.'),
    'VALIDATION_ERROR' => appText(
        'Girilen bilgileri kontrol edip tekrar deneyin.',
        'Check the entered information and try again.',
        'Проверьте введённые данные и повторите попытку.'),
    _ => appText(
        'İşlem tamamlanamadı. Bağlantınızı kontrol edip tekrar deneyin.',
        'The operation could not be completed. Check your connection and try again.',
        'Не удалось выполнить операцию. Проверьте подключение и повторите попытку.'),
  };
}
