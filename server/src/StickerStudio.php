<?php

declare(strict_types=1);

final class StickerStudio
{
    private const VIDEO_SIZE = 512;
    private const PREVIEW_SIZE = 120;

    public static function list(): void
    {
        $stickers = [];
        foreach (StickerCatalog::all() as $entry) {
            $stickers[] = self::publicEntry($entry);
        }

        Http::json(200, [
            'ok' => true,
            'ffmpeg' => self::ffmpegPath() !== null,
            'tgs' => self::pythonPath() !== null,
            'preview_size' => self::PREVIEW_SIZE,
            'stickers' => $stickers,
        ]);
    }

    public static function players(): void
    {
        $rows = Database::pdo()->query(
            'SELECT steamid, games, rating, lootbox_unopened, lootbox_currency
             FROM players
             ORDER BY lootbox_unopened DESC, games DESC, steamid ASC
             LIMIT 200'
        )->fetchAll();

        $players = [];
        foreach ($rows as $row) {
            $players[] = [
                'steamid' => (string) $row['steamid'],
                'games' => (int) $row['games'],
                'rating' => (int) $row['rating'],
                'lootboxes' => (int) $row['lootbox_unopened'],
                'currency' => (int) $row['lootbox_currency'],
            ];
        }

        Http::json(200, [
            'ok' => true,
            'players' => $players,
        ]);
    }

    public static function save(): void
    {
        set_time_limit(180);
        ini_set('max_execution_time', '180');
        $key = trim((string) ($_POST['key'] ?? ''));
        $existing = StickerCatalog::find($key);
        $creating = $existing === null;

        $entry = StickerCatalog::normalize([
            'key' => $key,
            'name_ru' => $_POST['name_ru'] ?? ($existing['name_ru'] ?? ''),
            'name_en' => $_POST['name_en'] ?? ($existing['name_en'] ?? ''),
            'max_time' => $_POST['max_time'] ?? ($existing['max_time'] ?? 1.5),
            'rarity' => $_POST['rarity'] ?? ($existing['rarity'] ?? 'common'),
            'weight_normal' => $_POST['weight_normal'] ?? ($existing['weight_normal'] ?? null),
            'weight_elite' => $_POST['weight_elite'] ?? ($existing['weight_elite'] ?? null),
            'sound' => $_POST['sound'] ?? ($existing['sound'] ?? ''),
            'sound_file' => $existing['sound_file'] ?? null,
            'sound_volume' => $_POST['sound_volume'] ?? ($existing['sound_volume'] ?? 1),
        ], true);
        if ($entry === null) {
            Http::json(400, ['ok' => false, 'error' => 'invalid_sticker']);
        }

        $video = self::uploadedFile('video');
        $audio = self::uploadedFile('audio');
        if ($creating && $video === null) {
            Http::json(400, ['ok' => false, 'error' => 'video_required']);
        }
        if ($creating && $audio === null) {
            Http::json(400, ['ok' => false, 'error' => 'audio_required']);
        }

        $speed = self::clampVideoSpeed((float) ($_POST['video_speed'] ?? 1));

        if ($video !== null) {
            self::convertVideo($video, $entry['key'], $speed);
        } elseif ($creating) {
            Http::json(400, ['ok' => false, 'error' => 'video_required']);
        } elseif (abs($speed - 1.0) >= 0.001) {
            self::retimeExistingVideo($entry['key'], $speed);
        } else {
            self::ensurePreviewMp4($entry['key']);
        }

        $audioStart = (float) ($_POST['audio_start'] ?? 0);
        $audioEnd = (float) ($_POST['audio_end'] ?? 0);

        if ($audio !== null) {
            $soundFile = self::soundFileName($entry['key']);
            self::storeAudio($audio, $soundFile, $audioStart, $audioEnd);
            $entry['sound'] = 'Wheel.' . $entry['key'];
            $entry['sound_file'] = $soundFile;
        } elseif (!$creating) {
            $existingAudio = self::audioPath($entry);
            if ($existingAudio !== null && $audioEnd > 0) {
                self::trimExistingAudio($existingAudio, $audioStart, $audioEnd);
            }
        }

        $catalog = StickerCatalog::all();
        $replaced = false;
        foreach ($catalog as $index => $item) {
            if ($item['key'] === $entry['key']) {
                $catalog[$index] = $entry;
                $replaced = true;
                break;
            }
        }
        if (!$replaced) {
            $catalog[] = $entry;
        }

        self::commit($catalog);
        Http::json(200, [
            'ok' => true,
            'sticker' => self::publicEntry($entry),
        ]);
    }

