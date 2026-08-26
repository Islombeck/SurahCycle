Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Net.Http
[Net.ServicePointManager]::DefaultConnectionLimit = 16

$workspacePath = Split-Path -Parent $PSScriptRoot
$metadataPath = Join-Path $workspacePath 'assets\quran\quran-data.xml'
$transliterationPath = Join-Path $workspacePath 'assets\quran\quran-transliteration-en.txt'
$manifestPath = Join-Path $workspacePath 'lib\features\quran\data\providers\known_official_quran_enc_translations.g.dart'
$utf8Strict = [Text.UTF8Encoding]::new($false, $true)
$utf8NoBom = [Text.UTF8Encoding]::new($false)
$hashAlgorithm = [Security.Cryptography.SHA256]::Create()
$httpClient = [System.Net.Http.HttpClient]::new()
$httpClient.Timeout = [TimeSpan]::FromSeconds(45)

function Get-Sha256Hex([byte[]] $Bytes) {
    return ([BitConverter]::ToString($hashAlgorithm.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant()
}

function Get-HttpBytes([string] $Uri) {
    $response = $httpClient.GetAsync($Uri).GetAwaiter().GetResult()
    try {
        if ([int] $response.StatusCode -ne 200) {
            throw "Unexpected HTTP status $([int] $response.StatusCode) for $Uri"
        }
        $contentType = $response.Content.Headers.ContentType.MediaType
        if ($contentType -notin @('application/json', 'application/octet-stream')) {
            throw "Unexpected Content-Type $contentType for $Uri"
        }
        return $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
    }
    finally {
        $response.Dispose()
    }
}

function Get-CanonicalSurahBytes([object[]] $Rows, [int] $SurahNumber, [int] $ExpectedAyahCount) {
    if ($Rows.Count -ne $ExpectedAyahCount) {
        throw "Surah $SurahNumber has $($Rows.Count) rows; expected $ExpectedAyahCount."
    }
    $stream = [IO.MemoryStream]::new()
    try {
        for ($index = 0; $index -lt $Rows.Count; $index += 1) {
            $row = $Rows[$index]
            $expectedAyah = $index + 1
            if ([int] $row.sura -ne $SurahNumber -or [int] $row.aya -ne $expectedAyah) {
                throw "Invalid coordinate at surah $SurahNumber ayah $expectedAyah."
            }
            if ($row.translation -isnot [string] -or $row.translation.Length -eq 0) {
                throw "Missing translation at surah $SurahNumber ayah $expectedAyah."
            }
            if ($null -ne $row.footnotes -and $row.footnotes -isnot [string]) {
                throw "Invalid footnotes at surah $SurahNumber ayah $expectedAyah."
            }
            $translation = [string] $row.translation
            $footnoteMarker = if ($null -eq $row.footnotes) { '0' } else { '1' + [string] $row.footnotes }
            foreach ($value in @($translation, $footnoteMarker)) {
                if ($value.Contains([char] 0x1f) -or $value.Contains([char] 0x1e)) {
                    throw "Reserved framing character at surah $SurahNumber ayah $expectedAyah."
                }
            }
            $canonical = "$SurahNumber$([char] 0x1f)$expectedAyah$([char] 0x1f)$translation$([char] 0x1f)$footnoteMarker$([char] 0x1e)"
            $part = $utf8NoBom.GetBytes($canonical)
            $stream.Write($part, 0, $part.Length)
        }
        return $stream.ToArray()
    }
    finally {
        $stream.Dispose()
    }
}

try {
    [xml] $metadata = [IO.File]::ReadAllText($metadataPath, $utf8Strict)
    $surahs = @($metadata.quran.suras.sura)
    if ($surahs.Count -ne 114) {
        throw "Expected 114 metadata surahs, got $($surahs.Count)."
    }

    $transliterationUri = 'https://tanzil.net/trans/en.transliteration?type=txt-2'
    $transliterationBytes = Get-HttpBytes $transliterationUri
    $transliterationExpectedLength = 1044894
    $transliterationExpectedHash = '8c20d95e484534e921cd2e0d2546aab7f5300090c0bd76697095b3ca1db1e01d'
    if ($transliterationBytes.Length -ne $transliterationExpectedLength) {
        throw "Tanzil transliteration byte length changed."
    }
    if ((Get-Sha256Hex $transliterationBytes) -ne $transliterationExpectedHash) {
        throw "Tanzil transliteration SHA-256 changed."
    }
    $transliterationText = $utf8Strict.GetString($transliterationBytes)
    if ($transliterationText.Contains("`r")) {
        throw 'Tanzil transliteration is no longer LF-only.'
    }
    $footerMarker = "`n`n`n# --------------------------------------------------------------------"
    $footerIndex = $transliterationText.IndexOf($footerMarker)
    if ($footerIndex -le 0) {
        throw 'Tanzil transliteration footer is missing.'
    }
    $requiredFooterValues = @(
        '#  Name: Transliteration',
        '#  Translator: English Transliteration',
        '#  Language: English',
        '#  ID: en.transliteration',
        '#  Last Update: September 6, 2010',
        '#  Source: Tanzil.net'
    )
    foreach ($marker in $requiredFooterValues) {
        if (-not $transliterationText.Substring($footerIndex + 3).Contains($marker)) {
            throw "Tanzil transliteration footer marker missing: $marker"
        }
    }
    $coordinateLines = @($transliterationText.Substring(0, $footerIndex).Split("`n"))
    if ($coordinateLines.Count -ne 6236) {
        throw "Expected 6,236 Tanzil coordinates, got $($coordinateLines.Count)."
    }
    $lineIndex = 0
    foreach ($surah in $surahs) {
        $surahNumber = [int] $surah.index
        for ($ayah = 1; $ayah -le [int] $surah.ayas; $ayah += 1) {
            $parts = $coordinateLines[$lineIndex].Split('|', 3)
            if ($parts.Count -ne 3 -or [int] $parts[0] -ne $surahNumber -or [int] $parts[1] -ne $ayah -or $parts[2].Length -eq 0) {
                throw "Invalid Tanzil coordinate at line $($lineIndex + 1)."
            }
            $lineIndex += 1
        }
    }
    [IO.File]::WriteAllBytes($transliterationPath, $transliterationBytes)

    $known = [ordered]@{
        russian_rwwad = 'c58986174045d030df67ec6b8f15ebe2fdeae74c092e73a7630c08acf742542a'
        russian_aboadel = 'ac9387c90b5cf90939f0a527702f4d1c5d025269cf705e2f6b2594b4f803a3ff'
    }
    $hashesByKey = [ordered]@{}
    foreach ($entry in $known.GetEnumerator()) {
        $key = $entry.Key
        $fullStream = [IO.MemoryStream]::new()
        $surahHashes = [Collections.Generic.List[string]]::new()
        try {
            for ($batchStart = 1; $batchStart -le 114; $batchStart += 12) {
                $batchEnd = [Math]::Min(114, $batchStart + 11)
                $tasks = @()
                for ($surahNumber = $batchStart; $surahNumber -le $batchEnd; $surahNumber += 1) {
                    $uri = "https://quranenc.com/api/v1/translation/sura/$key/$surahNumber"
                    $tasks += $httpClient.GetAsync($uri)
                }
                [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]] $tasks)
                for ($offset = 0; $offset -lt $tasks.Count; $offset += 1) {
                    $surahNumber = $batchStart + $offset
                    $response = $tasks[$offset].Result
                    try {
                        if ([int] $response.StatusCode -ne 200 -or $response.Content.Headers.ContentType.MediaType -ne 'application/json') {
                            throw "Invalid QuranEnc response for $key surah $surahNumber."
                        }
                        $bytes = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
                        $root = $utf8Strict.GetString($bytes) | ConvertFrom-Json
                        $canonical = Get-CanonicalSurahBytes @($root.result) $surahNumber ([int] $surahs[$surahNumber - 1].ayas)
                        $surahHashes.Add((Get-Sha256Hex $canonical))
                        $fullStream.Write($canonical, 0, $canonical.Length)
                    }
                    finally {
                        $response.Dispose()
                    }
                }
            }
            $fullHash = Get-Sha256Hex $fullStream.ToArray()
            if ($fullHash -ne $entry.Value) {
                throw "QuranEnc corpus revision changed for ${key}: $fullHash"
            }
            if ($surahHashes.Count -ne 114) {
                throw "QuranEnc manifest is incomplete for $key."
            }
            $hashesByKey[$key] = $surahHashes
        }
        finally {
            $fullStream.Dispose()
        }
    }

    $dart = [Text.StringBuilder]::new()
    [void] $dart.AppendLine('// GENERATED BY tool/import_sprint4_quran_sources.ps1. DO NOT EDIT.')
    [void] $dart.AppendLine()
    [void] $dart.AppendLine("part of 'known_official_quran_enc_translations.dart';")
    [void] $dart.AppendLine()
    [void] $dart.AppendLine('const Map<String, List<String>> _knownQuranEncSurahSha256 =')
    [void] $dart.AppendLine('    <String, List<String>>{')
    foreach ($entry in $hashesByKey.GetEnumerator()) {
        [void] $dart.AppendLine("      '$($entry.Key)': <String>[")
        foreach ($hash in $entry.Value) {
            [void] $dart.AppendLine("        '$hash',")
        }
        [void] $dart.AppendLine('      ],')
    }
    [void] $dart.AppendLine('    };')
    [IO.File]::WriteAllText($manifestPath, $dart.ToString().Replace("`r`n", "`n"), $utf8NoBom)

    Write-Output "Imported Tanzil transliteration: $($transliterationBytes.Length) bytes, $transliterationExpectedHash"
    foreach ($entry in $known.GetEnumerator()) {
        Write-Output "Verified QuranEnc $($entry.Key): 114 surahs, 6236 ayahs, $($entry.Value)"
    }
}
finally {
    $hashAlgorithm.Dispose()
    $httpClient.Dispose()
}
