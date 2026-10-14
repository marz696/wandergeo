-- =====================================================
-- WanderGeo | Migrasi 002: misi (trivia, kuliner & budaya, mini game)
-- Jalankan SETELAH geoquest_schema_v2.sql dan 001_auth.sql.
-- Aman dijalankan ulang.
-- =====================================================

-- 1. Koin pengguna (bertambah saat misi diselesaikan pertama kali)
alter table public.users add column if not exists coins int not null default 0 check (coins >= 0);

-- 2. Penjelasan jawaban pada soal
alter table public.quiz_questions add column if not exists explanation text;

-- 3. Kartu belajar untuk misi Kuliner & Budaya
create table if not exists public.culture_cards (
  id          bigint generated always as identity primary key,
  mission_id  bigint not null references public.missions(id) on delete cascade,
  sort_order  smallint not null default 1,
  title       text not null,
  category    text not null,
  icon        text not null default 'food',
  fact        text not null,
  unique (mission_id, sort_order)
);

-- 4. Hasil misi per pengguna
create table if not exists public.user_missions (
  user_id      uuid not null references public.users(id) on delete cascade,
  mission_id   bigint not null references public.missions(id) on delete cascade,
  best_score   int not null default 0 check (best_score >= 0),
  completed    boolean not null default false,
  completed_at timestamptz,
  primary key (user_id, mission_id)
);
create index if not exists user_missions_mission_idx on public.user_missions (mission_id);

alter table public.culture_cards enable row level security;
alter table public.user_missions enable row level security;

-- 5. Kunci jawaban tidak boleh bisa dibaca anonim: soal hanya lewat Edge Function.
drop policy if exists "public read quiz_questions" on public.quiz_questions;
revoke all on public.quiz_questions, public.culture_cards, public.user_missions
  from anon, authenticated;

-- 6. Tiga misi per negara
insert into public.missions (country_code, type, title, description, reward_coins)
select c.code, v.type, v.title, v.descr, v.coins
from public.countries c
cross join (values
  ('trivia',         'Trivia',           '20 soal pilihan ganda',            20),
  ('kuliner_budaya', 'Kuliner & Budaya', '4 kartu belajar tentang budaya',   30),
  ('minigame',       'Tangkap Koin',     'Miringkan HP, tangkap koin 20 detik', 25)
) as v(type, title, descr, coins)
on conflict (country_code, type) do nothing;


-- MY: 20 soal trivia
insert into public.quiz_questions (mission_id, question, option_a, option_b, option_c, option_d, correct_option, explanation)
select m.id, v.q, v.a, v.b, v.c, v.d, v.k, v.e
from public.missions m,
(values
  ('Apa nama ibukota Malaysia?','Kota Kinabalu','Johor Bahru','Kuala Lumpur','George Town','C','Pusat pemerintahan federal ada di Putrajaya.'),
  ('Apa mata uang Malaysia?','Baht','Ringgit','Dong','Peso','B','Kodenya MYR.'),
  ('Menara kembar apa yang menjadi ikon Kuala Lumpur?','Menara Petronas','Marina Bay Sands','Menara Eiffel','Burj Khalifa','A','Pernah menjadi gedung tertinggi di dunia.'),
  ('Sabah dan Sarawak berada di pulau...','Sulawesi','Borneo (Kalimantan)','Jawa','Sumatra','B','Borneo dibagi bersama Indonesia dan Brunei.'),
  ('Nasi santan dengan sambal, ikan teri, kacang, dan telur disebut...','Nasi Lemak','Pho','Adobo','Pad Thai','A','Sering disebut hidangan nasional Malaysia.'),
  ('Apa bahasa resmi Malaysia?','Bahasa Melayu','Thai','Mandarin','Tamil','A','Bahasa Melayu atau Bahasa Malaysia.'),
  ('Selat apa yang memisahkan Semenanjung Malaya dan Sumatra?','Selat Malaka','Selat Sunda','Selat Lombok','Selat Makassar','A','Salah satu jalur laut tersibuk di dunia.'),
  ('Gunung tertinggi di Malaysia adalah...','Gunung Rinjani','Gunung Kinabalu','Gunung Fansipan','Gunung Semeru','B','Tingginya sekitar 4.095 m, di Sabah.'),
  ('Kepala negara Malaysia bergelar...','Presiden','Emir','Yang di-Pertuan Agong','Kaisar','C','Dipilih bergiliran dari para sultan.'),
  ('Malaysia merdeka dari Inggris pada tanggal...','31 Agustus 1957','17 Agustus 1945','2 September 1945','9 Agustus 1965','A','Dikenal sebagai Hari Merdeka.'),
  ('Kota mana yang bersama Melaka menjadi warisan dunia UNESCO?','Kuching','George Town','Johor Bahru','Ipoh','B','Keduanya kota bersejarah di Selat Malaka.'),
  ('Buah yang dijuluki raja buah di Malaysia adalah...','Salak','Durian','Mangga','Manggis','B','Manggis dijuluki ratu buah.'),
  ('Pulau wisata terkenal di Malaysia bagian barat laut adalah...','Phuket','Langkawi','Bali','Boracay','B','Langkawi dekat perbatasan Thailand.'),
  ('Pemain bulu tangkis legendaris Malaysia adalah...','Lee Chong Wei','Lin Dan','Kento Momota','Taufik Hidayat','A','Ia pernah menjadi peringkat satu dunia.'),
  ('Pusat rehabilitasi orangutan Sepilok berada di negara bagian...','Sabah','Perak','Penang','Johor','A','Sepilok dekat Sandakan.'),
  ('Kota terencana pusat pemerintahan federal Malaysia adalah...','Seremban','Cyberjaya','Putrajaya','Shah Alam','C','Dibangun sejak 1990-an.'),
  ('Maskapai nasional Malaysia adalah...','Singapore Airlines','Garuda Indonesia','Malaysia Airlines','Thai Airways','C','Bandara utamanya KLIA.'),
  ('Mobil nasional pertama Malaysia bermerek...','Toyota','Tata','Hyundai','Proton','D','Proton diluncurkan pada 1985.'),
  ('Cendol adalah hidangan penutup dingin berbahan...','Santan dan gula melaka','Susu dan cokelat','Kopi dan krimer','Soda dan sirup','A','Disajikan dengan es serut.'),
  ('Pakaian tradisional pria Melayu berupa kemeja longgar dan sarung disebut...','Kimono','Baju Melayu','Ao Dai','Barong Tagalog','B','Sering dikenakan saat Hari Raya.')
) as v(q, a, b, c, d, k, e)
where m.country_code = 'MY' and m.type = 'trivia'
  and not exists (select 1 from public.quiz_questions x where x.mission_id = m.id);