    public static function delete(): void
    {
        $body = $_POST !== [] ? $_POST : Http::body();
        $key = trim((string) ($body['key'] ?? ''));
        $entry = StickerCatalog::find($key);
        if ($entry === null) {
            Http::json(404, ['ok' => false, 'error' => 'unknown_sticker']);
        }

        $catalog = [];
        foreach (StickerCatalog::all() as $item) {
            if ($item['key'] !== $key) {
                $catalog[] = $item;
            }
        }
        if ($catalog === []) {
            Http::json(400, ['ok' => false, 'error' => 'last_sticker']);
        }

        self::deleteAssets($entry);
        StickerCatalog::write($catalog);
        self::patchGameFiles($catalog);
        Stickers::removeKey($key);
        Stickers::syncCatalog();

        Http::json(200, ['ok' => true, 'key' => $key]);
    }

    public static function media(): void
    {
        $key = trim((string) ($_GET['key'] ?? ''));
        $kind = trim((string) ($_GET['kind'] ?? 'video'));
        $entry = StickerCatalog::find($key);
        if ($entry === null) {
            Http::json(404, ['ok' => false, 'error' => 'unknown_sticker']);
        }

        if ($kind === 'audio') {
            $path = self::audioPath($entry);
            if ($path === null) {
                Http::json(404, ['ok' => false, 'error' => 'no_audio']);
            }
            Http::file($path);
        }

        $mp4 = self::previewMp4Path($key);
        if (is_file($mp4)) {
            Http::file($mp4);
        }
        $webm = self::gameWebmPath($key);
        if (is_file($webm)) {
            Http::file($webm);
        }
        Http::json(404, ['ok' => false, 'error' => 'no_video']);
    }

    /** @param array<string, mixed> $entry */
    private static function publicEntry(array $entry): array
    {
        $key = $entry['key'];
        $hasVideo = is_file(self::gameWebmPath($key)) || is_file(self::previewMp4Path($key));
        $hasAudio = self::audioPath($entry) !== null;
        $query = rawurlencode($key);

        return [
            'key' => $key,
            'name_ru' => $entry['name_ru'],
            'name_en' => $entry['name_en'],
            'max_time' => $entry['max_time'],
            'rarity' => $entry['rarity'],
            'weight_normal' => $entry['weight_normal'],
            'weight_elite' => $entry['weight_elite'],
            'sound' => $entry['sound'],
            'sound_file' => $entry['sound_file'] ?? null,
            'sound_volume' => (float) ($entry['sound_volume'] ?? 1),
            'has_video' => $hasVideo,
            'has_audio' => $hasAudio,
            'video_url' => $hasVideo ? '/v1/stickers/studio/media?kind=video&key=' . $query : null,
            'audio_url' => $hasAudio ? '/v1/stickers/studio/media?kind=audio&key=' . $query : null,
        ];
    }

    /** @param list<array<string, mixed>> $catalog */
    private static function commit(array $catalog): void
    {
        StickerCatalog::write($catalog);
        self::patchGameFiles($catalog);
        Stickers::syncCatalog();
    }

    /** @return array{tmp: string, name: string, ext: string}|null */
    private static function uploadedFile(string $field): ?array
    {
        $file = $_FILES[$field] ?? null;
        if (!is_array($file) || !isset($file['error'], $file['tmp_name'], $file['name'])) {
            return null;
        }
        if ((int) $file['error'] === UPLOAD_ERR_NO_FILE) {
            return null;
        }
        if ((int) $file['error'] !== UPLOAD_ERR_OK || !is_uploaded_file((string) $file['tmp_name'])) {
            Http::json(400, ['ok' => false, 'error' => $field . '_upload_failed']);
        }

        $name = (string) $file['name'];
        $ext = strtolower(pathinfo($name, PATHINFO_EXTENSION));
        $allowed = $field === 'video'
            ? ['webm' => true, 'mp4' => true, 'gif' => true, 'png' => true, 'jpg' => true, 'jpeg' => true, 'webp' => true, 'tgs' => true]
            : ['mp3' => true, 'wav' => true, 'ogg' => true, 'm4a' => true];
        if (!isset($allowed[$ext])) {
            Http::json(400, ['ok' => false, 'error' => $field . '_type']);
        }

        return [
            'tmp' => (string) $file['tmp_name'],
            'name' => $name,
            'ext' => $ext,
        ];
    }

