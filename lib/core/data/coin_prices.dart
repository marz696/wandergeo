// Harga penggunaan koin. Nilai ini HARUS sama dengan konstanta di Edge
// Function (`HINT_COST` dan `VISA_BASE` di supabase/functions/auth/index.ts);
// server yang menentukan, aplikasi hanya menampilkannya.

/// Harga satu petunjuk trivia.
const int kHintCost = 3;

/// Dasar harga Visa Cepat.
const int kVisaBaseCost = 50;

/// Harga Visa Cepat sebuah negara: [kVisaBaseCost] x tingkat kesulitan (1..3).
int visaCostFor(int difficulty) => kVisaBaseCost * difficulty;