/// Tek bir yerden Türkçe metinler.
/// İlerde i18n eklemek için merkezi tutuyoruz.
class AppStrings {
  const AppStrings._();

  // Marka
  static const String appName = 'FırınNet';
  static const String appTagline = 'Fırıncının cep defteri';
  static const String appPitch = 'Fırıncının dijital ağı';
  static const String appLongPitch =
      'Atölyenden tedariğine, sektöründen müşterine — bir ağa bağlı.';
  static const String launchHint = 'Tezgahın yanında her gün.';

  // Onboarding
  static const String continueAsGuest = 'Kayıtsız Devam Et';
  static const String createProfile = 'Profil Oluştur';
  static const String onboardingTitle = 'Hoş geldin\nFırınNet\'e';
  static const String onboardingSubtitle =
      'Atölye, tedarik ve iş ağı bir arada.\n'
      'Üretimini cebinden yönet, sektöre bağlan.';
  static const String onboardingFooter =
      'Profil olmadan da kullanabilir, dilediğin zaman kayıt olabilirsin.';

  // Profile
  static const String accountType = 'Hesap türü';
  static const String accountCommercial = 'Ticari';
  static const String accountIndividual = 'Bireysel';
  static const String accountWholesaler = 'Toptancı';
  static const String displayName = 'Profil adı';
  static const String city = 'Şehir';
  static const String roleBadge = 'Meslek rozeti';
  static const String email = 'E-posta';
  static const String password = 'Şifre';
  static const String save = 'Kaydet';

  // Auth
  static const String authLoginTitle = 'Giriş Yap';
  static const String authSignInButton = 'Giriş Yap';
  static const String authSignUpButton = 'Profil Oluştur';
  static const String authEmailHint = 'firin@ornek.com';
  static const String authPasswordHint = 'En az 6 karakter';
  static const String authEmailRequired = 'E-posta gerekli';
  static const String authEmailInvalid = 'Geçerli bir e-posta gir';
  static const String authPasswordRequired = 'Şifre gerekli';
  static const String authPasswordTooShort = 'Şifre en az 6 karakter olmalı';
  static const String authSignedOutSnack = 'Çıkış yapıldı.';
  static const String authProfileSavedSnack = 'Profil kaydedildi.';
  static const String authProfileCreatedSnack =
      'Hesabın oluşturuldu. Hoş geldin!';
  static const String authBackendDisabled =
      'Sunucu bağlantısı yapılandırılmadı — bu sürümde yalnız misafir modu çalışır.';

  // Dashboard / nav
  static const String todayPrompt = 'Bugün ne yapacağız?';
  static const String bakeryPanel = 'Fırın Paneli';
  static const String bakeryPanelSub = 'Üretim, bayi, fire, gün sonu';
  static const String feed = 'Akış';
  static const String marketplace = 'İlanlar';
  static const String messages = 'Mesajlar';
  static const String profile = 'Profil';

  // Feed
  static const String feedTitle = 'FırınNet';
  static const String feedSubtitle = 'Atölyeden, sektörden, ağından';
  static const String feedSectionStories = 'Atölyeden anlık';
  static const String feedSectionPosts = 'Bugün ağda';
  static const String feedSectionAll = 'Tümü';

  // Feed quality (composer + interaction)
  static const String feedComposerPrompt = 'Ne paylaşmak istiyorsun?';
  static const String feedComposerExpandHint =
      'Atölyenden, deneyiminden, sorunundan…';
  static const String feedComposerTypeLabel = 'Paylaşım türü';
  static const String feedComposerSubmit = 'Paylaş';
  static const String feedComposerEmptyErr =
      'Önce bir şeyler yaz — soru, üretim, ipucu.';
  static const String feedComposerSavedSnack = 'Akışa eklendi.';
  static const String feedComposerCancel = 'Vazgeç';
  static const String feedComposerYouAuthor = 'Sen';
  static const String feedComposerYouRole = 'Misafir · FırınNet';