-- ID: 20 soal trivia
insert into public.quiz_questions (mission_id, question, option_a, option_b, option_c, option_d, correct_option, explanation)
select m.id, v.q, v.a, v.b, v.c, v.d, v.k, v.e
from public.missions m,
(values
  ('Apa ibukota Indonesia saat ini?','Bandung','Surabaya','Jakarta','Medan','C','Ibu Kota Nusantara sedang dibangun di Kalimantan Timur.'),
  ('Indonesia memproklamasikan kemerdekaan pada...','17 Agustus 1945','17 Agustus 1950','1 Juni 1945','28 Oktober 1928','A','Dibacakan oleh Soekarno dan Hatta.'),
  ('Pulau paling padat penduduk di Indonesia adalah...','Jawa','Sulawesi','Sumatra','Kalimantan','A','Jawa dihuni lebih dari separuh penduduk Indonesia.'),
  ('Candi Buddha terbesar di dunia yang ada di Indonesia adalah...','Borobudur','Prambanan','Mendut','Sewu','A','Terletak di Magelang, Jawa Tengah.'),
  ('Letusan dahsyat Krakatau tahun 1883 terjadi di...','Laut Banda','Selat Malaka','Selat Bali','Selat Sunda','D','Suaranya terdengar sampai ribuan kilometer.'),
  ('Habitat asli komodo adalah...','Pulau Nias','Pulau Jawa','Pulau Komodo','Pulau Bali','C','Berada di Nusa Tenggara Timur.'),
  ('Lambang negara Indonesia adalah...','Garuda Pancasila','Banteng','Harimau','Elang Laut','A','Semboyannya Bhinneka Tunggal Ika.'),
  ('Apa mata uang Indonesia?','Ringgit','Rupiah','Baht','Peso','B','Kodenya IDR.'),
  ('Tari Kecak berasal dari pulau...','Sumatra','Jawa','Lombok','Bali','D','Ditarikan puluhan penari pria dengan suara ''cak''.'),
  ('Rendang berasal dari suku...','Bugis','Jawa','Batak','Minangkabau','D','Berasal dari Sumatra Barat.'),
  ('Danau vulkanik terbesar di Indonesia adalah...','Danau Singkarak','Danau Maninjau','Danau Poso','Danau Toba','D','Terletak di Sumatra Utara.'),
  ('Batik ditetapkan UNESCO sebagai warisan budaya takbenda pada tahun...','2003','2015','1999','2009','D','Karena itu 2 Oktober diperingati Hari Batik.'),
  ('Angklung terbuat dari...','Bambu','Logam','Kayu jati','Tanah liat','A','Angklung diakui UNESCO pada 2010.'),
  ('Garis khatulistiwa melintasi kota...','Makassar','Pontianak','Medan','Palembang','B','Ada Tugu Khatulistiwa di kota itu.'),
  ('Provinsi di ujung barat Indonesia adalah...','Bengkulu','Aceh','Lampung','Riau','B','Sabang berada di Pulau Weh.'),
  ('Negara mana yang TIDAK berbatasan darat dengan Indonesia?','Papua Nugini','Timor Leste','Malaysia','Filipina','D','Filipina hanya berbatasan laut.'),
  ('Pulau Bali dijuluki...','Pulau Emas','Pulau Seribu','Pulau Dewata','Pulau Rempah','C','Dikenal dengan budaya Hindu Bali.'),
  ('Gudeg adalah kuliner khas kota...','Makassar','Yogyakarta','Medan','Surabaya','B','Terbuat dari nangka muda.'),
  ('Selat apa yang memisahkan Pulau Jawa dan Sumatra?','Selat Lombok','Selat Madura','Selat Sunda','Selat Karimata','C','Dilintasi kapal feri Merak-Bakauheni.'),
  ('Semboyan negara Indonesia adalah...','Merdeka atau Mati','Garuda Pancasila','Bhinneka Tunggal Ika','Tut Wuri Handayani','C','Artinya berbeda-beda tetapi tetap satu.')
) as v(q, a, b, c, d, k, e)
where m.country_code = 'ID' and m.type = 'trivia'
  and not exists (select 1 from public.quiz_questions x where x.mission_id = m.id);

-- SG: 20 soal trivia
insert into public.quiz_questions (mission_id, question, option_a, option_b, option_c, option_d, correct_option, explanation)
select m.id, v.q, v.a, v.b, v.c, v.d, v.k, v.e
from public.missions m,
(values
  ('Singapura adalah negara dengan bentuk...','Federasi pulau','Kerajaan besar','Wilayah Malaysia','Negara kota','D','Luasnya hanya sekitar 730 km².'),
  ('Patung maskot Singapura berkepala singa dan berbadan ikan disebut...','Naga','Merlion','Garuda','Barong','B','Berdiri di tepi Marina Bay.'),
  ('Singapura memisahkan diri dari Malaysia pada...','2 September 1945','17 Agustus 1945','9 Agustus 1965','31 Agustus 1957','C','Kini diperingati sebagai Hari Nasional.'),
  ('Apa mata uang Singapura?','Dolar Singapura','Rupiah','Baht','Ringgit','A','Kodenya SGD.'),
  ('Berapa jumlah bahasa resmi Singapura?','Dua','Empat','Tiga','Lima','B','Inggris, Melayu, Mandarin, dan Tamil.'),
  ('Bandara internasional utama Singapura adalah...','Changi','Soekarno-Hatta','KLIA','Suvarnabhumi','A','Sering dinobatkan sebagai bandara terbaik dunia.'),
  ('Taman futuristik dengan pohon raksasa buatan bernama...','Jurong Bird Park','Sentosa Park','Gardens by the Bay','Botanic Garden','C','Pohon buatannya disebut Supertree.'),
  ('Hotel dengan kolam renang di atap berbentuk kapal adalah...','Burj Al Arab','Marina Bay Sands','Raffles Hotel','Petronas Hotel','B','Salah satu ikon Singapura.'),
  ('Hidangan ayam rebus dengan nasi gurih khas Singapura adalah...','Nasi ayam Hainan','Nasi kuning','Nasi goreng kampung','Nasi lemak','A','Berasal dari tradisi imigran Hainan.'),
  ('Pusat jajanan murah berisi banyak kios makanan disebut...','Warteg','Hawker centre','Mall','Food truck','B','Budayanya diakui UNESCO pada 2020.'),
  ('Pulau resor di selatan Singapura bernama...','Langkawi','Bintan','Batam','Sentosa','D','Terhubung dengan jembatan dan kereta gantung.'),
  ('Singapura terhubung ke Johor Bahru lewat...','Causeway','Jembatan Merah','Terowongan bawah laut','Kapal feri saja','A','Ada juga Tuas Second Link.'),
  ('Pendiri Singapura modern pada 1819 adalah...','Sir Stamford Raffles','Lee Kuan Yew','Soekarno','Tunku Abdul Rahman','A','Ia mendirikan pos dagang Inggris.'),
  ('Perdana menteri pertama Singapura adalah...','Lee Kuan Yew','Tony Tan','Goh Chok Tong','Lee Hsien Loong','A','Memimpin sejak 1959.'),
  ('Apa yang sebagian besar dilarang dijual di Singapura sejak 1992?','Es krim','Kopi','Cokelat','Permen karet','D','Dilarang untuk menjaga kebersihan.'),
  ('Kebun binatang yang buka malam hari di Singapura disebut...','Moon Park','Night Safari','Zoo Gelap','Safari Bintang','B','Dibuka pertama kali pada 1994.'),
  ('Singapura salah satu pendiri ASEAN pada tahun...','1984','1967','1945','1999','B','Bersama Indonesia, Malaysia, Filipina, dan Thailand.'),
  ('Bunga nasional Singapura adalah anggrek...','Vanda Miss Joaquim','Kantong semar','Macan','Bulan','A','Dipilih sebagai bunga nasional pada 1981.'),
  ('Selama musim panas, Inggris memakai BST. Singapura berada di UTC...','+9','+7','+1','+8','D','Singapura tidak memakai waktu musim panas.'),
  ('Pelabuhan Singapura dikenal sebagai...','Pelabuhan khusus wisata','Pelabuhan yang sudah ditutup','Pelabuhan kecil nelayan','Salah satu pelabuhan tersibuk di dunia','D','Posisi strategis di Selat Malaka.')
) as v(q, a, b, c, d, k, e)
where m.country_code = 'SG' and m.type = 'trivia'
  and not exists (select 1 from public.quiz_questions x where x.mission_id = m.id);