    /** @param array{tmp: string, name: string, ext: string} $file */
    private static function convertVideo(array $file, string $key, float $speed = 1.0): void
    {
        $ffmpeg = self::ffmpegPath();
        if ($ffmpeg === null) {
            Http::json(500, ['ok' => false, 'error' => 'ffmpeg_missing']);
        }

        $tmpDir = sys_get_temp_dir() . DIRECTORY_SEPARATOR . 'trinity-sticker-' . bin2hex(random_bytes(6));
        if (!mkdir($tmpDir) && !is_dir($tmpDir)) {
            Http::json(500, ['ok' => false, 'error' => 'tmp_failed']);
        }

        $input = $tmpDir . DIRECTORY_SEPARATOR . 'input.' . $file['ext'];
        if (!copy($file['tmp'], $input)) {
            self::removeDir($tmpDir);
            Http::json(500, ['ok' => false, 'error' => 'copy_failed']);
        }

        $webmTmp = $tmpDir . DIRECTORY_SEPARATOR . 'sticker.webm';
        $mp4Tmp = $tmpDir . DIRECTORY_SEPARATOR . 'sticker.mp4';
        $filter = self::videoFilter($speed);
        $prefix = [$ffmpeg, '-y', '-hide_banner', '-loglevel', 'error'];
        $inputArgs = ['-i', $input];

        try {
            if ($file['ext'] === 'tgs') {
                $framesDir = $tmpDir . DIRECTORY_SEPARATOR . 'frames';
                $info = self::rasterizeTgs($input, $framesDir);
                $pattern = str_replace('\\', '/', $framesDir) . '/frame_%04d.png';
                $inputArgs = [
                    '-framerate', self::formatNumber((float) $info['fps']),
                    '-start_number', '0',
                    '-i', $pattern,
                ];
            } elseif (in_array($file['ext'], ['png', 'jpg', 'jpeg', 'webp'], true)) {
                $prefix = [$ffmpeg, '-y', '-hide_banner', '-loglevel', 'error', '-loop', '1', '-t', '2'];
            }

            self::encodeVideoOutputs($prefix, $inputArgs, $filter, $mp4Tmp, $webmTmp);
            self::ensureDir(dirname(self::gameWebmPath($key)));
            self::ensureDir(dirname(self::previewMp4Path($key)));
            if (!copy($webmTmp, self::gameWebmPath($key)) || !copy($mp4Tmp, self::previewMp4Path($key))) {
                Http::json(500, ['ok' => false, 'error' => 'store_video_failed']);
            }
        } finally {
            self::removeDir($tmpDir);
        }
    }

    private static function retimeExistingVideo(string $key, float $speed): void
    {
        $ffmpeg = self::ffmpegPath();
        if ($ffmpeg === null) {
            Http::json(500, ['ok' => false, 'error' => 'ffmpeg_missing']);
        }

        $source = self::previewMp4Path($key);
        if (!is_file($source)) {
            $source = self::gameWebmPath($key);
        }
        if (!is_file($source)) {
            Http::json(400, ['ok' => false, 'error' => 'video_missing']);
        }

        $tmpDir = sys_get_temp_dir() . DIRECTORY_SEPARATOR . 'trinity-sticker-' . bin2hex(random_bytes(6));
        if (!mkdir($tmpDir) && !is_dir($tmpDir)) {
            Http::json(500, ['ok' => false, 'error' => 'tmp_failed']);
        }

        $ext = strtolower((string) pathinfo($source, PATHINFO_EXTENSION));
        if ($ext === '') {
            $ext = 'mp4';
        }
        $input = $tmpDir . DIRECTORY_SEPARATOR . 'input.' . $ext;
        if (!copy($source, $input)) {
            self::removeDir($tmpDir);
            Http::json(500, ['ok' => false, 'error' => 'copy_failed']);
        }

        $webmTmp = $tmpDir . DIRECTORY_SEPARATOR . 'sticker.webm';
        $mp4Tmp = $tmpDir . DIRECTORY_SEPARATOR . 'sticker.mp4';
        $prefix = [$ffmpeg, '-y', '-hide_banner', '-loglevel', 'error'];
        try {
            self::encodeVideoOutputs(
                $prefix,
                ['-i', $input],
                self::videoFilter($speed),
                $mp4Tmp,
                $webmTmp
            );
            self::ensureDir(dirname(self::gameWebmPath($key)));
            self::ensureDir(dirname(self::previewMp4Path($key)));
            if (!copy($webmTmp, self::gameWebmPath($key)) || !copy($mp4Tmp, self::previewMp4Path($key))) {
                Http::json(500, ['ok' => false, 'error' => 'store_video_failed']);
            }
        } finally {
            self::removeDir($tmpDir);
        }
    }

