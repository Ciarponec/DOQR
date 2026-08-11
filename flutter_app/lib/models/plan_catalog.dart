class PlanFeature {
  final String title;
  final String detail;
  final String englishTitle;
  final String englishDetail;

  const PlanFeature(
      this.title, this.detail, this.englishTitle, this.englishDetail);

  String titleFor(bool english) => english ? englishTitle : title;
  String detailFor(bool english) => english ? englishDetail : detail;
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
    ),
    PlanFeature(
      'Yazılı görüşme',
      'Ziyaretçiyle uygulama yükletmeden güvenli şekilde mesajlaş.',
      'Text chat',
      'Message visitors securely without requiring them to install an app.',
    ),
    PlanFeature(
      '1 dijital zil ve 1 host',
      'Tek bir kapı için QR kodunu ve ev sahibi hesabını yönet.',
      '1 digital doorbell and 1 host',
      'Manage the QR code and host account for a single door.',
    ),
    PlanFeature(
      'Son 3 ziyaret kaydı',
      'En yeni üç ziyaretçi kaydına hızlıca eriş.',
      'Last 3 visit records',
      'Quickly access the three most recent visitor records.',
    ),
  ];

  static const proFeatures = <PlanFeature>[
    PlanFeature(
      'Free plandaki her şey',
      'Sınırsız ziyaretçi çağrısı, FCM bildirimi ve yazılı görüşme dahil.',
      'Everything in Free',
      'Includes unlimited visitor calls, FCM notifications, and text chat.',
    ),
    PlanFeature(
      'Sesli ve görüntülü görüşme',
      'Her zil çağrısında en fazla 1 dakika WebRTC görüşmesi.',
      'Audio and video calls',
      'Up to 1 minute of WebRTC calling per doorbell request.',
    ),
    PlanFeature(
      'Aylık medya kullanım hakkı',
      'Ayda 120 dakika ses ve 60 dakika görüntü için adil kullanım hakkı.',
      'Monthly media allowance',
      'Fair-use allowance of 120 audio and 60 video minutes per month.',
    ),
    PlanFeature(
      '3 dijital zil ve zil başına 3 host',
      'Kapıyı eşinizle veya ekibinizle ortak yönetin; herkes bildirim alır.',
      '3 digital doorbells and 3 hosts per door',
      'Share a door with your household or team so each host receives alerts.',
    ),
    PlanFeature(
      'Kurye notları ve teslimat kodları',
      'Kargo firmasına özel notları ve tek kullanımlık teslimat bilgisini göster.',
      'Courier notes and delivery codes',
      'Show courier-specific notes and one-time delivery information.',
    ),
    PlanFeature(
      'Spam koruması ve cihaz engelleme',
      'Arka arkaya zil çalmayı sınırla ve rahatsız eden cihazları engelle.',
      'Spam protection and device blocking',
      'Limit repeated rings and block disruptive devices.',
    ),
    PlanFeature(
      '90 günlük ziyaret geçmişi',
      'Ziyaret kayıtlarını son 90 gün boyunca görüntüle.',
      '90-day visit history',
      'View visit records from the last 90 days.',
    ),
  ];
}