-- TH: 20 soal trivia
insert into public.quiz_questions (mission_id, question, option_a, option_b, option_c, option_d, correct_option, explanation)
select m.id, v.q, v.a, v.b, v.c, v.d, v.k, v.e
from public.missions m,
(values
  ('Apa ibukota Thailand?','Pattaya','Phuket','Chiang Mai','Bangkok','D','Bangkok disebut Krung Thep dalam bahasa Thai.'),
  ('Apa mata uang Thailand?','Ringgit','Dong','Kip','Baht','D','Kodenya THB.'),
  ('Mie goreng khas Thailand dengan kacang dan udang disebut...','Laksa','Pho','Mi goreng','Pad Thai','D','Salah satu hidangan paling terkenal Thailand.'),
  ('Bentuk pemerintahan Thailand adalah...','Kekaisaran','Monarki absolut','Monarki konstitusional','Republik presidensial','C','Raja menjadi kepala negara.'),
  ('Nama lama Thailand sebelum 1939 adalah...','Siam','Annam','Champa','Burma','A','Dalam film dan sejarah masih sering disebut Siam.'),
  ('Hewan yang menjadi simbol nasional Thailand adalah...','Gajah','Komodo','Orangutan','Harimau','A','Gajah putih dianggap suci.'),
  ('Festival siram air tahun baru Thai disebut...','Diwali','Tet','Loy Krathong','Songkran','D','Dirayakan setiap pertengahan April.'),
  ('Kuil Buddha Zamrud berada di kompleks...','Shwedagon','Grand Palace Bangkok','Borobudur','Angkor Wat','B','Disebut Wat Phra Kaew.'),
  ('Pulau wisata terkenal di Thailand selatan adalah...','Langkawi','Bali','Phuket','Boracay','C','Phuket menghadap Laut Andaman.'),
  ('Negara mana yang berbatasan darat dengan Thailand?','Laos','Filipina','Vietnam','Singapura','A','Thailand juga berbatasan dengan Myanmar, Kamboja, Malaysia.'),
  ('Seni bela diri khas Thailand yang disebut ''delapan anggota tubuh'' adalah...','Karate','Taekwondo','Pencak silat','Muay Thai','D','Memakai tinju, siku, lutut, dan tulang kering.'),
  ('Kota di Thailand utara yang terkenal dengan kuil dan festival lampion adalah...','Krabi','Hua Hin','Chiang Mai','Pattaya','C','Didirikan pada 1296.'),
  ('Sungai utama yang melintasi Bangkok adalah...','Mekong','Chao Phraya','Salween','Irrawaddy','B','Disebut juga Sungai Raja.'),
  ('Sup asam pedas udang khas Thailand adalah...','Mohinga','Laksa','Soto','Tom Yum','D','Memakai serai dan daun jeruk.'),
  ('Kuil Fajar di tepi sungai Bangkok adalah...','Wat Phra Kaew','Wat Rong Khun','Wat Arun','Wat Pho','C','Menaranya dihias keramik.'),
  ('Salam Thailand dengan menangkupkan telapak tangan disebut...','Namaste','Gassho','Wai','Sampeah','C','Makin tinggi tangan, makin besar rasa hormat.'),
  ('Kendaraan roda tiga khas Thailand disebut...','Tuk-tuk','Bajaj','Delman','Becak','A','Sering menjadi taksi wisata.'),
  ('Kota kuno bekas ibukota Siam yang menjadi warisan UNESCO adalah...','Pattaya','Hat Yai','Sukhothai','Ayutthaya','D','Pernah menjadi ibukota selama sekitar 400 tahun.'),
  ('Thailand dikenal sebagai satu-satunya negara Asia Tenggara yang tidak pernah...','Memiliki pantai','Bergabung dengan ASEAN','Memiliki raja','Dijajah bangsa Eropa','D','Ia berhasil menjaga kedaulatannya.'),
  ('Saat Loy Krathong, orang melepaskan apa ke sungai?','Balon udara','Perahu kecil berhias bunga','Ikan hidup','Kertas doa terbakar','B','Melambangkan melepas hal buruk.')
) as v(q, a, b, c, d, k, e)
where m.country_code = 'TH' and m.type = 'trivia'
  and not exists (select 1 from public.quiz_questions x where x.mission_id = m.id);

-- VN: 20 soal trivia
insert into public.quiz_questions (mission_id, question, option_a, option_b, option_c, option_d, correct_option, explanation)
select m.id, v.q, v.a, v.b, v.c, v.d, v.k, v.e
from public.missions m,
(values
  ('Apa ibukota Vietnam?','Da Nang','Hue','Hanoi','Ho Chi Minh City','C','Hanoi ada di bagian utara.'),
  ('Apa mata uang Vietnam?','Kip','Dong','Baht','Riel','B','Kodenya VND.'),
  ('Sup mi daging khas Vietnam disebut...','Pho','Tom Yum','Laksa','Ramen','A','Disajikan dengan kaldu bening.'),
  ('Pakaian tradisional wanita Vietnam disebut...','Kimono','Hanbok','Kebaya','Ao Dai','D','Gaun panjang dengan belahan samping.'),
  ('Topi kerucut khas Vietnam disebut...','Salakot','Non La','Songkok','Peci','B','Dibuat dari daun palem atau bambu.'),
  ('Teluk dengan ribuan pulau karang di Vietnam utara adalah...','Teluk Siam','Teluk Tomini','Teluk Manila','Teluk Ha Long','D','Warisan dunia UNESCO.'),
  ('Delta sungai di Vietnam selatan adalah delta sungai...','Mekong','Chao Phraya','Mahakam','Irrawaddy','A','Lumbung beras Vietnam.'),
  ('Kota terbesar di Vietnam adalah...','Hue','Ho Chi Minh City','Hanoi','Hai Phong','B','Dulu bernama Saigon.'),
  ('Kopi Vietnam khas biasanya dicampur dengan...','Garam','Susu kental manis','Santan','Madu','B','Disajikan dalam saringan logam.'),
  ('Roti baguette isi daging dan sayur khas Vietnam disebut...','Pad Thai','Nasi lemak','Banh mi','Roti john','C','Warisan masa kolonial Prancis.'),
  ('Negara mana yang berbatasan darat dengan Vietnam?','Kamboja','Malaysia','Thailand','Myanmar','A','Vietnam juga berbatasan dengan Laos dan China.'),
  ('Tahun baru Imlek Vietnam disebut...','Tet','Songkran','Hari Raya','Pi Mai','A','Perayaan terbesar di Vietnam.'),
  ('Kota tua berlampion warna-warni yang jadi warisan UNESCO adalah...','Vung Tau','Hoi An','Da Lat','Hanoi','B','Terkenal dengan penjahit pakaian.'),
  ('Gunung tertinggi di Vietnam, ''atap Indochina'', adalah...','Rinjani','Kinabalu','Fansipan','Bromo','C','Tingginya sekitar 3.143 m.'),
  ('Pendiri Vietnam modern yang dikenal sebagai Paman Ho adalah...','Ngo Dinh Diem','Vo Nguyen Giap','Pol Pot','Ho Chi Minh','D','Memimpin kemerdekaan pada 1945.'),
  ('Pertunjukan boneka kayu di atas kolam khas Vietnam disebut...','Wayang air','Wayang golek','Wayang kulit','Ludruk','A','Diiringi musik tradisional.'),
  ('Lumpia segar Vietnam dibungkus dengan...','Kulit telur','Kertas beras','Daun pisang','Roti tawar','B','Isinya udang, sayur, dan mi.'),
  ('Kota kekaisaran lama yang menjadi ibukota dinasti Nguyen adalah...','Hue','Nha Trang','Can Tho','Hanoi','A','Terletak di Vietnam tengah.'),
  ('Hari Nasional Vietnam diperingati pada...','9 November','17 Agustus','2 September','1 Januari','C','Mengenang proklamasi kemerdekaan 1945.'),
  ('Terowongan perang Cu Chi berada dekat kota...','Da Nang','Ho Chi Minh City','Hue','Hanoi','B','Digunakan saat Perang Vietnam.')
) as v(q, a, b, c, d, k, e)
where m.country_code = 'VN' and m.type = 'trivia'
  and not exists (select 1 from public.quiz_questions x where x.mission_id = m.id);

