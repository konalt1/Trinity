const WEIGHTS = {
    common: { normal: 100, elite: 10 },
    rare: { normal: 30, elite: 3 },
};

const state = {
    stickers: [],
    selected: null,
    creating: false,
    ffmpeg: true,
    localVideo: null,
    localAudio: null,
    timer: 0,
    waveToken: 0,
    audioBuffer: null,
    audioDuration: 0,
    audioStart: 0,
    audioEnd: 0,
    audioPeaks: null,
    audioDrag: null,
    playheadTime: 0,
};

const els = {
    list: document.getElementById("sticker-list"),
    form: document.getElementById("sticker-form"),
    title: document.getElementById("form-title"),
    key: document.getElementById("field-key"),
    nameRu: document.getElementById("field-name-ru"),
    nameEn: document.getElementById("field-name-en"),
    maxTime: document.getElementById("field-max-time"),
    videoSpeed: document.getElementById("field-video-speed"),
    videoSpeedLabel: document.getElementById("video-speed-label"),
    soundVolume: document.getElementById("field-sound-volume"),
    soundVolumeLabel: document.getElementById("sound-volume-label"),
    rarity: document.getElementById("field-rarity"),
    weightNormal: document.getElementById("field-weight-normal"),
    weightElite: document.getElementById("field-weight-elite"),
    video: document.getElementById("field-video"),
    audio: document.getElementById("field-audio"),
    save: document.getElementById("btn-save"),
    remove: document.getElementById("btn-delete"),
    create: document.getElementById("btn-new"),
    search: document.getElementById("sticker-search"),
    count: document.getElementById("sticker-count"),
    ffmpeg: document.getElementById("ffmpeg-warn"),
    tgs: document.getElementById("tgs-warn"),
    videoHero: document.getElementById("preview-video"),
    lottieHero: document.getElementById("preview-lottie-hero"),
    previewNote: document.getElementById("preview-note"),
    trim: document.getElementById("audio-trim"),
    wave: document.getElementById("audio-wave"),
    waveWrap: document.getElementById("audio-wave-wrap"),
    audioPlay: document.getElementById("btn-audio-play"),
    trimPlayhead: document.getElementById("audio-playhead-time"),
    trimRange: document.getElementById("audio-trim-range"),
    trimMeta: document.getElementById("audio-trim-meta"),
};

let previewAudio = null;
let previewGain = null;
let lottieHero = null;
let tgsData = null;
let audioCtx = null;
let waveRaf = 0;

const TRIM_MIN = 0.2;
const STICKER_MAX = 10;
const HANDLE_PX = 8;
const PLAYHEAD_PX = 12;
const WAVE_PAD = 8;
const VIDEO_SPEED_MIN = 0.25;
const VIDEO_SPEED_MAX = 2;
const SOUND_VOLUME_MIN = 0.1;
const SOUND_VOLUME_MAX = 20;

function isTgsFile(file) {
    return !!(file && /\.tgs$/i.test(file.name || ""));
}

function destroyLottie() {
    if (lottieHero) {
        lottieHero.destroy();
        lottieHero = null;
    }
    tgsData = null;
    els.lottieHero.classList.add("hidden");
    els.lottieHero.innerHTML = "";
}

function hidePreviewVideo() {
    if (!els.videoHero) {
        return;
    }
    els.videoHero.pause();
    els.videoHero.removeAttribute("src");
    try {
        els.videoHero.load();
    } catch (_err) {}
    els.videoHero.classList.add("hidden");
}

function showPreviewVideo(src) {
    destroyLottie();
    if (!els.videoHero) {
        return;
    }
    els.videoHero.classList.remove("hidden");
    if (src) {
        els.videoHero.src = src;
    }
}

async function fileToLottieData(file) {
    const buffer = await file.arrayBuffer();
    try {
        const ds = new DecompressionStream("gzip");
        const stream = new Blob([buffer]).stream().pipeThrough(ds);
        const text = await new Response(stream).text();
        return JSON.parse(text);
    } catch (_err) {
        return JSON.parse(new TextDecoder().decode(buffer));
    }
}

