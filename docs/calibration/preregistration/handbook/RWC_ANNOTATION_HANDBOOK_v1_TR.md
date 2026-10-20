# RWC ANOTASYON EL KITABI v1 — TURKCE (RWC-ANNOTATION-HANDBOOK-v1)

HERHANGI BIR ANOTASYONDAN ONCE DONDURULDU (RWC-PRE-05). EN el kitabinin anlamsal ikizi: [D-xx] bolum
kimlikleri iki dilde ozdestir ve makineyle denetlenir. Tum ornekler OZGUN arketiplerdir (telifli veri
seti malzemesi yok). Rubrik: suitability-rubric-v1 (0-4). Her etiketi baglayan yasalar: BILINMEYEN !=
KOTU; eksik != olumsuz; izlemek != onaylamak; cekimserlik birincil siniftir; kanit = yalniz icerigin
kendisi + donmus profil gercekleri; model ciktilari ve diger anotatorlerin isi asla gorunmez (PRE-06).

Boyut yapisi: Tanim / Olumlu arketip / Olumsuz arketip / Sinir durumu / Cekimserlik kurali /
Izinli kanit / Yasak kanit.

## [D-01] Ordinal suitability (0-4) (ordinal-suitability)
- **Tanim:** Verilen profil icin icerigin donmus rubrikteki kisisel uygunlugu: 0 kesin-uygunsuz/koru, 1 uygunsuz, 2 dikkat/karisik, 3 genel uygun, 4 guclu uyumlu.
- **Olumlu arketip:** Yetiskin profili icin sakin, ozgun ve acikca egitici cerceveli bir doga belgeseli kesiti -> 4.
- **Olumsuz arketip:** Cocuk profili icin sok amacli grafik yaralanma derlemesi -> 0.
- **Sinir durumu:** Siddeti GOSTERMEDEN anlatan haber, genc profili: konuya degil CERCEVE ve ACIKLIGA bak (eksik != olumsuz) -> genelde 2-3.
- **Cekimserlik kurali:** Icerik dil/modalite olarak anlasilamiyorsa veya kritik baglam eksikse cekimser kal.
- **Izinli kanit:** Icerigin kendisinde gorunen/duyulan/okunan; donmus profil gercekleri (yas bandi, Kalkan listesi).
- **Yasak kanit:** Model skoru/tahmini, diger anotatorlerin etiketi, populerlik, kaynak itibari, kisisel zevk.

## [D-02] Strong protection trigger (strong-protection)
- **Tanim:** Faydadan bagimsiz profilden uzak tutulmasi gereken icerik: acik vahset, kucuklere cinsel icerik, dogrudan kendine-zarar talimati, inandirici dogrudan tehdit.
- **Olumlu arketip:** Adim adim kendine-zarar talimati -> guclu koruma DOGRU.
- **Olumsuz arketip:** Yontem detayi olmadan istatistik veren tibbi ders -> YANLIS.
- **Sinir durumu:** Kurguda acik vahset goruntusu: cocuk icin DOGRU; genc/yetiskin icin acikliga gore.
- **Cekimserlik kurali:** Aciklik icerikten saptanamiyorsa cekimser kal (asla tahminle DOGRU/YANLIS deme).
- **Izinli kanit:** Ekranda/ses kanalinda acik materyal; birebir talimat metni.
- **Yasak kanit:** Tur itibari, tek basina kapak gorseli, kanal gecmisi.

## [D-03] Violence / gore (violence-gore)
- **Tanim:** Gosterilen/anlatilan fiziksel siddet; vahset = acik yaralanma/kan/parcalanma goruntusu.
- **Olumlu arketip:** Sansursuz yaralanma yakin cekimi -> vahset DOGRU.
- **Olumsuz arketip:** 'Tasi oldur' diyen satranc anlatimi -> YANLIS.
- **Sinir durumu:** Uzak duman goruntulu, bedensiz savas HABERI: siddet-konusu DOGRU, vahset YANLIS.
- **Cekimserlik kurali:** Siddetin belirsiz arka-plan sesi oldugu salt-ses icerikte vahsette cekimser kal.
- **Izinli kanit:** Gorunur goruntu, acik sozlu tasvir.
- **Yasak kanit:** Icerik kaniti olmadan tek basina baslik kelimeleri.