-- PH: 20 soal trivia
insert into public.quiz_questions (mission_id, question, option_a, option_b, option_c, option_d, correct_option, explanation)
select m.id, v.q, v.a, v.b, v.c, v.d, v.k, v.e
from public.missions m,
(values
  ('Apa ibukota Filipina?','Cebu','Quezon City','Davao','Manila','D','Manila berada di Pulau Luzon.'),
  ('Apa mata uang Filipina?','Peso','Baht','Ringgit','Dong','A','Kodenya PHP.'),
  ('Hidangan daging dengan cuka dan kecap yang dianggap nasional adalah...','Satay','Adobo','Pho','Rendang','B','Bisa memakai ayam atau babi.'),
  ('Pahlawan nasional Filipina adalah...','Andres Bonifacio','Emilio Aguinaldo','Ferdinand Marcos','José Rizal','D','Ia dieksekusi pada 1896.'),
  ('Filipina terdiri dari lebih dari berapa pulau?','1.000','17.000','7.000','3.000','C','Totalnya sekitar 7.600 pulau.'),
  ('Pulau terbesar di Filipina adalah...','Mindanao','Cebu','Luzon','Palawan','C','Luzon memuat Manila.'),
  ('Gunung berapi berbentuk kerucut sempurna di Filipina adalah...','Gunung Merapi','Gunung Taal','Gunung Fuji','Gunung Mayon','D','Terletak di provinsi Albay.'),
  ('Pantai berpasir putih terkenal di Filipina adalah...','Kuta','Boracay','Pattaya','Patong','B','Terletak di Visayas.'),
  ('Bahasa nasional Filipina adalah...','Tagalog kuno','Filipino','Spanyol','Cebuano','B','Filipino dan Inggris menjadi bahasa resmi.'),
  ('Filipina dijajah Spanyol selama kira-kira...','50 tahun','700 tahun','300 tahun','10 tahun','C','Sejak 1565 hingga 1898.'),
  ('Hidangan es serut campur khas Filipina adalah...','Bubur sumsum','Es teler','Halo-halo','Cendol','C','Artinya ''campur-campur''.'),
  ('Sawah terasering warisan UNESCO di Filipina berada di...','Ubud','Sapa','Banaue','Ifugao-Bali','C','Dibuat oleh suku Ifugao.'),
  ('Primata mungil berumur panjang yang terkenal di Bohol adalah...','Tarsius','Bekantan','Orangutan','Lemur','A','Matanya sangat besar.'),
  ('Petinju Filipina yang terkenal di dunia adalah...','Muhammad Ali','Chris John','Manny Pacquiao','Mike Tyson','C','Ia juga pernah menjadi senator.'),
  ('Festival Sinulog dirayakan di kota...','Baguio','Davao','Cebu','Manila','C','Menghormati Santo Niño.'),
  ('Kendaraan umum berhias warna-warni khas Filipina adalah...','Bemo','Jeepney','Becak','Tuk-tuk','B','Awalnya dari jip bekas militer.'),
  ('Agama mayoritas di Filipina adalah...','Katolik','Islam','Hindu','Buddha','A','Warisan masa kolonial Spanyol.'),
  ('Sungai bawah tanah warisan UNESCO ada di pulau...','Cebu','Luzon','Palawan','Bohol','C','Disebut Puerto Princesa Underground River.'),
  ('Perayaan Natal di Filipina dimulai sejak bulan...','September','November','Januari','Desember','A','Dikenal sebagai Natal terpanjang di dunia.'),
  ('Tarian bambu khas Filipina yang meniru burung disebut...','Legong','Apsara','Saman','Tinikling','D','Penari melompati dua bambu.')
) as v(q, a, b, c, d, k, e)
where m.country_code = 'PH' and m.type = 'trivia'
  and not exists (select 1 from public.quiz_questions x where x.mission_id = m.id);

-- BN: 20 soal trivia
insert into public.quiz_questions (mission_id, question, option_a, option_b, option_c, option_d, correct_option, explanation)
select m.id, v.q, v.a, v.b, v.c, v.d, v.k, v.e
from public.missions m,
(values
  ('Apa ibukota Brunei?','Tutong','Bandar Seri Begawan','Muara','Kuala Belait','B','Kota terbesar di Brunei.'),
  ('Kepala negara Brunei bergelar...','Raja Muda','Kaisar','Presiden','Sultan','D','Sultan Hassanal Bolkiah memimpin sejak 1967.'),
  ('Apa mata uang Brunei?','Ringgit','Baht','Dolar Brunei','Rupiah','C','Kodenya BND.'),
  ('Brunei terletak di pulau...','Luzon','Borneo','Jawa','Sumatra','B','Dikelilingi wilayah Sarawak, Malaysia.'),
  ('Sumber utama pendapatan Brunei adalah...','Tekstil','Minyak dan gas bumi','Pertanian padi','Pariwisata','B','Sektor ini menopang sebagian besar ekonomi.'),
  ('Masjid berkubah emas di pusat Bandar Seri Begawan adalah masjid...','Sultan Ahmed','Omar Ali Saifuddien','Istiqlal','Baiturrahman','B','Menaranya terpantul di laguna.'),
  ('Permukiman terapung di atas sungai Bandar Seri Begawan disebut...','Kampong Glam','Kampong Ayer','Kampung Baru','Kampung Naga','B','Sering dijuluki Venesia dari Timur.'),
  ('Brunei merdeka dari Inggris pada...','31 Agustus 1957','17 Agustus 1945','9 Agustus 1965','1 Januari 1984','D','Hari Nasional diperingati 23 Februari.'),
  ('Apa bahasa resmi Brunei?','Mandarin','Inggris','Arab','Bahasa Melayu','D','Bahasa Inggris juga banyak dipakai.'),
  ('Taman nasional hutan hujan dengan jembatan kanopi di Brunei adalah...','Taman Negara','Ulu Temburong','Kinabalu','Tanjung Puting','B','Terletak di distrik Temburong.'),
  ('Hidangan sagu lengket khas Brunei disebut...','Gudeg','Lemang','Papeda','Ambuyat','D','Dimakan dengan alat bernama chandas.'),
  ('Agama resmi Brunei adalah...','Islam','Hindu','Kristen','Buddha','A','Brunei memakai sistem Melayu Islam Beraja.'),
  ('Brunei dikelilingi wilayah negara bagian...','Sarawak','Pahang','Kalimantan Utara','Sabah','A','Sarawak milik Malaysia.'),
  ('Kediaman Sultan Brunei, istana terbesar di dunia, bernama...','Istana Merdeka','Istana Nurul Iman','Istana Maimun','Istana Negara','B','Memiliki ratusan kamar.'),
  ('Brunei bergabung dengan ASEAN pada tahun...','1967','1984','2000','1995','B','Hanya seminggu setelah merdeka.'),
  ('Brunei dibagi menjadi berapa distrik?','Tujuh','Sebelas','Empat','Dua','C','Brunei-Muara, Belait, Tutong, dan Temburong.'),
  ('Kata ''Darussalam'' pada nama Brunei berarti...','Negeri damai','Negeri minyak','Tanah air','Kota emas','A','Berasal dari bahasa Arab.'),
  ('Distrik Temburong terpisah dari wilayah utama Brunei oleh wilayah...','Indonesia','Thailand','Malaysia','Filipina','C','Dibatasi Limbang, Sarawak.'),
  ('Warga Brunei dikenal tidak membayar...','Air minum','Listrik','Pajak penghasilan','Tiket bus','C','Ini salah satu hasil kekayaan migas.'),
  ('Brunei menganut bentuk pemerintahan...','Republik komunis','Republik parlementer','Monarki dengan sultan sebagai pemimpin','Federasi','C','Sultan juga menjadi perdana menteri.')
) as v(q, a, b, c, d, k, e)
where m.country_code = 'BN' and m.type = 'trivia'
  and not exists (select 1 from public.quiz_questions x where x.mission_id = m.id);