function playLottie(data, loop) {
    if (typeof lottie === "undefined") {
        return;
    }
    destroyLottie();
    tgsData = data;
    els.lottieHero.classList.remove("hidden");
    hidePreviewVideo();
    const opts = {
        renderer: "svg",
        loop: loop,
        autoplay: true,
        animationData: data,
    };
    lottieHero = lottie.loadAnimation(Object.assign({ container: els.lottieHero }, opts));
    applyVideoSpeed();
}

function showStatus(text, ok) {
    Trinity.toast(text, ok);
}

function hideStatus() {
}

els.form.addEventListener("input", () => Trinity.setDirty(true));

function revokeLocal() {
    if (state.localVideo) {
        URL.revokeObjectURL(state.localVideo);
        state.localVideo = null;
    }
    if (state.localAudio) {
        URL.revokeObjectURL(state.localAudio);
        state.localAudio = null;
    }
}

function currentEntry() {
    return state.stickers.find((item) => item.key === state.selected) || null;
}

function videoSrc() {
    if (state.localVideo) {
        return state.localVideo;
    }
    const entry = currentEntry();
    return entry && entry.video_url ? `${entry.video_url}&t=${Date.now()}` : "";
}

function audioSrc() {
    if (state.localAudio) {
        return state.localAudio;
    }
    const entry = currentEntry();
    return entry && entry.audio_url ? `${entry.audio_url}&t=${Date.now()}` : "";
}

function stopPreview(stopAudio) {
    clearTimeout(state.timer);
    if (els.videoHero) {
        els.videoHero.pause();
        try {
            els.videoHero.currentTime = 0;
        } catch (_err) {
            // ignore empty src
        }
    }
    if (lottieHero) {
        lottieHero.goToAndStop(0, true);
    }
    if (stopAudio !== false && previewAudio) {
        previewAudio.pause();
        previewAudio.currentTime = 0;
        previewAudio = null;
        previewGain = null;
        state.playheadTime = state.audioStart;
        updateTrimLabels();
        drawWave();
    }
    if (stopAudio !== false) {
        setTrimPlaying(false);
    }
}

function setTrimPlaying(playing) {
    if (els.audioPlay) {
        els.audioPlay.textContent = playing ? "❚❚" : "▶";
    }
}

function getAudioContext() {
    if (!audioCtx) {
        audioCtx = new AudioContext();
    }
    return audioCtx;
}

function formatClipTime(sec) {
    const safe = Math.max(0, Number(sec) || 0);
    const minutes = Math.floor(safe / 60);
    const remainder = safe - minutes * 60;
    const seconds = Math.floor(remainder);
    const tenth = Math.floor((remainder - seconds) * 10);
    return String(minutes).padStart(2, "0") + ":" + String(seconds).padStart(2, "0") + "." + tenth;
}

function stickerDuration() {
    return Math.max(TRIM_MIN, Math.min(STICKER_MAX, Number(els.maxTime.value) || 1.5));
}

function stickerMaxEnd() {
    return state.audioStart + stickerDuration();
}

function timelineDuration() {
    const end = Math.max(state.audioDuration, stickerMaxEnd());
    return end + Math.min(0.5, Math.max(0.25, end * 0.08));
}

function videoSpeed() {
    const raw = Number(els.videoSpeed && els.videoSpeed.value);
    if (!Number.isFinite(raw)) {
        return 1;
    }
    return Math.max(VIDEO_SPEED_MIN, Math.min(VIDEO_SPEED_MAX, raw));
}

function setVideoSpeed(value) {
    const speed = Math.max(VIDEO_SPEED_MIN, Math.min(VIDEO_SPEED_MAX, Number(value) || 1));
    if (els.videoSpeed) {
        els.videoSpeed.value = String(speed);
    }
    applyVideoSpeed();
}

function applyVideoSpeed() {
    const speed = videoSpeed();
    if (els.videoSpeedLabel) {
        els.videoSpeedLabel.textContent = speed.toFixed(2) + "×";
    }
    if (els.videoHero) {
        els.videoHero.playbackRate = speed;
        els.videoHero.defaultPlaybackRate = speed;
        const wall = isFinite(els.videoHero.duration) && els.videoHero.duration > 0
            ? els.videoHero.duration / speed
            : 0;
        els.videoHero.loop = wall <= 0 || wall < stickerDuration() - 0.03;
    }
    if (lottieHero) {
        lottieHero.setSpeed(speed);
    }
}