  // Post actions
  static const String feedActionLike = 'Beğen';
  static const String feedActionComment = 'Yorum';
  static const String feedActionShare = 'Paylaş';
  static const String feedActionSave = 'Kaydet';
  static const String feedActionGoToGroup = 'Grupta gör';
  static const String feedActionLikedSnack = 'Beğendin.';
  static const String feedActionUnlikedSnack = 'Beğeni geri alındı.';
  static const String feedActionSavedSnack = 'Kaydedildi.';
  static const String feedActionUnsavedSnack = 'Kayıtlardan çıktı.';
  static const String feedActionCommentSnack =
      'Yorum yazma yakında — beta için.';
  static const String feedActionShareSnack = 'Paylaşım menüsü açılıyor…';
  static const String feedActionTagSnack = 'Etiket filtresi yakında: #';

  // Group highlight banner
  static const String feedGroupHighlightSuffix = ' grubunda öne çıktı';

  // Insight cards
  static const String feedInsightSectionLabel = 'Sektör pulse';

  // Market
  static const String marketTitle = 'Market';
  static const String marketSubtitle = 'Fırıncının B2B pazarı';
  static const String marketSearchHint =
      'Spiral mikser, fırın, un, maya, susam…';
  static const String marketSectionFeatured = 'Öne çıkan';
  static const String marketSectionFresh = 'Yeni ilanlar';
  static const String marketBadgeFeatured = 'Öne çıkan';
  static const String marketHintV2 =
      'V2\'de mesajlaşma, doğrulanmış satıcı ve gelişmiş filtre açılır.';

  // Jobs
  static const String jobsTitle = 'İş İlanları';
  static const String jobsSubtitle = 'Sektörün iş ağı';
  static const String jobsSegHiring = 'Usta Arıyor';
  static const String jobsSegLooking = 'İş Arıyor';
  static const String jobsListHiring = 'Çalışan arayan fırınlar';
  static const String jobsListLooking = 'İş arayan ustalar';
  static const String jobsApply = 'Başvur';

  // Role-based dashboard kartları (Panel tab içerikleri)
  static const String panelGreetingPrefix = 'Merhaba';
  static const String panelRoleSubCommercial = 'Atölyeni ve bayilerini yönet';
  static const String panelRoleSubIndividual = 'İş ağına bağlan';
  static const String panelRoleSubWholesaler = 'Ürün ve müşterilerini yönet';

  // Ticari kartlar
  static const String cardBakeryPanel = 'Fırın Paneli';
  static const String cardBakeryPanelSub = 'Üretim, fire, gün sonu';
  static const String cardDealerPanel = 'Bayi Paneli';
  static const String cardDealerPanelSub = 'Teslimat, tahsilat, hesap';
  static const String cardMyListings = 'İlanlarım';
  static const String cardMyListingsSub = 'Yayında olan iş ilanların';
  static const String cardMessages = 'Mesajlar';
  static const String cardMessagesSub = 'Sohbet & bildirimler';

  // Bireysel kartlar
  static const String cardJobAds = 'İş İlanları';
  static const String cardJobAdsSub = 'Sektörde yayında olanlar';
  static const String cardPostJobSeeker = 'İş Arıyorum İlanı Ver';
  static const String cardPostJobSeekerSub = 'Kendini sektöre tanıt';
  static const String cardMyProfile = 'Profilim';
  static const String cardMyProfileSub = 'Bilgi, rozet, şehir';
  static const String cardMyRecipes = 'Reçetelerim';
  static const String cardMyRecipesSub = 'Hamur hesabı, malzeme, yapılış';

  // V1.2 — yeni ortak/role kartlar
  static const String cardCalculator = 'Hesaplama Makinesi';
  static const String cardCalculatorSub = 'Un, su, maya, tuz → adet';
  static const String cardWorkerProfile = 'Ustalık Bilgilerim';
  static const String cardWorkerProfileSub = 'Meslek, tecrübe, beceri';
  static const String cardWorkerExperiences = 'Çalışma Geçmişim';
  static const String cardWorkerExperiencesSub = 'Önceki iş yerleri ve roller';
  static const String cardWholesaleCustomers = 'Müşteriler / Bayiler';
  static const String cardWholesaleCustomersSub =
      'Teslimat, tahsilat, hesap özeti';
  static const String cardWholesalePriceList = 'Fiyat Listesi';
  static const String cardWholesalePriceListSub = 'Toptan fiyatları yönet';

