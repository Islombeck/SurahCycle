# Quran transliteration audit

Audit date: 2026-09-02.

## Profile architecture

Sprint 5 exposes transliteration through `QuranTransliterationProfile` with a
stable ID, display name, script, language, source, version, attribution, and
availability. The persisted profile ID is consumed by the shared
`QuranReadingRepository`, so Learning, Home Learning Card, and the Android
Learning Widget use the same profile without surface-specific text conversion.

`Latin — Tanzil` is the default and currently the only available profile. It
maps directly to the exact repository described below; its text and integrity
pin did not change.

`Cyrillic` is visible but disabled. No complete 6,236-coordinate Cyrillic
dataset with reliable provenance and acceptable usage terms has been approved.
Murajaah contains no Arabic-to-Cyrillic algorithm, Latin-to-Cyrillic mapping,
LLM output, or approximate phonetic fallback. The UI states that a verified
source has not been connected yet.

## Accepted offline dataset

Sprint 4 uses Tanzil's official **English Transliteration** dataset with ID
`en.transliteration`. It is a provider-owned technical Latin notation; it is
not generated from Arabic and Murajaah does not simplify or "improve" it.

Pinned artifact:

- official source: `https://tanzil.net/trans/en.transliteration?type=txt-2`;
- format: `txt-2` (`surah|ayah|exact text`);
- dataset footer date: `2010-09-06`;
- most recent changelog entry observed during the audit: `2010-09-14`;
- size: `1,044,894` bytes;
- SHA-256: `8c20d95e484534e921cd2e0d2546aab7f5300090c0bd76697095b3ca1db1e01d`;
- coverage: 114 surahs and 6,236 ordered coordinates;
- bundled asset: `assets/quran/quran-transliteration-en.txt`.

`TanzilEnglishTransliterationRepository` checks the byte count and SHA-256
before decoding. It then requires strict UTF-8, LF line endings, the exact
dataset metadata markers, all 6,236 coordinates in canonical order, and the
per-surah ayah counts from the independently pinned Tanzil metadata file. Any
failure rejects the whole corpus; there is no guessed fallback.

The substring after the second `|` is kept verbatim. That includes Tanzil's
technical notation (`AA`, for example) and the source presentation tags. The
observed tag vocabulary is `<u>`, `<b>`, `<strong>`, and `<i>` with case
variants. `TanzilTransliterationMarkup` interprets only those tags at display
time. The domain record still retains the exact source string; native renderers
may derive plain display text with `toPlainText` without persisting it.

`QuranTransliterationRepository` is intentionally independent from Arabic,
full translation, and word-by-word content. Every returned ayah has coordinates,
exact text, dataset ID, technical version, provenance URL, attribution, and
usage information.

## Licensing decision

Tanzil's translations terms allow this resource for non-commercial use. The
downloaded footer names `English Transliteration` as the translator and does
not name a separate copyright holder. This is not covered by the CC BY 3.0
notice for Tanzil's Arabic Quran text.

The pinned asset is therefore approved for the current private/testing,
non-commercial build only. A commercial, monetized, or otherwise incompatible
production distribution is a release blocker until permission is documented.
The bundled notice is `assets/quran/TANZIL_TRANSLITERATION_LICENSE.txt`.

## Future provider boundary

Quran Foundation may offer a more reader-friendly transliteration, but its
current content API authentication uses client credentials. A client secret
must never be embedded in an APK, Flutter asset, Dart/Kotlin constant, or
mobile `.env`. That integration remains backend-only until Murajaah has an
authorized server-side proxy.