-- KH: 20 soal trivia
insert into public.quiz_questions (mission_id, question, option_a, option_b, option_c, option_d, correct_option, explanation)
select m.id, v.q, v.a, v.b, v.c, v.d, v.k, v.e
from public.missions m,
(values
  ('Apa ibukota Kamboja?','Battambang','Siem Reap','Sihanoukville','Phnom Penh','D','Terletak di pertemuan sungai Mekong dan Tonle Sap.'),
  ('Apa mata uang resmi Kamboja?','Kip','Riel','Dong','Baht','B','Dolar AS juga banyak dipakai.'),
  ('Kompleks candi terbesar di dunia yang ada di Kamboja adalah...','Borobudur','Prambanan','Bagan','Angkor Wat','D','Dibangun pada abad ke-12.'),
  ('Danau air tawar terbesar di Asia Tenggara di Kamboja adalah...','Tasik Kenyir','Tonle Sap','Toba','Inle','B','Alirannya berbalik arah tiap musim.'),
  ('Apa bahasa resmi Kamboja?','Thai','Vietnam','Lao','Khmer','D','Aksara Khmer berasal dari India selatan.'),
  ('Kota yang menjadi pintu masuk ke Angkor adalah...','Kampot','Kep','Siem Reap','Poipet','C','Banyak wisatawan menginap di sana.'),
  ('Sungai besar yang melintasi Kamboja adalah...','Mekong','Irrawaddy','Salween','Chao Phraya','A','Mengalir dari utara ke selatan.'),
  ('Bentuk pemerintahan Kamboja adalah...','Monarki konstitusional','Republik presidensial','Monarki absolut','Federasi','A','Raja Norodom Sihamoni sejak 2004.'),
  ('Hidangan ikan kukus dengan santan dalam daun pisang adalah...','Pho','Laksa','Adobo','Amok','D','Dianggap hidangan nasional Kamboja.'),
  ('Kain kotak serbaguna khas Kamboja disebut...','Songket','Tais','Krama','Batik','C','Dipakai sebagai syal hingga gendongan.'),
  ('Kuil dengan wajah-wajah batu raksasa di Angkor Thom adalah...','Banteay Srei','Ta Prohm','Bayon','Preah Vihear','C','Wajahnya diyakini mewakili raja atau Avalokiteshvara.'),
  ('Kamboja merdeka dari Prancis pada tahun...','1975','1953','1945','1991','B','Dipimpin Raja Norodom Sihanouk.'),
  ('Kuil yang tertutup akar pohon raksasa dan dikenal dari film adalah...','Angkor Wat','Bayon','Neak Pean','Ta Prohm','D','Lokasi syuting Tomb Raider.'),
  ('Kota pantai populer di Kamboja selatan adalah...','Stung Treng','Battambang','Siem Reap','Sihanoukville','D','Menghadap Teluk Thailand.'),
  ('Tari klasik Khmer yang terinspirasi relief Angkor disebut...','Tinikling','Kecak','Apsara','Legong','C','Gerak tangannya sangat lentur.'),
  ('Negara mana yang TIDAK berbatasan darat dengan Kamboja?','Myanmar','Vietnam','Thailand','Laos','A','Kamboja berbatasan dengan tiga negara.'),
  ('Pemimpin rezim Khmer Merah (1975-1979) adalah...','Pol Pot','Sihanouk','Lon Nol','Hun Sen','A','Rezim ini menimbulkan tragedi besar.'),
  ('Festival air Bon Om Touk ditandai dengan...','Aliran Tonle Sap berbalik arah','Pelepasan balon','Lomba layang-layang','Siraman air tahun baru','A','Dirayakan dengan lomba perahu.'),
  ('Agama mayoritas di Kamboja adalah...','Katolik','Buddha Theravada','Islam','Hindu','B','Sekitar 95 persen penduduk.'),
  ('Candi Angkor Wat awalnya dibangun sebagai kuil...','Buddha','Kristen','Islam','Hindu','D','Kemudian berubah menjadi kuil Buddha.')
) as v(q, a, b, c, d, k, e)
where m.country_code = 'KH' and m.type = 'trivia'
  and not exists (select 1 from public.quiz_questions x where x.mission_id = m.id);

-- LA: 20 soal trivia
insert into public.quiz_questions (mission_id, question, option_a, option_b, option_c, option_d, correct_option, explanation)
select m.id, v.q, v.a, v.b, v.c, v.d, v.k, v.e
from public.missions m,
(values
  ('Apa ibukota Laos?','Vientiane','Luang Prabang','Savannakhet','Pakse','A','Terletak di tepi Sungai Mekong.'),
  ('Apa mata uang Laos?','Riel','Baht','Dong','Kip','D','Kodenya LAK.'),
  ('Laos adalah satu-satunya negara ASEAN yang...','Memiliki laut terluas','Tidak memiliki pantai','Berbentuk pulau','Dijajah Inggris','B','Negara ini terkurung daratan.'),
  ('Sungai besar di perbatasan Laos dan Thailand adalah...','Irrawaddy','Chao Phraya','Mekong','Salween','C','Disebut juga ibu air.'),
  ('Kota kuno warisan UNESCO di Laos utara adalah...','Luang Prabang','Pakse','Savannakhet','Vang Vieng','A','Dulu ibukota kerajaan Lan Xang.'),
  ('Apa bahasa resmi Laos?','Thai','Khmer','Vietnam','Lao','D','Bahasa Lao dekat dengan bahasa Thai.'),
  ('Makanan pokok Laos adalah...','Jagung','Ketan','Roti','Singkong','B','Dimakan dengan tangan.'),
  ('Hidangan nasional Laos berupa daging cincang berbumbu asam pedas adalah...','Pho','Amok','Larb','Satay','C','Sering disajikan dengan beras sangrai.'),
  ('Situs ribuan guci batu misterius di Laos bernama...','Plain of Jars','Angkor','Bagan','Gunung Padang','A','Terletak di Xieng Khouang.'),
  ('Sistem politik Laos adalah...','Monarki konstitusional','Republik satu partai','Monarki absolut','Federasi','B','Dipimpin Partai Revolusioner Rakyat Laos.'),
  ('Air terjun bertingkat bergradasi biru di dekat Luang Prabang adalah...','Kuang Si','Niagara','Victoria','Iguazu','A','Kolamnya biasa dipakai berenang.'),
  ('Pagoda emas simbol nasional di Vientiane adalah...','That Luang','Wat Arun','Bayon','Shwedagon','A','Muncul di lambang negara.'),
  ('Negara mana yang TIDAK berbatasan darat dengan Laos?','Malaysia','Myanmar','Thailand','Vietnam','A','Laos berbatasan dengan lima negara.'),
  ('Tahun baru tradisional Laos disebut...','Tet','Thingyan','Songkran','Pi Mai','D','Dirayakan sekitar April.'),
  ('Laos merdeka dari Prancis pada tahun...','1991','1975','1953','1945','C','Pada 1975 Laos menjadi republik.'),
  ('Ritual biksu menerima sedekah nasi tiap fajar disebut...','Songkran','Waisak','Tak Bat','Kathin','C','Terkenal di Luang Prabang.'),
  ('Alat musik tiup bambu khas Laos adalah...','Sasando','Suling','Khene','Angklung','C','Terdiri dari banyak pipa bambu.'),
  ('Dataran tinggi penghasil kopi di Laos selatan adalah...','Kintamani','Toraja','Gayo','Bolaven','D','Juga terkenal dengan air terjunnya.'),
  ('Kerajaan kuno Lan Xang berarti...','Sejuta gajah','Seribu kuil','Tanah emas','Sejuta bunga','A','Berdiri pada abad ke-14.'),
  ('Jubah biksu Laos umumnya berwarna...','Hijau','Biru','Putih','Oranye','D','Warna ini lazim di negara Buddha Theravada.')
) as v(q, a, b, c, d, k, e)
where m.country_code = 'LA' and m.type = 'trivia'
  and not exists (select 1 from public.quiz_questions x where x.mission_id = m.id);

