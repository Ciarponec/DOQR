class PlanFeature {
  final String title;
  final String detail;

  const PlanFeature(this.title, this.detail);
}

class PlanCatalog {
  static const proAnnualPriceUsdCents = 1499;
  static const proAnnualPriceLabel = r'$14.99 / yıl';

  static const freeFeatures = <PlanFeature>[
    PlanFeature(
      'Sınırsız ziyaretçi çağrısı',
      'Kapı zili çağrısı ve FCM bildirimi için aylık adet sınırı yok.',
    ),
    PlanFeature(
      'Yazılı görüşme',
      'Ziyaretçiyle uygulama yükletmeden güvenli şekilde mesajlaş.',
    ),
    PlanFeature(
      '1 dijital zil ve 1 host',
      'Tek bir kapı için QR kodunu ve ev sahibi hesabını yönet.',
    ),
    PlanFeature(
      'Son 3 ziyaret kaydı',
      'En yeni üç ziyaretçi kaydına hızlıca eriş.',
    ),
    PlanFeature(
      'Spam koruması ve cihaz engelleme',
      'Arka arkaya zil çalmayı sınırla ve rahatsız eden cihazları engelle.',
    ),
  ];

  static const proFeatures = <PlanFeature>[
    PlanFeature(
      'Free plandaki her şey',
      'Sınırsız ziyaretçi çağrısı, FCM bildirimi ve yazılı görüşme dahil.',
    ),
    PlanFeature(
      'Sesli ve görüntülü görüşme',
      'Her zil çağrısında en fazla 1 dakika WebRTC görüşmesi.',
    ),
    PlanFeature(
      'Aylık medya kullanım hakkı',
      'Ayda 120 dakika ses ve 60 dakika görüntü için adil kullanım hakkı.',
    ),
    PlanFeature(
      '3 dijital zil ve zil başına 3 host',
      'Birden fazla kapıyı ve ev sahibi hesabını birlikte yönet.',
    ),
    PlanFeature(
      'Kurye notları ve teslimat kodları',
      'Kargo firmasına özel notları ve tek kullanımlık teslimat bilgisini göster.',
    ),
    PlanFeature(
      '90 günlük ziyaret geçmişi',
      'Ziyaret kayıtlarını son 90 gün boyunca görüntüle.',
    ),
  ];
}
