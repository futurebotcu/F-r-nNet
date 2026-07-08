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

  // V1.3 — Auth Entry (yeni boot landing)
  static const String authEntryTitle = 'FırınNet\'e hoş geldin';
  static const String authEntrySubtitle =
      'Fırıncılar, ustalar ve toptancılar için iş, reçete ve paylaşım ağı.';
  static const String authEntrySignIn = 'Giriş Yap';
  static const String authEntrySignUp = 'Hesabım yok, üye ol';
  static const String authEntryGuest = 'Kayıtsız devam et';
  static const String authEntryBackendOff =
      'Canlı giriş kapalı. Kayıtsız devam edebilirsin.';

  // V1.3 — Role select (signup öncesi)
  static const String roleSelectTitle = 'Hangi rol senin için?';
  static const String roleSelectSubtitle =
      'Sektördeki yerini seç — formdaki alanları rolüne göre düzenleriz.';
  static const String roleCommercialTitle = 'Fırın / İşletme';
  static const String roleCommercialSub =
      'Fırın işletmesi, bayi ve üretim yönetimi';
  static const String roleIndividualTitle = 'Usta / Çalışan';
  static const String roleIndividualSub = 'Usta profili, iş arama ve reçeteler';
  static const String roleWholesalerTitle = 'Tedarikçi / Toptancı';
  static const String roleWholesalerSub =
      'Müşteri, ürün, fiyat ve teslimat yönetimi';

  // V1.3 — Login & sign-up nav
  static const String authLoginNoAccountQ = 'Hesabın yok mu? Üye ol';
  static const String authForgotPassword = 'Şifremi unuttum';

  // V1.3.5 — Şifremi unuttum ekranı
  static const String authForgotPasswordTitle = 'Şifreni mi unuttun?';
  static const String authForgotPasswordHint =
      'E-posta adresine şifre yenileme bağlantısı göndereceğiz.';
  static const String authForgotPasswordSubmit = 'Reset Link Gönder';
  static const String authForgotPasswordSent =
      'Mailini kontrol et — şifre yenileme bağlantısı gönderildi.';
  static const String authForgotPasswordFail =
      'Bağlantı gönderilemedi. E-posta adresini kontrol edip tekrar dene.';

  // V1.3.5 — Yasal metinler
  static const String legalTermsTitle = 'Kullanım Şartları';
  static const String legalPrivacyTitle = 'Gizlilik Politikası';
  static const String legalAcceptCheckbox =
      'Kullanım Şartları ve Gizlilik Politikası\'nı okudum, kabul ediyorum.';
  static const String legalAcceptRequired =
      'Devam etmek için kullanım şartlarını ve gizlilik politikasını '
      'kabul etmelisin.';
  static const String legalFooterAccept =
      'Devam ederek Kullanım Şartları ve Gizlilik Politikası\'nı kabul '
      'etmiş olursun.';
  static const String authGuestDataWriteBlock =
      'Bu işlem için giriş yapman gerekiyor.';

  // V1.3.1 — AuthRequired bottom sheet (guest write action prompt)
  static const String authRequiredTitle =
      'Hesabını oluştur, kaydın sende kalsın';
  static const String authRequiredBody =
      'Bu işlemi kaydetmek için FırınNet hesabı gerekir. Hesap oluşturduğunda '
      'reçetelerin, bayi kayıtların ve ilanların sana özel saklanır.';
  static const String authRequiredCreate = 'Hesap oluştur';
  static const String authRequiredSignIn = 'Giriş yap';
  static const String authRequiredKeepBrowsing = 'Şimdilik gezmeye devam et';

  // V1.3.1 — Profile create escape hatch
  static const String profileCreateGuestEscape = 'Üye olmadan gezmeye devam et';
  static const String profileCreateGuestHint =
      'İstersen daha sonra hesap oluşturabilirsin.';
  static const String profileCreateDiscardTitle = 'Formdan çıkılsın mı?';
  static const String profileCreateDiscardBody =
      'Girdiğin profil bilgileri kaydedilmeyecek. Kayıtsız gezmeye devam '
      'edebilirsin.';
  static const String profileCreateDiscardKeep = 'Forma dön';
  static const String profileCreateDiscardLeave = 'Gezmeye devam et';
  // V1.4 P1.5 — Completion mode'da ProfileController async hydrate eder.
  // Hydrate bitmeden submit denenirse form default değerleri Supabase'e
  // yazılırdı (örn. accountType=commercial + badge=first). Guard bilgi
  // ver + submit'i bloke et.
  static const String profileStillLoadingError =
      'Profil bilgilerin hazırlanıyor. Lütfen birkaç saniye sonra tekrar dene.';

  // Profile
  static const String accountType = 'Hesap türü';
  static const String accountCommercial = 'Fırın / İşletme';
  static const String accountIndividual = 'Usta / Çalışan';
  static const String accountWholesaler = 'Tedarikçi / Toptancı';
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

  // V1.4 — Email adresi server-side reject (örn. .test/.example/.invalid TLD,
  // disposable domain block list, vb.) veya client-side reserved TLD guard.
  static const String authEmailAddressInvalid =
      'Bu e-posta adresi kabul edilmiyor. Lütfen geçerli bir e-posta adresi gir.';
  static const String authEmailTestTldNotAllowed =
      'Test uzantılı e-posta kullanılamaz. Lütfen gerçek bir e-posta adresi gir.';
  static const String commonOk = 'Tamam';
  static const String authSignedOutSnack = 'Çıkış yapıldı.';
  static const String authProfileSavedSnack = 'Profil kaydedildi.';
  static const String authProfileCreatedSnack =
      'Hesabın oluşturuldu. Hoş geldin!';

  // V1.4 — Signup sonrası e-posta onayı bekleniyorsa gösterilen dialog.
  // Supabase Auth ayarında `mailer_autoconfirm = false` olduğu durumda
  // SupabaseAuthRepository.signUp `needsEmailConfirmation = true` döner.
  static const String authEmailConfirmTitle = 'E-postanı onayla';
  static const String authEmailConfirmBody =
      'Sana bir doğrulama linki gönderdik. Gelen kutunu kontrol et ve '
      'linke tıkladıktan sonra giriş yapabilirsin.';
  static const String authEmailConfirmOk = 'Tamam';

  // V1.4 — Social login (Google + Apple).
  static const String authContinueWithGoogle = 'Google ile devam et';
  static const String authContinueWithApple = 'Apple ile devam et';
  static const String authSocialDivider = 'veya';
  static const String authProviderDisabled =
      'Bu giriş yöntemi henüz yapılandırılmadı. Lütfen e-posta ile devam et.';
  static const String authOAuthCancelled = 'Giriş iptal edildi.';
  static const String authOAuthFailed =
      'Giriş tamamlanamadı. Lütfen tekrar dene.';

  // V1.4 — Apple iOS-only "coming soon" davranışı: provider Supabase'te
  // kapalı, native iOS Sign in with Apple capability/Service ID/.p8 hazır
  // değil. Butona dokunulursa OAuth tetiklenmez; bilinçli roadmap mesajı.
  static const String authAppleComingSoonBadge = 'Yakında';
  static const String authAppleComingSoonSnack =
      'Apple ile giriş yakında eklenecek.';

  // V1.4 — GoTrue Google `code → token` exchange aşamasında Google'dan
  // `invalid_client` dönerse (Client ID/Secret yanlış veya rotate edilmiş).
  static const String authGoogleConfigError =
      'Google giriş ayarı hatalı. Lütfen daha sonra tekrar dene.';

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
  static const String feedSectionPosts = 'Bugün ağda';
  static const String feedSectionAll = 'Tümü';

  // V1 Donor-First Social Rebuild — yeni SocialFeedPage için ek string'ler.
  static const String feedLoadError =
      'Akış yüklenemedi. Bağlantını kontrol edip yeniden dener misin?';
  static const String feedEmpty =
      'Henüz paylaşım yok. İlk gönderiyi sen at — ağ buradan büyür.';
  // Faz 2 UI — premium boş-state başlık/alt metin ayrımı.
  static const String feedEmptyTitle = 'Akış henüz boş';
  static const String feedEmptySubtitle =
      'İlk gönderiyi sen paylaş — sektörün gündemi buradan büyür.';
  static const String feedComposerNewPostCta = 'Paylaş';
  // Social UI Polish Sprint 1 — inline composer card.
  static const String feedComposerInlinePlaceholder = 'Ne paylaşmak istersin?';
  static const String feedComposerInlineCtaPhoto = 'Fotoğraf';
  static const String feedComposerInlineCtaQuestion = 'Soru';
  static const String feedComposerInlineCtaProduction = 'Üretim';
  // Feed Premium Sprint — Twitter/FB tarzı inline composer.
  static const String feedComposerPanelPlaceholder =
      'Bugün ne paylaşmak istersin?';
  static const String feedComposerPanelSubtitle =
      'Üretimini, tarifini, sorunu veya duyurunu paylaş.';
  static const String feedComposerActionMedia = 'Medya';
  static const String feedComposerActionQuestion = 'Soru';
  static const String feedComposerActionRecipe = 'Tarif';
  static const String feedComposerActionAnnouncement = 'Duyuru';
  static const String feedComposerActionShare = 'Paylaş';
  // Medya aksiyonu → modal action sheet (4 mevcut işlev).
  static const String mediaSheetTitle = 'Medya ekle';
  static const String mediaSheetCapturePhoto = 'Fotoğraf çek';
  static const String mediaSheetPickPhoto = 'Galeriden fotoğraf seç';
  static const String mediaSheetCaptureVideo = 'Video çek';
  static const String mediaSheetPickVideo = 'Galeriden video seç';
  static const String mediaSheetCancel = 'Vazgeç';
  // Social UI Polish Sprint 2A — Feed segmentation (Genel Akış / Takip Edilenler)
  // Faz 2 UI — feed iç filtresi "Tümü / Takip Edilenler". Eskiden "Genel Akış"
  // idi; Topluluk üst segmenti zaten "Genel Akış | Gruplar" olduğu için
  // çift-etiket karmaşası oluşuyordu. "Tümü" hem ayrışır hem de All/Following
  // filtresini daha net anlatır.
  static const String feedSegmentAll = 'Tümü';
  static const String feedSegmentFollowing = 'Takip Edilenler';
  static const String feedFollowingEmptyNoFollows =
      'Henüz kimseyi takip etmiyorsun.';
  static const String feedFollowingEmptyNoFollowsHint =
      'Beğendiğin paylaşımların sahibi profillere git ve Takip Et.';
  static const String feedFollowingEmptyNoPosts =
      'Takip ettiklerinden henüz paylaşım yok.';
  static const String feedFollowingEmptyGuest =
      'Takip Edilenler akışını görmek için giriş yap.';
  static const String feedFollowingBackToAll = 'Tüm akışa dön';
  static const String retry = 'Yeniden dene';
  // Faz 2 UI — ortak hata durumu (ham exception kullanıcıya gösterilmez).
  static const String errorGenericTitle = 'Bir şeyler ters gitti';
  static const String errorGenericSubtitle =
      'İçerik şu an yüklenemedi. Bağlantını kontrol edip tekrar dene.';
  // Ortak kullanıcı-dostu işlem hata metinleri (ham exception UI'a sızmaz).
  static const String commonSaveError = 'Kaydedilemedi. Lütfen tekrar dene.';
  static const String commonFeedShareError =
      'Akışta paylaşılamadı. Lütfen tekrar dene.';
  static const String storiesMyStoryLabel = 'Senin Hikayen';
  static const String storiesEmptyHint = 'Henüz hikaye paylaşılmamış.';

  // V2 Social Core Commit 2 — stories
  static const String storyCreateTitle = 'Hikaye ekle';
  static const String storyCreatePickCta = 'Galeriden seç';
  static const String storyCreateShareCta = 'Paylaş';
  static const String storyCreatePickError =
      'Görsel seçilemedi. Tekrar dener misin?';
  static const String storyCreateUploadError =
      'Hikaye yüklenemedi. Bağlantını kontrol et.';
  static const String storyCreateSavedSnack = 'Hikayen paylaşıldı.';
  static const String storyCreateGuestCta = 'Hikaye paylaşmak için giriş yap';
  static const String storyViewerTitle = 'Hikaye';
  static const String storyDeleteConfirm = 'Bu hikayeyi silmek istiyor musun?';
  static const String storyDeleteCta = 'Sil';
  static const String storyDeleteCancelCta = 'Vazgeç';
  static const String storyDeletedSnack = 'Hikaye silindi.';
  static const String storyDeleteFailed =
      'Hikaye silinemedi. Tekrar dener misin?';
  static const String storyAddMyHint = 'Galeriden bir görsel seç.';
  static const String storyExpiresInHint = '24 saat sonra kaybolur.';

  // V2 Social Core Commit 3 — Video post
  static const String composerPickVideoCta = 'Video seç';
  static const String composerPickVideoChangeCta = 'Video değiştir';
  static const String composerRemoveVideoCta = 'Videoyu kaldır';

  // V2 Social Core Commit 3.5 — Composer media fix (kamera + sticky CTA)
  static const String composerPromptHeadline =
      'Fotoğraf, video veya deneyimini paylaş.';
  static const String composerPickPhotoCta = 'Foto seç';
  static const String composerCapturePhotoCta = 'Foto çek';
  static const String composerCaptureVideoCta = 'Video çek';
  static const String composerShareCta = 'Paylaş';
  static const String composerSharingCta = 'Paylaşılıyor…';
  static const String composerMediaSectionLabel = 'Medya';

  // Story create — kamera + sticky CTA
  static const String storyCapturePhotoCta = 'Foto çek';
  static const String storyShareCta = 'Hikayeyi paylaş';
  static const String storySharingCta = 'Paylaşılıyor…';
  static const String composerVideoTooLargeError =
      'Video çok büyük (maks 50 MB). Daha kısa bir video seç.';
  static const String composerVideoTooLongError =
      'Video çok uzun (maks 60 saniye).';
  static const String composerVideoPickError =
      'Video seçilemedi. Tekrar dener misin?';
  static const String composerVideoUploadError =
      'Video yüklenemedi. Bağlantını kontrol et.';
  static const String postVideoTapToPlay = 'Oynatmak için dokun';
  static const String postVideoPlaybackError =
      'Video oynatılamadı. Tekrar dener misin?';
  static const String postCommentsCountLabel = 'yorum';
  static const String postViewAllComments = 'Tüm yorumları gör';

  // V1 P0 — Twitter-style post detail (yorum sayfası başlığı + section heading).
  static const String postDetailTitle = 'Gönderi';
  static String postCommentsHeading(int n) => 'Yorumlar ($n)';
  static const String postLikesShortLabel = 'beğeni';
  static const String postCommentsShortLabel = 'yorum';

  // V2 Social Core — pagination + post edit
  static const String feedEndOfList = 'Akışın sonu.';
  static const String postEditTitle = 'Gönderiyi düzenle';
  static const String postEditSaveCta = 'Kaydet';
  static const String postEditCancelCta = 'Vazgeç';
  static const String postEditEmptyError = 'Metin boş olamaz — bir şeyler yaz.';
  static const String postEditSavedSnack = 'Gönderi güncellendi.';
  static const String postEditError =
      'Gönderi güncellenemedi. Tekrar dener misin?';
  static const String postEditMenuItem = 'Düzenle';

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
  // V1.4 P0.1 — addPost exception olursa kullanıcıya ham İngilizce hata
  // sızmasın; composer expanded kalır, kullanıcı tekrar deneyebilir.
  static const String feedPostCreateError =
      'Gönderi paylaşılamadı. Lütfen tekrar dene.';

  // Post actions
  static const String feedActionLike = 'Beğen';
  static const String feedActionComment = 'Yorum';
  static const String feedActionShare = 'Paylaş';
  static const String feedActionSave = 'Kaydet';
  static const String feedActionRepost = 'Yeniden paylaş';
  static const String feedActionReply = 'Cevapla';
  static const String feedActionGoToGroup = 'Grupta gör';
  // Repost surfacing — akış attribution satırı ("<Ad> yeniden paylaştı").
  static String feedRepostedByLabel(String name) => '$name yeniden paylaştı';
  static const String feedRepostAttributionFallback = 'Bir kullanıcı';
  // Repost (toggle) geri bildirim + hata.
  static const String feedRepostedSnack = 'Yeniden paylaşıldı.';
  static const String feedRepostUndoneSnack = 'Repost geri alındı.';
  static const String feedRepostUpdateError =
      'Repost güncellenemedi. Lütfen tekrar dene.';
  static const String feedActionLikedSnack = 'Beğendin.';
  static const String feedActionUnlikedSnack = 'Beğeni geri alındı.';
  static const String feedActionSavedSnack = 'Kaydedildi.';
  static const String feedActionUnsavedSnack = 'Kayıtlardan çıktı.';
  // V1.4 P1.18 — toggleLike network/repo exception → kullanıcıya Türkçe.
  static const String feedLikeUpdateError =
      'Beğeni güncellenemedi. Lütfen tekrar dene.';
  // V1.4 P1.19 — toggleSave network/repo exception → kullanıcıya Türkçe.
  static const String feedSaveUpdateError =
      'Kaydetme işlemi tamamlanamadı. Lütfen tekrar dene.';
  // V1 P1-B — Feed yorumlar gerçek UI'a bağlandı; eski snackbar kaldırıldı.
  static const String feedActionCommentSnack = 'Yorumlar yükleniyor…';
  static const String feedCommentSheetTitle = 'Yorumlar';
  static const String feedCommentComposerHint = 'Yorum yaz…';
  static const String feedCommentSendCta = 'Gönder';
  static const String feedCommentEmpty = 'Henüz yorum yok. İlk yorumu sen yaz.';
  static const String feedCommentEmptyGuest =
      'Henüz yorum yok. Üye olunca ilk yorumu sen atabilirsin.';
  static const String feedCommentErrorGeneric =
      'Yorumlar yüklenemedi. Yeniden dener misin?';
  static const String feedCommentEmptyError =
      'Önce bir şeyler yaz — kısa da olsa.';
  static const String feedCommentSavedSnack = 'Yorum eklendi.';
  static const String feedCommentDeleteConfirm =
      'Bu yorumu silmek istiyor musun?';
  static const String feedCommentDeleteCta = 'Sil';
  static const String feedCommentCancelCta = 'Vazgeç';
  static const String feedCommentDeletedSnack = 'Yorum silindi.';
  static const String feedCommentDeleteFailed =
      'Yorum silinemedi. Bağlantını kontrol et ve tekrar dene.';
  static const String feedCommentOwnLabel = 'Sen';
  // V1 — Yorum sheet UX hardening: composer altta inline error + guest CTA.
  // Network exception ayrı mesaj; gerçek sebep snackbar yerine sheet içinde
  // görünür (bottom sheet üstüne snackbar açılamadığı için).
  static const String feedCommentErrorNetwork =
      'Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.';
  static const String feedCommentErrorSubmit =
      'Yorum gönderilemedi. Lütfen tekrar dene.';
  static const String feedCommentGuestCta = 'Yorum yazmak için giriş yap';

  // V1 Feed F1 — Owner post-delete metinleri.
  static const String feedPostMenuDelete = 'Gönderiyi sil';
  static const String feedPostDeleteConfirmTitle = 'Bu gönderiyi sil?';
  static const String feedPostDeleteConfirmBody =
      'Gönderi feed\'den kalkacak. Bu işlem geri alınamaz.';
  static const String feedPostDeleteCta = 'Sil';
  static const String feedPostDeleteCancelCta = 'Vazgeç';
  static const String feedPostDeleteSuccess = 'Gönderi silindi.';
  static const String feedPostDeleteError =
      'Gönderi silinemedi. Lütfen tekrar dene.';

  // V1 Social S1 — Public profile sayfası.
  static const String publicProfileTitle = 'Profil';
  static const String publicProfileFallbackTitle = 'FırınNet Kullanıcısı';
  static const String publicProfileLoadError =
      'Profil yüklenemedi. Yeniden dener misin?';
  static String publicProfilePostsHeading(int count) =>
      count == 1 ? '1 gönderi' : '$count gönderi';
  static const String publicProfilePostsEmpty =
      'Bu kullanıcı henüz gönderi paylaşmadı.';
  static const String publicProfileSelfHint = 'Bu senin profilin';

  // V1 Social F2 — Profile statistics tile labels.
  static const String profileStatPosts = 'Gönderi';
  static const String profileStatFollowers = 'Takipçi';
  static const String profileStatFollowing = 'Takip';
  static const String followersListTitle = 'Takipçiler';
  static const String followingListTitle = 'Takip edilenler';
  static const String followersEmpty = 'Henüz takipçi yok.';
  static const String followingEmpty = 'Henüz takip edilen yok.';

  // V1 Social S2 — Follow / Subscriptions
  static const String followCtaFollow = 'Takip et';
  static const String followCtaUnfollow = 'Takipten çık';
  static const String followFollowing = 'Takip ediyorsun';
  static const String followError =
      'Takip işlemi tamamlanamadı. Lütfen tekrar dene.';
  static String followCountFollowers(int n) => '$n takipçi';
  static String followCountFollowing(int n) => '$n takip';

  // V1 Social S3 — Feed image post.
  static const String feedComposerAddPhoto = 'Foto ekle';
  static const String feedComposerPhotoSelected = 'Foto seçildi';
  static const String feedComposerRemovePhoto = 'Resmi kaldır';
  static const String feedComposerPickError =
      'Resim seçilemedi. Lütfen tekrar dene.';
  // V1 Feed P0 — image upload P0 fix: silent text-only fallback kaldırıldı.
  // Resim upload başarısız olursa post da rollback edilir; net hata.
  static const String feedComposerUploadError =
      'Resim yüklenemedi. Gönderi paylaşılmadı.';
  static const String feedImageLoadError = 'Resim yüklenemedi.';
  static const String feedImageViewerTitle = 'Resim';
  // V1 P1-C — Eski fake share snackbar. Native share aktif edildiğinden
  // onShare içinde artık KULLANILMAZ; key tek dependent test referansı
  // sürdürmek için tutuluyor.
  static const String feedActionShareSnack = 'Paylaşım menüsü açılıyor…';

  // V1 P1-D — Private group join requests + in-app notifications.
  static const String notificationsTitle = 'Bildirimler';
  static const String notificationsEmptyTitle = 'Henüz bildirimin yok';
  static const String notificationsEmptyBody =
      'Katılım istekleri ve önemli gelişmeler burada görünür.';
  static const String notificationsErrorGeneric =
      'Bildirimler yüklenemedi. Yeniden dener misin?';
  static const String notificationsMarkAllRead = 'Tümünü okundu işaretle';
  static const String notificationsTileTitle = 'Bildirimler';
  static const String notificationsTileSubtitle =
      'Katılım istekleri ve grup hareketleri';
  static const String groupJoinRequestSend = 'Katılma isteği gönder';
  static const String groupJoinRequestPending = 'İstek gönderildi';
  static const String groupJoinRequestRejectedLabel = 'İstek reddedildi';
  static const String groupJoinRequestResend = 'Tekrar istek gönder';
  static const String groupJoinRequestSent = 'Katılma isteğin gönderildi.';
  static const String groupJoinRequestError =
      'Katılma isteği gönderilemedi. Lütfen tekrar dene.';
  static const String groupJoinRequestApproved = 'Katılım isteği kabul edildi.';
  static const String groupJoinRequestRejected = 'Katılım isteği reddedildi.';
  static const String groupJoinRequestDecideError =
      'İstek güncellenemedi. Lütfen tekrar dene.';
  static const String groupJoinRequestsTitle = 'Katılım istekleri';
  static const String groupJoinRequestsEmpty = 'Bekleyen katılım isteği yok.';
  static const String groupPrivateInfo =
      'Bu grup katılım onaylıdır. İçeriği görmek için katılma isteği gönderebilirsin.';
  static const String groupApprovalRequiredBadge = 'Katılım onaylı';
  static const String groupJoinRequestApproveCta = 'Kabul Et';
  static const String groupJoinRequestRejectCta = 'Reddet';

  /// Groups V1 Sprint 1 / GB-1 — Owner primary status (kurucu için).
  /// "Katıl"/"Ayrıl" yerine kurucuya bu metin gösterilir.
  /// Sprint 2'de "Yönet" trailing'i eklendi; status card artık tıklanır.
  static const String groupOwnerStatusTitle = 'Bu grubun kurucususun';
  static const String groupOwnerStatusSubtitle = 'Yönet menüsüne dokun';

  /// V1 Sprint 2 — Üyeler / Yönet / Gruptan çık / Grubu kapat metinleri.
  static const String groupManage = 'Yönet';
  static const String groupMembers = 'Üyeler';
  static const String groupMembersEmpty = 'Bu grubun üyeleri henüz görünmüyor.';
  static const String groupFounder = 'Kurucu';
  static const String groupRemoveMember = 'Üyeyi çıkar';
  static const String groupLeave = 'Gruptan çık';
  static const String groupLeaveConfirmTitle = 'Gruptan çık?';
  static const String groupLeaveConfirmBodyTransfer =
      'Liderlik otomatik olarak başka bir üyeye geçecek.';
  static const String groupLeaveConfirmBodyClose =
      'Grupta başka üye yok. Grup kapatılacak.';
  static const String groupLeaveConfirmBodyMember =
      'Gruptan çıkmak istediğine emin misin?';
  static const String groupLeft = 'Gruptan çıktın.';
  static const String groupLeftTransferred =
      'Gruptan çıktın. Liderlik başka bir üyeye geçti.';
  static const String groupLeftClosed = 'Gruptan çıktın. Grup kapatıldı.';
  // Not: `groupLeaveError` zaten aşağıda V1.4 P1.20'de tanımlı; bu blok
  // yeniden tanımlamaz.
  static const String groupDelete = 'Grubu kapat';
  static const String groupDeleteConfirmTitle = 'Grubu kapat?';
  static const String groupDeleteConfirmBody =
      'Grup listeden kalkacak. Bu işlem geri alınamaz.';
  static const String groupDeleteCta = 'Kapat';
  static const String groupDeleteSuccess = 'Grup kapatıldı.';
  static const String groupDeleteError =
      'Grup kapatılamadı. Lütfen tekrar dene.';
  static const String groupMemberRemoveConfirmTitle = 'Üyeyi çıkar?';
  static const String groupMemberRemoveConfirmBody =
      'Üye gruptan çıkarılacak. Tekrar katılmak için istek göndermesi gerekir.';
  static const String groupMemberRemoveCta = 'Çıkar';
  static const String groupMemberRemoveSuccess = 'Üye gruptan çıkarıldı.';
  static const String groupMemberRemoveError =
      'Üye çıkarılamadı. Lütfen tekrar dene.';

  /// G.N4 — Owner grup kartında pending request count badge metni.
  /// Tekil: "1 bekleyen istek". Çoğul: "{N} bekleyen istek".
  static String groupPendingRequestCount(int count) =>
      count == 1 ? '1 bekleyen istek' : '$count bekleyen istek';

  /// V1 UX Reset — chat-centric grup ekranı için kısa metinler.
  static const String groupFirstMessage = 'İlk mesajı sen yaz';
  static String groupInfoMembers(int count) => '$count üye';
  static String groupJoinRequestsCompact(int count) =>
      count == 1 ? '1 katılım isteği' : '$count katılım isteği';
  static const String groupJoinRequestsMenu = 'Katılım istekleri';
  static const String groupJoinNowCta = 'Sohbete katıl';
  // V1 P1-C — Native share (share_plus) için subject + hata snackbar.
  static const String feedShareSubject = 'FırınNet — Paylaşım';
  static const String feedShareError =
      'Paylaşım açılamadı. Lütfen tekrar dene.';
  static const String feedActionTagSnack = 'Etiket filtresi yakında: #';

  // Group highlight banner
  static const String feedGroupHighlightSuffix = ' grubunda öne çıktı';

  // Feed/Groups Sosyal Omurga V1 — kullanıcı dostu hata/boş durumlar.
  static const String feedErrorGeneric =
      'Akış şu an yüklenemedi. Bağlantını kontrol edip yeniden dene.';
  static const String feedEmptyState =
      'Henüz paylaşım yok. İlk gönderiyi sen at — sektör seni bekliyor.';
  static const String feedEmptyStateGuest =
      'Akış henüz boş. Üye olunca ilk gönderiyi sen atabilirsin.';
  static const String groupsErrorGeneric =
      'Gruplar yüklenemedi. Bağlantını kontrol edip yeniden dene.';
  static const String groupMessagesErrorGeneric =
      'Mesajlar yüklenemedi. Yeniden dener misin?';
  static const String groupDetailErrorGeneric =
      'Grup yüklenemedi. Yeniden dener misin?';

  // Insight cards
  static const String feedInsightSectionLabel = 'Sektör pulse';

  // ─────────────────────── Borç & Gider Defteri (Final Functional Sprint)
  static const String debtExpenseTitle = 'Borç & Gider';
  static const String debtExpenseCardSub =
      'Borçlarını, giderlerini ve personel ödemelerini takip et';
  static const String deTabOverview = 'Genel Bakış';
  static const String deTabDebts = 'Borçlar';
  static const String deTabExpenses = 'Giderler';
  static const String deTabStaff = 'Personel';
  static const String deTabReports = 'Raporlar';
  static const String deAddDebt = 'Borç ekle';
  static const String deAddExpense = 'Gider ekle';
  static const String deAddStaff = 'Personel ödemesi';
  static const String deAddPayment = 'Ödeme ekle';
  static const String deEmptyTitle = 'Henüz borç veya gider eklenmedi';
  static const String deEmptySub =
      'İlk kaydını ekleyerek ödemelerini düzenli takip etmeye başla.';
  static const String deOpenDebt = 'Açık borç';
  static const String deThisMonthExpense = 'Bu ay gider';
  static const String deStaffPayable = 'Ödenecek personel';
  static const String deUpcoming = 'Bu hafta vade';
  static const String deOverdue = 'Geciken';
  static const String deRemaining = 'Kalan';
  static const String deClosed = 'Kapandı';
  static const String deStatusOpen = 'Açık';
  static const String deStatusPartial = 'Kısmi';
  static const String deStatusPaid = 'Kapandı';
  static const String deStatusOverdue = 'Gecikti';
  static const String deMarkPaid = 'Kapandı işaretle';
  static const String deDueDate = 'Vade tarihi';
  static const String deNoDueDate = 'Vade yok';
  static const String deCustomCategoryHint = 'Örn. özel un, katkı karışımı';
  static const String deCustomCategoryLabel = 'Kategori adını yaz';

  // ─────────────────────── 4 sayfalık premium intro onboarding
  static const String introSkip = 'Atla';
  static const String introNext = 'İleri';
  static const String introStart = 'FırınNet\'e Başla';
  static const String introP1Title = 'Fırıncıların yeni ağı';
  static const String introP1Body =
      'Fırınlar, bayiler ve tedarikçiler aynı sektörel ağda buluşur.';
  static const String introP2Title = 'Paylaş, keşfet, bağlantı kur';
  static const String introP2Body =
      'Sektörden paylaşımları takip et, yorum yap, doğru kişilerle temas kur.';
  static const String introP3Title = 'Pazar ve teklif ağı';
  static const String introP3Body =
      'Ürün, hizmet ve talepler için daha düzenli bir ticaret alanı.';
  static const String introP4Title = 'İşini daha düzenli yönet';
  static const String introP4Body =
      'Bayi defteri ve pratik araçlarla günlük işlerini daha kontrollü takip et.';

  // ─────────────────────── Navigation IA Sprint — alt nav + sekme başlıkları
  // Alt nav: Topluluk · Pazar · İlanlar · Mesajlar · Panel
  static const String navCommunity = 'Topluluk';
  static const String navPazar = 'Pazar';
  static const String navListings = 'İlanlar';
  static const String navMessages = 'Mesajlar';
  static const String navPanel = 'Panel';
  static const String navComingSoonBadge = 'Yakında';

  // Topluluk sekmesi (Feed + Gruplar)
  static const String communityTitle = 'Topluluk';
  static const String communitySubtitle =
      'Fırıncıların gündemi, paylaşımları ve grupları';
  static const String communitySegFeed = 'Genel Akış';
  static const String communitySegGroups = 'Gruplar';

  // İlanlar sekmesi (Eleman + İş yeri + Ekipman)
  static const String listingsTitle = 'İlanlar';
  static const String listingsSubtitle = 'Eleman, iş yeri ve ekipman ilanları';
  static const String listingsSegStaff = 'Eleman';
  static const String listingsSegWorkplace = 'İş yeri';
  static const String listingsSegEquipment = 'Ekipman';

  // Pazar — "Yakında" (B2B / tedarikçi / teklif ağı)
  static const String pazarComingTitle = 'Pazar yakında';
  static const String pazarComingSubtitle =
      'Fırıncının B2B tedarik ve teklif ağı çok yakında burada.';
  static const String pazarComingBadge = 'Yakında';
  static const String pazarBulletSuppliersTitle = 'Tedarikçileri keşfet';
  static const String pazarBulletSuppliersBody =
      'Un, maya, ekipman ve hizmet tedarikçilerini tek yerden bul.';
  static const String pazarBulletOffersTitle = 'Teklif al';
  static const String pazarBulletOffersBody =
      'İhtiyacını yaz, tedarikçilerden rekabetçi teklifler topla.';
  static const String pazarBulletCampaignsTitle =
      'Ürün ve kampanyaları takip et';
  static const String pazarBulletCampaignsBody =
      'Toptancı fiyatları, kampanyalar ve yeni ürünlerden haberdar ol.';
  static const String pazarComingFootnote =
      'Bu alan hazır olduğunda burada görünecek; şimdilik bir şey yapman gerekmiyor.';

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
  static const String jobsContact = 'İletişime geç';

  // V1 — Job messaging (job_conversations + job_messages)
  static const String messagesTitle = 'Mesajlar';
  static const String messagesSubtitle =
      'İlanlar üzerinden başlattığın sohbetler';
  static const String messagesEmpty =
      'Henüz mesaj yok. Bir ilana başvurduğunda veya iletişime geçtiğinde '
      'sohbetler burada görünür.';
  static const String messagesEmptyGuest =
      'Mesajları görmek için önce giriş yap.';
  // Faz 2 P2 — premium EmptyState için başlık + alt metin ayrımı.
  static const String messagesEmptyTitle = 'Henüz mesajın yok';
  static const String messagesEmptySubtitle =
      'Bir ilana başvurduğunda veya iletişime geçtiğinde sohbetler burada '
      'görünür.';
  static const String messagesEmptyGuestTitle = 'Mesajlar için giriş yap';
  static const String messagesErrorGeneric =
      'Mesajlar yüklenemedi. Yeniden dener misin?';
  static const String messagesRelatedJobOffer = 'Usta arayan ilan';
  static const String messagesRelatedJobSeek = 'İş arayan ilan';
  static const String messagesClosedBadge = 'KAPALI';

  static const String conversationTitleFallback = 'Sohbet';
  static const String conversationComposerHint = 'Mesaj yaz…';
  static const String conversationSendCta = 'Gönder';
  static const String conversationSendError =
      'Mesaj gönderilemedi. Yeniden dener misin?';
  static const String conversationLoadError =
      'Sohbet yüklenemedi. Yeniden dener misin?';
  static const String conversationEmptyOwn =
      'Henüz mesaj yok. İlk mesajı sen yaz.';
  static const String conversationClosedBanner =
      'Bu sohbet kapatıldı. Yeni mesaj gönderilemez.';
  static const String conversationCloseCta = 'Sohbeti kapat';
  static const String conversationClosedSnack = 'Sohbet kapatıldı.';
  static const String conversationDeleteOwnCta = 'Mesajı sil';
  static const String conversationDeletedPlaceholder = '[Mesaj silindi]';

  static const String startConvoSheetTitleOffer = 'İlana başvuru';
  static const String startConvoSheetTitleSeek = 'İletişime geç';
  static const String startConvoSheetSubtitleOffer =
      'Kendini tanıt — kim olduğunu, tecrübeni, neden bu iş için uygun olduğunu yaz.';
  static const String startConvoSheetSubtitleSeek =
      'Kısaca tanış — hangi iş için aradığını ve iletişim için ne yapacağını yaz.';
  static const String startConvoSendCta = 'Mesajı Gönder';
  static const String startConvoEmptyError = 'Boş mesaj gönderilemez.';
  static const String startConvoOwnPostError =
      'Kendi ilanına başvuru yapamazsın.';
  static const String startConvoGenericError =
      'Mesaj başlatılamadı. Yeniden dener misin?';
  static const String startConvoOpenedSnack = 'Mesajın gönderildi.';

  // V1 — Profile tehlikeli alan başlığı (hesap silme vurgusu için)
  static const String profileSectionDanger = 'Tehlikeli alan';
  static const String profileDangerHint =
      'Bu işlem geri alınamaz. Hesabını silmeden önce '
      'düşündüğünden emin ol.';

  // V1.4 — Settings (Ayarlar) menüsü Phase 1.
  // Sahte/çalışmayan tile eklenmez: bildirim/tema/dil/destek/help yok.
  static const String settingsTitle = 'Ayarlar';
  static const String settingsTooltip = 'Ayarlar';

  // Section başlıkları
  static const String settingsSectionAccount = 'Hesap';
  static const String settingsSectionSecurity = 'Güvenlik ve Veri';
  static const String settingsSectionLegal = 'Yasal';
  static const String settingsSectionApp = 'Uygulama';

  // Tile etiketleri
  // FırınNet ID — sadece sahibine gösterilir; public alanlarda yok.
  static const String settingsFirinnetIdTitle = 'FırınNet ID';
  static const String settingsFirinnetIdCopied = 'FırınNet ID kopyalandı.';
  static const String settingsEditProfile = 'Profilimi düzenle';
  static const String settingsEditProfileSubtitle =
      'Ad, hesap türü, şehir ve meslek rozetini güncelle.';
  static const String settingsSignOut = 'Çıkış yap';
  static const String settingsSignOutSubtitle = 'Bu cihazda oturumunu kapat.';
  static const String settingsDeleteAccount = 'Hesabımı sil';
  static const String settingsDeleteAccountSubtitle =
      'Hesabını ve tüm verilerini kalıcı olarak siler.';
  static const String settingsDataInfo = 'Verilerim hakkında bilgi';
  static const String settingsDataInfoSubtitle =
      'Hangi veriler tutuluyor, hesap silindiğinde ne olur?';
  static const String settingsPrivacy = 'Gizlilik Politikası';
  static const String settingsTerms = 'Kullanım Şartları';
  static const String settingsAbout = 'Hakkında';
  static const String settingsAboutSubtitle =
      'FırınNet hakkında ve sürüm bilgisi.';

  // Verilerim hakkında bilgi statik ekranı
  static const String dataInfoTitle = 'Verilerim hakkında bilgi';
  static const String dataInfoBody =
      'FırınNet hesabında profil bilgilerin (ad, hesap türü, şehir, '
      'meslek rozeti, e-posta), fırın paneli kayıtların (üretim, fire, '
      'reçeteler), bayi/müşteri kayıtların, iş ilanı/marketplace '
      'paylaşımların ve sosyal akış içeriklerin (gönderiler, beğeniler, '
      'yorumlar, gruplar, mesajlar) tutulur.\n\n'
      'Hesabını sildiğinde, hesabına bağlı bu veriler de silinir.\n\n'
      'Bu metin yasal bir döküman değildir; özet bilgilendirme amaçlıdır. '
      'Yasal kapsam için Gizlilik Politikası ve Kullanım Şartları '
      'sayfalarına bakabilirsin.';

  // Hakkında statik ekranı
  static const String aboutTitle = 'Hakkında';
  static const String aboutAppLine = 'FırınNet';
  static const String aboutTagline =
      'Fırıncılar ve sektör kullanıcıları için sosyal ağ ve iş yönetimi.';
  static const String aboutBody =
      'V1: Sektör akışı (feed), gruplar, fırın paneli (üretim, fire, '
      'reçete kütüphanesi, bayi yönetimi), iş ilanı ve marketplace '
      'akışları, hesap güvenliği.\n\n'
      'Apple ile giriş yakında eklenecek.';
  static const String aboutVersionLabel = 'Sürüm';

  // ─────────────────────── Google-only auth + legal/support polish
  // Auth giriş ekranı (Google birincil): hero copy + misafir CTA.
  static const String authEntryHeroTitle = 'Fırıncının dijital ağı';
  static const String authEntryHeroSubtitle =
      'İşini takip et, sektörle bağlantıda kal.';
  static const String authEntryGoogleHint =
      'FırınNet\'e Google hesabınla güvenli şekilde devam et.';
  static const String authEntryGuestExplore = 'Misafir olarak keşfet';

  // Topluluk Kuralları (yasal ekran + ayarlar tile)
  static const String legalCommunityTitle = 'Topluluk Kuralları';
  static const String settingsCommunity = 'Topluluk Kuralları';
  static const String settingsCommunitySubtitle =
      'FırınNet\'i güvenli ve faydalı tutan ilkeler.';

  // Hesap ve Veri Silme (yasal bilgilendirme ekranı + ayarlar tile)
  static const String legalAccountDeletionTitle = 'Hesap ve Veri Silme';
  static const String settingsAccountDeletion = 'Hesap ve veri silme';
  static const String settingsAccountDeletionSubtitle =
      'Hesabını ve verilerini nasıl silersin?';

  // Destek ve Yardım
  static const String supportTitle = 'Destek ve Yardım';
  static const String supportSubtitle =
      'FırınNet kullanımı, hesap işlemleri ve geri bildirimlerin için '
      'buradan destek alabilirsin.';
  static const String settingsSupport = 'Destek ve Yardım';
  static const String settingsSupportSubtitle =
      'Sık sorulan sorular ve bize ulaşma.';
  static const String supportFaqSection = 'Sık sorulan sorular';
  static const String supportContactSection = 'Bize ulaşın';
  static const String supportContactDesc =
      'Sorun, öneri veya geri bildirimin için e-posta gönderebilirsin. '
      'Genelde 1-2 iş günü içinde dönüş yapılır.';
  static const String supportContactCta = 'Destek e-postası gönder';
  static const String supportEmail = 'fatihkartal75@gmail.com';
  static const String supportEmailSubject = 'FırınNet Destek Talebi';
  static const String supportMailError =
      'E-posta uygulaması açılamadı. Destek adresi: ';

  // V1 — Jobs gerçek veri durumları (P0 mock temizliği)
  static const String jobsLookingEmpty =
      'Henüz aktif iş arayan ilanı yok. İlk ilanı sen ver veya daha sonra tekrar bak.';
  static const String jobsLookingEmptyGuest =
      'Henüz aktif iş arayan ilanı yok. Üye olunca kendin de ilan verebilirsin.';
  // V1 — Job offer ("Usta Arıyor") UI copy.
  static const String jobOfferEmpty =
      'Henüz aktif "Usta Arıyor" ilanı yok. Sektörden ilk ilanı bekliyoruz.';
  static const String jobOfferEmptyGuest =
      'Henüz aktif "Usta Arıyor" ilanı yok. Üye olunca sen de yayınlayabilirsin.';
  static const String jobOfferErrorGeneric =
      'İlanlar yüklenemedi. Bağlantını kontrol edip yeniden dene.';
  static const String jobOfferAddCta = 'Usta Arıyorum İlanı Ver';
  static const String jobOfferSavedSnack = 'İlanın yayında.';

  // Form
  static const String jobOfferFormTitleNew = 'Usta Arıyorum İlanı';
  static const String jobOfferFormTitleEdit = 'İlanı Düzenle';
  static const String jobOfferFormSubtitle =
      'Aradığın ustayı net anlat — şehir, vardiya, beklenti.';
  static const String jobOfferFormSaveCta = 'İlanı Yayınla';
  static const String jobOfferFieldTitle = 'Başlık';
  static const String jobOfferFieldTitleHint = 'Örn. Taş Fırın Ustası Aranıyor';
  static const String jobOfferFieldTitleRequired = 'Başlık gerekli';
  static const String jobOfferFieldRole = 'Rol / Pozisyon';
  static const String jobOfferFieldRoleHint = 'Örn. Ekmek Ustası';
  static const String jobOfferFieldRoleRequired = 'Aranan rolü seç.';
  // M8 Cleanup — bireysel role guard + salary validation messages.
  static const String jobOfferCommercialOnly =
      'Usta Arıyor ilanı vermek için ticari veya toptancı hesap gerekir.';
  static const String jobOfferSalaryNegative = 'Maaş negatif olamaz.';
  static const String jobOfferSalaryMinGtMax = 'Asgari maaş azamiyi aşamaz.';
  // Polish Sprint 1 — generic load error messages (exception detayı UI'da YOK)
  static const String dealersErrorLoad =
      'Bayi verileri yüklenemedi. Bağlantını kontrol edip tekrar dene.';
  static const String dealerBalanceErrorLoad = 'Bakiye okunamadı.';
  static const String jobOfferFieldCity = 'Şehir';
  static const String jobOfferFieldDistrict = 'İlçe';
  static const String jobOfferFieldSalaryMin = 'Ücret min (₺)';
  static const String jobOfferFieldSalaryMax = 'Ücret max (₺)';
  static const String jobOfferFieldShift = 'Vardiya';
  static const String jobOfferFieldShiftHint = 'Örn. Gece üretim 23–07';
  static const String jobOfferFieldExperience = 'Tecrübe';
  static const String jobOfferFieldExperienceHint = 'Örn. 5+ yıl';
  static const String jobOfferFieldDescription = 'Açıklama';
  static const String jobOfferFieldDescriptionHint =
      'İşin günlük akışı, atölye, beklenti…';
  static const String jobOfferFieldIsActive = 'İlan yayında';
  static const String jobOfferFieldIsActiveHint =
      'Kapatınca listeden çıkar; tekrar açabilirsin.';

  // V1 — Marketplace listing UI copy.
  static const String marketListingEmpty =
      'Henüz aktif ürün/hizmet ilanı yok. İlk ilanı sen ver.';
  static const String marketListingEmptyGuest =
      'Henüz aktif ürün/hizmet ilanı yok. Üye olunca yayınlayabilirsin.';

  // V1 Unified Profile M2 — section labels + empty states.
  static const String profileSectionAbout = 'Hakkında';
  static const String profileSectionBakery = 'İşletme';
  static const String profileSectionProfessional = 'Ustalık Bilgisi';
  static const String profileSectionPublicRecipes = 'Açık Reçeteler';
  static const String profileSectionPosts = 'Gönderiler';
  static const String profileEditCta = 'Profili düzenle';
  static const String profileEmptyProfessional =
      'Henüz mesleki bilgi eklenmemiş.';
  static const String profileEmptyBakery = 'Henüz işletme bilgisi yok.';
  static const String profileEmptyRecipes = 'Açık reçete yok.';
  // Profile Social Sprint — preview limiti aşıldığında "+N reçete daha".
  static const String profileRecipesMoreSuffix = 'reçete daha';
  static const String profileExperienceCurrent = 'Şu an';
  static const String profileExperienceYearsLabel = 'yıl deneyim';
  static const String profileWorkerSkillsLabel = 'Beceriler';
  static const String profileWorkerCitiesLabel = 'Tercih edilen şehirler';
  static const String profileWorkerShiftLabel = 'Vardiya tercihi';
  static const Map<String, String> profileAccountTypeLabels = <String, String>{
    'commercial': 'Fırın / İşletme',
    'individual': 'Usta / Çalışan',
    'wholesaler': 'Tedarikçi / Toptancı',
  };

  // Professional Profile Center Sprint 1 — çalışma geçmişi + iş arama + durum.
  static const String profileSectionExperience = 'Çalışma Geçmişi';
  static const String profileEmptyExperience =
      'Henüz çalışma geçmişi eklenmemiş.';
  static const String profileExperienceAddCta = 'Çalışma geçmişi ekle';
  static const String profileJobSeekTitle = 'İş Arıyor';
  static const String profileJobSeekViewCta = 'İlanı görüntüle';
  static const String profileJobSeekManageCta = 'İş arama durumunu güncelle';

  // Unified Professional CV Center — profil vitrini + /profile/cv merkezi.
  static const String profileHeaderAddBioCta =
      'Mesleki CV\'ne kısa tanıtım ekle';
  static const String profileCvVisitorEmpty =
      'Henüz mesleki bilgi paylaşılmamış.';
  // Profile About Section — bio header yerine ayrı "Hakkımda" bölümünde.
  static const String profileAboutTitleSelf = 'Hakkımda';
  static const String profileAboutAddCta = 'Kısa tanıtım ekle';
  // Profile Visual Placement — yan yana yatay kategori tabları.
  static const String profileTabPosts = 'Gönderiler';
  static const String profileTabRecipes = 'Reçeteler';
  static const String profileTabCv = 'Mesleki Bilgi';
  static const String profileSectionCv = 'Mesleki CV';
  static const String profileCvSectionSubtitle =
      'Kısa tanıtımın, son mesleki durumun ve çalışma geçmişin profilinde görünür.';
  static const String profileCvEditCta = 'Mesleki CV\'ni düzenle';
  static const String profileCvEmptySelf =
      'Mesleki CV bilgilerini ekle — meslek, çalışma geçmişi ve iş arama durumu.';
  static const String cvCenterTitle = 'Mesleki CV';
  static const String cvCenterIntro =
      'Tek yerden yönet: kısa tanıtım, son durum, çalışma geçmişi ve iş arama.';
  static const String cvBioLabel = 'Kısa tanıtım';
  static const String cvBioHint =
      '20 yıldır ekşi mayalı ekmek ve simit üretiyorum.';
  static const String cvBioSaveCta = 'Tanıtımı kaydet';
  static const String cvBioSaved = 'Tanıtım kaydedildi.';
  static const String cvStatusLabel = 'Son mesleki durum';
  static const String cvRecordsLabel = 'CV / Çalışma Geçmişi';
  static const String cvAddRecordCta = 'CV kaydı ekle';
  static const String cvEmptyRecords = 'Henüz CV kaydı yok. İlk kaydını ekle.';
  static const String cvVisibilityPublic = 'Profilde görünür';
  static const String cvVisibilityHidden = 'Gizli';
  static const String cvEntryTypeLabel = 'Kayıt türü';
  // Not: AppPrimaryButton label'ı uppercase + letterSpacing ile render eder;
  // "CV'den" ön-eki kaldırıldı (zaten CV merkezindeyiz) → Galaxy A34'te 11px
  // sağ taşma giderildi, buton fonksiyonu/akışı aynı.
  static const String cvOpenJobSeekCta = 'İş Arıyorum ilanı aç';
  static const String cvUpdateJobSeekCta = 'Aktif iş ilanını düzenle';
  static const Map<String, String> cvEntryTypeLabels = <String, String>{
    'individual': 'Usta / Çalışan',
    'commercial': 'Fırın / İşletme',
    'wholesaler': 'Tedarikçi / Toptancı',
    'other': 'Diğer',
  };
  static const String profileStatusSeeking = 'İş arıyor';
  static const String profileStatusBakery = 'Fırın işletmesi';
  static const String profileStatusWholesaler = 'Toptancı';
  static const String profileStatusWorking = 'Çalışıyor';

  // Profile Self-Edit M3 — temel bilgiler sheet.
  static const String profileEditSheetTitle = 'Temel bilgiler';
  static const String profileEditNameLabel = 'Ad';
  static const String profileEditCityLabel = 'Şehir';
  static const String profileEditAccountTypeLabel = 'Hesap tipi';
  // M5 Data Foundation — meslek chip section labeli.
  static const String profileEditProfessionLabel = 'Meslek';
  static const String profileEditAvatarChange = 'Fotoğraf değiştir';
  static const String profileEditAvatarUploading = 'Yükleniyor…';
  static const String profileEditAvatarErrorPick =
      'Fotoğraf seçilemedi. Lütfen tekrar dene.';
  static const String profileEditAvatarErrorUpload =
      'Fotoğraf yüklenemedi. Lütfen tekrar dene.';
  static const String profileEditSaveCta = 'Kaydet';
  static const String profileEditSaving = 'Kaydediliyor…';
  static const String profileEditSaveSuccess = 'Profil bilgilerin güncellendi.';
  static const String profileEditSaveError =
      'Kaydedilemedi. Lütfen tekrar dene.';
  static const String profileEditNameRequired = 'Adın boş olamaz.';
  static const String profileEditWorkerLink = 'Ustalık bilgilerini düzenle';

  // Profile M4 Polish — paged posts.
  static const String profilePostsLoadMore = 'Daha fazla göster';

  // Listing Contact Phone Sprint — opsiyonel telefon paylaşımı.
  static const String listingContactPhoneLabel = 'Telefon numarası (opsiyonel)';
  static const String listingContactPhoneHint = 'Örn. 0532 123 45 67';
  static const String listingContactPhoneHelper =
      'Numaranı yazarsan ilanda görünür ve arayan kişi seni doğrudan arayabilir. '
      'Doğrulama yapılmaz — paylaşmak istemiyorsan boş bırak.';
  static const String listingContactCallCta = 'Ara';
  static const String listingContactWhatsappCta = 'WhatsApp';
  static const String listingContactCallError = 'Arama ekranı açılamadı.';

  // V1 Messaging M1.2 — generic chat labels.
  static const String messagingDefaultTitle = 'Mesaj';
  static const String messagesUnknownUser = 'FırınNet kullanıcısı';
  static const String messagingContextMarket = 'Market ilanı';
  static const String messagingContextJobOffer = 'İş ilanı';
  static const String messagingContextJobSeek = 'İş arayan ilanı';
  static const String messagingSendError =
      'Mesaj gönderilemedi. Bağlantını kontrol edip tekrar dene.';
  static const String messagingStartError =
      'Sohbet başlatılamadı. Yeniden dene.';
  // Sprint A — chat empty state + failed-send retry.
  static const String messagingEmptyTitle = 'İlk mesajı sen yaz';
  static const String messagingEmptySubtitle =
      'Mesajını yaz, sohbet burada başlasın.';
  static const String messagingRetryCta = 'Tekrar dene';

  // Sprint G — chat media (image V1). V1.1 ile sheet videoyu da kapsıyor.
  static const String chatMediaSheetTitle = 'Medya ekle';
  static const String chatMediaPickGallery = 'Galeriden seç';
  static const String chatMediaTakePhoto = 'Fotoğraf çek';
  static const String chatMediaUploading = 'Fotoğraf gönderiliyor…';
  static const String chatMediaSendError =
      'Fotoğraf gönderilemedi. Bağlantını kontrol edip tekrar dene.';
  static const String chatMediaTooLarge =
      'Fotoğraf çok büyük (en fazla 10 MB).';
  static const String chatMediaUnsupported =
      'Bu dosya türü desteklenmiyor. JPG, PNG veya WebP seç.';
  static const String chatMediaPermissionDenied =
      'Galeri/kamera izni verilmedi.';
  // Resim mesajında caption yoksa content alanına yazılan kısa placeholder
  // (messages.content 1..4000 CHECK'ini karşılar; UI resmi render eder).
  static const String messagingImageFallback = '📷 Fotoğraf';

  // Chat Media V1.1 — video attachment.
  static const String chatMediaPickVideoGallery = 'Video seç';
  static const String chatMediaRecordVideo = 'Video çek';
  static const String chatMediaVideoUploading = 'Video gönderiliyor…';
  static const String chatMediaVideoSendError =
      'Video gönderilemedi. Bağlantını kontrol edip tekrar dene.';
  static const String chatMediaVideoTooLarge =
      'Video çok büyük (en fazla 25 MB).';
  static const String chatMediaVideoUnsupported =
      'Bu video türü desteklenmiyor. MP4 veya MOV seç.';
  static const String chatMediaVideoLabel = 'Video';
  // Signed URL üretilemezse (geçici yetki/ağ sorunu) bubble fallback metni.
  static const String chatMediaUnavailable = 'Medya yüklenemedi';

  // UGC Safety V1 — şikayet + engelleme.
  static const String reportSheetTitle = 'İçeriği şikayet et';
  static const String reportDetailsHint = 'Açıklama (opsiyonel)';
  static const String reportSubmit = 'Gönder';
  static const String reportSuccessBanner =
      'Şikayetin alındı. Ekibimiz inceleyecek.';
  static const String reportDuplicateBanner = 'Bu içeriği zaten şikayet ettin.';
  static const String reportErrorBanner =
      'Şikayet gönderilemedi. Bağlantını kontrol edip tekrar dene.';
  static const String safetyActionReport = 'Şikayet et';
  static const String safetyActionBlock = 'Kullanıcıyı engelle';
  static const String safetyActionUnblock = 'Engeli kaldır';
  static const String blockConfirmTitle = 'Bu kullanıcıyı engelle?';
  static const String blockConfirmBody =
      'Bu kişinin içeriklerini daha az görürsün ve seninle etkileşimi '
      'sınırlanır.';
  static const String blockConfirmCta = 'Engelle';
  static const String blockSuccessBanner = 'Kullanıcı engellendi.';
  static const String blockAlreadyBanner = 'Bu kullanıcı zaten engelli.';
  static const String unblockSuccessBanner = 'Engel kaldırıldı.';
  static const String safetyErrorBanner = 'İşlem tamamlanamadı. Tekrar dene.';
  // Engellenen kullanıcının yorum/grup mesajı yerine gösterilen placeholder.
  static const String blockedContentPlaceholder =
      'Engellediğin kullanıcıdan içerik';
  static const String blockedMessageStartBanner =
      'Engellediğin bir kullanıcıya mesaj başlatamazsın.';
  static const String safetyCancel = 'Vazgeç';
  static const String blockedUsersTitle = 'Engellediğim kullanıcılar';
  static const String blockedUsersTileSubtitle =
      'Engellediklerini gör ve engeli kaldır';
  static const String blockedUsersEmptyTitle = 'Engellediğin kullanıcı yok';
  static const String blockedUsersEmptyBody =
      'Bir kullanıcıyı engellersen burada listelenir ve engeli buradan '
      'kaldırabilirsin.';

  // Feed Boundary V1 — composer guard copy'leri.
  static const String boundaryEditCta = 'Metni düzenle';
  static const String boundaryCancelCta = 'Vazgeç';
  static const String boundaryCommercialTitle =
      'Bu paylaşım Pazar için daha uygun';
  static const String boundaryCommercialBody =
      'Feed, fırıncıların sohbet ve deneyim paylaşım alanı. Ürün, hizmet ve '
      'kampanya tanıtımlarını Pazar\'da yayınlayarak doğru alıcıya daha '
      'düzenli şekilde ulaştırabilirsin.';
  static const String boundaryCommercialCta = 'Pazar\'a git';
  static const String boundaryJobTitle =
      'Bu içerik İş İlanları için daha uygun';
  static const String boundaryJobBody =
      'Eleman arama ve iş ilanları Feed\'de kaybolmasın. İlanlar bölümünde '
      'daha doğru kişilere ulaşır ve başvurular daha düzenli takip edilir.';
  static const String boundaryJobCta = 'İş ilanı oluştur';
  static const String boundaryJobSeekTitle =
      'İş arıyorsan sana özel bir alan var';
  static const String boundaryJobSeekBody =
      '"İş Arıyorum" ilanın Feed\'de kaybolmaz; İlanlar bölümünde işverenler '
      'seni doğrudan bulur ve iletişime geçer.';
  static const String boundaryJobSeekCta = 'İş Arıyorum ilanı ver';
  static const String boundaryWorkplaceTitle =
      'İşyeri satış/devir ilanı ayrı alanda yayınlanmalı';
  static const String boundaryWorkplaceBody =
      'Fırın veya işyeri satış/devir paylaşımları Feed yerine İş yeri '
      'ilanlarında daha doğru kişilere ulaşır.';
  static const String boundaryWorkplaceCta = 'İş yeri ilanına git';
  static const String boundaryEquipmentTitle =
      'Makine ve ekipman ilanları ayrı alanda';
  static const String boundaryEquipmentBody =
      'İkinci el ekipman ve makine satışlarını ilgili ilan alanında '
      'paylaşabilirsin. Böylece alıcılar ilanını daha kolay bulur.';
  static const String boundaryEquipmentCta = 'Ekipman ilanına git';
  static const String boundaryProfanityTitle = 'Paylaşımı biraz yumuşatalım';
  static const String boundaryProfanityBody =
      'FırınNet\'te tartışma ve eleştiri serbest; hakaret, tehdit ve ağır '
      'küfür içeren paylaşımları yayınlayamıyoruz.';
  static const String boundaryScamTitle = 'Bu içerik yayınlanamaz';
  static const String boundaryScamBody =
      'Güvenlik kurallarımız gereği kaçak ürün, sahte belge veya yasa dışı '
      'hizmet içeren paylaşımlar FırınNet\'te yer alamaz.';
  static const String boundaryWhyLabel = 'Neden Feed\'de değil?';
  static const String boundaryWhyBody =
      'Feed; sohbet, soru, deneyim ve gündem için ayrıldı. İlan ve '
      'tanıtımlar kendi alanlarında hem daha görünür olur hem de Feed '
      'herkes için keyifli kalır.';
  static const String boundaryCommentBlocked =
      'Bu yorum topluluk kurallarına uymuyor. Daha yapıcı bir dille '
      'tekrar yazmayı dene.';
  // Video mesajında caption yoksa content placeholder'ı.
  static const String messagingVideoFallback = '🎬 Video';
  static const String messagingMessageCtaProfile = 'Mesaj';
  static const String messagingMessageCtaMarket = 'Satıcıya mesaj gönder';
  static const String messagingAuthRequiredMarketReason =
      'Bu satıcıya mesaj göndermek için giriş yap.';
  static const String messagingAuthRequiredProfileReason =
      'Mesaj göndermek için giriş yap.';

  // V1 Market M3 polish — empty state.
  static const String marketEmptyTitle = 'Henüz ilan yok';
  static const String marketEmptySubtitle =
      'Sektör seninle başlasın — ekipmanını sat ya da devrini ilan ver.';
  static const String marketEmptyCta = 'İlk ilanı oluştur';
  static const String marketEmptyFilteredTitle =
      'Bu filtrelerle ilan bulunamadı';
  static const String marketEmptyFilteredSubtitle =
      'Filtreleri biraz gevşetip tekrar dene.';
  static const String marketEmptyClearFiltersCta = 'Filtreleri temizle';
  static const String marketListingErrorGeneric =
      'Market ilanları yüklenemedi. Yeniden dener misin?';
  static const String marketListingAddCta = 'Ürün/Hizmet İlanı Ver';
  static const String marketListingSavedSnack = 'İlanın yayında.';

  static const String marketListingFormTitleNew = 'Ürün/Hizmet İlanı';
  static const String marketListingFormTitleEdit = 'İlanı Düzenle';
  static const String marketListingFormSubtitle =
      'Sattığın ürünü veya hizmeti dürüstçe tanıt.';
  static const String marketListingFormSaveCta = 'İlanı Yayınla';
  static const String marketListingFieldTitle = 'Başlık';
  static const String marketListingFieldTitleHint = 'Örn. Spiral mikser 80 L';
  static const String marketListingFieldTitleRequired = 'Başlık gerekli';
  static const String marketListingFieldCategory = 'Kategori';
  static const String marketListingFieldCategoryRequired = 'Kategori seç';
  static const String marketListingFieldListingType = 'Tür';
  static const String marketListingFieldCondition = 'Durum';
  static const String marketListingFieldDescription = 'Açıklama';
  static const String marketListingFieldDescriptionHint =
      'Yıl, durum, garanti, teslimat…';
  static const String marketListingFieldCity = 'Şehir';
  static const String marketListingFieldDistrict = 'İlçe';
  static const String marketListingFieldPrice = 'Fiyat (₺)';
  static const String marketListingFieldUnit = 'Birim';
  static const String marketListingFieldUnitHint = 'Örn. adet, kg, paket';
  static const String marketListingFieldIsActive = 'İlan yayında';
  static const String marketListingFieldIsActiveHint =
      'Kapatınca listeden çıkar; tekrar açabilirsin.';

  // Category labels (Türkçe gösterim)
  static const Map<String, String> marketCategoryLabels = <String, String>{
    'hammadde': 'Hammadde',
    'ekipman': 'Ekipman',
    'devren_firin': 'Devren Fırın',
    'ikinci_el': 'İkinci El',
    'ambalaj': 'Ambalaj',
    'hizmet': 'Hizmet',
    'diger': 'Diğer',
  };

  // V1 Market M1+M2: ana iki sınıflandırma (eski jenerik tipleri kaldırıldı).
  static const Map<String, String> marketListingTypeLabels = <String, String>{
    'equipment_sale': 'Ekipman satışı',
    'bakery_transfer': 'Fırın devri',
  };

  static const Map<String, String> marketConditionLabels = <String, String>{
    'new': 'Sıfır',
    'used': 'İkinci el',
    'refurbished': 'Yenilenmiş',
  };

  // V1 Market M2: ekipman alt kategorisi (listing_type=equipment_sale için).
  static const Map<String, String> marketEquipmentCategoryLabels =
      <String, String>{
        'oven': 'Fırın',
        'mixer': 'Hamur karıştırıcı',
        'dough_divider': 'Hamur böleri',
        'proofing': 'Mayalama dolabı',
        'refrigerator': 'Buzdolabı',
        'display_counter': 'Vitrin / Reyon',
        'vehicle': 'Servis aracı',
        'other': 'Diğer',
      };

  // V1 Market M2 — UI labels
  static const String marketFilterCta = 'Filtrele';
  static const String marketFilterTitle = 'Filtreler';
  static const String marketFilterClearAll = 'Tümünü temizle';
  static const String marketFilterApply = 'Uygula';
  static const String marketFilterListingType = 'İlan türü';
  static const String marketFilterEquipmentCategory = 'Ekipman kategorisi';
  static const String marketFilterCity = 'Şehir';
  static const String marketFilterDistrict = 'İlçe';
  static const String marketFilterPriceRange = 'Fiyat aralığı';
  static const String marketFilterMinPrice = 'En az';
  static const String marketFilterMaxPrice = 'En çok';
  static const String marketFilterCondition = 'Durum';
  static const String marketFilterNegotiable = 'Pazarlık var';

  static const String marketDetailTitle = 'İlan detayı';
  static const String marketDetailDescription = 'Açıklama';
  static const String marketDetailAttributes = 'Özellikler';
  static const String marketDetailOwnerSection = 'İlan sahibi';
  static const String marketDetailViewProfileCta = 'Profili gör';
  static const String marketDetailNoPhoto = 'Fotoğraf eklenmemiş.';

  static const String marketContactInApp = 'Mesaj gönder';
  static const String marketContactPhone = 'Ara';
  static const String marketContactWhatsapp = 'WhatsApp';
  static const String marketContactShareCta = 'Paylaş';
  static const String marketContactSaveCta = 'Kaydet';
  static const String marketContactSavedCta = 'Kaydedildi';

  static const String marketAttrBrand = 'Marka';
  static const String marketAttrModel = 'Model';
  static const String marketAttrYear = 'Yıl';
  static const String marketAttrCondition = 'Durum';
  static const String marketAttrCategory = 'Kategori';
  static const String marketAttrEquipmentCategory = 'Ekipman tipi';
  static const String marketAttrCity = 'Şehir';
  static const String marketAttrDistrict = 'İlçe';
  static const String marketAttrNegotiable = 'Pazarlık';
  static const String marketAttrPrice = 'Fiyat';
  static const String marketAttrCurrency = 'Para birimi';
  static const String marketAttrRentPrice = 'Aylık kira';
  static const String marketAttrTransferPrice = 'Devir bedeli';
  static const String marketAttrAreaM2 = 'Alan (m²)';
  static const String marketAttrHasLicense = 'Ruhsatlı';
  static const String marketAttrEquipmentIncluded = 'Ekipman dahil';

  static const String marketAttrYes = 'Evet';
  static const String marketAttrNo = 'Hayır';

  // Form (genişletilmiş)
  static const String marketListingFieldBrand = 'Marka';
  static const String marketListingFieldModel = 'Model';
  static const String marketListingFieldYear = 'Yıl';
  static const String marketListingFieldEquipmentCategory = 'Ekipman tipi';
  static const String marketListingFieldRentPrice = 'Aylık kira (₺)';
  static const String marketListingFieldTransferPrice = 'Devir bedeli (₺)';
  static const String marketListingFieldAreaM2 = 'Alan (m²)';
  static const String marketListingFieldEquipmentIncluded = 'Ekipman dahil';
  static const String marketListingFieldHasLicense = 'Ruhsat var';
  static const String marketListingFieldNegotiable = 'Pazarlığa açık';
  static const String marketListingFieldContactPhone = 'Telefon';
  static const String marketListingFieldContactWhatsapp = 'WhatsApp';
  static const String marketListingFieldPhotos = 'Fotoğraflar';
  static const String marketListingPickPhotoCta = 'Foto seç';
  static const String marketListingCapturePhotoCta = 'Foto çek';
  static const String marketListingPhotoMaxHint = 'En fazla 6 fotoğraf.';
  static const String marketListingPublishCta = 'Yayınla';
  static const String marketListingPublishingCta = 'Yayınlanıyor…';
  static const String jobsErrorGeneric =
      'İlanlar yüklenemedi. Bağlantını kontrol edip yeniden dene.';
  static const String jobsCardSalaryUnset = 'Ücret belirtilmemiş';
  static const String jobsCardExperienceUnset = 'Tecrübe belirtilmemiş';
  static const String jobsCardCityUnset = 'Şehir belirtilmemiş';
  static const String jobsCardBadgeActive = 'Aktif';
  static const String jobsCardBusinessFallback = 'FırınNet üyesi';

  // V1 — Account deletion (P0 / KVKK / Play compliance)
  static const String accountDeleteCta = 'Hesabımı Sil';
  static const String accountDeleteConfirmTitle =
      'Hesabını silmek istiyor musun?';
  static const String accountDeleteConfirmBody =
      'Bu işlem geri alınamaz. Hesabın, profilin, reçeteler, bayi kayıtların, '
      'fire/üretim verilerin ve sosyal omurga paylaşımların kalıcı silinir.';
  static const String accountDeleteConfirmKeyword = 'HESABIMI SİL';
  static const String accountDeleteConfirmFieldLabel =
      'Onaylamak için "HESABIMI SİL" yaz';
  static const String accountDeleteConfirmFieldHint = 'HESABIMI SİL';
  static const String accountDeleteCancel = 'Vazgeç';
  static const String accountDeleteConfirmButton = 'Hesabı kalıcı sil';
  static const String accountDeleteLoading = 'Hesap siliniyor…';
  static const String accountDeleteErrorGeneric =
      'Hesap silinemedi. Bağlantını kontrol edip yeniden dene.';
  static const String accountDeleteSuccessSnack = 'Hesabın silindi.';
  static const String accountDeleteRequireAuth =
      'Hesap silmek için giriş yapman gerekiyor.';
  static const String accountDeleteUnsupportedOffline =
      'Hesap silme yalnız Supabase bağlı modda çalışır.';

  // V1 — Marketplace mock temizliği (P0)
  static const String marketComingSoonTitle = 'Market yakında açılır';
  static const String marketComingSoonBody =
      'Doğrulanmış satıcı, gerçek ürün ve mesajlaşma altyapısı V2\'de '
      'aktive olur. O ana kadar burada ilan göstermiyoruz; sahte ürün '
      'görmektense boş bir liste daha dürüst.';
  static const String marketComingSoonHintCommercial =
      'Ticari rolündeysen Fırın Paneli ve Bayi Paneli üzerinden günlük '
      'işlerine devam edebilirsin.';

  // Role-based dashboard kartları (Panel tab içerikleri)
  static const String panelGreetingPrefix = 'Merhaba';
  static const String panelRoleSubCommercial = 'Atölyeni ve bayilerini yönet';
  static const String panelRoleSubIndividual = 'İş ağına bağlan';
  static const String panelRoleSubWholesaler = 'Ürün ve müşterilerini yönet';

  // Ticari kartlar
  static const String cardBakeryPanel = 'Fırın Defteri';
  static const String cardBakeryPanelSub =
      'Üretim, fire, ciro ve günlük işlerini takip et.';
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
  // Profile Routing + Panel Consolidation Sprint — paneldeki dağınık mesleki
  // kartları (Ustalık/Çalışma Geçmişi/İş Arıyorum) tek "Profil ve CV"
  // girişine indirir; düzenleme profil vitrinindeki CTA'lardan yapılır.
  static const String cardProfileCv = 'Profil ve CV';
  static const String cardProfileCvSubIndividual =
      'Mesleğin, çalışma geçmişin ve iş arama durumun profilinde görünür';
  static const String cardProfileCvSubCommercial =
      'Fırın bilgilerin ve ilanların profilinde görünür';
  static const String cardMyRecipes = 'Reçetelerim';
  static const String cardMyRecipesSub = 'Hamur hesabı, malzeme, yapılış';

  // V1.2 — yeni ortak/role kartlar
  static const String cardCalculator = 'Hesaplama Makinesi';
  static const String cardCalculatorSub = 'Un, su, maya, tuz → adet';

  // Modüler hesaplama merkezi (calculators/) — /calculator hub + araçlar.
  static const String calcHubTitle = 'Hesaplama';
  static const String calcHubEmpty =
      'Bu hesap türü için şimdilik hesaplama aracı yok.';
  // Hub UX cilası — kategori başlıkları, offline rozeti, kısa not.
  static const String calcHubOfflineNote =
      'Tüm hesaplar internet olmadan çalışır.';
  static const String calcOfflineBadge = 'Offline';
  // Faz 2 — ortak ürün preset kataloğu bilgilendirme notu.
  static const String calcPresetDefaultNote =
      'Bu değerler varsayılan öneridir; un, fırın ve reçeteye göre '
      'değiştirebilirsin.';
  static const String calcProductSelectLabel = 'Ürün';
  static const String calcProductGroupSelectLabel = 'Ürün grubu';
  // Premium hub yenileme — üstte rol-bazlı "Bugün lazım olur" kısayolları
  // ve kategori başlığındaki araç sayacı eki ("6 araç").
  static const String calcHubFeaturedTitle = 'Bugün lazım olur';
  static const String calcHubToolCountSuffix = 'araç';

  // ── Uygulama içi yönlendirme (guide) yüzeyleri ─────────────────────────
  // Şoför ekleme işlem rehberi (bottomGuide) — her yeni ekleme işleminde
  // görünür; kalıcı gizleme yok. Metinler GERÇEK akışa göre: ekleme
  // FırınNet ID ile davet akışıdır; ID şoför tarafında Ayarlar ekranında
  // gösterilir (dokununca kopyalanır).
  static const String driverAddGuideTitle = 'Şoför nasıl eklenir?';
  static const String driverAddGuideBody =
      'Şoförün FırınNet ID\'sini al, bu ekrana gir ve yetkisini '
      'belirleyerek davet gönder.';
  static const String driverAddGuideStep1Title =
      'Şoförden FırınNet ID\'sini iste';
  static const String driverAddGuideStep1Body =
      'Şoför uygulamaya kendi hesabıyla giriş yapar ve Ayarlar '
      'bölümündeki FırınNet ID\'sini sana gönderir.';
  static const String driverAddGuideStep2Title = 'ID\'yi bu ekrana yaz';
  static const String driverAddGuideStep2Body =
      'Şoförün gönderdiği FırınNet ID\'yi buradaki ID alanına gir. '
      'Böylece doğru kullanıcı bulunur.';
  static const String driverAddGuideStep3Title = 'Görev ve yetkiyi belirle';
  static const String driverAddGuideStep3Body =
      'Şoförün hangi teslimat, bayi ve cari işlemlerini görebileceğini seç.';
  static const String driverAddGuideStep4Title = 'Daveti gönder';
  static const String driverAddGuideStep4Body =
      'Kaydettikten sonra şoföre davet gider. Şoför onayladığında panelde '
      'aktifleşir.';
  static const String driverAddGuideFootnote =
      'ID\'yi bulamıyorsa şoföre uygulamayı açıp Ayarlar bölümünden '
      'FırınNet ID\'sini kopyalamasını söyle.';
  // Şoför daveti gönderildi kısa üst bilgi şeridi (topBanner, success).
  static const String driverAddedBannerTitle = 'Şoför daveti gönderildi';
  static const String driverAddedBannerBody =
      'Şoför onayladığında teslimat ve cari takibini panelden '
      'yönetebilirsin.';

  // ── Şube Yönetimi mini app ─────────────────────────────────────────────
  static const String branchMgmtTitle = 'Şube Yönetimi';
  static const String branchMgmtSubtitle = 'Ticari Panel';
  static const String branchMgmtCardSub =
      'Şubelerini, personelini ve süreçlerini yönet';
  static const String branchMgmtHighlights = 'Bugün Öne Çıkanlar';
  static const String branchKpiTotalBranches = 'Toplam Şube';
  static const String branchKpiActiveStaff = 'Aktif Personel';
  static const String branchKpiOpenProcesses = 'Açık Süreç';
  static const String branchKpiPendingInvites = 'Bekleyen Davet';
  static const String branchCreateCta = 'Yeni Şube Oluştur';
  static const String branchListEmpty =
      'Henüz şube yok. İlk şubeni oluşturup personelini davet et.';
  static const String branchStatusActive = 'Aktif';
  static const String branchStatusAttention = 'Dikkat';
  static const String branchStatusPassive = 'Pasif';
  static const String branchFormTitle = 'Yeni Şube';
  static const String branchFormName = 'Şube adı';
  static const String branchFormAddress = 'Adres (opsiyonel)';
  static const String branchFormPhone = 'Telefon (opsiyonel)';
  static const String branchFormSave = 'Şubeyi Oluştur';
  static const String branchFormNameRequired = 'Şube adını gir.';
  static const String branchTabGeneral = 'Genel';
  static const String branchTabStaff = 'Personel';
  static const String branchTabProcesses = 'Süreçler';
  static const String branchTabPermissions = 'Yetkiler';
  static const String branchDetailManager = 'Şube sorumlusu';
  static const String branchDetailNoManager = 'Sorumlu atanmadı';
  static const String branchStaffAddCta = 'Personel Ekle';
  static const String branchStaffEmpty =
      'Bu şubede henüz personel yok. FırınNet ID ile davet gönder.';
  static const String branchStaffPendingSection = 'Bekleyen Davetler';
  static const String branchStaffSuspend = 'Askıya Al';
  static const String branchStaffActivate = 'Aktifleştir';
  static const String branchStaffRemove = 'Çıkar';
  static const String branchProcessAddCta = 'Süreç Ekle';
  static const String branchProcessEmpty =
      'Henüz süreç yok. Günlük işleri süreç olarak ekleyip takip et.';
  static const String branchProcessFormTitle = 'Yeni Süreç';
  static const String branchProcessFormTitleField = 'Başlık';
  static const String branchProcessFormNoteField = 'Not (opsiyonel)';
  static const String branchProcessFormTypeField = 'Süreç tipi';
  static const String branchProcessTitleRequired = 'Süreç başlığını gir.';
  static const String branchPermissionsInfo =
      'Roller ve süreç izinleri davet sırasında belirlenir. Şube sorumlusu '
      'tüm süreç tiplerine yetkilidir; diğer roller yalnız seçilen tiplerde '
      'süreç ekleyip güncelleyebilir. İzin denetimi sunucudadır.';
  // Personel davet ekranı.
  static const String branchInviteTitle = 'Personel Davet Et';
  static const String branchInviteFnIdLabel = 'FırınNet ID';
  static const String branchInviteFnIdHint = 'Örn. FN-2026-000123';
  static const String branchInviteBranchField = 'Şube';
  static const String branchInviteRoleField = 'Rol';
  static const String branchInvitePermissionsField = 'Süreç izinleri';
  static const String branchInviteSend = 'Davet Gönder';
  static const String branchInviteSending = 'Gönderiliyor…';
  static const String branchInviteFnIdRequired =
      'Davet oluşturulamadı. FırınNet ID\'yi kontrol edin.';
  static const String branchInviteBranchRequired = 'Şube seç.';
  // Bireysel "Şube İşlerim".
  static const String myBranchTitle = 'Şube İşlerim';
  static const String myBranchCardSub =
      'Bağlı olduğun şubenin süreçlerini yönet';
  static const String myBranchEmpty =
      'Aktif şube üyeliğin yok. Bir işletme seni FırınNet ID\'nle şube '
      'personeli olarak eklerse şuben burada görünür.';
  static const String myBranchInviteSection = 'Şube Davetleri';
  static const String myBranchInviteAccept = 'Kabul Et';
  static const String myBranchInviteReject = 'Reddet';
  static const String myBranchPickerLabel = 'Şube';
  static const String myBranchNoPermittedTypes =
      'Bu şubede süreç ekleme yetkin yok. Süreçleri görüntüleyebilirsin.';
  // "Çalışan nasıl eklenir?" rehberi (Guide Surface).
  static const String branchStaffGuideTitle = 'Çalışan nasıl eklenir?';
  static const String branchStaffGuideBody =
      'Çalışanın FırınNet ID\'sini al, şubesini ve yetkisini seçip davet '
      'gönder.';
  static const String branchStaffGuideStep1Title =
      'Çalışandan FırınNet ID\'sini iste';
  static const String branchStaffGuideStep1Body =
      'Çalışan uygulamaya kendi hesabıyla giriş yapar ve Ayarlar '
      'bölümündeki FırınNet ID\'sini sana gönderir.';
  static const String branchStaffGuideStep2Title = 'ID\'yi bu ekrana yaz';
  static const String branchStaffGuideStep2Body =
      'Çalışanın gönderdiği FırınNet ID\'yi buradaki ID alanına gir.';
  static const String branchStaffGuideStep3Title = 'Çalışacağı şubeyi seç';
  static const String branchStaffGuideStep3Body =
      'Çalışanın bağlanacağı şubeyi listeden seç.';
  static const String branchStaffGuideStep4Title = 'Rol ve yetkisini belirle';
  static const String branchStaffGuideStep4Body =
      'Rolünü seç; hangi süreç tiplerinde çalışabileceğini işaretle.';
  static const String branchStaffGuideStep5Title = 'Daveti gönder';
  static const String branchStaffGuideStep5Body =
      'Davet çalışanın hesabına düşer; onaylayana dek şube verisi görünmez.';
  static const String branchStaffGuideStep6Title =
      'Onaylayınca süreçler açılır';
  static const String branchStaffGuideStep6Body =
      'Çalışan onaylayınca "Şube İşlerim" açılır; sen de hareketleri '
      'panelden takip edersin.';
  static const String branchStaffGuideFootnote =
      'ID\'yi bulamıyorsa çalışana uygulamayı açıp Ayarlar bölümünden '
      'FırınNet ID\'sini kopyalamasını söyle.';
  static const String branchInviteSentBannerTitle =
      'Personel daveti gönderildi';
  static const String branchInviteSentBannerBody =
      'Çalışan onayladığında şube süreçlerinde çalışmaya başlayabilir.';
  // V1 polish — davet ekranı bilgi notu + genel hata.
  static const String branchInviteNoPermissionNote =
      'İzin seçmezsen personel şubeyi görebilir, ancak süreç ekleyemez.';
  static const String branchInviteGenericError =
      'Davet gönderilemedi. Bağlantını kontrol edip tekrar dene.';
  // V1 polish — personel durum değişikliği onayları.
  static const String branchStaffSuspendConfirmTitle =
      'Personel askıya alınsın mı?';
  static const String branchStaffSuspendConfirmBody =
      'Bu personelin şube erişimi geçici olarak kapatılacak. İstediğin '
      'zaman tekrar aktifleştirebilirsin.';
  static const String branchStaffRemoveConfirmTitle = 'Personel çıkarılsın mı?';
  static const String branchStaffRemoveConfirmBody =
      'Bu personelin şube erişimi kapatılacak. Tekrar eklemek için yeni '
      'bir davet göndermen gerekir.';
  static const String branchConfirmCancel = 'Vazgeç';
  static const String branchConfirmApprove = 'Onayla';
  // V1 polish — şube pasifleştirme/aktifleştirme.
  static const String branchDeactivateCta = 'Şubeyi Pasifleştir';
  static const String branchActivateCta = 'Şubeyi Aktifleştir';
  static const String branchDeactivateConfirmTitle =
      'Şube pasifleştirilsin mi?';
  static const String branchDeactivateConfirmBody =
      'Şube listede Pasif olarak görünür; personel ve süreç verileri '
      'silinmez. İstediğin zaman tekrar aktifleştirebilirsin.';
  // V1 polish — bireysel davet kartı.
  static const String myBranchInviteFallbackTitle = 'Şube daveti';
  static const String myBranchInviteFrom = 'Davet eden';
  // V1 polish — şube listesi hata durumu.
  static const String branchListError = 'Şubeler yüklenemedi.';
  // ── Şube Yönetimi V2 ──
  static const String branchKpiAttention = 'Dikkat Gereken';
  static const String branchKpiCompletedToday = 'Bugün Tamamlanan';
  static const String branchTabActivity = 'Geçmiş';
  static const String branchActivityTitle = 'Aktivite Geçmişi';
  static const String branchActivityEmpty =
      'Henüz aktivite yok. Davetler, personel değişiklikleri ve süreç '
      'hareketleri burada listelenir.';
  static const String branchTemplatesSection = 'Şablondan Süreç Oluştur';
  static const String branchTemplateCreate = 'Oluştur';
  static const String branchSummaryToday = 'Bugün';
  static const String branchSummaryWeek = '7 Gün';
  static const String branchSummaryCreated = 'Açılan süreç';
  static const String branchSummaryCompleted = 'Tamamlanan süreç';
  static const String branchSummaryLastActivity = 'Son aktivite';
  static const String myBranchSummaryTitle = 'Şube Özetim';
  static const String myBranchSummaryOpen = 'Açık Süreç';
  static const String myBranchSummaryAttention = 'Dikkat';
  static const String myBranchSummaryCompleted = 'Tamamlanan';
  static const String myBranchSummaryPermittedTypes = 'Yetkili Tip';
  static const String myBranchManagerSection = 'Sorumlu Araçları';
  static const String myBranchManagerInfo =
      'Bu şubenin sorumlususun: personel davet edebilir, personel durumunu '
      'yönetebilir ve tüm süreçleri takip edebilirsin.';
  static const String myBranchManagerStaffSection = 'Şube Personeli';
  static const String myBranchManagerInviteCta = 'Personel Davet Et';
  static const String branchManagerInviteRoleNote =
      'Şube sorumlusu yalnız alt rollere davet gönderebilir; şube sorumlusu '
      'rolünü sadece işletme sahibi verebilir.';
  static const String branchPermissionsEditCta = 'İzinleri Düzenle';
  static const String branchPermissionsSheetTitle = 'Süreç İzinleri';
  static const String branchPermissionsSave = 'Kaydet';
  static const String branchPermissionsUpdated = 'İzinler güncellendi.';

  // ── Anlaşmalı İş Yerleri V1 ──
  static const String partnersTitle = 'Anlaşmalı İş Yerleri';
  static const String partnersCardSub =
      'Şehrinizdeki avantajlı iş yerlerini keşfedin.';
  static const String partnersSearchHint = 'İş yeri, kategori veya şehir ara';
  static const String partnersFilterCity = 'Şehir';
  static const String partnersFilterDistrict = 'İlçe';
  static const String partnersFilterCategory = 'Kategori';
  static const String partnersFilterAll = 'Tümü';
  static const String partnersFilterClear = 'Filtreleri temizle';
  static const String partnersEmptyTitle =
      'Bu bölgede henüz anlaşmalı iş yeri yok.';
  static const String partnersEmptyBody =
      'Anlaşmalı iş yeri olmak için destek bölümünden başvuru '
      'yapabilirsiniz.';
  static const String partnersListError = 'Anlaşmalı iş yerleri yüklenemedi.';
  static const String partnersBadge = 'Anlaşmalı İş Yeri';
  static const String partnersCall = 'Ara';
  static const String partnersOpenMap = 'Haritada aç';
  static const String partnersDetailCta = 'Detay';
  static const String partnersDetailNotFound = 'İş yeri bulunamadı.';
  static const String partnersDetailBenefit = 'Avantaj';
  static const String partnersDetailAbout = 'Hakkında';
  static const String partnersDetailContact = 'İletişim';
  static const String partnersDetailWebsite = 'Web sitesi';
  static const String partnersDetailReportHint =
      'Bilgilerde hata mı var? Destek ile iletişime geçin.';
  static const String partnersLinkError = 'Bağlantı açılamadı.';
  // Başvuru formu.
  static const String partnersApplyTitle = 'Anlaşmalı İş Yeri Başvurusu';
  static const String partnersApplyEntry = 'Anlaşmalı iş yeri olmak istiyorum';
  static const String partnersApplyEntrySub =
      'İşletmeni FırınNet anlaşmalı iş yerleri arasına ekletmek için '
      'başvuru yap.';
  static const String partnersApplyBusinessName = 'İşletme adı *';
  static const String partnersApplyContactName = 'Yetkili adı *';
  static const String partnersApplyPhone = 'Telefon *';
  static const String partnersApplyEmail = 'E-posta';
  static const String partnersApplyCity = 'Şehir *';
  static const String partnersApplyDistrict = 'İlçe *';
  static const String partnersApplyCategory = 'Kategori *';
  static const String partnersApplyMessage = 'Mesaj / açıklama';
  static const String partnersApplyRequired = 'Zorunlu alanları doldur.';
  static const String partnersApplySubmit = 'Başvuruyu Gönder';
  static const String partnersApplySubmitting = 'Gönderiliyor…';
  static const String partnersApplySuccess =
      'Başvurunuz alındı. Ekibimiz sizinle iletişime geçecek.';
  static const String partnersApplyError =
      'Başvuru gönderilemedi. Tekrar dene.';

  // ── Fırın Defteri V1 ──
  static const String ledgerTitle = 'Fırın Defteri';
  static const String ledgerSubtitle =
      'Bugünkü üretim, fire, ciro ve işlerini tek yerden takip et.';
  static const String ledgerDayOpen = 'Gün Açık';
  static const String ledgerDayClosed = 'Gün Kapatıldı';
  static const String ledgerQuickSection = 'Hızlı Girişler';
  static const String ledgerQuickProduction = 'Üretim yaz';
  static const String ledgerQuickWaste = 'Fire yaz';
  static const String ledgerQuickRevenue = 'Ciro yaz';
  static const String ledgerQuickNote = 'Not ekle';
  static const String ledgerQuickTask = 'İş ekle';
  static const String ledgerQuickEndOfDay = 'Gün sonu';
  static const String ledgerTasksSection = 'Bugün ne yapacağım?';
  static const String ledgerTasksEmpty =
      'Bugün için iş eklemedin. Önerilerden seç veya kendin yaz:';
  static const String ledgerTaskAddHint = 'Yeni iş yaz…';
  static const String ledgerTaskAdded = 'İş eklendi.';
  static const String ledgerRecentSection = 'Son Kayıtlar';
  static const String ledgerRecentEmpty =
      'Bugün henüz kayıt yok. Üretim veya fire yazarak başla.';
  // Akıllı özet chip'leri (deterministik).
  static const String ledgerChipNoProduction = 'Bugün üretim kaydı yok';
  static const String ledgerChipNoRevenue = 'Bugün ciro kaydı yok';
  static const String ledgerChipHighWaste = 'Fire oranı yüksek';
  static const String ledgerChipDayOpen = 'Gün sonu bekliyor';
  static const String ledgerChipAllGood = 'Bugün düzenli görünüyor';
  // Ciro / not sheet'i.
  static const String ledgerRevenueSheetTitle = 'Ciro / Gün Notu';
  static const String ledgerRevenueField = 'Bugünkü ciro (₺)';
  static const String ledgerRevenueHint =
      'Günlük ciro notudur; muhasebe kaydı değildir.';
  static const String ledgerDayNoteField = 'Gün notu';
  static const String ledgerSaved = 'Kaydedildi.';
  // Fire sebebi.
  static const String ledgerWasteReasonField = 'Fire sebebi';
  static const String ledgerWasteReasonRequired = 'Fire sebebini seç.';
  // Gün sonu.
  static const String ledgerEodTitle = 'Gün Sonu';
  static const String ledgerCloseDayCta = 'Günü kapat';
  static const String ledgerReopenDayCta = 'Günü yeniden aç';
  static const String ledgerDayClosedInfo =
      'Bu gün kapatıldı. Değişiklik için günü yeniden açabilirsin.';
  static const String ledgerEodTasksDone = 'Tamamlanan iş';
  static const String ledgerEodTasksOpen = 'Açık iş';
  static const String ledgerEodProduction = 'Üretim';
  static const String ledgerEodWaste = 'Fire';
  static const String ledgerEodWasteRatio = 'Fire oranı';
  static const String ledgerEodRevenue = 'Ciro';
  static const String ledgerEodNoteLabel = 'Gün notu';
  // Rapor.
  static const String ledgerReportTitle = 'Rapor';
  static const String ledgerReportClosedDays = 'Kapatılan gün';
  static const String ledgerReportTopWaste = 'En çok fire yazılan ürünler';
  static const String ledgerReportRecentNotes = 'Son günlük notlar';
  static const String ledgerReportEmpty =
      'Bu dönemde kayıt yok. Üretim, fire veya ciro yazdıkça rapor burada '
      'oluşur.';
  // Gider ayrımı — Fırın Defteri gider sistemi DEĞİLDİR.
  static const String ledgerExpenseLinkCta = 'Giderleri yönet';
  static const String ledgerExpenseLinkNote =
      'Giderler ayrı menüden takip edilir.';
  // Operasyon tabloları (tables polish).
  static const String ledgerTableProductionTitle = 'Bugünün Üretimi';
  static const String ledgerTableWasteTitle = 'Bugünün Fire / Zayiatı';
  static const String ledgerTableProductionEmpty =
      'Bugün henüz üretim kaydı yok.';
  static const String ledgerTableWasteEmpty = 'Bugün fire kaydı yok.';
  static const String ledgerTableDayBookTitle = 'Gün Sonu Defteri';
  static const String ledgerTableProductSummaryTitle = 'Ürün Bazlı Özet';
  static const String ledgerTableNotesTitle = 'Son Notlar';
  static const String ledgerTableEodTitle = 'Günün Özeti';
  static const String ledgerTableColTime = 'Saat';
  static const String ledgerTableColProduct = 'Ürün';
  static const String ledgerTableColQty = 'Adet';
  static const String ledgerTableColReason = 'Sebep';
  static const String ledgerTableColLoss = 'Zarar';
  static const String ledgerTableColDate = 'Tarih';
  static const String ledgerTableColRevenue = 'Ciro';
  static const String ledgerTableColProduction = 'Üretim';
  static const String ledgerTableColWaste = 'Fire';
  static const String ledgerTableColRatio = 'Oran';
  static const String ledgerTableColStatus = 'Durum';
  static const String ledgerTableShowAll = 'Tümünü gör';
  static const String ledgerTableShowLess = 'Daha az göster';
  static const String ledgerTaskStatusOpen = 'Açık';
  static const String ledgerTaskStatusDone = 'Tamamlandı';

  // ── Ticari İşletme Paywall UI V1 ──
  // Plan etiketleri.
  static const String planFreeLabel = 'Free';
  static const String planProLabel = 'Pro';
  static const String planPremiumLabel = 'Premium';
  static const String planTrialLabel = 'Deneme';
  // Panel plan/trial kartı.
  static const String planCardTrialTitle = 'Deneme sürümündesiniz';
  static const String planCardTrialDaysLeft = 'gün kaldı';
  static const String planCardTrialSub =
      'Deneme boyunca Premium özellikleri kullanabilirsiniz.';
  static const String planCardFreeTitle = 'Free plan';
  static const String planCardFreeSub =
      'Temel Fırın Defteri, 5 reçete ve temel hesaplamalar açık.';
  static const String planCardProTitle = 'Pro plan';
  static const String planCardProSub =
      'Bayi Defteri, Borç-Gider, 50 reçete ve gelişmiş raporlar açık.';
  static const String planCardPremiumTitle = 'Premium plan';
  static const String planCardPremiumSub =
      'Şube, şoförlü bayi, sınırsız reçete ve tüm raporlar açık.';
  static const String planCardViewPlans = 'Paketleri incele';
  // Planlar ekranı.
  static const String plansTitle = 'Paketler';
  static const String plansSubtitle =
      'İşletmene uygun paketi seç. Ödeme yakında; şimdilik deneme sürümü açık.';
  static const String plansTrialBanner =
      'Deneme süresince tüm Premium özellikler açık.';
  static const String plansSupportCta = 'Destek ile iletişime geç';
  static const String plansComingSoon = 'Satın alma yakında';
  static const String plansCurrentBadge = 'Mevcut';
  // Plan özellik listeleri (planlar ekranı).
  static const String planFreeFeatures =
      'Fırın Defteri temel · 7 gün rapor · 5 reçete · 8 temel hesaplama · '
      'B2B alıcı ve Anlaşmalı İş Yerleri';
  static const String planProFeatures =
      'Borç-Gider · Bayi Defteri (sınırsız bayi, tek kullanıcı) · 50 reçete · '
      '~19 hesaplama · 30 gün rapor · ürün bazlı özet';
  static const String planPremiumFeatures =
      'Şube Yönetimi · şoförlü/ekipli bayi operasyonu · sınırsız reçete · '
      'tüm hesaplamalar · sınırsız geçmiş · ileri raporlar';
  // Paywall sheet genel.
  static const String paywallUpgradeCta = 'Paketleri incele';
  static const String paywallProTag = 'Pro';
  static const String paywallPremiumTag = 'Premium';
  // Modül paywall metinleri.
  static const String paywallBranchesTitle = 'Şube Yönetimi Premium’da açılır.';
  static const String paywallBranchesBody =
      'Şube, personel, süreç ve aktivite takibi için Premium’a geçin.';
  static const String paywallDealerBookTitle = 'Bayi Defteri Pro’da açılır.';
  static const String paywallDealerBookBody =
      'Pro’da sınırsız bayi defteri tutabilir, tahsilat/iade/hareketleri '
      'yönetebilirsiniz. (Bayi Defteri tek kullanıcı/işletme sahibi '
      'kullanımıyla açıktır; bayi sayısı sınırsızdır.)';
  static const String paywallDealerDriverTitle =
      'Şoförlü ve ekipli bayi operasyonu Premium’da açılır.';
  static const String paywallDealerDriverBody =
      'Şoför daveti, atama ve scoped erişim Premium paketindedir.';
  static const String paywallDebtExpenseTitle =
      'Borç-Gider kayıtları Pro’da açılır.';
  static const String paywallDebtExpenseBody =
      'Borç, gider ve personel ödeme kayıtlarını Pro veya Premium ile '
      'takip edin.';
  static const String paywallRecipeFreeTitle =
      '5 reçeteye kadar ücretsiz kullanabilirsiniz.';
  static const String paywallRecipeFreeBody =
      'Daha fazla reçete için Pro’ya geçin.';
  static const String paywallRecipeProTitle =
      '50 reçeteye kadar Pro’da kullanabilirsiniz.';
  static const String paywallRecipeProBody =
      'Sınırsız reçete için Premium’a geçin.';
  static const String paywallCalcProTitle = 'Bu hesaplama Pro’da açılır.';
  static const String paywallCalcPremiumTitle =
      'Bu hesaplama Premium’da açılır.';
  static const String paywallCalcBody =
      'Daha fazla karar-odaklı hesaplama için paketi yükseltin.';
  static const String paywallReportProTitle =
      'Son 30 gün raporu Pro’da açılır.';
  static const String paywallReportPremiumTitle =
      'Sınırsız geçmiş Premium’da açılır.';
  static const String paywallReportBody =
      'Daha uzun rapor geçmişi için paketi yükseltin.';

  // ── İlan Ücretlendirme V1 ──
  static const String listingFeeFreeSeek = 'İş arama ilanları ücretsizdir.';
  static const String listingFeeFreePlan =
      'Planınızla ilan yayınlama ücretsiz.';
  static const String listingFeePaidTitle =
      'Bu ilan türü 50 TL yayın ücretlidir.';
  static const String listingFeePaidBody =
      'Ödeme tamamlandıktan sonra ilan yayına alınır. Pro ve Premium ticari '
      'işletmeler ilanları ücretsiz yayınlar.';
  static const String listingFeeSupplierBody =
      'Tedarikçi ilanları 50 TL yayın ücretlidir. Ödeme onayından sonra '
      'yayınlanır.';
  static const String listingFeeIndividualBody =
      'Ekipman ve işyeri devri ilanları 50 TL’dir. Ödeme onayından sonra '
      'yayınlanır.';
  static const String listingFeePendingBadge = 'Ödeme bekliyor';
  static const String listingFeePendingNotice =
      'İlanınız ödeme onayından sonra yayınlanır. Ödeme için destek ile '
      'iletişime geçin.';
  static const String listingFeePendingSupportCta = 'Destek ile iletişime geç';

  // ── Tedarikçi / Toptancı Paywall UI V1 ──
  static const String supPlanFreeTitle = 'Free tedarikçi';
  static const String supPlanFreeSub =
      '1 ürün, 3 teklif cevabı/ay ve ücretli ilan kullanımı.';
  static const String supPlanProTitle = 'Pro tedarikçi';
  static const String supPlanProSub =
      '5 ürün, 3 kampanya, 20 teklif cevabı/ay ve ücretsiz ilanlar.';
  static const String supPlanPremiumTitle = 'Premium tedarikçi';
  static const String supPlanPremiumSub =
      'Sınırsız ürün, kampanya ve teklif cevabı.';
  static const String supPlanTrialTitle = 'Deneme sürümündesiniz';
  static const String supPlanTrialSub =
      'Tedarikçi denemesi Pro özellikleriyle çalışır.';
  static const String supQuotaProducts = 'Ürün';
  static const String supQuotaCampaigns = 'Kampanya';
  static const String supQuotaReplies = 'Aylık teklif cevabı';
  static const String supQuotaUnlimited = 'Sınırsız';
  static const String supQuotaReplyExhausted = 'Bu ayki hakkınız doldu';
  static const String supPaywallProductFreeTitle =
      'Free tedarikçiler 1 ürün yayınlayabilir.';
  static const String supPaywallProductFreeBody =
      'Daha fazla ürün için Pro’ya geçin. Pro’da 5 ürün, Premium’da sınırsız '
      'ürün yayınlayabilirsiniz.';
  static const String supPaywallProductProTitle =
      'Pro’da 5 ürün yayınlayabilirsiniz.';
  static const String supPaywallProductProBody =
      'Sınırsız ürün için Premium’a geçin.';
  static const String supPaywallCampaignFreeTitle =
      'Kampanya yayınlama Pro’da açılır.';
  static const String supPaywallCampaignFreeBody =
      'Pro’da 3 kampanya, Premium’da sınırsız kampanya yayınlayabilirsiniz.';
  static const String supPaywallCampaignProTitle =
      'Pro’da 3 aktif kampanya yayınlayabilirsiniz.';
  static const String supPaywallCampaignProBody =
      'Sınırsız kampanya için Premium’a geçin.';
  static const String supPaywallReplyFreeTitle =
      'Free tedarikçiler ayda 3 teklif cevabı verebilir.';
  static const String supPaywallReplyFreeBody =
      'Daha fazla teklif cevabı için Pro’ya geçin.';
  static const String supPaywallReplyProTitle =
      'Pro’da ayda 20 teklif cevabı verebilirsiniz.';
  static const String supPaywallReplyProBody =
      'Sınırsız teklif cevabı için Premium’a geçin.';
  static const String supErrorProductQuota = 'Ürün kotanız doldu.';
  static const String supErrorCampaignQuota = 'Kampanya kotanız doldu.';
  static const String supErrorReplyQuota =
      'Bu ayki teklif cevabı hakkınız doldu.';
  static const String supPlanFreeFeatures =
      '1 ürün · kampanya yok · ayda 3 teklif cevabı · ilanlar 50 TL';
  static const String supPlanProFeatures =
      '5 ürün · 3 kampanya · ayda 20 teklif cevabı · ilanlar ücretsiz';
  static const String supPlanPremiumFeatures =
      'sınırsız ürün · sınırsız kampanya · sınırsız teklif cevabı · '
      'ilanlar ücretsiz';

  static const String calcCatDailyQuickTitle = 'Günlük Hızlı Hesaplar';
  static const String calcCatProductionTitle = 'Üretim ve Reçete';
  static const String calcCatBossCostTitle = 'Patron Maliyet ve Kâr';
  static const String calcCatSupplierTitle = 'Tedarikçi ve Pazarlık';
  static const String calcDoughYieldTitle = 'Hamurdan Ürün';
  static const String calcDoughYieldSub =
      'Hamurdan kaç ürün çıkar, hızlıca gör';
  // Ortak modüller (ticari + bireysel).
  static const String calcMorningPlanTitle = 'Sabah Üretim Planlayıcı';
  static const String calcMorningPlanSub = 'Adete göre un, su, maya, tuz.';
  static const String calcWaterRatioTitle = 'Hamur Kıvamı (Su Oranı)';
  static const String calcWaterRatioSub = 'Su oranına göre hamur kıvamını gör.';
  static const String calcSackBreadTitle = 'Çuvaldan Kaç Ürün Çıkar?';
  static const String calcSackBreadSub =
      'Çuvaldan yaklaşık ürün adedini hesapla.';
  static const String calcBakersPercentTitle =
      'Fırıncı Yüzdesi (Una Göre Reçete)';
  static const String calcBakersPercentSub =
      'Una göre su, tuz, maya miktarını bul.';
  static const String calcRecipeScaleTitle = 'Reçete Büyüt / Küçült';
  static const String calcRecipeScaleSub = 'Reçeteyi büyüt ya da küçült';
  // Çalışan modülü (yalnız bireysel).
  static const String calcWaterTempTitle = 'Hamur Suyu Sıcaklığı';
  static const String calcWaterTempSub =
      'Hamur tutsun diye su kaç derece olmalı?';
  // Patron modülleri (yalnız ticari).
  static const String calcCostProfitTitle = 'Gerçek Maliyet + Kâr';
  static const String calcCostProfitSub = 'Adet başı maliyet ve kârı gör.';
  static const String calcFlourHikeTitle = 'Un Zammı Cebe Etkisi';
  static const String calcFlourHikeSub = 'Un zammı cebine ne kadar yansır?';
  static const String calcOvenEnergyTitle = 'Fırın Enerji Maliyeti';
  static const String calcOvenEnergySub = 'Fırının günlük enerji gideri';
  static const String calcFreeGoodsTitle = 'X Al Y Bedelsiz Hesabı';
  static const String calcFreeGoodsSub = 'Bedelsizle gerçek çuval fiyatını gör';
  static const String calcEveningDiscountTitle = 'Gün Sonu Fiyatı';
  static const String calcEveningDiscountSub = 'Zarar etmeden indirim sınırı';
  // Faz 3 — ortak modüller (ticari + bireysel).
  static const String calcStockRunwayTitle = 'Stok Bu Hafta Biter mi?';
  static const String calcStockRunwaySub = 'Stokun kaç gün yeteceğini gör.';
  static const String calcBatchValueTitle = 'Tepsi / Parti Değeri';
  static const String calcBatchValueSub = 'Bir tepsi kasaya ne bırakır, gör.';
  // Faz 3 — patron modülleri (yalnız ticari).
  static const String calcPriceUpdateTitle = 'Fiyat Güncelleme Simülatörü';
  static const String calcPriceUpdateSub = 'Maliyet artınca yeni fiyatı bul.';
  static const String calcDealerProfitTitle = 'Bayi Kârlılık Ölçeği';
  static const String calcDealerProfitSub =
      'Bayi iade sonrası kazandırıyor mu?';
  static const String calcFixedCostTitle = 'Dükkan Boşta Kaça Çalışıyor?';
  static const String calcFixedCostSub = 'Sabit giderin ürün başına yükü.';
  static const String calcWasteLossTitle = 'Günlük Fire / Bayat Zarar';
  static const String calcWasteLossSub = 'Bayat/fire bugün ne kadar zarar?';
  // Final tamamlama paketi — yeni kategori + yeni modüller.
  static const String calcCatStaffShareTitle = 'Personel ve Paylaşım';
  // Final — ortak modüller (ticari + bireysel).
  static const String calcWeightChangeTitle = 'Gramaj Değişimi';
  static const String calcWeightChangeSub =
      'Gramaj değişince adet farkını gör.';
  static const String calcPackConvertTitle = 'Koli / Paket Dönüştürücü';
  static const String calcPackConvertSub = 'Adet ↔ koli dönüşümünü yap.';
  // Final — çalışan modülleri (yalnız bireysel).
  static const String calcFermentationTitle = 'Mayalanma Süresi Tahmini';
  static const String calcFermentationSub = 'Hamur yaklaşık ne zaman hazır?';
  static const String calcOvertimePayTitle = 'Mesai + Prim Hesaplayıcı';
  static const String calcOvertimePaySub = 'Mesai ve prim tutarını hesapla.';
  // Final — patron modülleri (yalnız ticari).
  static const String calcRecipeCostDetailTitle = 'Detaylı Reçete Maliyeti';
  static const String calcRecipeCostDetailSub =
      'Ürün başı gerçek maliyeti bul.';
  static const String calcFlatDealTitle = 'Düz Hesap / İskonto';
  static const String calcFlatDealSub = 'Düz hesap yüzde kaç iskonto?';
  static const String calcOvenCapacityTitle = 'Fırın Kapasite Hesabı';
  static const String calcOvenCapacitySub = 'Günlük azami üretim kapasiten.';
  static const String calcLaborIndexTitle = 'Ürün Başı İşçilik';
  static const String calcLaborIndexSub = 'Ürün başı işçilik (saniye + ₺).';
  static const String calcMasterEarningsTitle = 'Usta Hak Ediş Hesabı';
  static const String calcMasterEarningsSub = 'Ustanın prim hak edişini bul.';
  static const String calcTipSplitTitle = 'Prim / Bahşiş Bölüştürücü';
  static const String calcTipSplitSub = 'Primi ekip arasında adil böl.';
  static const String calcDailyCloseTitle = 'Günlük Kapanış (Kâr / Zarar)';
  static const String calcDailyCloseSub = 'Günün kâr / zarar özetini gör.';
  static const String cardWorkerProfile = 'Ustalık Bilgilerim';
  static const String cardWorkerProfileSub = 'Meslek, tecrübe, beceri';
  static const String cardWorkerExperiences = 'Çalışma Geçmişim';
  static const String cardWorkerExperiencesSub = 'Önceki iş yerleri ve roller';
  static const String cardWholesaleCustomers = 'Fırın Müşterileri';
  static const String cardWholesaleCustomersSub =
      'Fırın müşterilerini, satışlarını ve tahsilatlarını takip et';
  // fix/wholesaler-panel-card-to-dealers: toptancı ana kartı artık normal Bayi
  // Yönetimi shell'ine (/dealers) gider; copy ticari Bayi Paneli ile aynı
  // sistemi anlatır (müşteri/hareket/tahsilat/şoför).
  static const String cardWholesaleDealerPanelSub =
      'Müşterilerini, hareketlerini, tahsilatlarını ve şoförlerini yönet.';
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
  // V1.4 P1.6 — Recipe save exception olursa ham hata sızmasın; form
  // verisi korunur, kullanıcı tekrar deneyebilir.
  static const String recipeSaveError =
      'Reçete kaydedilemedi. Lütfen tekrar dene.';

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
  static const String dealerEditTitle = 'Bayiyi Düzenle';
  static const String dealerAddTooltip = 'Bayi ekle';

  // List
  static const String dealerSearchHint = 'Bayi adı, bölge, kişi ara…';
  static const String dealerFilterAll = 'Tümü';
  static const String dealerFilterActive = 'Aktif';
  static const String dealerFilterPassive = 'Pasif';
  static const String dealerFilterDebtOnly = 'Borçlu';
  static const String dealerListSection = 'Bayiler';
  static const String dealerListNoMatch = 'Bu kriterlerle eşleşen bayi yok.';
  static const String dealerListNoMatchHint =
      'Aramayı temizle veya filtreyi değiştirerek tekrar dene.';
  static const String dealerListEmptyTitle = 'Henüz bayi yok';
  static const String dealerListEmptySub =
      'Bayilerini ekledikçe teslimat, iade ve tahsilatları '
      'tek yerden yöneteceksin.';
  static const String dealerListEmptyCta = 'İlk bayiyi ekle';
  // Tedarikçi/Toptancı dili — aynı liste yüzeyi "Müşteri" bağlamıyla
  // (Fırın/İşletme'de "Bayi" dili korunur; rol-bazlı seçilir).
  static const String wholesalerListTitle = 'Müşteri Yönetimi';
  static const String wholesalerSearchHint = 'Müşteri adı, bölge veya kişi ara';
  static const String wholesalerListSection = 'Müşteriler';
  static const String wholesalerListNoMatch =
      'Bu kriterlerle eşleşen müşteri yok.';
  static const String wholesalerListEmptyTitle = 'Henüz müşteri eklenmemiş.';
  static const String wholesalerListEmptySub =
      'İlk müşterini ekleyerek teslimat ve tahsilatlarını takip etmeye '
      'başlayabilirsin.';
  static const String wholesalerListEmptyCta = 'İlk müşteriyi ekle';
  static const String dealerCardBalanceLabel = 'Bakiye';
  static const String dealerCardCreditLabel = 'Alacak';
  static const String dealerCardClosedLabel = 'Kapalı';
  static const String dealerCardLastTxLabel = 'Son hareket';
  static const String dealerCardPassiveBadge = 'Pasif';

  // Add dealer form
  static const String dealerFormIntro =
      'Bayi bilgilerini sade tut; teslimat, tahsilat ve hesap takibi bu kayıt üzerinden yürür.';
  static const String dealerFieldName = 'Bayi adı';
  static const String dealerFieldNameHint = 'Örn. Hamdi Bakkal';
  static const String dealerFieldNameRequired = 'Bayi adı gerekli';
  static const String dealerFieldContact = 'İletişim (opsiyonel)';
  static const String dealerFieldContactPerson = 'Yetkili kişi';
  static const String dealerFieldContactHelper =
      'Boş bırakabilirsin; teslimatta hızlı arama için önerilir.';
  static const String dealerFieldPhone = 'Telefon';
  static const String dealerFieldPhoneHelper =
      'Örn. 05xx xxx xx xx. En az 10 rakam gir.';
  static const String dealerFieldPhoneInvalid =
      'Telefon için en az 10 rakam gir veya boş bırak.';
  static const String dealerFieldArea = 'Bölge / adres';
  static const String dealerFieldAreaHint = 'Örn. Konya · Selçuklu';
  static const String dealerFieldAreaHelper =
      'İl/ilçe opsiyonel; bayi listesinde bölge takibi için kullanılır.';
  static const String dealerFieldWorkingType = 'Çalışma tipi';
  static const String dealerFieldWorkingTypeHelper =
      'Bayiyle peşin, vadeli veya karma çalışmanı not eder.';
  static const String dealerWorkingCash = 'Peşin';
  static const String dealerWorkingTerm = 'Vadeli';
  static const String dealerWorkingMixed = 'Karma';
  static const String dealerFieldNote = 'Not (opsiyonel)';
  static const String dealerFieldNoteHint =
      'Sabah erken teslim, Cuma tahsilatı vb.';
  static const String dealerSaveButton = 'Bayi Ekle';
  static const String dealerUpdateButton = 'Değişiklikleri Kaydet';
  static const String dealerSaveSnack = 'Bayi eklendi: ';
  static const String dealerUpdateSnack = 'Bayi güncellendi: ';
  static const String dealerSaveError =
      'Bayi kaydedilemedi. Lütfen bilgileri kontrol edip tekrar dene.';
  static const String dealerUpdateError =
      'Bayi güncellenemedi. Lütfen tekrar dene.';

  // Detail
  static const String dealerDetailFallbackTitle = 'Bayi';
  static const String dealerDetailNotFound = 'Bayi bulunamadı';
  static const String dealerDetailShareTooltip = 'Hesap özeti & PDF';
  static const String dealerDetailEditTooltip = 'Bayiyi düzenle';
  static const String dealerDetailStatusTooltip = 'Bayi durumu';
  static const String dealerDetailSetPassive = 'Pasifleştir';
  static const String dealerDetailSetActive = 'Aktifleştir';
  static const String dealerDetailPassiveInfo =
      'Pasif bayi listede ayrı görünür; geçmiş teslimat, tahsilat ve bakiye kayıtları silinmez.';
  static const String dealerStatusPassiveTitle = 'Bayi pasifleştirilsin mi?';
  static const String dealerStatusPassiveBody =
      'Bayi aktif iş listenden çıkar. Geçmiş hareketler, bakiye ve raporlar korunur.';
  static const String dealerStatusActiveTitle =
      'Bayi tekrar aktifleştirilsin mi?';
  static const String dealerStatusActiveBody =
      'Bayi yeniden aktif listede görünür.';
  static const String dealerStatusPassiveConfirm = 'Pasifleştir';
  static const String dealerStatusActiveConfirm = 'Aktifleştir';
  static const String dealerStatusUpdated = 'Bayi durumu güncellendi.';
  static const String dealerStatusUpdateError =
      'Bayi durumu güncellenemedi. Lütfen tekrar dene.';
  static const String dealerDetailLoadError =
      'Bayi bilgileri yüklenemedi. Bağlantını kontrol edip tekrar dene.';
  static const String dealerRetry = 'Tekrar dene';
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
  static const String dealerActionReport = 'Rapor';
  static const String dealerActionQuickPayment = 'Hızlı Tahsilat';

  // Cash tendered calculator (Sprint 6C donor lift)
  static const String cashCalcLabelPaid = 'Verilen';
  static const String cashCalcLabelChange = 'Para üstü';
  static const String cashCalcInsufficient = 'Eksik tahsilat';

  // Hızlı Tahsilat modal (Sprint 6C)
  static const String quickPaymentTitle = 'Hızlı Tahsilat';
  static const String quickPaymentDebtLabel = 'BORÇ';
  static const String quickPaymentPartialHint =
      'Kısmi tahsilat için Ödeme Al formunu kullan.';
  static const String quickPaymentSuccess = 'Tahsilat kaydedildi';
  static const String quickPaymentChangeReturn = 'Para üstü:';

  // Bayi Defteri Genel Bakış (Sprint 6B)
  static const String dealerOverviewActiveDealersLabel = 'AKTİF BAYİ';
  static const String dealerOverviewKpiOpenBalance = 'Açık Alacaklar';
  static const String dealerOverviewKpiTodayDelivery = 'Bugün Teslimat';
  static const String dealerOverviewKpiTodayPayment = 'Bugün Tahsilat';
  static const String dealerOverviewKpiMonthTxCount = 'Bu Ay İşlem';
  static const String dealerOverviewKpiMonthNetChange = 'Bu Ay Net Değişim';
  static const String dealerOverviewRecentActivityTitle = 'Son Hareketler';
  static const String dealerOverviewQuickActionsTitle = 'Hızlı İşlem';
  static const String dealerOverviewQuickAddDealer = 'Bayi Ekle';
  static const String dealerOverviewQuickDebtDealers = 'Borçlu Bayiler';
  static const String dealerOverviewQuickReports = 'Raporlar';
  static const String dealerOverviewQuickDelivery = 'Teslimat Gir';
  static const String dealerOverviewQuickPayment = 'Ödeme Al';
  static const String dealerOverviewEmptyActivity = 'Henüz hareket yok';
  static const String dealerOverviewSeeAll = 'Tümünü Gör';

  // Bayi Defteri Nabız (Sprint 3.5 — donor concept-lift EMA pattern)
  static const String dealerPulseTitle = 'NABIZ';
  static const String dealerPulseSubtitle =
      'Bugünün hareketi son 20 günlük ortalamayla karşılaştırılır';
  static const String dealerPulseMetricDelivery = 'Teslimat';
  static const String dealerPulseMetricPayment = 'Tahsilat';
  static const String dealerPulseMetricNetChange = 'Net Değişim';
  static const String dealerPulseBaselineSuffix = 'baseline';
  static const String dealerPulseInsufficientTitle = 'Pulse hesaplanamıyor';
  static const String dealerPulseInsufficientBody =
      'En az 3 günlük geçmiş hareket olduğunda nabız bilgisi gelir.';
  static const String dealerPulseFlat = 'normalde';

  // Bayi Defteri Hareketler tab (Sprint Activity)
  static const String dealerActivityTitle = 'Hareketler';
  static const String dealerActivitySearchHint = 'Bayi ara…';
  static const String dealerActivityEmptyTitle = 'Henüz hareket yok';
  static const String dealerActivityEmptyBody =
      'Bir bayiye teslimat, iade veya tahsilat ekleyince hareketler '
      'burada listelenir.';
  static const String dealerActivityNoMatchTitle = 'Eşleşen hareket yok';
  static const String dealerActivityNoMatchBody =
      'Farklı filtre veya arama dene.';
  static const String dealerActivityGroupToday = 'Bugün';
  static const String dealerActivityGroupYesterday = 'Dün';
  static const String dealerActivityGroupThisWeek = 'Bu hafta';
  static const String dealerActivityGroupOlder = 'Daha eski';

  // Bayi seçici sheet (Sprint 6B)
  static const String dealerPickerTitle = 'Bayi Seç';
  static const String dealerPickerFilterAll = 'Tümü';
  static const String dealerPickerFilterDebtOnly = 'Borçlu';
  static const String dealerPickerSearchHint = 'Bayi ara…';
  static const String dealerPickerNoDealers = 'Bayi bulunamadı';
  static const String dealerPickerNoDebtors = 'Borçlu bayi yok';

  // Bayi Defteri Mini-App Shell (Sprint 6A)
  static const String dealerShellTitle = 'Bayi Defteri';
  static const String dealerShellTabOverview = 'Genel Bakış';
  static const String dealerShellTabDealers = 'Bayiler';
  static const String dealerShellTabActivity = 'Hareketler';
  static const String dealerShellTabReports = 'Raporlar';
  static const String dealerShellTabEndOfDay = 'Gün Sonu';
  // Gün Sonu V1 — pasif günlük rapor + plain text share
  static const String dealerEndOfDayHeaderToday = 'Bugün';
  static const String dealerEndOfDaySummaryTitle = 'Bugün Özeti';
  static const String dealerEndOfDayByDealerTitle = 'Bayi Bazlı Bugün';
  static const String dealerEndOfDayRecentTitle = 'Bugünün Hareketleri';
  static const String dealerEndOfDaySeeAll = 'Tümünü Gör';
  static const String dealerEndOfDayEmptyTitle = 'Bugün henüz hareket yok';
  static const String dealerEndOfDayEmptyBody =
      'Bayilere teslimat ver veya tahsilat al; gün sonu özeti burada görünecek.';
  static const String dealerEndOfDayShareCta = 'WhatsApp/SMS Paylaş';
  static const String dealerEndOfDayShareTooltip = 'Bugünü paylaş';
  static const String dealerEndOfDayPlainTextHeader =
      'FırınNet — Gün Sonu Özeti';
  static const String dealerEndOfDayTxCountSuffix = 'işlem';
  static const String dealerEndOfDayShareEmptyLine = 'Bugün henüz hareket yok.';

  // Raporlar tab (mini-app — toplu + bayi bazlı)
  static const String dealerReportsPeriodLast7 = 'Son 7 gün';
  static const String dealerReportsPeriodLast30 = 'Son 30 gün';
  static const String dealerReportsPeriodThisMonth = 'Bu ay';
  static const String dealerReportsSummaryTitle = 'Genel Toplam';
  static const String dealerReportsByDealerTitle = 'Bayi Bazlı Rapor';
  static const String dealerReportsActiveDealersLabel = 'aktif bayi';
  static const String dealerReportsEmpty = 'Bu aralıkta hareket yok';
  static const String dealerReportsNoActiveDealers =
      'Henüz aktif bayi yok. Bayiler sekmesinden bayi ekle.';
  static const String dealerReportsKpiDelivery = 'Teslimat';
  static const String dealerReportsKpiReturn = 'İade';
  static const String dealerReportsKpiPayment = 'Tahsilat';
  static const String dealerReportsKpiNetChange = 'Net Değişim';
  static const String dealerReportsKpiTxCount = 'İşlem Sayısı';

  // Aralık Raporu (Sprint 3 — date-range metrics)
  static const String dealerReportTitle = 'Aralık Raporu';
  static const String dealerReportPeriodLast30 = 'Son 30 gün';
  static const String dealerReportPeriodPrevWeek = 'Geçen hafta';
  static const String dealerReportPeriodPrevMonth = 'Geçen ay';
  static const String dealerReportMetricNet = 'Net Değişim';
  static const String dealerReportMetricTxCount = 'İşlem Sayısı';
  static const String dealerReportEmptyTitle = 'Bu aralıkta hareket yok';
  static const String dealerReportEmptyBody =
      'Farklı bir aralık seçerek bayinin geçmiş hareketlerini gör.';

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
  static const String dealerNotesEmpty = 'Bu bayi için henüz not eklenmedi.';
  static const String dealerNotesAddHint = 'Yeni not ekle…';
  // V1.4 P1.23 — addNote exception olursa ham hata kullanıcıya sızmasın;
  // not metni input'ta korunur, kullanıcı tekrar deneyebilir.
  static const String dealerNoteAddError =
      'Not eklenemedi. Lütfen tekrar dene.';

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
  static const String dealerReturnNoteHint = 'Akşam kalan, müşteri iadesi vb.';
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
  static const String dealerAdjustmentDirectionAdd = 'Bakiyeyi artır (+)';
  static const String dealerAdjustmentDirectionSubtract = 'Bakiyeyi azalt (−)';
  static const String dealerAdjustmentNoteRequired = 'Not zorunlu';
  static const String dealerAdjustmentNoteLabel = 'Açıklama (zorunlu)';
  static const String dealerAdjustmentNoteHint =
      'Örn. eski hesap kapanışı, hatalı kayıt düzeltme';
  static const String dealerSaveSnackAdjustment =
      'Bakiye düzeltmesi kaydedildi: ';

  // V1.4 P1.7 — 4 dealer form save exception olursa Türkçe error snackbar.
  // Form AÇIK kalır (Navigator.pop çağrılmaz) ki kullanıcı tekrar deneyebilsin.
  static const String dealerDeliverySaveError =
      'Teslimat kaydedilemedi. Lütfen tekrar dene.';
  static const String dealerPaymentSaveError =
      'Ödeme kaydedilemedi. Lütfen tekrar dene.';
  static const String dealerReturnSaveError =
      'İade kaydedilemedi. Lütfen tekrar dene.';
  static const String dealerAdjustmentSaveError =
      'Düzeltme kaydedilemedi. Lütfen tekrar dene.';

  // Price sheet (V1.1)
  static const String dealerPriceSheetTitle = 'Geçerli fiyat ekle';
  static const String dealerPriceSheetProduct = 'Ürün';
  static const String dealerPriceSheetUnitPrice = 'Birim fiyat';
  static const String dealerPriceSheetValidFrom = 'Geçerlilik';
  static const String dealerPriceSheetSave = 'Kaydet';
  static const String dealerPriceSheetSaved = 'Fiyat kaydedildi: ';
  static const String dealerPriceSheetNoteHint =
      'Eski fiyat geçmişte kalır; bu kayıt yalnızca sonraki işlemlerde geçerli olur.';
  // V1.4 P1.22 — addPrice exception olursa ham hata sızmasın; sheet açık
  // kalır, kullanıcı tekrar deneyebilir.
  static const String dealerPriceSaveError =
      'Fiyat kaydedilemedi. Lütfen tekrar dene.';
  // V1.4 P1.24 — upsertJobSeekPost (toggle) exception olursa Türkçe hata.
  static const String jobSeekPostToggleError =
      'İlan durumu güncellenemedi. Lütfen tekrar dene.';
  // V1.4 P1.25 — deleteJobSeekPost exception olursa Türkçe hata; confirm
  // dialog'a dokunulmaz.
  static const String jobSeekPostDeleteError =
      'İlan silinemedi. Lütfen tekrar dene.';

  // Common errors
  static const String dealerErrPickProduct = 'Önce bir ürün seç.';
  static const String dealerErrPickReturn = 'Önce iade edilen ürünü seç.';
  static const String dealerErrQtyPositive = 'Adet sıfırdan büyük olmalı.';
  static const String dealerErrPricePositive =
      'Birim fiyat sıfırdan büyük olmalı.';
  static const String dealerErrAmountPositive = 'Tutar sıfırdan büyük olmalı.';

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
  // V1 P1-D / G.N5 — "Özel" badge kaldırıldı. Tek terim: "Katılım onaylı"
  // (bkz. groupApprovalRequiredBadge). Gizli değil, sadece içerik gated.
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
  // V1.4 P1.20 — leaveGroup non-guest/network exception → Türkçe.
  static const String groupLeaveError =
      'Gruptan çıkılamadı. Lütfen tekrar dene.';
  // V1.4 P1.21 — postMessage exception → Türkçe; input metni korunur.
  static const String groupMessageSendError =
      'Mesaj gönderilemedi. Lütfen tekrar dene.';
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
  static const String groupCreatePrivacyPrivate =
      'Katılım onaylı — istek ile katılım';
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