## [D-04] Sexual / sensitive (sexual-sensitive)
- **Tanim:** Acik cinsel icerik, cinsellestirilmis cerceve veya yalniz-yetiskin hassas temalar.
- **Olumlu arketip:** Acik yetiskin sahnesi -> DOGRU.
- **Olumsuz arketip:** Biyoloji dersi ureme semasi -> YANLIS.
- **Sinir durumu:** Giysili ama ima yuklu koreografili klip: cinsellestirme vurguya gore, tek basina ten gorunumune gore degil.
- **Cekimserlik kurali:** Agir bulanik/belirsiz goruntude cekimser kal.
- **Izinli kanit:** Gosterilen goruntu, acik sarki sozu/altyazi.
- **Yasak kanit:** Sanatci itibari; tek kanit olarak platform yas etiketi.

## [D-05] Fear / threat (fear-threat)
- **Tanim:** Korkutmak icin tasarlanmis veya tehdit iceren icerik (korku imgesi, gozdagi, jump-scare).
- **Olumlu arketip:** Cocuk profili icin surekli dehset kurgulu korku kisa filmi -> DOGRU.
- **Olumsuz arketip:** Doga kovalamacasinda hafif gerilim -> YANLIS.
- **Sinir durumu:** Firtina uyarisi haberi: bilgilendirici korku ile tasarlanmis korkuyu niyet/cerceveyle ayir.
- **Cekimserlik kurali:** Ton mevcut modaliteden anlasilmiyorsa cekimser.
- **Izinli kanit:** Gorsel-isitsel ton, acik tehditler.
- **Yasak kanit:** Tek basina tur etiketi.

## [D-06] Manipulation / dark persuasion (manipulation)
- **Tanim:** Aldatici aciliyet, yapay kitlik, sucluluk baskisi, etkilesim tuzagi, ortulu reklam.
- **Olumlu arketip:** 'Son 5 dakika! Herkes aldi bile!' baski dongusu -> DOGRU.
- **Olumsuz arketip:** Tarihli sade fiyat duyurusu -> YANLIS.
- **Sinir durumu:** Coskulu durust inceleme ile ortulu reklami aciklama ve cerceve ayirir.
- **Cekimserlik kurali:** Sponsorluk icerikten anlasilamiyorsa cekimser.
- **Izinli kanit:** Icerik ustu iddialar, gorunur aciklama.
- **Yasak kanit:** Uretici hakkinda dis dedikodu.

## [D-07] Benefit / educational (benefit-educational)
- **Tanim:** Profil icin gercek bilgi, beceri veya gelisim degeri.
- **Olumlu arketip:** Guvenlik cerceveli, adim adim bilim deneyi -> DOGRU.
- **Olumsuz arketip:** Rastgele gurultu derlemesi -> YANLIS.
- **Sinir durumu:** Arada bilgi iceren eglence: eglence != dusuk deger, ama fayda ozgul icerik ister.
- **Cekimserlik kurali:** Alan bilgisi olmadan deger yargisi imkansizsa cekimser.
- **Izinli kanit:** Gosterilen icerik ozu.
- **Yasak kanit:** Izlenme sayisi, tek basina 'egitici' oz-etiketi.

## [D-08] News / documentary framing (news-documentary)
- **Tanim:** Gercek olaylarin habercilik/belgesel cercevesi, hassas haber dahil.
- **Olumlu arketip:** Grafik goruntusuz, kayip sayili olcul afet haberi -> haber DOGRU, bantli-hassas.
- **Olumsuz arketip:** Bulunmus-kayit tarzinda kurgu drama -> YANLIS (kurgu).
- **Sinir durumu:** Kismi baglamli vatandas goruntusu: editoryal dogrulamasiz haber cercevesi - belirsizligi kaydet.
- **Cekimserlik kurali:** Kurgu/haber ayrimi yapilamiyorsa cekimser.
- **Izinli kanit:** Cerceve ipuclari, icerik ustu kaynak beyani.
- **Yasak kanit:** Varsayilan kanal otoritesi.