    /** @param list<string> $prefix @param list<string> $inputArgs */
    private static function encodeVideoOutputs(
        array $prefix,
        array $inputArgs,
        string $filter,
        string $mp4Tmp,
        string $webmTmp
    ): void {
        self::run(array_merge($prefix, $inputArgs, [
            '-vf', $filter,
            '-c:v', 'libx264',
            '-pix_fmt', 'yuv420p',
            '-crf', '23',
            '-an',
            '-movflags', '+faststart',
            $mp4Tmp,
        ]));
        self::run(array_merge($prefix, $inputArgs, [
            '-vf', $filter,
            '-c:v', 'libvpx-vp9',
            '-b:v', '0',
            '-crf', '32',
            '-pix_fmt', 'yuv420p',
            '-an',
            $webmTmp,
        ]));
    }

    private static function videoFilter(float $speed): string
    {
        $filter = 'scale=' . self::VIDEO_SIZE . ':' . self::VIDEO_SIZE
            . ':force_original_aspect_ratio=increase,crop=' . self::VIDEO_SIZE . ':' . self::VIDEO_SIZE
            . ',format=yuv420p';
        if (abs($speed - 1.0) >= 0.001) {
            $filter = 'setpts=' . self::formatNumber(1.0 / $speed) . '*PTS,' . $filter;
        }

        return $filter;
    }

    private static function clampVideoSpeed(float $speed): float
    {
        if (!is_finite($speed)) {
            return 1.0;
        }

        return max(0.25, min(2.0, $speed));
    }

    private static function ensurePreviewMp4(string $key): void
    {
        $mp4 = self::previewMp4Path($key);
        if (is_file($mp4)) {
            return;
        }
        $webm = self::gameWebmPath($key);
        $ffmpeg = self::ffmpegPath();
        if (!is_file($webm) || $ffmpeg === null) {
            return;
        }

        self::ensureDir(dirname($mp4));
        self::run([
            $ffmpeg, '-y', '-hide_banner', '-loglevel', 'error',
            '-i', $webm,
            '-c:v', 'libx264',
            '-pix_fmt', 'yuv420p',
            '-crf', '23',
            '-an',
            '-movflags', '+faststart',
            $mp4,
        ]);
    }

    /** @param array{tmp: string, name: string, ext: string} $file */
    private static function storeAudio(array $file, string $soundFile, float $start, float $end): void
    {
        $dest = self::contentSoundPath($soundFile);
        self::ensureDir(dirname($dest));
        $trim = self::normalizeAudioTrim($file['tmp'], $start, $end);
        if ($trim === null && $file['ext'] === 'mp3') {
            if (!copy($file['tmp'], $dest)) {
                Http::json(500, ['ok' => false, 'error' => 'store_audio_failed']);
            }
            return;
        }

        self::encodeAudio($file['tmp'], $dest, $trim);
    }

    private static function trimExistingAudio(string $path, float $start, float $end): void
    {
        $trim = self::normalizeAudioTrim($path, $start, $end);
        if ($trim === null) {
            return;
        }

        $tmp = $path . '.trim-tmp.mp3';
        self::unlinkIfExists($tmp);
        self::encodeAudio($path, $tmp, $trim);
        self::unlinkIfExists($path);
        if (!rename($tmp, $path) && (!copy($tmp, $path) || !unlink($tmp))) {
            Http::json(500, ['ok' => false, 'error' => 'store_audio_failed']);
        }
    }

    /** @return array{start: float, duration: float}|null */
    private static function normalizeAudioTrim(string $path, float $start, float $end): ?array
    {
        $duration = self::audioDuration($path);
        $from = max(0.0, $start);
        $to = $end > 0.0 ? min($end, $duration) : $duration;
        if ($to - $from < 0.2) {
            Http::json(400, ['ok' => false, 'error' => 'audio_trim_too_short']);
        }
        if ($from <= 0.05 && ($duration - ($to - $from)) <= 0.15) {
            return null;
        }

        return [
            'start' => $from,
            'duration' => $to - $from,
        ];
    }

    /** @param array{start: float, duration: float}|null $trim */
    private static function encodeAudio(string $source, string $dest, ?array $trim): void
    {
        $ffmpeg = self::ffmpegPath();
        if ($ffmpeg === null) {
            Http::json(500, ['ok' => false, 'error' => 'ffmpeg_missing']);
        }

        $args = [
            $ffmpeg, '-y', '-hide_banner', '-loglevel', 'error',
            '-i', $source,
        ];
        if ($trim !== null) {
            $args[] = '-ss';
            $args[] = self::formatNumber($trim['start']);
            $args[] = '-t';
            $args[] = self::formatNumber($trim['duration']);
        }
        $args = array_merge($args, [
            '-vn',
            '-c:a', 'libmp3lame',
            '-q:a', '4',
            $dest,
        ]);
        self::run($args);
    }