  // Toptancı kartlar
  static const String cardPostProductListing = 'Ürün/Hizmet İlanı Ver';
  static const String cardPostProductListingSub = 'Market\'te yayına al';
  static const String cardIncomingMessages = 'Gelen Mesajlar';
  static const String cardIncomingMessagesSub = 'Müşteri talepleri';
  static const String cardCompanyProfile = 'Firma Profilim';
  static const String cardCompanyProfileSub = 'Kart, iletişim, bölge';
  static const String cardPriceAnnouncements = 'Duyuru / Fiyat Listesi';
  static const String cardPriceAnnouncementsSub = 'Toptan fiyat bildir';

  // Panel
  static const String panelTitle = 'Panel';
  static const String panelHeroLabel = 'Bugünün özeti';
  static const String panelHeroLive = 'CANLI';
  static const String panelHeroSub = 'Net özet — bayi tutarı eksi fire zararı';
  static const String panelSectionQuick = 'Hızlı işlemler';
  static const String panelSectionRecent = 'Son hareketler';
  static const String panelSectionTips = 'Bugün ağdan';
  static const String panelTrailingDayEnd = 'Gün sonu';
  static const String panelEmptyTitle = 'Bugün henüz kayıt yok';
  static const String panelEmptySub =
      'Üretim, bayi veya fire girdiğinde burada özetleyeceğim.';
  static const String panelEmptyCta = 'İlk üretimi gir';

  // Bakery panel actions
  static const String calculate = 'Hesapla';
  static const String calculateSub = 'Reçete / hamur hesabı';
  static const String addProduction = 'Üretim Gir';
  static const String addProductionSub = 'Günlük üretim kaydı';
  static const String addDealer = 'Bayiye Ver';
  static const String addDealerSub = 'Dağıtım kaydı';
  static const String addWaste = 'Fire Gir';
  static const String addWasteSub = 'Kalan / iade / fire';
  static const String endOfDay = 'Gün Sonu';
  static const String endOfDaySub = 'Günlük özet';
  static const String getReport = 'Rapor Al';
  static const String getReportSub = 'Paylaşılabilir rapor';

  // Recipe
  static const String flourKg = 'Un (kg)';
  static const String waterPct = 'Su oranı (%)';
  static const String yeastPct = 'Maya oranı (%)';
  static const String saltPct = 'Tuz oranı (%)';
  static const String pieceWeightG = 'Ürün gramajı (gr)';
  static const String wastePct = 'Fire oranı (%)';
  static const String recipeHint =
      'Varsayılan: 50 kg un · %60 su · %1 maya · %2 tuz · 250 gr · %3 fire';

  // Generic
  static const String today = 'Bugün';
  static const String emptyDay = 'Bugün henüz kayıt yok.';
  static const String copyText = 'Metni Kopyala';
  static const String shareWhatsapp = "WhatsApp'a Gönder";
  static const String pdfReport = 'PDF Rapor Al';
  static const String comingSoon = 'Yakında aktif olacak';

  // ─────────────────────────── Dealer / Bayi (V1 + V1.1)

  // App bar / nav
  static const String dealerSectionTitle = 'Bayi Yönetimi';
  static const String dealerListTitle = 'Bayi Yönetimi';
  static const String dealerAddTitle = 'Bayi Ekle';
  static const String dealerAddTooltip = 'Bayi ekle';

  // List
  static const String dealerSearchHint = 'Bayi adı, bölge, kişi ara…';
  static const String dealerFilterAll = 'Tümü';
  static const String dealerFilterActive = 'Aktif';
  static const String dealerFilterPassive = 'Pasif';
  static const String dealerListSection = 'Bayiler';
  static const String dealerListNoMatch = 'Bu kriterlerle eşleşen bayi yok.';
  static const String dealerListEmptyTitle = 'Henüz bayi yok';
  static const String dealerListEmptySub =
      'Bayilerini ekledikçe teslimat, iade ve tahsilatları '
      'tek yerden yöneteceksin.';
  static const String dealerListEmptyCta = 'İlk bayiyi ekle';
  static const String dealerCardBalanceLabel = 'Bakiye';
  static const String dealerCardCreditLabel = 'Alacak';
  static const String dealerCardClosedLabel = 'Kapalı';
  static const String dealerCardLastTxLabel = 'Son hareket';
  static const String dealerCardPassiveBadge = 'Pasif';