-- MM: 20 soal trivia
insert into public.quiz_questions (mission_id, question, option_a, option_b, option_c, option_d, correct_option, explanation)
select m.id, v.q, v.a, v.b, v.c, v.d, v.k, v.e
from public.missions m,
(values
  ('Apa ibukota Myanmar saat ini?','Naypyidaw','Bagan','Mandalay','Yangon','A','Menjadi ibukota sejak 2006.'),
  ('Kota terbesar di Myanmar adalah...','Naypyidaw','Bago','Mandalay','Yangon','D','Dulu menjadi ibukota.'),
  ('Pagoda emas terkenal di Yangon adalah...','Wat Arun','Bayon','That Luang','Shwedagon','D','Konon menyimpan relik Buddha.'),
  ('Apa mata uang Myanmar?','Riel','Kyat','Kip','Baht','B','Kodenya MMK.'),
  ('Sungai terbesar yang mengalir melintasi Myanmar adalah...','Mekong','Irrawaddy','Salween','Chao Phraya','B','Disebut juga Ayeyarwady.'),
  ('Dataran ribuan kuil dan pagoda yang jadi warisan UNESCO adalah...','Angkor','Ayutthaya','Bagan','Borobudur','C','Terletak di tepi Irrawaddy.'),
  ('Nama lama Myanmar adalah...','Burma','Champa','Annam','Siam','A','Nama Myanmar dipakai resmi sejak 1989.'),
  ('Nelayan di Danau Inle terkenal mendayung dengan...','Layar','Kaki','Mesin','Tangan kiri','B','Gaya mendayung suku Intha.'),
  ('Kain sarung tradisional Myanmar disebut...','Longyi','Hanbok','Kebaya','Ao Dai','A','Dipakai pria dan wanita.'),
  ('Pasta kulit kayu yang dioleskan di wajah orang Myanmar adalah...','Thanaka','Lulur','Bedak dingin','Henna','A','Dipercaya melindungi dari matahari.'),
  ('Myanmar merdeka dari Inggris pada tahun...','1945','1957','1948','1984','C','Pada 4 Januari.'),
  ('Agama mayoritas Myanmar adalah...','Islam','Katolik','Buddha Theravada','Hindu','C','Sebagian besar etnis Burma beragama Buddha.'),
  ('Sup mi ikan yang dianggap hidangan nasional Myanmar adalah...','Pho','Tom Yum','Laksa','Mohinga','D','Biasa untuk sarapan.'),
  ('Negara mana yang TIDAK berbatasan darat dengan Myanmar?','Thailand','China','Kamboja','India','C','Myanmar juga berbatasan dengan Laos dan Bangladesh.'),
  ('Peraih Nobel Perdamaian 1991 dari Myanmar adalah...','Ne Win','U Thant','Aung San Suu Kyi','Thein Sein','C','Ia memperjuangkan demokrasi.'),
  ('Festival air tahun baru Myanmar disebut...','Pi Mai','Thingyan','Tet','Songkran','B','Dirayakan sekitar April.'),
  ('Salad daun teh fermentasi khas Myanmar adalah...','Gado-gado','Pecel','Lahpet','Som Tam','C','Daun tehnya difermentasi.'),
  ('Gunung tertinggi di Myanmar adalah...','Fansipan','Hkakabo Razi','Rinjani','Kinabalu','B','Tingginya sekitar 5.881 m.'),
  ('Kota bekas ibukota kerajaan Burma terakhir adalah...','Bagan','Mandalay','Yangon','Bago','B','Berdiri pada 1857.'),
  ('Biksu dan novis di Myanmar biasanya berpakaian berwarna...','Putih','Merah marun','Biru','Hijau','B','Berbeda dari jingga di Laos dan Thailand.')
) as v(q, a, b, c, d, k, e)
where m.country_code = 'MM' and m.type = 'trivia'
  and not exists (select 1 from public.quiz_questions x where x.mission_id = m.id);

-- TL: 20 soal trivia
insert into public.quiz_questions (mission_id, question, option_a, option_b, option_c, option_d, correct_option, explanation)
select m.id, v.q, v.a, v.b, v.c, v.d, v.k, v.e
from public.missions m,
(values
  ('Apa ibukota Timor Leste?','Baucau','Maliana','Dili','Lospalos','C','Terletak di pantai utara.'),
  ('Apa mata uang yang dipakai Timor Leste?','Ringgit','Rupiah','Escudo','Dolar AS','D','Timor Leste memakai USD.'),
  ('Timor Leste memulihkan kemerdekaan pada...','17 Agustus 1945','20 Mei 2002','30 Agustus 1999','28 November 1975','B','Pada tahun itu PBB menyerahkan pemerintahan.'),
  ('Bahasa resmi Timor Leste adalah...','Tetun dan Portugis','Inggris dan Melayu','Tagalog dan Spanyol','Khmer dan Prancis','A','Indonesia dan Inggris menjadi bahasa kerja.'),
  ('Timor Leste dahulu dijajah oleh...','Spanyol','Portugal','Belanda','Inggris','B','Selama sekitar 450 tahun.'),
  ('Agama mayoritas di Timor Leste adalah...','Hindu','Katolik','Islam','Buddha','B','Gereja berperan besar dalam sejarahnya.'),
  ('Gunung tertinggi di Timor Leste adalah...','Semeru','Tatamailau','Rinjani','Kinabalu','B','Disebut juga Gunung Ramelau.'),
  ('Patung besar di bukit Dili yang menghadap laut adalah...','Garuda Wisnu','Cristo Rei','Patung Liberty','Merlion','B','Berdiri di atas bola dunia.'),
  ('Pulau kecil tujuan menyelam di utara Dili adalah...','Weh','Bunaken','Atauro','Komodo','C','Terumbu karangnya sangat kaya.'),
  ('Timor Leste menjadi anggota ke-11 ASEAN pada tahun...','2025','2002','2010','1999','A','Resmi bergabung pada 2025.'),
  ('Hasil pertanian ekspor utama Timor Leste adalah...','Karet','Kopi','Gandum','Kapas','B','Ditanam di dataran tinggi.'),
  ('Referendum penentuan nasib Timor Timur berlangsung pada...','20 Mei 2002','28 November 1975','17 Agustus 1945','30 Agustus 1999','D','Rakyat memilih merdeka.'),
  ('Presiden pertama Timor Leste adalah...','Taur Matan Ruak','Xanana Gusmão','Mari Alkatiri','José Ramos-Horta','B','Menjabat 2002 hingga 2007.'),
  ('Pulau Timor dibagi dengan negara...','Indonesia','Papua Nugini','Filipina','Australia','A','Bagian barat adalah Nusa Tenggara Timur.'),
  ('Kain tenun tradisional Timor Leste disebut...','Songket','Batik','Tais','Ulos','C','Setiap daerah punya motif berbeda.'),
  ('Rumah adat sakral yang menyimpan pusaka leluhur disebut...','Rumah Gadang','Joglo','Tongkonan','Uma Lulik','D','Artinya rumah suci.'),
  ('Oecusse adalah wilayah eksklave Timor Leste yang dikelilingi wilayah...','Filipina','Australia','Indonesia','Portugal','C','Terletak di sisi barat Pulau Timor.'),
  ('Sumber pendapatan utama negara Timor Leste adalah...','Tekstil','Minyak dan gas di Laut Timor','Pariwisata','Perikanan','B','Dikelola lewat dana perminyakan.'),
  ('Menurut legenda, Pulau Timor terbentuk dari...','Seekor buaya','Seekor burung','Seekor penyu','Seekor naga','A','Buaya dianggap leluhur masyarakat.'),
  ('Bintang putih pada bendera Timor Leste melambangkan...','Cahaya yang memandu','Laut','Kekuatan militer','Kekayaan alam','A','Bendera juga berwarna merah, kuning, dan hitam.')
) as v(q, a, b, c, d, k, e)
where m.country_code = 'TL' and m.type = 'trivia'
  and not exists (select 1 from public.quiz_questions x where x.mission_id = m.id);