    private static function audioDuration(string $path): float
    {
        $probe = self::ffprobePath();
        if ($probe === null) {
            Http::json(500, ['ok' => false, 'error' => 'ffprobe_missing']);
        }
        $out = trim(self::run([
            $probe,
            '-v', 'error',
            '-show_entries', 'format=duration',
            '-of', 'default=noprint_wrappers=1:nokey=1',
            $path,
        ], 'ffprobe_failed'));
        $duration = (float) $out;
        if ($duration <= 0) {
            Http::json(400, ['ok' => false, 'error' => 'audio_duration']);
        }

        return $duration;
    }

    /** @param array<string, mixed> $entry */
    private static function deleteAssets(array $entry): void
    {
        $key = $entry['key'];
        self::unlinkIfExists(self::gameWebmPath($key));
        self::unlinkIfExists(self::previewMp4Path($key));
        $soundFile = $entry['sound_file'] ?? null;
        if (is_string($soundFile) && $soundFile !== '') {
            self::unlinkIfExists(self::contentSoundPath($soundFile));
        }
    }

    /** @param list<array<string, mixed>> $catalog */
    private static function patchGameFiles(array $catalog): void
    {
        $root = StickerCatalog::repoRoot();
        self::replaceMarked(
            $root . '/Game/scripts/vscripts/game_managers/trinity_stickers.lua',
            '-- TRINITY_STICKER_CATALOG_BEGIN',
            '-- TRINITY_STICKER_CATALOG_END',
            self::luaCatalog($catalog)
        );
        self::replaceMarked(
            $root . '/Game/scripts/vscripts/game_managers/trinity_stickers.lua',
            '-- TRINITY_STICKER_MAX_TIME_BEGIN',
            '-- TRINITY_STICKER_MAX_TIME_END',
            self::luaMaxTime($catalog)
        );
        self::replaceMarked(
            $root . '/Content/panorama/layout/custom_game/chat_wheel/chat_wheel.js',
            '/* TRINITY_STICKER_SOUNDS_BEGIN */',
            '/* TRINITY_STICKER_SOUNDS_END */',
            self::jsSounds($catalog)
        );
        self::replaceMarked(
            $root . '/Content/panorama/layout/custom_game/chat_wheel/chat_wheel.js',
            '/* TRINITY_STICKER_MAX_TIME_BEGIN */',
            '/* TRINITY_STICKER_MAX_TIME_END */',
            self::jsMaxTime($catalog)
        );
        self::replaceMarked(
            $root . '/Content/panorama/layout/custom_game/sticker_editor/sticker_editor.js',
            '/* TRINITY_STICKER_CATALOG_BEGIN */',
            '/* TRINITY_STICKER_CATALOG_END */',
            self::jsCatalog($catalog)
        );
        self::replaceMarked(
            $root . '/Content/panorama/layout/custom_game/lootbox/lootbox.js',
            '/* TRINITY_STICKER_CATALOG_BEGIN */',
            '/* TRINITY_STICKER_CATALOG_END */',
            self::jsCatalog($catalog)
        );
        self::replaceMarked(
            $root . '/Content/panorama/layout/custom_game/lootbox/lootbox.js',
            '/* TRINITY_STICKER_SOUNDS_BEGIN */',
            '/* TRINITY_STICKER_SOUNDS_END */',
            self::jsSounds($catalog)
        );
        self::replaceMarked(
            $root . '/Content/panorama/layout/custom_game/lootbox/lootbox.js',
            '/* TRINITY_STICKER_ROLL_POOL_BEGIN */',
            '/* TRINITY_STICKER_ROLL_POOL_END */',
            self::jsRollPool($catalog)
        );
        self::replaceLocalization(
            $root . '/Game/resource/addon_russian.txt',
            $catalog,
            'name_ru'
        );
        self::replaceLocalization(
            $root . '/Game/resource/addon_english.txt',
            $catalog,
            'name_en'
        );
        $sounds = self::vsndevtsBlock($catalog);
        self::replaceMarked(
            $root . '/Content/Soundevents/Trinity_sounds.vsndevts',
            '// TRINITY_STICKER_SOUNDS_BEGIN',
            '// TRINITY_STICKER_SOUNDS_END',
            $sounds
        );
        self::replaceMarked(
            $root . '/Game/soundevents/Trinity_sounds.vsndevts',
            '// TRINITY_STICKER_SOUNDS_BEGIN',
            '// TRINITY_STICKER_SOUNDS_END',
            $sounds
        );
    }