function soundVolume() {
    const raw = Number(els.soundVolume && els.soundVolume.value);
    if (!Number.isFinite(raw)) {
        return 1;
    }
    return Math.max(SOUND_VOLUME_MIN, Math.min(SOUND_VOLUME_MAX, raw));
}

function setSoundVolume(value) {
    const volume = Math.max(SOUND_VOLUME_MIN, Math.min(SOUND_VOLUME_MAX, Number(value) || 1));
    if (els.soundVolume) {
        els.soundVolume.value = String(volume);
    }
    applySoundVolume();
}

function applySoundVolume() {
    const volume = soundVolume();
    if (els.soundVolumeLabel) {
        els.soundVolumeLabel.textContent = volume.toFixed(1) + "×";
    }
    if (previewGain) {
        previewGain.gain.value = volume;
    } else if (previewAudio) {
        previewAudio.volume = Math.max(0, Math.min(1, volume));
    }
}

function isAudioPlaying() {
    return !!(previewAudio && !previewAudio.paused && !previewAudio.ended);
}

function currentPlayheadTime() {
    if (isAudioPlaying()) {
        return previewAudio.currentTime;
    }
    return state.playheadTime;
}

function seekPlayhead(time) {
    const maxT = state.audioDuration > 0 ? state.audioDuration : timelineDuration();
    state.playheadTime = Math.max(0, Math.min(time, maxT));
    if (previewAudio) {
        try {
            const limit = isFinite(previewAudio.duration) && previewAudio.duration > 0
                ? previewAudio.duration
                : state.playheadTime;
            previewAudio.currentTime = Math.min(state.playheadTime, limit);
        } catch (_err) {}
    }
    updateTrimLabels();
    drawWave();
}

function resetAudioTrim() {
    state.waveToken += 1;
    state.audioBuffer = null;
    state.audioDuration = 0;
    state.audioStart = 0;
    state.audioEnd = 0;
    state.audioPeaks = null;
    state.audioDrag = null;
    state.playheadTime = 0;
    els.trim.classList.add("hidden");
    setTrimPlaying(false);
    if (els.trimPlayhead) {
        els.trimPlayhead.textContent = "00:00.0";
    }
    els.trimRange.textContent = "00:00.0 – 00:00.0";
    els.trimMeta.textContent = "";
}

function buildPeaks(buffer, bars) {
    const data = buffer.getChannelData(0);
    const size = Math.max(1, Math.floor(data.length / bars));
    const peaks = new Float32Array(bars);
    for (let i = 0; i < bars; i++) {
        let max = 0;
        const from = i * size;
        const to = Math.min(from + size, data.length);
        for (let j = from; j < to; j++) {
            const value = Math.abs(data[j]);
            if (value > max) {
                max = value;
            }
        }
        peaks[i] = max;
    }
    return peaks;
}

function timeToX(time, width) {
    const duration = timelineDuration();
    if (duration <= 0) {
        return WAVE_PAD;
    }
    const inner = Math.max(1, width - WAVE_PAD * 2);
    return WAVE_PAD + (time / duration) * inner;
}

function xToTime(x, width) {
    const duration = timelineDuration();
    if (width <= 0 || duration <= 0) {
        return 0;
    }
    const inner = Math.max(1, width - WAVE_PAD * 2);
    const time = ((x - WAVE_PAD) / inner) * duration;
    if (state.audioDrag === "maxEnd") {
        return Math.max(0, time);
    }
    return Math.max(0, Math.min(duration, time));
}

function drawHandle(ctx, x, height, color) {
    ctx.fillStyle = color;
    ctx.fillRect(x - 1, 0, 2, height);
    ctx.beginPath();
    ctx.moveTo(x, 3);
    ctx.lineTo(x + 5, 11);
    ctx.lineTo(x - 5, 11);
    ctx.closePath();
    ctx.fill();
}

function drawStickerHandle(ctx, x, height, color) {
    const mid = height / 2;
    const triH = 8;
    const triW = 5;
    const apexY = mid - triH / 2;
    const baseY = mid + triH / 2;
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.moveTo(x, apexY);
    ctx.lineTo(x + triW, baseY);
    ctx.lineTo(x - triW, baseY);
    ctx.closePath();
    ctx.fill();
    ctx.fillRect(x - 1, baseY, 2, Math.max(0, height - baseY));
}

