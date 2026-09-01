# Quran audio source audit

Audit date: 2026-09-02.

## Approved source

Murajaah uses the documented MP3Quran.net API v3 and the HTTPS audio URLs returned by that API. It does not scrape reader pages and does not alter recordings.

- Source: https://www.mp3quran.net/
- API documentation: https://www.mp3quran.net/eng/api
- Timing API documentation: https://www.mp3quran.net/eng/timing-api
- Published policy: https://www.mp3quran.net/eng/privacy
- Attribution: `Quran audio: MP3Quran.net · reciter and riwaya from the live catalog`.

The English policy states that visitors and developers may copy material or use links from the websites. Murajaah treats this as permission to stream the published recordings and use the API links, not as permission to edit, remix, normalize, truncate permanently, or redistribute modified recordings. Exact playback clips are runtime seek boundaries over the unchanged remote file.

## API contract used

- `GET /api/v3/reciters?language=eng`: dynamic reciters, moshaf, `rewaya_id`, server, `surah_total`, and `surah_list`.
- `GET /api/v3/ayat_timing/reads`: reads for which timing exists.
- `GET /api/v3/ayat_timing?surah={surah}&read={read}`: millisecond start/end boundaries for ayahs.
- Track URL: the catalog `server` plus a three-digit surah number and `.mp3`.

Only HTTPS endpoints and server URLs are accepted. JSON, response size, identifiers, surah range, `surah_total`, and monotonically ordered timings are validated. Response bodies and low-level causes are not exposed in user errors.

## Riwaya rule

The initial catalog is explicitly limited to `rewaya_id = 1`, Rewayat Hafs A'n Assem. Other riwayat are never silently mixed into the list. The selected moshaf's riwaya remains visible beside the reciter name.

## Live verification

The 2026-09-02 live response contained 242 reciters, 220 Hafs recordings, and 115 timing reads. Exact normalized-folder matching associated 98 Hafs recordings with a timing read.

Alijon Qori was discovered through the ordinary catalog, not through application constants:

- reciter id: `21196`
- moshaf id: `10917`
- riwaya: Hafs A'n Assem
- available surahs: 114
- timing match on the audit date: none, therefore Murajaah truthfully offers full-surah playback only for this recording

Catalog contents are remote data and may change. These numbers are audit evidence, not runtime assumptions.

## Fail-closed behavior

- No timing read or incomplete timing range: play the full surah and state that exact clipping is unavailable.
- Unknown reciter, moshaf, or surah: do not construct a speculative URL.
- A timing-catalog HTTP failure leaves full-surah streaming available and marks timing unavailable; a reciter-catalog failure shows a retryable audio error.
- Invalid JSON, invalid schema, or an unsafe URL: show a retryable audio error.
- A catalog/learning-stage change stops the previous session before a new load; a late timing response cannot restart stale audio.