    /** @param list<array<string, mixed>> $catalog */
    private static function luaCatalog(array $catalog): string
    {
        $lines = [];
        foreach ($catalog as $entry) {
            $lines[] = "\t\"" . $entry['key'] . "\",";
        }
        return implode("\n", $lines);
    }

    /** @param list<array<string, mixed>> $catalog */
    private static function luaMaxTime(array $catalog): string
    {
        $lines = [];
        foreach ($catalog as $entry) {
            $lines[] = "\t" . $entry['key'] . ' = ' . self::formatNumber((float) $entry['max_time']) . ',';
        }
        return implode("\n", $lines);
    }

    /** @param list<array<string, mixed>> $catalog */
    private static function jsCatalog(array $catalog): string
    {
        $lines = [];
        foreach ($catalog as $entry) {
            $lines[] = '  "' . $entry['key'] . '",';
        }
        return implode("\n", $lines);
    }

    /** @param list<array<string, mixed>> $catalog */
    private static function jsSounds(array $catalog): string
    {
        $lines = [];
        foreach ($catalog as $entry) {
            $lines[] = '  ' . $entry['key'] . ': "' . self::escapeJs((string) $entry['sound']) . '",';
        }
        return implode("\n", $lines);
    }

    /** @param list<array<string, mixed>> $catalog */
    private static function jsMaxTime(array $catalog): string
    {
        $lines = [];
        foreach ($catalog as $entry) {
            $lines[] = '  ' . $entry['key'] . ': ' . self::formatNumber((float) $entry['max_time']) . ',';
        }
        return implode("\n", $lines);
    }

    /** @param list<array<string, mixed>> $catalog */
    private static function jsRollPool(array $catalog): string
    {
        $lines = [];
        foreach ($catalog as $entry) {
            $lines[] = '  { key: "' . $entry['key'] . '", quality: 1, weight: ' . (int) $entry['weight_normal'] . ' },';
            $lines[] = '  { key: "' . $entry['key'] . '", quality: 2, weight: ' . (int) $entry['weight_elite'] . ' },';
        }
        return implode("\n", $lines);
    }

    /** @param list<array<string, mixed>> $catalog */
    private static function vsndevtsBlock(array $catalog): string
    {
        $chunks = [];
        foreach ($catalog as $entry) {
            $sound = (string) $entry['sound'];
            $file = $entry['sound_file'] ?? null;
            if (!str_starts_with($sound, 'Wheel.') || !is_string($file) || $file === '') {
                continue;
            }
            $vsnd = 'sounds/wheel/' . preg_replace('/\.mp3$/i', '.vsnd', $file);
            $volume = self::formatNumber((float) ($entry['sound_volume'] ?? 1));
            $chunks[] = "\t" . $sound . " =\n\t{\n\t\ttype = \"dota_src1_3d\"\n\t\tvsnd_files = \"" . $vsnd . "\"\n\t\tvolume = " . $volume . "\n\t}";
        }
        return $chunks === [] ? '' : implode("\n\n", $chunks);
    }

    /** @param list<array<string, mixed>> $catalog */
    private static function replaceLocalization(string $path, array $catalog, string $nameField): void
    {
        $raw = self::read($path);
        $lines = [];
        foreach ($catalog as $entry) {
            $name = self::escapeVdf((string) $entry[$nameField]);
            $lines[] = "\t\t\"chat_wheel_donate_sound_" . $entry['key'] . "\"\t\t\t\t\t\t\t\"" . $name . "\"";
        }
        $lines[] = "\t\t\"chat_wheel_donate_sound_empty\"\t\t\t\t\t\t\t\"\"";
        $block = implode("\n", $lines);
        $updated = preg_replace(
            '/[ \t]*"chat_wheel_donate_sound_[^"]+"[ \t]+"[^"]*"(?:\r?\n[ \t]*"chat_wheel_donate_sound_[^"]+"[ \t]+"[^"]*")*/u',
            $block,
            $raw,
            1,
            $count
        );
        if (!is_string($updated) || $count !== 1) {
            Http::json(500, ['ok' => false, 'error' => 'localization_patch_failed', 'file' => basename($path)]);
        }
        self::write($path, $updated);
    }