  // Add dealer form
  static const String dealerFieldName = 'Bayi adı';
  static const String dealerFieldNameHint = 'Örn. Hamdi Bakkal';
  static const String dealerFieldNameRequired = 'Bayi adı gerekli';
  static const String dealerFieldContact = 'İletişim';
  static const String dealerFieldContactPerson = 'Yetkili kişi';
  static const String dealerFieldPhone = 'Telefon';
  static const String dealerFieldArea = 'Bölge / adres';
  static const String dealerFieldAreaHint = 'Örn. Konya · Selçuklu';
  static const String dealerFieldWorkingType = 'Çalışma tipi';
  static const String dealerWorkingCash = 'Peşin';
  static const String dealerWorkingTerm = 'Vadeli';
  static const String dealerWorkingMixed = 'Karma';
  static const String dealerFieldNote = 'Not (opsiyonel)';
  static const String dealerFieldNoteHint =
      'Sabah erken teslim, Cuma tahsilatı vb.';
  static const String dealerSaveButton = 'Bayiyi Kaydet';
  static const String dealerSaveSnack = 'Bayi eklendi: ';

  // Detail
  static const String dealerDetailFallbackTitle = 'Bayi';
  static const String dealerDetailNotFound = 'Bayi bulunamadı';
  static const String dealerDetailShareTooltip = 'Hesap özeti & PDF';
  static const String dealerDetailHeroLabel = 'Cari bakiye';
  static const String dealerDetailHeroDebt = 'BORÇ';
  static const String dealerDetailHeroCredit = 'ALACAK';
  static const String dealerDetailHeroClosed = 'KAPALI';
  static const String dealerDetailMetricDelivery = 'Teslim';
  static const String dealerDetailMetricReturn = 'İade';
  static const String dealerDetailMetricPayment = 'Ödeme';
  static const String dealerDetailChipWeek = 'Bu hafta';
  static const String dealerDetailChipMonth = 'Bu ay';
  static const String dealerDetailChipLastPayment = 'Son ödeme';
  static const String dealerDetailSectionActions = 'Aksiyonlar';
  static const String dealerDetailSectionPrices = 'Fiyat listesi';
  static const String dealerDetailSectionTxs = 'İşlem geçmişi';
  static const String dealerDetailSectionNotes = 'Notlar';

  // Detail action chips
  static const String dealerActionDelivery = 'Ürün Ver';
  static const String dealerActionReturn = 'İade Al';
  static const String dealerActionPayment = 'Ödeme Al';
  static const String dealerActionShare = 'Hesap Paylaş';
  static const String dealerActionAdjustment = 'Düzeltme';
  static const String dealerActionAddPrice = 'Fiyat ekle';

  // Prices empty
  static const String dealerPricesEmpty =
      'Bu bayi için tanımlı fiyat yok. Teslimatta manuel fiyat girersin.';
  static const String dealerPriceValidFromLabel = 'Geçerli';

  // Tx empty + filter
  static const String dealerTxsEmpty = 'Bu bayi için henüz işlem yok.';
  static const String dealerTxsNoMatch = 'Filtreyle eşleşen işlem yok.';
  static const String dealerTxFilterTypeAll = 'Tümü';
  static const String dealerTxFilterTypeDelivery = 'Teslimat';
  static const String dealerTxFilterTypeReturn = 'İade';
  static const String dealerTxFilterTypePayment = 'Ödeme';
  static const String dealerTxFilterTypeAdjustment = 'Düzeltme';
  static const String dealerTxFilterRangeToday = 'Bugün';
  static const String dealerTxFilterRangeWeek = 'Bu hafta';
  static const String dealerTxFilterRangeMonth = 'Bu ay';
  static const String dealerTxFilterRangeAll = 'Tümü';

  // Tx labels (kart içinde gösterim)
  static const String dealerTxKindReturn = 'İade';
  static const String dealerTxKindPayment = 'Ödeme';
  static const String dealerTxKindAdjustment = 'Bakiye düzeltmesi';

  // Notes
  static const String dealerNotesEmpty =
      'Bu bayi için henüz not eklenmedi.';
  static const String dealerNotesAddHint = 'Yeni not ekle…';

