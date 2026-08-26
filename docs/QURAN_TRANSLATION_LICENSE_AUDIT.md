# Quran translation license and source audit

Audit date: 2026-08-26.

## QuranEnc Russian discovery

The documented QuranEnc catalog request for `language=ru` and
`localization=ru` returned HTTP 200 with a valid JSON body containing an empty
`translations` array (19 response bytes at audit time). This explains the empty
selector: the client was correctly parsing an upstream catalog inconsistency,
not failing to make an HTTP request.

Two keys visible on official QuranEnc surfaces were separately audited through
the documented public `translation/sura/{key}/{sura}` API only. No HTML content
is scraped and no private or reverse-engineered endpoint is used.

| Key | Official identity surface | Version | Updated observed | Full corpus technical SHA-256 |
| --- | --- | --- | --- | --- |
| `russian_rwwad` | Rowwad Translation Center | `V1.0.1` | 2026-03-29 | `c58986174045d030df67ec6b8f15ebe2fdeae74c092e73a7630c08acf742542a` |
| `russian_aboadel` | Abu Adel | `V1.0.0` | 2026-02-14 | `ac9387c90b5cf90939f0a527702f4d1c5d025269cf705e2f6b2594b4f803a3ff` |

For both keys, all 114 direct surah responses were HTTPS JSON, contained all
6,236 coordinates in order, and had non-empty exact translations. The corpus
hash covers coordinates, exact translation strings, and the null/present state
plus exact value of footnotes using unambiguous framing. The generated manifest
also pins each of the 114 surah hashes.

The direct response does not repeat the version displayed on the official
browse page. Murajaah therefore records that value as `officialVersion` audit
metadata but uses a clearly app-owned `quranenc-direct-...-sha256-...`
technical revision for cache identity. It does not claim that technical string
is an upstream QuranEnc version.

At runtime, `KnownOfficialQuranEncTranslations` is consulted only when the
successfully parsed Russian catalog is empty. Each known key must pass a fresh
direct JSON probe and its pinned surah hash before it is returned as available;
every later fetched surah must match its own pinned hash before caching. A
failed endpoint, HTML response, malformed coordinate set, or content revision
mismatch is not shown as available. No candidate is selected automatically.

Developer diagnostics contain only request URI, status, content type, response
byte length, parsed count, probe key, and stable result code. Quran translation
body text is not logged.

The reproducible audit/import tool is `tool/import_sprint4_quran_sources.ps1`.
It fails closed if either full corpus hash or the Tanzil transliteration pin has
changed; a source change requires a new human audit, not an automatic update.

## QuranEnc usage terms

QuranEnc's API terms require the content to remain unmodified, attribution of
the publisher and QuranEnc, retention of version/transcript information,
reporting notes to QuranEnc, use of reviewed updates, and avoidance of
inappropriate advertising. Murajaah stores translation and footnote strings
verbatim with source, key, technical revision, attribution, fetch time, and
source URI. Successful downloads remain available through the versioned local
Quran cache after restart or loss of network.

This audit approves the documented QuranEnc API/cache path subject to those
terms. It does not grant rights for unrelated translation files.

## Tanzil translation/transliteration distinction

Tanzil Arabic Quran text and Tanzil translation resources are legally distinct.
The Arabic Uthmani asset has its own CC BY 3.0 notice. The bundled English
Transliteration is governed by Tanzil's non-commercial translations terms; see
`QURAN_TRANSLITERATION.md` and its bundled notice.

Accordingly, the current transliteration asset is allowed only in the private,
testing, non-commercial build. Shipping it in a commercial or monetized
production build remains blocked until redistribution permission is recorded.
