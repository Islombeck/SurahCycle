# Quran audio architecture

## Scope

Sprint 5D adds focused streaming to the active Learning stage. It is not a general Quran player and does not download the library.

## Layers

1. `QuranAudioProvider`, `QuranReciter`, `QuranMoshaf`, `QuranAudioTrack`, `AyahTiming`, and `AudioCapability` form the provider-neutral contract.
2. `Mp3QuranAudioProvider` validates MP3Quran API v3 and exposes a Hafs-only dynamic catalog.
3. `LearningAudioRangeResolver` maps the immutable learning stage to either an exact ayah/range clip or an explicit full-surah fallback.
4. `LearningAudioController` owns cancellation generations and stops the current session before reciter, surah, or stage changes.
5. `JustAudioQuranPlayback` is the single process-wide player. `just_audio_background` supplies the Android media notification, lock-screen controls, and screen-off playback.

## Timing and repeat

- `NEW_AYAH`: start and end of that exact ayah.
- Review/cumulative/bridge/section/final range: start of the first ayah through end of the last ayah.
- Missing any required timing: no estimated boundary; full-surah playback only.
- Finite repeat: a sequence containing 1, 3, 5, or 10 copies of the same source/clip.
- Infinite repeat: one source with loop mode; it is never selected automatically.

Every sequence item carries a media item containing the reciter, visible riwaya, surah, and learning range. Stop removes the media session; pause leaves it resumable.

## Lifecycle safety

The controller increments a generation before every load and stop. Timing results from an older generation are discarded. The Learning control stops playback when its stage/surah changes or the control is disposed. Selecting a different reciter or repeat mode stops the previous source before applying the choice. Network/player errors are contained and leave a retryable UI.

## Android integration

The app activity extends `AudioServiceActivity`. The manifest declares wake-lock and media-playback foreground-service permissions plus the audio service and media-button receiver. On Android 13+, the notification permission is requested only when the user first starts audio. Denial does not block foreground playback, but Android may hide the media notification. The existing Learning home-widget notification path is separate and is not converted into a media session.