function drawPlayhead(ctx, x, height, width) {
    ctx.save();
    ctx.strokeStyle = "#7cf0ff";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x, height);
    ctx.stroke();
    ctx.fillStyle = "#7cf0ff";
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x + 8, 13);
    ctx.lineTo(x - 8, 13);
    ctx.closePath();
    ctx.fill();
    const label = formatClipTime(currentPlayheadTime());
    ctx.font = "12px ui-sans-serif, sans-serif";
    ctx.textBaseline = "top";
    const onRight = x + 52 < width;
    ctx.textAlign = onRight ? "left" : "right";
    ctx.fillText(label, onRight ? x + 10 : x - 10, 2);
    ctx.restore();
}

function updateTrimLabels() {
    if (els.trimPlayhead) {
        els.trimPlayhead.textContent = formatClipTime(currentPlayheadTime());
    }
    els.trimRange.textContent = formatClipTime(state.audioStart) + " – " + formatClipTime(state.audioEnd);
    const kept = Math.max(0, state.audioEnd - state.audioStart);
    els.trimMeta.textContent = "стикер " + stickerDuration().toFixed(1) + "с · файл " + kept.toFixed(1) + "с";
}

function scheduleWave() {
    if (waveRaf) {
        return;
    }
    waveRaf = requestAnimationFrame(() => {
        waveRaf = 0;
        drawWave();
        if (isAudioPlaying()) {
            scheduleWave();
        }
    });
}

function drawWave() {
    const canvas = els.wave;
    if (!canvas || state.audioDuration <= 0) {
        return;
    }
    const dpr = window.devicePixelRatio || 1;
    const cssW = Math.max(1, canvas.clientWidth || els.waveWrap.clientWidth || 1);
    const cssH = Math.max(1, canvas.clientHeight || 96);
    const width = Math.floor(cssW * dpr);
    const height = Math.floor(cssH * dpr);
    if (canvas.width !== width || canvas.height !== height) {
        canvas.width = width;
        canvas.height = height;
    }
    const audioRight = timeToX(state.audioDuration, cssW);
    const barArea = Math.max(1, audioRight - WAVE_PAD);
    const bars = Math.max(32, Math.floor(barArea / 2));
    if ((!state.audioPeaks || state.audioPeaks.length !== bars) && state.audioBuffer) {
        state.audioPeaks = buildPeaks(state.audioBuffer, bars);
    }
    const ctx = canvas.getContext("2d");
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, cssW, cssH);
    ctx.fillStyle = "#0c1730";
    ctx.fillRect(0, 0, cssW, cssH);

    const startX = timeToX(state.audioStart, cssW);
    const endX = timeToX(state.audioEnd, cssW);
    const maxX = timeToX(stickerMaxEnd(), cssW);
    const peaks = state.audioPeaks;
    if (peaks && peaks.length) {
        const barW = barArea / peaks.length;
        const mid = cssH / 2;
        for (let i = 0; i < peaks.length; i++) {
            const center = WAVE_PAD + i * barW + barW / 2;
            const amp = Math.max(2, peaks[i] * (cssH - 8));
            let color = "rgba(62, 214, 176, 0.28)";
            if (center >= startX && center <= endX) {
                color = center <= maxX ? "#3ee6b0" : "rgba(62, 214, 176, 0.72)";
            }
            ctx.fillStyle = color;
            ctx.fillRect(center - Math.max(1, barW * 0.38), mid - amp / 2, Math.max(1, barW * 0.72), amp);
        }
    }

    if (state.audioStart > 0.01) {
        ctx.fillStyle = "rgba(6, 12, 24, 0.55)";
        ctx.fillRect(0, 0, startX, cssH);
    }
    if (state.audioEnd < timelineDuration() - 0.01) {
        ctx.fillStyle = "rgba(6, 12, 24, 0.55)";
        ctx.fillRect(endX, 0, cssW - endX, cssH);
    }
    ctx.fillStyle = "rgba(226, 197, 106, 0.2)";
    ctx.fillRect(startX, 0, Math.max(0, maxX - startX), cssH);

    drawStickerHandle(ctx, startX, cssH, "#e2c56a");
    drawStickerHandle(ctx, maxX, cssH, "#e2c56a");
    drawHandle(ctx, endX, cssH, "#e8eef7");
    drawPlayhead(ctx, timeToX(currentPlayheadTime(), cssW), cssH, cssW);

    if (isAudioPlaying()) {
        state.playheadTime = previewAudio.currentTime;
        updateTrimLabels();
        scheduleWave();
    }
}