  // Forms — Delivery
  static const String dealerDeliveryTitle = 'Bayiye Ürün Ver';
  static const String dealerDeliveryStripLabel = 'Bayi';
  static const String dealerDeliveryProductLabel = 'Ürün';
  static const String dealerDeliveryQtyLabel = 'Adet';
  static const String dealerDeliveryQtySuffix = 'adet';
  static const String dealerDeliveryUnitPriceLabel = 'Birim fiyat';
  static const String dealerDeliveryUnitPriceHintAuto = 'bayi fiyatı';
  static const String dealerDeliveryAutoPriceMsg =
      'Bu bayi için kayıtlı fiyat geldi.';
  static const String dealerDeliveryTotalLabel = 'Toplam tutar';
  static const String dealerDeliveryNoteHint =
      'Sabah teslim, ekstra dilimli vb.';
  static const String dealerSaveSnackDelivery = 'Teslimat kaydedildi: ';

  // Forms — Return
  static const String dealerReturnTitle = 'İade Al';
  static const String dealerReturnProductLabel = 'İade edilen ürün';
  static const String dealerReturnUnitPriceHint = 'iade kıymeti';
  static const String dealerReturnTotalLabel = 'İade toplamı';
  static const String dealerReturnNoteHint =
      'Akşam kalan, müşteri iadesi vb.';
  static const String dealerReturnReasonLabel = 'Neden / not (opsiyonel)';
  static const String dealerSaveSnackReturn = 'İade kaydedildi: ';

  // Forms — Payment
  static const String dealerPaymentTitle = 'Ödeme Al';
  static const String dealerPaymentAmountLabel = 'Tutar';
  static const String dealerPaymentReceivedLabel = 'Alınan tutar';
  static const String dealerPaymentMethodLabel = 'Ödeme yöntemi';
  static const String dealerPaymentDecreasesLabel = 'Bakiyeyi düşürür';
  static const String dealerPaymentNoteHint = 'Cuma tahsilatı, kapora vb.';
  static const String dealerSaveSnackPayment = 'Ödeme kaydedildi: ';

  // Forms — Adjustment (V1.1)
  static const String dealerAdjustmentTitle = 'Bakiye Düzeltmesi';
  static const String dealerAdjustmentDirectionLabel = 'Yön';
  static const String dealerAdjustmentDirectionAdd =
      'Bakiyeyi artır (+)';
  static const String dealerAdjustmentDirectionSubtract =
      'Bakiyeyi azalt (−)';
  static const String dealerAdjustmentNoteRequired = 'Not zorunlu';
  static const String dealerAdjustmentNoteLabel =
      'Açıklama (zorunlu)';
  static const String dealerAdjustmentNoteHint =
      'Örn. eski hesap kapanışı, hatalı kayıt düzeltme';
  static const String dealerSaveSnackAdjustment =
      'Bakiye düzeltmesi kaydedildi: ';

  // Price sheet (V1.1)
  static const String dealerPriceSheetTitle = 'Fiyat ekle / güncelle';
  static const String dealerPriceSheetProduct = 'Ürün';
  static const String dealerPriceSheetUnitPrice = 'Birim fiyat';
  static const String dealerPriceSheetValidFrom = 'Geçerlilik';
  static const String dealerPriceSheetSave = 'Fiyatı kaydet';
  static const String dealerPriceSheetSaved = 'Fiyat kaydedildi: ';
  static const String dealerPriceSheetNoteHint =
      'Eski fiyat geçmişte kalır, yeni fiyat aktif olur.';

  // Common errors
  static const String dealerErrPickProduct = 'Önce bir ürün seç.';
  static const String dealerErrPickReturn = 'Önce iade edilen ürünü seç.';
  static const String dealerErrQtyPositive = 'Adet sıfırdan büyük olmalı.';
  static const String dealerErrPricePositive =
      'Birim fiyat sıfırdan büyük olmalı.';
  static const String dealerErrAmountPositive =
      'Tutar sıfırdan büyük olmalı.';

  // ─────────────────────────── Social Groups (V1)

  // Feed integration
  static const String feedSectionGroups = 'Sektör Grupları';
  static const String feedGroupsCtaAll = 'Tüm gruplar';
  static const String feedGroupsEmpty =
      'Henüz grup yok. İlk grubu oluşturarak başla.';

