class PlanFeature {
  final String title;
  final String detail;
  final String englishTitle;
  final String englishDetail;
  final String russianTitle;
  final String russianDetail;

  const PlanFeature(this.title, this.detail, this.englishTitle,
      this.englishDetail, this.russianTitle, this.russianDetail);

  String titleFor(String languageCode) => switch (languageCode) {
        'en' => englishTitle,
        'ru' => russianTitle,
        _ => title,
      };
  String detailFor(String languageCode) => switch (languageCode) {
        'en' => englishDetail,
        'ru' => russianDetail,
        _ => detail,
      };
}

class PlanCatalog {
  static const proAnnualPriceUsdCents = 1499;
  static const proAnnualPriceLabel = r'$14.99 / yıl';

  static const freeFeatures = <PlanFeature>[
    PlanFeature(
      'Sınırsız ziyaretçi çağrısı',
      'Kapı zili çağrısı ve FCM bildirimi için aylık adet sınırı yok.',
      'Unlimited visitor calls',
      'No monthly count limit for doorbell calls and FCM notifications.',
      'Неограниченные вызовы посетителей',
      'Нет ежемесячного ограничения на звонки в дверь и push-уведомления.',
    ),
    PlanFeature(
      'Yazılı görüşme',
      'Ziyaretçiyle uygulama yükletmeden güvenli şekilde mesajlaş.',
      'Text chat',
      'Message visitors securely without requiring them to install an app.',
      'Текстовый чат',
      'Безопасно общайтесь с посетителями без установки приложения.',
    ),
    PlanFeature(
      '1 dijital zil ve 1 yönetici',
      'Tek bir kapının QR kodunu ve yönetici hesabını yönetin.',
      '1 digital doorbell and 1 manager',
      'Manage the QR code and manager account for a single door.',
      '1 цифровой звонок и 1 управляющий',
      'Управляйте QR-кодом и учётной записью управляющего одной двери.',
    ),
    PlanFeature(
      'Son 3 ziyaret kaydı',
      'En yeni üç ziyaretçi kaydına hızlıca eriş.',
      'Last 3 visit records',
      'Quickly access the three most recent visitor records.',
      'Последние 3 визита',
      'Быстрый доступ к трём последним записям о посетителях.',
    ),
  ];

  static const proFeatures = <PlanFeature>[
    PlanFeature(
      'Free plandaki her şey',
      'Sınırsız ziyaretçi çağrısı, FCM bildirimi ve yazılı görüşme dahil.',
      'Everything in Free',
      'Includes unlimited visitor calls, FCM notifications, and text chat.',
      'Всё из тарифа Free',
      'Неограниченные вызовы, push-уведомления и текстовый чат.',
    ),
    PlanFeature(
      'Sesli ve görüntülü görüşme',
      'Her zil çağrısında en fazla 1 dakika WebRTC görüşmesi.',
      'Audio and video calls',
      'Up to 1 minute of WebRTC calling per doorbell request.',
      'Аудио- и видеозвонки',
      'До 1 минуты WebRTC-связи на один вызов в дверь.',
    ),
    PlanFeature(
      'Aylık medya kullanım hakkı',
      'Ayda 120 dakika ses ve 60 dakika görüntü için adil kullanım hakkı.',
      'Monthly media allowance',
      'Fair-use allowance of 120 audio and 60 video minutes per month.',
      'Месячный лимит связи',
      '120 минут аудио и 60 минут видео в месяц по правилам добросовестного использования.',
    ),
    PlanFeature(
      '3 dijital zil ve zil başına 3 yönetici',
      'Kapıyı ev halkınızla veya ekibinizle yönetin; herkes bildirim alır.',
      '3 digital doorbells and 3 managers per door',
      'Share a door with your household or team so every manager receives alerts.',
      '3 цифровых звонка и 3 управляющих на дверь',
      'Управляйте дверью вместе с семьёй или командой; все получают уведомления.',
    ),
    PlanFeature(
      'Kurye notları ve teslimat kodları',
      'Kargo firmasına özel notları ve tek kullanımlık teslimat bilgisini göster.',
      'Courier notes and delivery codes',
      'Show courier-specific notes and one-time delivery information.',
      'Заметки и коды для курьеров',
      'Показывайте курьеру специальные инструкции и одноразовые данные доставки.',
    ),
    PlanFeature(
      'Spam koruması ve cihaz engelleme',
      'Arka arkaya zil çalmayı sınırla ve rahatsız eden cihazları engelle.',
      'Spam protection and device blocking',
      'Limit repeated rings and block disruptive devices.',
      'Защита от спама и блокировка устройств',
      'Ограничивайте повторные звонки и блокируйте нежелательные устройства.',
    ),
    PlanFeature(
      '90 günlük ziyaret geçmişi',
      'Ziyaret kayıtlarını son 90 gün boyunca görüntüle.',
      '90-day visit history',
      'View visit records from the last 90 days.',
      'История визитов за 90 дней',
      'Просматривайте записи о визитах за последние 90 дней.',
    ),
  ];
}