-- GB: 20 soal trivia
insert into public.quiz_questions (mission_id, question, option_a, option_b, option_c, option_d, correct_option, explanation)
select m.id, v.q, v.a, v.b, v.c, v.d, v.k, v.e
from public.missions m,
(values
  ('Apa ibukota Inggris Raya?','Liverpool','Manchester','Birmingham','London','D','London terletak di tepi Sungai Thames.'),
  ('Apa mata uang Inggris Raya?','Dolar','Euro','Poundsterling','Franc','C','Kodenya GBP.'),
  ('Big Ben adalah lonceng di menara...','Istana Buckingham','Istana Westminster','Tower Bridge','Katedral St Paul','B','Menaranya bernama Elizabeth Tower.'),
  ('Yang TIDAK termasuk wilayah Inggris Raya adalah...','Irlandia Utara','Skotlandia','Republik Irlandia','Wales','C','Republik Irlandia adalah negara merdeka.'),
  ('Ibukota Skotlandia adalah...','Glasgow','Edinburgh','Dundee','Aberdeen','B','Terkenal dengan kastilnya.'),
  ('Ibukota Wales adalah...','Swansea','Bangor','Newport','Cardiff','D','Terletak di pantai selatan Wales.'),
  ('Lingkaran batu prasejarah di Wiltshire adalah...','Tower Bridge','Hadrian''s Wall','Big Ben','Stonehenge','D','Berusia sekitar 4.500 tahun.'),
  ('Sungai yang melintasi London adalah...','Sungai Danube','Sungai Thames','Sungai Rhine','Sungai Seine','B','Panjangnya sekitar 346 km.'),
  ('Bentuk pemerintahan Inggris Raya adalah...','Monarki absolut','Federasi','Republik presidensial','Monarki konstitusional','D','Raja sebagai kepala negara.'),
  ('Kediaman resmi perdana menteri Inggris berada di...','Kensington Palace','Buckingham Palace','10 Downing Street','Windsor Castle','C','Berada di Westminster.'),
  ('Universitas tertua di dunia berbahasa Inggris adalah...','Cambridge','Oxford','Edinburgh','Harvard','B','Pengajaran sudah ada sejak abad ke-11.'),
  ('Garis bujur nol derajat melewati...','Edinburgh','Greenwich','Cardiff','Manchester','B','Dasar waktu GMT.'),
  ('Terowongan kereta bawah laut yang menghubungkan Inggris dan Prancis adalah...','Channel Tunnel','Seikan Tunnel','Lærdal Tunnel','Mersey Tunnel','A','Dibuka pada 1994.'),
  ('Hidangan ikan goreng dengan kentang goreng khas Inggris adalah...','Pizza','Paella','Fish and chips','Sushi','C','Sering dibungkus kertas.'),
  ('Dramawan terkenal kelahiran Stratford-upon-Avon adalah...','Jane Austen','William Shakespeare','Oscar Wilde','Charles Dickens','B','Menulis Hamlet dan Romeo and Juliet.'),
  ('Revolusi Industri berawal di...','Amerika Serikat','Prancis','Inggris','Jerman','C','Dimulai pada abad ke-18.'),
  ('Liga sepak bola kasta tertinggi Inggris adalah...','La Liga','Premier League','Bundesliga','Serie A','B','Dimulai pada 1992.'),
  ('Bendera Union Jack menggabungkan salib santo Inggris, Skotlandia, dan...','Prancis','Irlandia','Denmark','Wales','B','Salib Santo Patrick mewakili Irlandia.'),
  ('Monster legendaris di danau Skotlandia dijuluki...','Bigfoot','Kraken','Godzilla','Nessie','D','Katanya hidup di Loch Ness.'),
  ('Saat musim panas Inggris memakai BST yaitu UTC...','+2','+3','+1','+0','C','Di musim dingin memakai GMT atau UTC+0.')
) as v(q, a, b, c, d, k, e)
where m.country_code = 'GB' and m.type = 'trivia'
  and not exists (select 1 from public.quiz_questions x where x.mission_id = m.id);

-- MY: 4 kartu budaya
insert into public.culture_cards (mission_id, sort_order, title, category, icon, fact)
select m.id, v.n, v.t, v.c, v.i, v.f
from public.missions m,
(values
  (1,'Nasi Lemak','Hidangan','food','Nasi harum santan disajikan dengan sambal, ikan teri, kacang, dan telur. Sering disebut hidangan nasional Malaysia.'),
  (2,'Batik','Kain','dress','Kain bermotif lilin. Batik Malaysia terkenal dengan motif bunga, terutama dari pantai timur seperti Kelantan dan Terengganu.'),
  (3,'Songket','Tenun','craft','Kain tenun berbenang emas atau perak yang dipakai pada upacara adat Melayu.'),
  (4,'Wayang Kulit','Seni','theatre','Pertunjukan boneka kulit bayangan. Wayang kulit Kelantan adalah salah satu tradisi yang paling terkenal.')
) as v(n, t, c, i, f)
where m.country_code = 'MY' and m.type = 'kuliner_budaya'
on conflict (mission_id, sort_order) do nothing;

-- ID: 4 kartu budaya
insert into public.culture_cards (mission_id, sort_order, title, category, icon, fact)
select m.id, v.n, v.t, v.c, v.i, v.f
from public.missions m,
(values
  (1,'Rendang','Hidangan','food','Daging dimasak lama dengan santan dan rempah hingga kering. Berasal dari masyarakat Minangkabau di Sumatra Barat.'),
  (2,'Batik','Kain','dress','Diakui UNESCO sebagai warisan budaya takbenda pada 2009. Hampir tiap daerah punya motif khas.'),
  (3,'Angklung','Musik','music','Alat musik bambu yang dimainkan dengan cara digoyang. Diakui UNESCO pada 2010.'),
  (4,'Tari Kecak','Tari','dance','Tarian Bali yang diiringi puluhan penari pria yang menyerukan ''cak'' tanpa gamelan.')
) as v(n, t, c, i, f)
where m.country_code = 'ID' and m.type = 'kuliner_budaya'
on conflict (mission_id, sort_order) do nothing;

-- SG: 4 kartu budaya
insert into public.culture_cards (mission_id, sort_order, title, category, icon, fact)
select m.id, v.n, v.t, v.c, v.i, v.f
from public.missions m,
(values
  (1,'Nasi Ayam Hainan','Hidangan','food','Ayam rebus lembut dengan nasi gurih, sering disebut hidangan khas Singapura.'),
  (2,'Budaya Hawker','Kuliner','food','Pusat jajanan dengan puluhan kios. Budaya hawker Singapura masuk daftar warisan UNESCO pada 2020.'),
  (3,'Kebaya Nyonya','Busana','dress','Busana perpaduan budaya Tionghoa dan Melayu dari komunitas Peranakan, dihiasi sulaman halus.'),
  (4,'Merlion','Ikon','landmark','Patung berkepala singa dan berbadan ikan, melambangkan asal usul Singapura sebagai kota pelabuhan.')
) as v(n, t, c, i, f)
where m.country_code = 'SG' and m.type = 'kuliner_budaya'
on conflict (mission_id, sort_order) do nothing;

-- TH: 4 kartu budaya
insert into public.culture_cards (mission_id, sort_order, title, category, icon, fact)
select m.id, v.n, v.t, v.c, v.i, v.f
from public.missions m,
(values
  (1,'Pad Thai','Hidangan','food','Mi goreng dengan udang, tauge, dan kacang tanah. Salah satu hidangan paling terkenal Thailand.'),
  (2,'Songkran','Festival','festival','Tahun baru Thai pada pertengahan April. Orang saling menyiram air sebagai simbol membersihkan nasib buruk.'),
  (3,'Muay Thai','Olahraga','sport','Seni bela diri ''delapan anggota tubuh'' yang memakai tinju, siku, lutut, dan tulang kering.'),
  (4,'Wai','Salam','greeting','Salam dengan menangkupkan kedua telapak tangan. Makin tinggi tangan, makin besar penghormatan.')
) as v(n, t, c, i, f)
where m.country_code = 'TH' and m.type = 'kuliner_budaya'
on conflict (mission_id, sort_order) do nothing;