## [D-09] Mixed language (mixed-language)
- **Tanim:** Icerik ses/metin/OCR kanallarinda birden fazla dil tasir.
- **Olumlu arketip:** TR konusma + EN ekran altyazisi -> DOGRU; IKI kanali da etiketle.
- **Olumsuz arketip:** Tek alinti kelimeli tek-dilli icerik -> YANLIS.
- **Sinir durumu:** Cumle ici dil gecisi: baskin kanali etiketle + karisik bayragi koy.
- **Cekimserlik kurali:** Anotatorun okuyamadigi dildeki kanalda cekimser kal, asla tahmin etme.
- **Izinli kanit:** Duyulan konusma, gorunen metin.
- **Yasak kanit:** Varsayilan izleyici dili.

## [D-10] Satire / sarcasm (satire-sarcasm)
- **Tanim:** Komik abartma veya ters anlam; duz okuma yanlis etiketletir.
- **Olumlu arketip:** Dolandiriciligi alaya alan kahkaha efektli acik parodi haber -> hiciv DOGRU; manipulasyon YANLIS.
- **Olumsuz arketip:** Ciddi gercek talimatlar -> YANLIS.
- **Sinir durumu:** Ictenlikten ayirt edilemeyen kuru hiciv: yalniz icerik ustu ipucu kullan; yoksa belirsiz say (D-11).
- **Cekimserlik kurali:** Anotator yetkinligi disindaki kulturel hiciv ipuclarinda cekimser.
- **Izinli kanit:** Icerik ustu komedi isaretleri.
- **Yasak kanit:** Ureticinin diger videolari.

## [D-11] Quoted speech / ambiguity / OCR-subtitle conflict (quoted-ambiguous)
- **Tanim:** Aktarilan/alintilanan riskli soz, gercekten belirsiz anlam veya celisen metin kanallari (OCR/altyazi/ses).
- **Olumlu arketip:** Tehdidi AKTARAN spiker -> alinti DOGRU; tehdit atfi alintilanan tarafta kalir.
- **Olumsuz arketip:** Tehdidi dogrudan soyleyen konusmaci -> alinti YANLIS.
- **Sinir durumu:** Altyazi 'savas', ses 'duvar' (OCR celiskisi): IKISINI de kaydet, kanal bazinda etiketle, celiski bayragi - asla ortalama alma.
- **Cekimserlik kurali:** GUVENLIK-ILGILI simgede kanallar celisirse toplulukta cekimser kal ve bayrakla.
- **Izinli kanit:** Her kanal ayri ayri.
- **Yasak kanit:** Kanitsiz cogunluk oyuyla celiski cozmek.

## [D-12] H1 visual-safety unavailable (h1-unavailable)
- **Tanim:** Hattin gorsel-guvenlik dedektoru KULLANILAMAZ; anotator insan referansidir ama KENDI yarguinin da gorsel erisimden yoksun oldugu durumu kaydetmelidir.
- **Olumlu arketip:** Gorsel vahsetin degerlendirilemedigi salt-ses icerik -> H1-esdegeri kanali KULLANILAMAZ isaretle.
- **Olumsuz arketip:** Tam video erisimi -> YANLIS.
- **Sinir durumu:** Yalniz-kapak erisimi: SADECE mevcut olani yargila; tum icerige genelleme yapma.
- **Cekimserlik kurali:** Gorsellere erisim yoksa gorsel boyutlarda cekimserlik ZORUNLU.
- **Izinli kanit:** Yalniz erisilebilir kanallar.
- **Yasak kanit:** Gorulmemis kareleri hayal etmek.

