# Multilingual Quran layers

Audit date: 2026-09-02.

## Independent language and translation choices

The Quran translation language is a separate persisted setting
(`quran.translation.language.v1`). It is not the application locale and it is
not the selected theological translation. The resolution order for the catalog
language is:

1. the user's explicit translation-language setting;
2. the language of an already pinned translation;
3. a supported UI-locale suggestion (`ru` or `uz`);
4. Russian as the neutral compatibility fallback.

Changing the UI locale or catalog language never creates, clears, or replaces
`quran.translation.selection.v1`. A new translation is stored only after an
explicit selector action. This preserves existing Russian selections and their
versioned cache while allowing Russian UI with Uzbek content and Uzbek UI with
Russian content.

`quranTranslationsProvider` is a family keyed by translation language and UI
localization language. QuranEnc remains the only selectable production source.

Official surfaces used by the audit:

- documented API: `https://quranenc.com/uz/home/api`;
- translation index: `https://quranenc.com/en/home`;
- browse identities: `https://quranenc.com/en/browse/{translation_key}`.

## Audited QuranEnc translations

Every available direct fallback below was checked through all 114 documented
`translation/sura/{key}/{surah}` endpoints. The audit requires exactly 6,236
ordered unique coordinates, non-empty exact provider text, valid optional
footnotes, strict JSON transport, and exact corpus/per-surah SHA-256 values.
Provider strings are framed and hashed verbatim; they are not trimmed,
normalized, transliterated, translated, or otherwise rewritten.

| Language | Key | Official identity/version | App technical corpus SHA-256 |
| --- | --- | --- | --- |
| Russian | `russian_rwwad` | Rowwad, `V1.0.1` at pinned audit | `c58986174045d030df67ec6b8f15ebe2fdeae74c092e73a7630c08acf742542a` |
| Russian | `russian_aboadel` | Abu Adel, `V1.0.0` | `ac9387c90b5cf90939f0a527702f4d1c5d025269cf705e2f6b2594b4f803a3ff` |
| Uzbek | `uzbek_rwwad` | Rowwad, `V1.0.4` | `f49a16d9e5079bd98722feef311d6cbb7afce53cc9186c1a034359ea8f979e72` |
| Uzbek | `uzbek_sadiq` | Muhammad Sadiq Muhammad Yusuf, `V1.0.1` | `eb87e39c86411467df16fa0eabd1081d0c4426c9ec1a8e76706a80643fbc052f` |
| Uzbek | `uzbek_mansour` | Alaauddin Mansour, `V1.0.0` | `3922d6bc01370a67b6c33a65ffb8697cdcb497994c0ec16040b6b9b11a197a90` |

The public Uzbek list currently returns Rowwad and Mansour but can omit Sadiq.
For Uzbek only, the provider augments that list by runtime-probing missing keys
from the audited registry. Russian retains its previous behavior: direct keys
are probed only after a valid empty Russian catalog. A probe never selects a
translation.

Known official catalog versions and app-owned direct revisions both validate
every downloaded surah against the pinned per-surah manifest before cache
commit. A version/hash/coordinate mismatch fails closed and leaves the previous
offline cache unchanged.

## Confirmed but unavailable Uzbek entries

Official browse pages prove the exact identifiers `uzbek_mokhtasar`
(Al-Mukhtasar) and `uzbek_moyassar` (At-Tafsir Al-Muyassar). On 2026-09-02,
their documented direct API URLs returned HTTP 200 as empty `text/html`, not a
JSON corpus. They therefore remain visible in Settings as unavailable and are
not present in the production registry, selector, or cache. They can be enabled
only after the same complete 114/6,236/hash audit succeeds.

## Reproducible audit

`tool/import_sprint4_quran_sources.ps1` re-downloads the five available pinned
corpora and the Tanzil Latin transliteration, validates every coordinate, checks
the full hashes above, and regenerates the 114-hash-per-key Dart manifest. A
changed source is a human audit event, never an automatic data update.
