import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguageController extends ChangeNotifier {
  static const _preferenceKey = 'app_language';
  static const supportedLanguageCodes = {'tr', 'en', 'ru'};
  static String currentLanguageCode = 'tr';

  AppLanguageController({Locale initialLocale = const Locale('tr')})
      : _locale = initialLocale {
    currentLanguageCode = initialLocale.languageCode;
  }

  Locale _locale;

  Locale get locale => _locale;

  static Future<Locale> resolveInitialLocale({Locale? deviceLocale}) async {
    final preferences = await SharedPreferences.getInstance();
    final languageCode = preferences.getString(_preferenceKey);
    if (supportedLanguageCodes.contains(languageCode)) {
      return Locale(languageCode!);
    }
    final deviceCode = deviceLocale?.languageCode.toLowerCase();
    return supportedLanguageCodes.contains(deviceCode)
        ? Locale(deviceCode!)
        : const Locale('tr');
  }

  Future<void> load({Locale? deviceLocale}) async {
    final resolved = await resolveInitialLocale(deviceLocale: deviceLocale);
    if (_locale.languageCode == resolved.languageCode) return;
    _locale = resolved;
    currentLanguageCode = resolved.languageCode;
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (!supportedLanguageCodes.contains(locale.languageCode)) return;
    if (_locale.languageCode == locale.languageCode) return;
    _locale = Locale(locale.languageCode);
    currentLanguageCode = locale.languageCode;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, locale.languageCode);
  }
}

String appText(String turkish, String english, [String? russian]) =>
    switch (AppLanguageController.currentLanguageCode) {
      'en' => english,
      'ru' => russian ?? russianText(english),
      _ => turkish,
    };

// Central fallback keeps the existing call sites compatible while Russian is
// rolled out. Every user-facing English source string is covered by tests.
String russianText(String english) => russianTranslations[english] ?? english;