  // Groups list screen
  static const String groupsTitle = 'Sektör Grupları';
  static const String groupsSearchHint = 'Grup adı, kategori, şehir ara…';
  static const String groupsCreateCta = 'Grup Oluştur';
  static const String groupsCreateTooltip = 'Yeni grup';
  static const String groupsSectionRecommended = 'Öneriler';
  static const String groupsSectionPopular = 'Bu hafta öne çıkan';
  static const String groupsSectionJoined = 'Üyesi olduğum gruplar';
  static const String groupsSectionAll = 'Tüm gruplar';
  static const String groupsCategoryAll = 'Tümü';
  static const String groupsListEmpty =
      'Bu kategoride grup yok. Aramayı temizle veya kategori değiştir.';
  static const String groupsJoinedEmpty =
      'Henüz hiç gruba katılmadın. Listeden seç veya kendin oluştur.';

  // Group card actions
  static const String groupActionJoin = 'Katıl';
  static const String groupActionOpen = 'Aç';
  static const String groupActionFull = 'Dolu';
  static const String groupActionLeave = 'Ayrıl';
  static const String groupBadgePrivate = 'Özel';
  static const String groupBadgePublic = 'Açık';
  static const String groupBadgeMember = 'Üye';
  static const String groupBadgeUnlimited = 'Sınırsız';

  // Group detail
  static const String groupDetailFallbackTitle = 'Grup';
  static const String groupDetailNotFound = 'Grup bulunamadı';
  static const String groupDetailMembersLabel = 'Üye';
  static const String groupDetailLimitLabel = 'Limit';
  static const String groupDetailOwnerLabel = 'Yönetici';
  static const String groupDetailFullBanner =
      'Bu grup dolu — yeni katılım kapalı.';
  static const String groupDetailMessagesSection = 'Son konuşmalar';
  static const String groupDetailMessagesEmpty =
      'Henüz hiç mesaj yok. Grubu sen başlat — bir soru veya tarif paylaş.';
  static const String groupDetailComposeHint = 'Mesaj yaz…';
  static const String groupDetailComposeJoinedOnly =
      'Mesaj yazmak için önce gruba katıl.';
  static const String groupDetailJoinSnackSuccess = 'Gruba katıldın.';
  static const String groupDetailLeaveSnackSuccess = 'Gruptan ayrıldın.';
  static const String groupDetailPinnedBadge = 'SABİTLENDİ';

  // Group create
  static const String groupCreateTitle = 'Grup Oluştur';
  static const String groupCreateFieldName = 'Grup adı';
  static const String groupCreateFieldNameHint = 'Örn. Konya Fırıncıları';
  static const String groupCreateFieldDescription = 'Açıklama';
  static const String groupCreateFieldDescriptionHint =
      'Grubun amacını kısaca anlat — kim katılsın, ne konuşulsun?';
  static const String groupCreateFieldCategory = 'Kategori';
  static const String groupCreateFieldCity = 'Şehir (opsiyonel)';
  static const String groupCreateFieldCityHint = 'Bölgesel grup ise yaz';
  static const String groupCreateFieldPrivacy = 'Görünürlük';
  static const String groupCreatePrivacyPublic = 'Açık — herkes katılabilir';
  static const String groupCreatePrivacyPrivate = 'Özel — onayla katılım';
  static const String groupCreateFieldLimit = 'Katılımcı limiti';
  static const String groupCreateLimitUnlimited = 'Sınırsız';
  static const String groupCreateFieldTags = 'Etiketler (virgülle ayır)';
  static const String groupCreateFieldTagsHint = 'ekşimaya, simit, konya';
  static const String groupCreateButton = 'Grubu Oluştur';
  static const String groupCreatedSnack = 'Grup oluşturuldu: ';

  // Share screen
  static const String dealerShareTitle = 'Hesap Özeti & Paylaş';
  static const String dealerShareCopiedSnack = 'Metin panoya kopyalandı.';
  static const String dealerShareWhatsapp = 'WhatsApp / Paylaş';
  static const String dealerSharePdfBuilding = 'PDF hazırlanıyor…';
  static const String dealerSharePdfButton = 'PDF Oluştur ve Paylaş';
  static const String dealerSharePdfSuffix = ' ve paylaşım açıldı.';
  static const String dealerSharePdfErr = 'PDF oluşturulamadı: ';
}