function hitHandle(x, width) {
    const handles = [
        { name: "start", x: timeToX(state.audioStart, width) },
        { name: "maxEnd", x: timeToX(stickerMaxEnd(), width) },
        { name: "end", x: timeToX(state.audioEnd, width) },
    ];
    const near = handles
        .map((handle) => ({ name: handle.name, x: handle.x, dist: Math.abs(x - handle.x) }))
        .filter((handle) => handle.dist <= HANDLE_PX)
        .sort((a, b) => a.dist - b.dist);
    if (!near.length) {
        return null;
    }
    if (near.length > 1 && Math.abs(near[0].x - near[1].x) <= 6) {
        const names = near.map((handle) => handle.name);
        if (names.indexOf("maxEnd") !== -1 && names.indexOf("end") !== -1) {
            return x < near[0].x ? "maxEnd" : "end";
        }
    }
    return near[0].name;
}

function hitPlayhead(x, width) {
    return Math.abs(x - timeToX(currentPlayheadTime(), width)) <= PLAYHEAD_PX;
}

function applyDrag(name, time) {
    const minGap = TRIM_MIN;
    if (name === "start") {
        const oldMaxEnd = stickerMaxEnd();
        state.audioStart = Math.max(0, Math.min(time, state.audioEnd - minGap));
        const next = Math.max(TRIM_MIN, Math.min(STICKER_MAX, oldMaxEnd - state.audioStart));
        els.maxTime.value = next.toFixed(1);
        applyVideoSpeed();
    } else if (name === "end") {
        state.audioEnd = Math.max(state.audioStart + minGap, Math.min(time, state.audioDuration));
    } else if (name === "maxEnd") {
        const next = Math.max(TRIM_MIN, Math.min(STICKER_MAX, time - state.audioStart));
        els.maxTime.value = next.toFixed(1);
        applyVideoSpeed();
    }
    updateTrimLabels();
    drawWave();
}

async function loadAudioWave(source) {
    const token = ++state.waveToken;
    state.audioBuffer = null;
    state.audioPeaks = null;
    state.audioDuration = 0;
    if (!source) {
        els.trim.classList.add("hidden");
        return;
    }
    try {
        let bytes;
        if (source instanceof Blob) {
            bytes = await source.arrayBuffer();
        } else {
            const response = await fetch(source);
            if (!response.ok) {
                throw new Error("audio_fetch");
            }
            bytes = await response.arrayBuffer();
        }
        if (token !== state.waveToken) {
            return;
        }
        const decoded = await getAudioContext().decodeAudioData(bytes.slice(0));
        if (token !== state.waveToken) {
            return;
        }
        state.audioBuffer = decoded;
        state.audioDuration = decoded.duration;
        state.audioStart = 0;
        state.audioEnd = decoded.duration;
        state.playheadTime = 0;
        state.audioPeaks = null;
        els.trim.classList.remove("hidden");
        updateTrimLabels();
        requestAnimationFrame(() => requestAnimationFrame(drawWave));
    } catch (_err) {
        if (token === state.waveToken) {
            els.trim.classList.add("hidden");
            showStatus("Не удалось прочитать звук для обрезки", false);
        }
    }
}