-- VN: 4 kartu budaya
insert into public.culture_cards (mission_id, sort_order, title, category, icon, fact)
select m.id, v.n, v.t, v.c, v.i, v.f
from public.missions m,
(values
  (1,'Pho','Hidangan','food','Sup mi dengan kaldu bening dan irisan daging sapi atau ayam, sering untuk sarapan.'),
  (2,'Ao Dai','Busana','dress','Gaun panjang berbelahan samping yang dikenakan dengan celana panjang. Pakaian tradisional wanita Vietnam.'),
  (3,'Wayang Air','Seni','theatre','Boneka kayu ''menari'' di atas kolam air, diiringi musik tradisional.'),
  (4,'Lentera Hoi An','Festival','festival','Kota tua Hoi An, warisan UNESCO, diterangi lentera warna-warni, terutama saat bulan purnama.')
) as v(n, t, c, i, f)
where m.country_code = 'VN' and m.type = 'kuliner_budaya'
on conflict (mission_id, sort_order) do nothing;

-- PH: 4 kartu budaya
insert into public.culture_cards (mission_id, sort_order, title, category, icon, fact)
select m.id, v.n, v.t, v.c, v.i, v.f
from public.missions m,
(values
  (1,'Adobo','Hidangan','food','Daging yang dimasak dengan cuka, kecap, dan bawang putih. Sering dianggap hidangan nasional.'),
  (2,'Halo-halo','Hidangan penutup','drink','Es serut campur kacang manis, buah, dan es krim. Namanya berarti ''campur-campur''.'),
  (3,'Tinikling','Tari','dance','Penari melompati dua batang bambu yang dibenturkan ritmis, meniru gerak burung tikling.'),
  (4,'Jeepney','Transportasi','vehicle','Kendaraan umum berhias warna-warni. Awalnya dibuat dari jip bekas militer Amerika.')
) as v(n, t, c, i, f)
where m.country_code = 'PH' and m.type = 'kuliner_budaya'
on conflict (mission_id, sort_order) do nothing;

-- BN: 4 kartu budaya
insert into public.culture_cards (mission_id, sort_order, title, category, icon, fact)
select m.id, v.n, v.t, v.c, v.i, v.f
from public.missions m,
(values
  (1,'Ambuyat','Hidangan','food','Bubur sagu lengket yang dimakan dengan alat dua bilah bernama chandas, dicocol saus asam.'),
  (2,'Kampong Ayer','Permukiman','landmark','Permukiman rumah panggung di atas sungai Bandar Seri Begawan yang sudah ada selama berabad-abad.'),
  (3,'Masjid Omar Ali Saifuddien','Arsitektur','temple','Masjid berkubah emas dengan menara yang terpantul di laguna, ikon ibukota Brunei.'),
  (4,'Istana Nurul Iman','Ikon','landmark','Kediaman Sultan Brunei yang tercatat sebagai salah satu istana terbesar di dunia.')
) as v(n, t, c, i, f)
where m.country_code = 'BN' and m.type = 'kuliner_budaya'
on conflict (mission_id, sort_order) do nothing;

-- KH: 4 kartu budaya
insert into public.culture_cards (mission_id, sort_order, title, category, icon, fact)
select m.id, v.n, v.t, v.c, v.i, v.f
from public.missions m,
(values
  (1,'Fish Amok','Hidangan','food','Ikan dikukus dalam daun pisang dengan santan dan pasta kroeung. Dianggap hidangan nasional.'),
  (2,'Tari Apsara','Tari','dance','Tari klasik Khmer dengan gerak tangan lentur, terinspirasi relief bidadari di Angkor.'),
  (3,'Krama','Kain','dress','Kain katun kotak-kotak serbaguna: syal, penutup kepala, hingga gendongan bayi.'),
  (4,'Angkor Wat','Candi','temple','Kompleks kuil yang dibangun pada abad ke-12 dan dianggap monumen keagamaan terbesar di dunia.')
) as v(n, t, c, i, f)
where m.country_code = 'KH' and m.type = 'kuliner_budaya'
on conflict (mission_id, sort_order) do nothing;

-- LA: 4 kartu budaya
insert into public.culture_cards (mission_id, sort_order, title, category, icon, fact)
select m.id, v.n, v.t, v.c, v.i, v.f
from public.missions m,
(values
  (1,'Ketan','Makanan pokok','food','Dikukus dalam keranjang bambu dan dimakan dengan tangan. Dipandang sebagai jati diri orang Laos.'),
  (2,'Larb','Hidangan','food','Daging cincang dengan jeruk nipis, saus ikan, herba, dan beras sangrai. Hidangan nasional Laos.'),
  (3,'Tak Bat','Tradisi','festival','Tiap fajar, biksu berjalan menerima sedekah nasi dari warga, terutama di Luang Prabang.'),
  (4,'Khene','Musik','music','Alat musik tiup dari pipa bambu yang suaranya khas dan menjadi simbol musik Laos.')
) as v(n, t, c, i, f)
where m.country_code = 'LA' and m.type = 'kuliner_budaya'
on conflict (mission_id, sort_order) do nothing;

-- MM: 4 kartu budaya
insert into public.culture_cards (mission_id, sort_order, title, category, icon, fact)
select m.id, v.n, v.t, v.c, v.i, v.f
from public.missions m,
(values
  (1,'Mohinga','Hidangan','food','Sup mi ikan dengan kaldu kental, biasa untuk sarapan dan dianggap hidangan nasional.'),
  (2,'Thanaka','Tradisi','craft','Pasta bubuk kulit kayu yang dioleskan di wajah, dipercaya melindungi kulit dari matahari.'),
  (3,'Longyi','Busana','dress','Kain sarung tabung yang dipakai pria dan wanita Myanmar sehari-hari.'),
  (4,'Thingyan','Festival','festival','Festival air tahun baru Myanmar pada April, ditandai saling menyiram air.')
) as v(n, t, c, i, f)
where m.country_code = 'MM' and m.type = 'kuliner_budaya'
on conflict (mission_id, sort_order) do nothing;

-- TL: 4 kartu budaya
insert into public.culture_cards (mission_id, sort_order, title, category, icon, fact)
select m.id, v.n, v.t, v.c, v.i, v.f
from public.missions m,
(values
  (1,'Tais','Kain','dress','Kain tenun tangan dengan motif khas tiap daerah, dipakai pada upacara adat.'),
  (2,'Kopi Timor','Minuman','drink','Kopi arabika dari dataran tinggi yang menjadi salah satu hasil ekspor penting.'),
  (3,'Uma Lulik','Rumah adat','landmark','Rumah suci tempat menyimpan pusaka leluhur dan menggelar upacara adat.'),
  (4,'Cristo Rei','Ikon','landmark','Patung Kristus setinggi sekitar 27 meter di bukit dekat Dili, menghadap Laut Banda.')
) as v(n, t, c, i, f)
where m.country_code = 'TL' and m.type = 'kuliner_budaya'
on conflict (mission_id, sort_order) do nothing;

-- GB: 4 kartu budaya
insert into public.culture_cards (mission_id, sort_order, title, category, icon, fact)
select m.id, v.n, v.t, v.c, v.i, v.f
from public.missions m,
(values
  (1,'Fish and Chips','Hidangan','food','Ikan goreng tepung dengan kentang goreng, sering dibungkus kertas dan diberi cuka.'),
  (2,'Afternoon Tea','Tradisi','drink','Tradisi minum teh sore dengan scone, sandwich kecil, dan kue. Populer sejak abad ke-19.'),
  (3,'Pergantian Penjaga','Upacara','history','Upacara penjaga istana berseragam jaket merah dan topi bulu beruang di depan Buckingham Palace.'),
  (4,'Stonehenge','Prasejarah','landmark','Lingkaran batu raksasa di Wiltshire yang berusia sekitar 4.500 tahun.')
) as v(n, t, c, i, f)
where m.country_code = 'GB' and m.type = 'kuliner_budaya'
on conflict (mission_id, sort_order) do nothing;