const Map<String, String> russianTranslations = {
  '1 hour': '1 час',
  '24 hours': '24 часа',
  '4–12 digit PIN': '4–12-значный PIN-код',
  '7 days': '7 дней',
  'A visitor scans your QR code': 'Посетитель сканирует ваш QR-код',
  'Accepted': 'Принято',
  'Accommodation': 'Размещение',
  'Account could not be deleted. Please try again.':
      'Аккаунт не может быть удален. Пожалуйста, попробуйте еще раз.',
  'Active': 'Активный',
  'Add': 'Добавить',
  'Add courier note': 'Добавить примечание курьера',
  'Add note': 'Добавить примечание',
  'Add PIN protection': 'Добавить защиту PIN-кодом',
  'Address': 'Адрес',
  'Address (visible only to door managers)':
      'Адрес (виден только администраторам дверей)',
  'An account already exists for this email address.':
      'Учетная запись для этого адреса электронной почты уже существует.',
  'An invited person joins with their own account and receives notifications when this door rings. Each invite can be used once.':
      'Приглашенный человек присоединяется со своей учетной записью и получает уведомления, когда звонит эта дверь. Каждое приглашение можно использовать один раз.',
  'Answer': 'Ответ',
  'Answer by chat': 'Ответ в чате',
  'Apartment': 'Квартира',
  'Are you visiting?': 'Вы в гостях?',
  'At least 8 characters.': 'Минимум 8 символов.',
  'Audio': 'Аудио',
  'Audio call': 'Аудио звонок',
  'Auto-renews; renewal can be canceled in subscription settings.':
      'Автообновление; продление можно отменить в настройках подписки.',
  'Awaiting approval': 'Ожидает одобрения',
  'Block saved.': 'Блок сохранен.',
  'Block this network for 24 hours': 'Заблокируйте эту сеть на 24 часа',
  'Block visitor': 'Заблокировать посетителя',
  'Blocked visitors': 'Заблокированные посетители',
  'Call active': 'Вызов активен',
  'Call ended': 'Звонок завершен',
  'Calling, courier tools, and extended history.':
      'Звонки, курьерские инструменты и расширенная история.',
  'Camera and microphone permission is requested only after they accept an audio or video call.':
      'Разрешение камеры и микрофона запрашивается только после того, как они примут аудио- или видеовызов.',
  'Cancel': 'Отмена',
  'Cancel request': 'Отменить запрос',
  'Cancelled': 'Отменено',
  'Check the entered information and try again.':
      'Проверьте введенную информацию и повторите попытку.',
  'Choose a strong password that you do not use elsewhere.':
      'Выберите надежный пароль, который вы не используете где-либо еще.',
  'Choose a stronger password.': 'Выберите более надежный пароль.',
  'Choose language': 'Выберите язык',
  'Close': 'Закрыть',
  'Compare Free and Pro plans': 'Сравните бесплатные и профессиональные планы',
  'Compare plans': 'Сравнить планы',
  'Confirm new password': 'Подтвердите новый пароль',
  'Connected': 'Подключено',
  'Connecting…': 'Подключение…',
  'Contact vehicle owner': 'Связаться с владельцем автомобиля',
  'Copy invite': 'Копировать приглашение',
  'Courier': 'Курьер',
  'Courier (Pro)': 'Курьер (Про)',
  'Courier company': 'Курьерская компания',
  'Courier notes': 'Курьерские заметки',
  'Courier notes are a Pro feature':
      'Курьерские заметки – это функция версии Pro.',
  'Courier visit': 'Визит курьера',
  'Courier-specific delivery notes and delivery codes are available with DOQR Pro.':
      'В DOQR Pro доступны накладные и коды доставки для конкретных курьеров.',
  'Create': 'Создать',
  'Create a free account': 'Создать бесплатную учетную запись',
  'Create account': 'Создать учетную запись',
  'Create door manager invite': 'Создать приглашение менеджера дверей',
  'Create invite': 'Создать приглашение',
  'Create your own doorbell': 'Создайте свой собственный дверной звонок',
  'Current plan: Free': 'Текущий план: Бесплатно',
  'Current plan: Pro': 'Текущий план: Про',
  'Current plan: Pro Trial': 'Текущий план: Pro Trial',
  'Customize your QR output': 'Настройте свой QR-вывод',
  'Decline': 'Отклонить',
  'Declined': 'Отклонено',
  'Delete': 'Удалить',
  'Delete doorbell permanently': 'Удалить дверной звонок навсегда',
  'Delete DOQR account?': 'Удалить аккаунт DOQR?',
  'Delete my account': 'Удалить мою учетную запись',
  'Delete permanently': 'Удалить навсегда',
  'Delete this doorbell?': 'Удалить этот дверной звонок?',
  'Delivery code (optional)': 'Код доставки (необязательно)',
  'delivery note': 'накладная',
  'Device block': 'Блок устройства',
  'Device blocking is recommended. Network blocking may also affect other people on the same Wi-Fi network.':
      'Рекомендуется заблокировать устройство. Блокировка сети также может повлиять на других людей, находящихся в той же сети Wi-Fi.',
  'Digital doorbell active': 'Цифровой дверной звонок активен',
  'Digital doorbells': 'Цифровые дверные звонки',
  'Door': 'Дверь',
  'Door access': 'Доступ к двери',
  'Door added.': 'Дверь добавлена.',
  'Doorbell': 'Дверной звонок',
  'Doorbell name': 'Имя дверного звонка',
  'DOQR demo': 'Демо-версия DOQR',
  'DOQR host invite': 'Приглашение хоста DOQR',
  'DOQR Pro Annual': 'DOQR Pro Ежегодный',
  'DOQR Pro has been activated on your account.':
      'DOQR Pro активирован в вашей учетной записи.',
  'DOQR Pro is an annual, auto-renewing subscription. Payment is charged to your store account. You can cancel renewal at any time in your Google Play or App Store subscription settings; Pro access continues through the paid period.':
      'DOQR Pro — это годовая подписка с автоматическим продлением. Оплата списывается со счета вашего магазина. Вы можете отменить продление в любое время в настройках подписки Google Play или App Store; Доступ Pro сохраняется в течение оплаченного периода.',
  'e.g. Scan for apartment 6': 'например Сканировать квартиру 6',
  'e.g. Visitor entrance': 'например Вход для посетителей',
  'e.g. XYZ site - Block B': 'например Сайт XYZ - Блок Б',
  'Edit': 'Редактировать',
  'Edit courier note': 'Изменить примечание курьера',
  'Email': 'Электронная почта',
  'Email and password are required.':
      'Требуется адрес электронной почты и пароль.',
  'Ended': 'Закончено',
  'Enter a valid email address.':
      'Введите действительный адрес электронной почты.',
  'Enter the invite code sent by the door owner. Once joined, you receive this door’s notifications and visitor messages.':
      'Введите пригласительный код, отправленный владельцем двери. После присоединения вы получаете уведомления от этой двери и сообщения посетителей.',
  'Enter your valid email address first.':
      'Сначала введите свой действующий адрес электронной почты.',
  'Essential digital doorbell features.':
      'Основные функции цифрового дверного звонка.',
  'Expires': 'Срок действия истекает',
  'Expiry': 'Срок действия',
  'For voice or video, the visitor is asked for approval first.':
      'Для голосового или видео посетителя сначала запрашивают одобрение.',
  'Forgot password': 'Забыли пароль',
  'Framed': 'В рамке',
  'Free plan active • Pro \$14.99/year':
      'Активен план Free • Pro — \$14,99 в год',
  'Guest entrance': 'Гостевой вход',
  'Hardware threads': 'Потоки процессора',
  'How would you like to answer?': 'Как бы вы хотели ответить?',
  'I understand this deletion is permanent.':
      'Я понимаю, что это удаление является окончательным.',
  'In the DOQR app, go to Digital doorbells > Use invite code to join.':
      'В приложении DOQR перейдите в раздел «Цифровые дверные звонки» > «Использовать код приглашения, чтобы присоединиться».',
  'Invite code': 'Пригласительный код',
  'Invite copied.': 'Приглашение скопировано.',
  'Join': 'Присоединиться',
  'Join door invite': 'Присоединиться к дверному приглашению',
  'Language': 'Язык',
  'Last 3 records': 'Последние 3 записи',
  'Last 90 days': 'Последние 90 дней',
  'Leave': 'Уйти',
  'Leave shared door': 'Выйти из общей двери',
  'Leave this shared door?': 'Выйти из этой общей двери?',
  'Manage Subscription': 'Управление подпиской',
  'Messaging is closed; no new messages can be sent in this session.':
      'Обмен сообщениями закрыт; в этом сеансе нельзя отправлять новые сообщения.',
  'Minimal': 'Минимальный',
  'Missed': 'Пропущен',
  'Missed visit': 'Пропущенный визит',
  'My digital doorbells and QR codes': 'Мои цифровые дверные звонки и QR-коды',
  'Network block': 'Сетевой блок',
  'Network candidates for the call could not be received.':
      'Сетевые кандидаты на вызов не были приняты.',
  'New digital doorbell': 'Новый цифровой звонок',
  'New password': 'Новый пароль',
  'No address added': 'Адрес не добавлен',
  'No courier notes yet.': 'Никаких курьерских накладных пока нет.',
  'No one except the door owner has access.':
      'Никто, кроме владельца двери, не имеет доступа.',
  'No QR code for this doorbell will be able to start a new visit.':
      'Никакой QR-код для этого дверного звонка не позволит начать новый визит.',
  'No visitors yet': 'Посетителей пока нет',
  'Notification and message access': 'Доступ к уведомлениям и сообщениям',
  'now': 'сейчас',
  'Office': 'Офис',
  'Old QR printouts will stop working immediately. You will need to print the new code.':
      'Старые QR-распечатки немедленно перестанут работать. Вам нужно будет распечатать новый код.',
  'Only share this invite with someone you trust. Whoever accepts it can receive alerts and visitor messages for this door.':
      'Делитесь этим приглашением только с теми, кому вы доверяете. Тот, кто его примет, сможет получать оповещения и сообщения для посетителей об этой двери.',
  'Parking / urgent': 'Парковка / срочно',
  'Password': 'Пароль',
  'Password must be at least 8 characters.':
      'Пароль должен быть не менее 8 символов.',
  'PDF preview': 'Предварительный просмотр PDF',
  'Pending': 'Ожидается',
  'Pending invites': 'Ожидающие приглашения',
  'People with access': 'Люди с доступом',
  'Permanently block this device': 'Заблокировать это устройство навсегда',
  'Permanently delete my account': 'Удалить мой аккаунт навсегда',
  'PIN (if provided)': 'ПИН-код (если указан)',
  'Plan and subscription': 'План и подписка',
  'Plans': 'Планы',
  'Platform': 'Платформа',
  'Please leave it at the door.': 'Пожалуйста, оставьте его у двери.',
  'Poster': 'Плакат',
  'Privacy notice': 'Уведомление о конфиденциальности',
  'Privacy Policy': 'Политика конфиденциальности',
  'Pro feature': 'Профессиональная функция',
  'Pro features active • \$14.99/year': 'Функции Pro активны • \$14,99 в год',
  'Pro trial active': 'Пробная версия Pro активна',
  'QR code': 'QR-код',
  'QR security': 'Безопасность QR-кода',
  'Ready invite': 'Готово приглашение',
  'Ready-to-use presets': 'Готовые к использованию пресеты',
  'Recent visitors': 'Недавние посетители',
  'Reception': 'Прием',
  'Remove access': 'Удалить доступ',
  'Remove access?': 'Удалить доступ?',
  'Remove block': 'Удалить блок',
  'Remove text': 'Удалить текст',
  'Remove this block?': 'Удалить этот блок?',
  'Request video call': 'Запросить видеозвонок',
  'Request voice call': 'Запросить голосовой вызов',
  'Require visitor name': 'Запросить имя посетителя',
  'Resend verification email': 'Повторно отправить письмо с подтверждением',
  'Restart demo': 'Перезапустить демо-версию',
  'Restore purchases': 'Восстановление покупок',
  'Revoke all': 'Отозвать все',
  'Revoke all QR codes': 'Отменить все QR-коды',
  'Revoke all QR codes?': 'Отозвать все QR-коды?',
  'Revoke invite': 'Отозвать приглашение',
  'Ring the sample bell': 'Позвоните в колокольчик',
  'Ring timeout': 'Тайм-аут звонка',
  'Ringing': 'Звонок',
  'Ringing…': 'Звонок…',
  'Rotate': 'Обновить',
  'Rotate QR code': 'Обновить QR-код',
  'Rotate the QR code?': 'Обновить QR-код?',
  'Save': 'Сохранить',
  'Save PDF': 'Сохранить PDF',
  'Scan for this vehicle': 'Сканировать этот автомобиль',
  'Scan to reach the host': 'Сканирование, чтобы добраться до хоста',
  'Scan to reach your host': 'Сканируйте, чтобы связаться с вашим хостом',
  'Scan to ring the bell': 'Сканируйте, чтобы позвонить в колокольчик',
  'Screen': 'Экран',
  'Security information': 'Информация о безопасности',
  'Security-first digital doorbell':
      'Цифровой дверной звонок, ориентированный на безопасность',
  'Send this code to your spouse or co-host through a trusted channel.':
      'Отправьте этот код своему супругу или соорганизатору через надежный канал.',
  'Session ended': 'Сессия завершена',
  'Set a new password': 'Установить новый пароль',
  'Settings': 'Настройки',
  'Share code': 'Поделиться кодом',
  'Share door access': 'Общий доступ к двери',
  'Share PDF': 'Поделиться PDF-файлом',
  'Shared user': 'Общий пользователь',
  'Show response options': 'Показать варианты ответа',
  'Sign in': 'Войти',
  'Sign in to your host account': 'Войдите в свою учетную запись хоста',
  'Sign out': 'Выйти',
  'Start by creating your first digital doorbell.':
      'Начните с создания своего первого цифрового дверного звонка.',
  'Start the conversation': 'Начать разговор',
  'Stored encrypted on the server.':
      'Хранится на сервере в зашифрованном виде.',
  'Template': 'Шаблон',
  'Terms of Use': 'Условия использования',
  'Text': 'Текст',
  'Text above QR (optional)': 'Текст над QR-кодом (необязательно)',
  'Text below QR (optional)': 'Текст под QR-кодом (необязательно)',
  'Text beside QR (optional)': 'Текст рядом с QR (необязательно)',
  'Text chat': 'Текстовый чат',
  'The 1-minute video call limit has ended.':
      'Ограничение на 1 минуту видеовызова закончилось.',
  'The call connection could not be established.':
      'Соединение для вызова не может быть установлено.',
  'The call could not be started. Please try again.':
      'Не удалось начать вызов. Пожалуйста, попробуйте еще раз.',
  'The call signal could not be received. Please try again.':
      'Не удалось принять сигнал вызова. Пожалуйста, попробуйте еще раз.',
  'The calling service is currently unavailable. Please try again.':
      'Служба вызова в настоящее время недоступна. Пожалуйста, попробуйте еще раз.',
  'The conversation starts after visitor approval':
      'Разговор начинается после одобрения посетителя',
  'The delivery code was shared with this visitor.':
      'Код доставки был предоставлен этому посетителю.',
  'The doorbell was not found or you no longer have access.':
      'Дверной звонок не найден или у вас больше нет доступа.',
  'The email address has not been verified yet.':
      'Адрес электронной почты еще не подтвержден.',
  'The email or password is incorrect.':
      'Электронная почта или пароль неверны.',
  'The Free plan allows only the owner to manage the door. Pro is required to share it with a spouse or another person.':
      'Бесплатный план позволяет управлять дверью только владельцу. Pro необходимо поделиться им с супругом или другим лицом.',
  'The Free plan includes 1 digital doorbell. Upgrade to Pro to add another doorbell and create up to 3 digital doorbells.':
      'В бесплатный план входит 1 цифровой дверной звонок. Обновите версию до Pro, чтобы добавить еще один дверной звонок и создать до трех цифровых дверных звонков.',
  'The host selects text, audio, or video with one tap.':
      'Организатор выбирает текст, аудио или видео одним нажатием.',
  'The invite has expired.': 'Срок действия приглашения истек.',
  'The invite was not found or is no longer valid.':
      'Приглашение не найдено или больше недействительно.',
  'The new password must be at least 8 characters.':
      'Новый пароль должен содержать не менее 8 символов.',
  'The new QR code is ready. Old codes were revoked.':
      'Новый QR-код готов. Старые коды были отменены.',
  'The operation could not be completed. Check your connection and try again.':
      'Операцию не удалось завершить. Проверьте подключение и повторите попытку.',
  'The passwords do not match.': 'Пароли не совпадают.',
  'The PIN is incorrect.': 'PIN-код неверен.',
  'The QR code was not found or is no longer valid.':
      'QR-код не найден или больше не действителен.',
  'The sharing limit for this door has been reached.':
      'Достигнут лимит общего доступа для этой двери.',
  'The sharing record no longer exists.':
      'Запись общего доступа больше не существует.',
  'The status changed on another device. Refresh and try again.':
      'Статус изменился на другом устройстве. Обновите и повторите попытку.',
  'The verification email could not be sent right now. Please try again shortly.':
      'Не удалось отправить письмо с подтверждением прямо сейчас. Пожалуйста, повторите попытку в ближайшее время.',
  'The verification link has expired. Enter the email address you used to sign up above and try again.':
      'Срок действия ссылки для подтверждения истек. Введите адрес электронной почты, который вы использовали при регистрации выше, и повторите попытку.',
  'The verification link has expired. Tap the button below to get a new link valid for 60 minutes.':
      'Срок действия ссылки для подтверждения истек. Нажмите кнопку ниже, чтобы получить новую ссылку, действительную в течение 60 минут.',
  'The WebRTC offer could not be created.':
      'Предложение WebRTC не удалось создать.',
  'There are no active device or network blocks.':
      'Нет активных устройств или сетевых блоков.',
  'These fields only appear on the QR printout; they do not change the QR link.':
      'Эти поля появляются только на распечатке QR; они не меняют QR-ссылку.',
  'This device or network will be able to ring the digital doorbell again.':
      'Это устройство или сеть сможет снова позвонить в цифровой дверной звонок.',
  'This doorbell cannot be deleted while a visit is active.':
      'Этот дверной звонок нельзя удалить, пока активно посещение.',
  'This feature requires DOQR Pro.': 'Для этой функции требуется DOQR Pro.',
  'This information is disclosed to the visitor in advance. It does not verify identity; it helps investigate misuse.':
      'Эта информация сообщается посетителю заранее. Он не проверяет личность; это помогает расследовать злоупотребления.',
  'This is an interactive preview; no data is saved.':
      'Это интерактивный предварительный просмотр; никакие данные не сохраняются.',
  'Time zone': 'Часовой пояс',
  'Trial allowance: 30 min audio • 15 min video':
      'Пробное пособие: 30 минут аудио • 15 минут видео.',
  'Try again': 'Попробуйте еще раз',
  'Try the flow without an account': 'Попробуйте поток без учетной записи',
  'Try without an account': 'Попробуйте без аккаунта',
  'Unable to send the verification email. Please try again.':
      'Не удалось отправить письмо с подтверждением. Пожалуйста, попробуйте еще раз.',
  'Unable to sign in right now. Please try again.':
      'Не удалось войти в систему прямо сейчас. Пожалуйста, попробуйте еще раз.',
  'Unknown': 'Неизвестно',
  'Unused invite': 'Неиспользованное приглашение',
  'Update password': 'Обновить пароль',
  'Use invite code': 'Используйте код приглашения',
  'Vehicle': 'Транспортное средство',
  'Verification email sent again. The link is valid for 60 minutes; check your inbox and spam folder and use only the link in the newest email.':
      'Письмо с подтверждением отправлено повторно. Ссылка действительна 60 минут; проверьте папку «Входящие» и папку «Спам» и используйте только ссылку из самого нового письма.',
  'Video call': 'Видеозвонок',
  'View plans': 'Посмотреть планы',
  'Visit': 'Визит',
  'Visitor': 'Посетитель',
  'Visitor cancelled': 'Посетитель отменен',
  'Visitor entrance': 'Вход для посетителей',
  'Visitor welcome message': 'Приветственное сообщение посетителю',
  'Visitors scan the QR code without installing an app. You are notified instantly and respond securely.':
      'Посетители сканируют QR-код, не устанавливая приложение. Вы получите мгновенное уведомление и ответите безопасно.',
  'Visitors will appear here when your QR code is scanned.':
      'Посетители появятся здесь после сканирования вашего QR-кода.',
  'Voice call': 'Голосовой вызов',
  'Wait 60 seconds before requesting another verification email.':
      'Подождите 60 секунд, прежде чем запросить еще одно письмо с подтверждением.',
  'Wait briefly before requesting another email.':
      'Подождите немного, прежде чем запрашивать еще одно электронное письмо.',
  'Waiting for store approval…': 'Ожидание одобрения магазина…',
  'Waiting for visitor approval': 'Ожидание одобрения посетителя',
  'When a visitor selects this courier company, the host gets a “Share note” option. The note and delivery code are sent only after the host approves.':
      'Когда посетитель выбирает эту курьерскую компанию, хозяин получает опцию «Поделиться заметкой». Примечание и код доставки отправляются только после одобрения организатора.',
  'When the visitor selects this company, this note is offered to the host.':
      'Когда посетитель выбирает эту компанию, эта заметка предлагается хозяину.',
  'Without installing the app, they only ring the bell; you choose how to respond.':
      'Без установки приложения они только звонят в колокольчик; вы сами выбираете, как реагировать.',
  'Write a message…': 'Написать сообщение…',
  'You do not have permission for this operation.':
      'У вас нет разрешения на эту операцию.',
  'You reached the Free plan doorbell limit':
      'Вы достигли лимита дверных звонков в бесплатном плане.',
  'You receive an instant notification': 'Вы получаете мгновенное уведомление',
  'Your 3-day Pro trial is active. Your account will automatically switch to Free when it ends.':
      'Ваша трехдневная пробная версия Pro активна. Когда он закончится, ваша учетная запись автоматически переключится на бесплатный режим.',
  'Your digital doorbells, QR links, visit history, and account-related data will be permanently deleted. This cannot be undone. If you have a store subscription, you must also cancel it in Google Play or the App Store.':
      'Ваши цифровые дверные звонки, QR-ссылки, история посещений и данные, связанные с учетной записью, будут безвозвратно удалены. Это невозможно отменить. Если у вас есть подписка в магазине, вам также необходимо отменить ее в Google Play или App Store.',
  'Your door is one scan away.':
      'Ваша дверь находится на расстоянии одного сканирования.',
  'Your email address is not verified yet. You can request a new link; the link is valid for 60 minutes.':
      'Ваш адрес электронной почты еще не подтвержден. Вы можете запросить новую ссылку; ссылка действительна 60 минут.',
  'Your Pro features are active. You can manage the subscription from your store account.':
      'Ваши функции Pro активны. Вы можете управлять подпиской из своей учетной записи в магазине.',
  'Your Pro plan is active': 'Ваш план Pro активен',
};