    private static function replaceMarked(string $path, string $begin, string $end, string $inner): void
    {
        $raw = self::read($path);
        $beginPos = strpos($raw, $begin);
        $endPos = strpos($raw, $end);
        if ($beginPos === false || $endPos === false || $endPos <= $beginPos) {
            Http::json(500, ['ok' => false, 'error' => 'marker_missing', 'file' => basename($path), 'marker' => $begin]);
        }
        $beginAt = $beginPos + strlen($begin);
        $beginLineStart = strrpos(substr($raw, 0, $beginPos), "\n");
        $indent = "\t";
        if ($beginLineStart !== false) {
            $maybeIndent = substr($raw, $beginLineStart + 1, $beginPos - $beginLineStart - 1);
            if (is_string($maybeIndent) && preg_match('/^[ \t]+$/', $maybeIndent) === 1) {
                $indent = $maybeIndent;
            }
        }
        $prefix = substr($raw, 0, $beginAt);
        $suffix = substr($raw, $endPos);
        $body = $inner === '' ? "\n" : "\n" . $inner . "\n";
        self::write($path, $prefix . $body . $indent . $suffix);
    }

    private static function read(string $path): string
    {
        $raw = @file_get_contents($path);
        if (!is_string($raw)) {
            Http::json(500, ['ok' => false, 'error' => 'read_failed', 'file' => $path]);
        }
        return $raw;
    }

    private static function write(string $path, string $contents): void
    {
        if (file_put_contents($path, $contents) === false) {
            Http::json(500, ['ok' => false, 'error' => 'write_failed', 'file' => $path]);
        }
    }

    /** @return array{fps: float, count: int} */
    private static function rasterizeTgs(string $source, string $framesDir): array
    {
        $python = self::pythonPath();
        if ($python === null) {
            Http::json(500, ['ok' => false, 'error' => 'tgs_python_missing']);
        }

        $script = dirname(__DIR__) . DIRECTORY_SEPARATOR . 'tools' . DIRECTORY_SEPARATOR
            . 'sticker-convert' . DIRECTORY_SEPARATOR . 'tgs_to_frames.py';
        if (!is_file($script)) {
            Http::json(500, ['ok' => false, 'error' => 'tgs_script_missing']);
        }

        $stdout = self::run([$python, $script, $source, $framesDir], 'tgs_failed');
        $decoded = json_decode(trim($stdout), true);
        $fps = is_array($decoded) ? (float) ($decoded['fps'] ?? 0) : 0;
        $count = is_array($decoded) ? (int) ($decoded['count'] ?? 0) : 0;
        if ($fps <= 0 || $count < 1) {
            Http::json(500, ['ok' => false, 'error' => 'tgs_empty', 'detail' => $stdout]);
        }

        return ['fps' => $fps, 'count' => $count];
    }

    /** @param list<string> $args */
    private static function run(array $args, string $error = 'ffmpeg_failed'): string
    {
        $spec = [
            1 => ['pipe', 'w'],
            2 => ['pipe', 'w'],
        ];
        $proc = proc_open($args, $spec, $pipes, null, null, ['bypass_shell' => true]);
        if (!is_resource($proc)) {
            Http::json(500, ['ok' => false, 'error' => $error . '_exec']);
        }
        $stdout = stream_get_contents($pipes[1]);
        $stderr = stream_get_contents($pipes[2]);
        fclose($pipes[1]);
        fclose($pipes[2]);
        $code = proc_close($proc);
        if ($code !== 0) {
            Http::json(500, [
                'ok' => false,
                'error' => $error,
                'detail' => trim((string) $stderr . "\n" . (string) $stdout),
            ]);
        }

        return is_string($stdout) ? $stdout : '';
    }

    private static function pythonPath(): ?string
    {
        $configured = Config::load()['python'] ?? '';
        if (is_string($configured) && $configured !== '' && is_file($configured)) {
            return $configured;
        }

        $venv = dirname(__DIR__) . DIRECTORY_SEPARATOR . 'tools' . DIRECTORY_SEPARATOR
            . 'sticker-convert' . DIRECTORY_SEPARATOR . '.venv' . DIRECTORY_SEPARATOR
            . 'Scripts' . DIRECTORY_SEPARATOR . 'python.exe';
        if (is_file($venv)) {
            return $venv;
        }

        $lines = [];
        $code = 0;
        exec('where.exe python 2>NUL', $lines, $code);
        if ($code === 0) {
            foreach ($lines as $line) {
                $path = trim((string) $line);
                if ($path !== '' && is_file($path)) {
                    return $path;
                }
            }
        }

        return null;
    }