function playSound(url) {
    if (previewAudio) {
        previewAudio.pause();
        previewAudio = null;
        previewGain = null;
    }
    if (!url) {
        setTrimPlaying(false);
        showStatus("Нет своего mp3: ванильный звук Dota в браузере не играет", false);
        return Promise.resolve();
    }
    const start = state.audioDuration > 0 ? state.audioStart : 0;
    const stopAt = state.audioDuration > 0 ? state.audioEnd : Infinity;
    let from = start;
    if (state.playheadTime > start + 0.05 && state.playheadTime < stopAt - 0.05) {
        from = state.playheadTime;
    }
    if (audioCtx && audioCtx.state === "suspended") {
        audioCtx.resume().catch(() => {});
    }
    const audio = new Audio(url);
    audio.preload = "auto";
    audio.volume = 1;
    previewAudio = audio;
    try {
        const ctx = getAudioContext();
        const source = ctx.createMediaElementSource(audio);
        previewGain = ctx.createGain();
        previewGain.gain.value = soundVolume();
        source.connect(previewGain);
        previewGain.connect(ctx.destination);
    } catch (_err) {
        previewGain = null;
        audio.volume = Math.max(0, Math.min(1, soundVolume()));
    }

    const finish = () => {
        if (audio !== previewAudio) {
            return;
        }
        audio.pause();
        try {
            audio.currentTime = start;
        } catch (_err) {}
        state.playheadTime = start;
        setTrimPlaying(false);
        updateTrimLabels();
        drawWave();
    };
    audio.addEventListener("timeupdate", () => {
        if (audio !== previewAudio) {
            return;
        }
        state.playheadTime = audio.currentTime;
        updateTrimLabels();
        drawWave();
        if (audio.currentTime >= stopAt - 0.03) {
            finish();
        }
    });
    audio.addEventListener("playing", () => {
        if (audio !== previewAudio) {
            return;
        }
        scheduleWave();
    });
    audio.addEventListener("ended", finish);

    const seekAndPlay = () => {
        try {
            audio.currentTime = from;
        } catch (_err) {}
        state.playheadTime = from;
        setTrimPlaying(true);
        updateTrimLabels();
        drawWave();
        return audio.play().then(() => {
            scheduleWave();
        }).catch((err) => {
            setTrimPlaying(false);
            showStatus("Звук не играет: " + (err && err.message ? err.message : err), false);
        });
    };
    if (audio.readyState >= 1) {
        return seekAndPlay();
    }
    return new Promise((resolve) => {
        audio.addEventListener("loadedmetadata", () => resolve(seekAndPlay()), { once: true });
    });
}

function playPreview(elite) {
    const maxTime = Math.max(0.2, Number(els.maxTime.value) || 1.5);
    const speed = videoSpeed();
    if (tgsData && typeof lottie !== "undefined") {
        stopPreview(true);
        playLottie(tgsData, true);
        applyVideoSpeed();
        if (elite) {
            playSound(audioSrc());
            els.previewNote.textContent = "Плей: TGS + свой mp3";
        } else {
            els.previewNote.textContent = "Только стикер, без звука";
        }
        state.timer = setTimeout(() => stopPreview(false), maxTime * 1000);
        return;
    }
    const src = videoSrc();
    if (!src) {
        showStatus("Нет видео для превью", false);
        return;
    }
    stopPreview(true);
    destroyLottie();
    showPreviewVideo(src);
    els.videoHero.muted = true;
    els.videoHero.playbackRate = speed;
    els.videoHero.defaultPlaybackRate = speed;
    els.videoHero.loop = true;
    els.videoHero.play().catch(() => {});
    applyVideoSpeed();
    if (elite) {
        playSound(audioSrc());
        els.previewNote.textContent = "Плей: стикер + свой mp3";
    } else {
        els.previewNote.textContent = "Только стикер, без звука";
    }
    state.timer = setTimeout(() => stopPreview(false), maxTime * 1000);
}

function fillForm(entry) {
    stopPreview(true);
    destroyLottie();
    revokeLocal();
    Trinity.setDirty(false);
    els.video.value = "";
    els.audio.value = "";
    if (!entry) {
        state.creating = true;
        state.selected = null;
        els.title.textContent = "Новый стикер";
        els.key.disabled = false;
        els.key.value = "";
        els.nameRu.value = "";
        els.nameEn.value = "";
        els.maxTime.value = "1.5";
        setVideoSpeed(1);
        setSoundVolume(1);
        els.rarity.value = "common";
        els.weightNormal.value = "100";
        els.weightElite.value = "10";
        els.remove.classList.add("hidden");
        hidePreviewVideo();
        els.previewNote.textContent = "";
        resetAudioTrim();
        renderList();
        return;
    }

    state.creating = false;
    state.selected = entry.key;
    els.title.textContent = entry.key;
    els.key.disabled = true;
    els.key.value = entry.key;
    els.nameRu.value = entry.name_ru;
    els.nameEn.value = entry.name_en;
    els.maxTime.value = String(entry.max_time);
    setVideoSpeed(1);
    setSoundVolume(entry.sound_volume || 1);
    els.rarity.value = entry.rarity;
    els.weightNormal.value = String(entry.weight_normal);
    els.weightElite.value = String(entry.weight_elite);
    els.remove.classList.remove("hidden");
    showPreviewVideo(videoSrc());
    applyVideoSpeed();
    els.previewNote.textContent = entry.has_audio
        ? ""
        : "У этого стикера ванильный звук Dota, в превью элиты его не будет";
    if (entry.has_audio) {
        loadAudioWave(`${entry.audio_url}&t=${Date.now()}`);
    } else {
        resetAudioTrim();
    }
    renderList();
}