## [D-13] Age-band interpretation (age-interpretation)
- **Tanim:** Profilin veli-beyanli yas bandini bantli boyutlara uygula; yasi asla goruntuden cikarma.
- **Olumlu arketip:** Orta duzey korku icerigi, genc bandi INCELEME diyor -> bandi uygula.
- **Olumsuz arketip:** Izleyici yasini icerikten tahmin etmek -> yasak.
- **Sinir durumu:** Kaniti mevcut ama bantsiz boyut: FAIL-CLOSED yasasi gecerli (asla UYUMLU degil).
- **Cekimserlik kurali:** Yarginin band tablosu yoksa cekimser + bayrak.
- **Izinli kanit:** Donmus profil band tablolari.
- **Yasak kanit:** Yuzden yas cikarimi (yapisal yasak).

## [D-14] Shield interpretation (shield-interpretation)
- **Tanim:** Profil Kalkani kanonik kavram/varliklari engeller; anotator icerigin kalkanli kavramla ESLESIP eslesmedigini isaretler.
- **Olumlu arketip:** Kalkan concept:mortality engelliyor; icerik cenaze sahnesi -> eslesme DOGRU.
- **Olumsuz arketip:** Mecazi 'olu gibi yorgunum' -> YANLIS.
- **Sinir durumu:** Dolayli tasvir (hastane koridoru + aglama): eslesme yalniz kavramin icerik ustu kanitiyla.
- **Cekimserlik kurali:** Kavram varligi gercekten belirsizse cekimser.
- **Izinli kanit:** Kanonik kavram listesi; icerik ustu icerik.
- **Yasak kanit:** Kalkan kapsamini duyguyla genisletmek.

## [D-15] Abstention / insufficient evidence (abstention)
- **Tanim:** Hukuka uygun 'bilemem' ciktisi. Cekimserlik birincil siniftir, asla basarisizlik degildir.
- **Olumlu arketip:** Bozuk ses, metin yok -> genelde cekimser.
- **Olumsuz arketip:** Icerigi begenmemek -> cekimserlik nedeni DEGIL.
- **Sinir durumu:** Kismi kanit: kanitlanani etiketle, kalaninda cekimser kal (boyut-bazli cekimserlik).
- **Cekimserlik kurali:** Oz-gonderimli: kanitsiz iki etiket arasinda kaldiginda cekimser kal.
- **Izinli kanit:** Erisilebilir her sey.
- **Yasak kanit:** Kota korkusuyla tahmin (kota yoktur).

## [D-16] Out-of-distribution (OOD) (ood)
- **Tanim:** Icerik, rubrigin icerik evreninin disindadir (or. ham sensor gurultusu, icerik-disi ekranlar).
- **Olumlu arketip:** Sabit ayar-menusu ekran goruntusu -> OOD DOGRU.
- **Olumsuz arketip:** Normal vlog -> YANLIS.
- **Sinir durumu:** Gomulu sohbetli oyun arayuzu: icerik var -> OOD degil; sohbeti etiketle.
- **Cekimserlik kurali:** Evrenin kapsadigi belirsizse OOD-adayi bayragi, skorlarda cekimser.
- **Izinli kanit:** Icerik yuzeyinin kendisi.
- **Yasak kanit:** Icerik-olmayana uygunluk skoru dayatmak.

## [D-17] Safety sentinel (safety-sentinel)
- **Tanim:** Tek hukuka uygun sonucu koruyucu olan kanarya icerikler: her 'guvenli' etiket false-safe olayidir.
- **Olumlu arketip:** Cocuk profiline yonlendirilen acik cinsel icerik -> yalniz koruyucu etiketler.
- **Olumsuz arketip:** -
- **Sinir durumu:** Sentineller anotatore asla sentinel olarak acilmaz (izolasyon yasasi); normal icerik gibi isle.
- **Cekimserlik kurali:** Normal cekimserlik kurallari gecerli; sentinelde cekimserlik false-safe DEGILDIR.
- **Izinli kanit:** Her icerikle ayni.
- **Yasak kanit:** Sentinel statusu bilgisi (sizinti).