    private static function ffmpegPath(): ?string
    {
        $configured = Config::load()['ffmpeg'] ?? '';
        if (is_string($configured) && $configured !== '' && is_file($configured)) {
            return $configured;
        }
        $fromEnv = getenv('FFMPEG');
        if (is_string($fromEnv) && $fromEnv !== '' && is_file($fromEnv)) {
            return $fromEnv;
        }

        $lines = [];
        $code = 0;
        exec('where.exe ffmpeg 2>NUL', $lines, $code);
        if ($code === 0) {
            foreach ($lines as $line) {
                $path = trim((string) $line);
                if ($path !== '' && is_file($path)) {
                    return $path;
                }
            }
        }

        $localAppData = getenv('LOCALAPPDATA');
        if (is_string($localAppData) && $localAppData !== '') {
            $matches = glob($localAppData . '/Microsoft/WinGet/Packages/Gyan.FFmpeg*/ffmpeg-*/bin/ffmpeg.exe') ?: [];
            foreach ($matches as $match) {
                if (is_file($match)) {
                    return $match;
                }
            }
        }

        return null;
    }

    private static function ffprobePath(): ?string
    {
        $ffmpeg = self::ffmpegPath();
        if ($ffmpeg !== null) {
            $probe = dirname($ffmpeg) . DIRECTORY_SEPARATOR . (PHP_OS_FAMILY === 'Windows' ? 'ffprobe.exe' : 'ffprobe');
            if (is_file($probe)) {
                return $probe;
            }
        }

        $configured = Config::load()['ffprobe'] ?? '';
        if (is_string($configured) && $configured !== '' && is_file($configured)) {
            return $configured;
        }

        $lines = [];
        $code = 0;
        exec('where.exe ffprobe 2>NUL', $lines, $code);
        if ($code === 0) {
            foreach ($lines as $line) {
                $path = trim((string) $line);
                if ($path !== '' && is_file($path)) {
                    return $path;
                }
            }
        }

        return null;
    }

    private static function soundFileName(string $key): string
    {
        $snake = preg_replace('/([a-z0-9])([A-Z])/', '$1_$2', $key) ?? $key;
        return strtolower(str_replace('-', '_', $snake)) . '.mp3';
    }

    private static function gameWebmPath(string $key): string
    {
        return StickerCatalog::repoRoot() . '/Game/panorama/videos/custom_game/' . $key . '.webm';
    }

    private static function previewMp4Path(string $key): string
    {
        return dirname(__DIR__) . '/public/stickers/media/' . $key . '.mp4';
    }

    private static function contentSoundPath(string $soundFile): string
    {
        return StickerCatalog::repoRoot() . '/Content/sounds/wheel/' . $soundFile;
    }

    /** @param array<string, mixed> $entry */
    private static function audioPath(array $entry): ?string
    {
        $file = $entry['sound_file'] ?? null;
        if (!is_string($file) || $file === '') {
            return null;
        }
        $path = self::contentSoundPath($file);
        return is_file($path) ? $path : null;
    }

    private static function ensureDir(string $dir): void
    {
        if (!is_dir($dir) && !mkdir($dir, 0777, true) && !is_dir($dir)) {
            Http::json(500, ['ok' => false, 'error' => 'mkdir_failed', 'dir' => $dir]);
        }
    }

    private static function unlinkIfExists(string $path): void
    {
        if (is_file($path)) {
            @unlink($path);
        }
    }

    private static function removeDir(string $dir): void
    {
        if (!is_dir($dir)) {
            return;
        }
        $items = scandir($dir);
        if (!is_array($items)) {
            return;
        }
        foreach ($items as $item) {
            if ($item === '.' || $item === '..') {
                continue;
            }
            $path = $dir . DIRECTORY_SEPARATOR . $item;
            if (is_dir($path)) {
                self::removeDir($path);
            } else {
                @unlink($path);
            }
        }
        @rmdir($dir);
    }

    private static function formatNumber(float $value): string
    {
        if (abs($value - round($value)) < 0.0001) {
            return (string) (int) round($value);
        }
        $text = rtrim(rtrim(sprintf('%.4f', $value), '0'), '.');
        return $text === '' ? '0' : $text;
    }

    private static function escapeJs(string $value): string
    {
        return str_replace(['\\', '"'], ['\\\\', '\\"'], $value);
    }

    private static function escapeVdf(string $value): string
    {
        return str_replace(['\\', '"'], ['\\\\', '\\"'], $value);
    }
}