function renderList() {
    const query = ((els.search && els.search.value) || "").trim().toLowerCase();
    const visible = state.stickers.filter((entry) => {
        if (!query) {
            return true;
        }
        return `${entry.key} ${entry.name_ru} ${entry.name_en}`.toLowerCase().includes(query);
    });
    if (els.count) {
        els.count.textContent = visible.length === state.stickers.length
            ? String(state.stickers.length)
            : `${visible.length} из ${state.stickers.length}`;
    }
    els.list.innerHTML = "";
    visible.forEach((entry) => {
        const button = document.createElement("button");
        button.type = "button";
        button.className = "sticker-btn" + (entry.rarity === "rare" ? " rare" : "");
        if (entry.key === state.selected) {
            button.classList.add("active");
        }
        const thumb = document.createElement(entry.video_url ? "video" : "div");
        thumb.className = "thumb";
        if (entry.video_url) {
            thumb.src = entry.video_url;
            thumb.muted = true;
            thumb.playsInline = true;
            thumb.addEventListener("mouseenter", () => {
                thumb.play().catch(() => {});
            });
            thumb.addEventListener("mouseleave", () => {
                thumb.pause();
                try { thumb.currentTime = 0; } catch (_err) {}
            });
        }
        const meta = document.createElement("span");
        meta.className = "meta";
        meta.innerHTML = `<span class="name">${entry.name_ru}</span><span class="key">${entry.key}</span>`;
        button.append(thumb, meta);
        button.addEventListener("click", () => fillForm(entry));
        els.list.appendChild(button);
    });
}

async function loadCatalog() {
    const response = await fetch("/v1/stickers/studio");
    const data = await response.json();
    if (!data.ok) {
        throw new Error(data.error || "load_failed");
    }
    state.stickers = data.stickers || [];
    state.ffmpeg = !!data.ffmpeg;
    state.tgs = !!data.tgs;
    els.ffmpeg.classList.toggle("hidden", state.ffmpeg);
    els.tgs.classList.toggle("hidden", state.tgs);
    if (state.selected) {
        const entry = currentEntry();
        if (entry) {
            fillForm(entry);
            return;
        }
    }
    if (state.stickers[0] && !state.creating) {
        fillForm(state.stickers[0]);
        return;
    }
    renderList();
}

els.maxTime.addEventListener("input", () => {
    applyVideoSpeed();
    updateTrimLabels();
    drawWave();
});

if (els.videoSpeed) {
    els.videoSpeed.addEventListener("input", () => applyVideoSpeed());
}
if (els.soundVolume) {
    els.soundVolume.addEventListener("input", () => applySoundVolume());
}

els.rarity.addEventListener("change", () => {
    const preset = WEIGHTS[els.rarity.value] || WEIGHTS.common;
    els.weightNormal.value = String(preset.normal);
    els.weightElite.value = String(preset.elite);
});

els.video.addEventListener("change", async () => {
    revokeLocal();
    destroyLottie();
    const file = els.video.files && els.video.files[0];
    if (!file) {
        return;
    }
    if (isTgsFile(file)) {
        try {
            const data = await fileToLottieData(file);
            playLottie(data, true);
            els.previewNote.textContent = "TGS: после сохранения станет webm/mp4";
        } catch (_err) {
            showStatus("Не удалось прочитать TGS", false);
        }
        return;
    }
    state.localVideo = URL.createObjectURL(file);
    showPreviewVideo(state.localVideo);
    applyVideoSpeed();
});