class AppLanguageScope extends InheritedNotifier<AppLanguageController> {
  const AppLanguageScope({
    super.key,
    required AppLanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLanguageController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    assert(scope != null, 'AppLanguageScope is missing above this context.');
    return scope!.notifier!;
  }
}

extension DoqrTranslations on BuildContext {
  bool get isEnglish => Localizations.localeOf(this).languageCode == 'en';
  bool get isRussian => Localizations.localeOf(this).languageCode == 'ru';

  String tr(String turkish, String english, [String? russian]) => isEnglish
      ? english
      : isRussian
          ? russian ?? russianText(english)
          : turkish;
}

class LanguagePickerButton extends StatelessWidget {
  const LanguagePickerButton({super.key, this.foregroundColor});

  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    return PopupMenuButton<String>(
      tooltip: context.tr('Dil seç', 'Choose language'),
      icon: Icon(Icons.language_rounded, color: foregroundColor),
      onSelected: (value) =>
          AppLanguageScope.of(context).setLocale(Locale(value)),
      itemBuilder: (context) => [
        _languageItem('tr', 'Türkçe', languageCode),
        _languageItem('en', 'English', languageCode),
        _languageItem('ru', 'Русский', languageCode),
      ],
    );
  }

  PopupMenuItem<String> _languageItem(
      String value, String label, String selectedLanguageCode) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: value == selectedLanguageCode
                ? const Icon(Icons.check_rounded, size: 20)
                : null,
          ),
          Text(label),
        ],
      ),
    );
  }
}