els.audio.addEventListener("change", () => {
    if (state.localAudio) {
        URL.revokeObjectURL(state.localAudio);
        state.localAudio = null;
    }
    const file = els.audio.files && els.audio.files[0];
    if (file) {
        state.localAudio = URL.createObjectURL(file);
        loadAudioWave(file);
    } else {
        resetAudioTrim();
    }
});

els.create.addEventListener("click", () => fillForm(null));
if (els.search) {
    els.search.addEventListener("input", renderList);
}
document.getElementById("btn-preview-play").addEventListener("click", () => playPreview(true));
document.getElementById("btn-preview-normal").addEventListener("click", () => playPreview(false));
document.getElementById("btn-preview-sound").addEventListener("click", () => {
    playSound(audioSrc());
});
document.getElementById("btn-preview-stop").addEventListener("click", () => stopPreview(true));
els.audioPlay.addEventListener("click", () => {
    if (previewAudio && !previewAudio.paused) {
        previewAudio.pause();
        state.playheadTime = previewAudio.currentTime;
        setTrimPlaying(false);
        updateTrimLabels();
        drawWave();
        return;
    }
    playSound(audioSrc());
});

if (els.waveWrap) {
    els.waveWrap.addEventListener("pointerdown", (event) => {
        if (state.audioDuration <= 0) {
            return;
        }
        const rect = els.waveWrap.getBoundingClientRect();
        const x = event.clientX - rect.left;
        const handle = hitHandle(x, rect.width);
        event.preventDefault();
        els.waveWrap.setPointerCapture(event.pointerId);
        state.audioDrag = handle || "playhead";
        const time = xToTime(x, rect.width);
        if (state.audioDrag === "playhead") {
            seekPlayhead(time);
        } else {
            applyDrag(handle, time);
        }
    });
    els.waveWrap.addEventListener("pointermove", (event) => {
        const rect = els.waveWrap.getBoundingClientRect();
        const x = event.clientX - rect.left;
        if (state.audioDrag === "playhead") {
            seekPlayhead(xToTime(x, rect.width));
            return;
        }
        if (state.audioDrag) {
            applyDrag(state.audioDrag, xToTime(x, rect.width));
            return;
        }
        els.waveWrap.style.cursor = hitHandle(x, rect.width) || hitPlayhead(x, rect.width)
            ? "ew-resize"
            : "default";
    });
    const endDrag = () => {
        state.audioDrag = null;
    };
    els.waveWrap.addEventListener("pointerup", endDrag);
    els.waveWrap.addEventListener("pointercancel", endDrag);
    new ResizeObserver(() => {
        state.audioPeaks = null;
        drawWave();
    }).observe(els.waveWrap);
}

els.form.addEventListener("submit", async (event) => {
    event.preventDefault();
    hideStatus();
    els.save.disabled = true;
    const body = new FormData(els.form);
    if (els.key.disabled) {
        body.set("key", els.key.value);
    }
    if (state.audioDuration > 0) {
        body.set("audio_start", String(state.audioStart));
        body.set("audio_end", String(state.audioEnd));
    }
    try {
        const response = await fetch("/v1/stickers/studio", { method: "POST", body });
        const data = await response.json();
        if (!data.ok) {
            throw new Error(data.error || data.detail || "save_failed");
        }
        state.creating = false;
        state.selected = data.sticker.key;
        await loadCatalog();
        Trinity.setDirty(false);
        showStatus("Сохранено. Для звука в матче нужен compile в Workshop Tools.", true);
    } catch (err) {
        showStatus(String(err.message || err), false);
    } finally {
        els.save.disabled = false;
    }
});

els.remove.addEventListener("click", async () => {
    const key = els.key.value;
    if (!key || !window.confirm(`Удалить ${key} из коллекции, файлов и инвентарей?`)) {
        return;
    }
    hideStatus();
    try {
        const response = await fetch("/v1/stickers/studio/delete", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ key }),
        });
        const data = await response.json();
        if (!data.ok) {
            throw new Error(data.error || "delete_failed");
        }
        state.selected = null;
        state.creating = true;
        await loadCatalog();
        fillForm(null);
        showStatus(`${key} удалён`, true);
    } catch (err) {
        showStatus(String(err.message || err), false);
    }
});

if (els.videoHero) {
    els.videoHero.addEventListener("loadedmetadata", () => applyVideoSpeed());
}

loadCatalog().catch((err) => showStatus(String(err.message || err), false));
