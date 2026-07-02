/**
 * Этот скрипт создаёт junction-ссылки (аналог симлинков для папок в Windows)
 * из папок Content и Game этого репозитория в папки аддона внутри Dota 2:
 *   <Dota 2>\content\dota_addons\trinity -> Content
 *   <Dota 2>\game\dota_addons\trinity    -> Game
 *
 * Зачем: чтобы Dota 2 (Workshop Tools) видела аддон как часть своей игры,
 * а сами файлы при этом оставались в этом git-репозитории и не копировались.
 *
 * Как пользоваться:
 *   node setup.js
 * Скрипт сам попробует найти путь к Dota 2 через реестр Steam. Если не
 * найдёт - укажите путь вручную одним из способов:
 *   node setup.js "F:\SteamLibrary\steamapps\common\dota 2 beta"
 *   DOTA2_PATH="F:\SteamLibrary\steamapps\common\dota 2 beta" node setup.js
 *
 * Скрипт безопасен для повторного запуска: уже существующие правильные
 * ссылки не трогает, а если на месте ссылки лежит что-то другое - просто
 * предупреждает и ничего не удаляет.
 */

'use strict';

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const ADDON_NAME = 'trinity';
const REPO_ROOT = __dirname;
const LINKS = [
  { source: path.join(REPO_ROOT, 'Content'), kind: 'content' },
  { source: path.join(REPO_ROOT, 'Game'), kind: 'game' },
];

function findSteamPath() {
  try {
    const out = execSync('reg query "HKCU\\Software\\Valve\\Steam" /v SteamPath', { encoding: 'utf8' });
    const match = out.match(/SteamPath\s+REG_SZ\s+(.+)/i);
    if (match) return match[1].trim().replace(/\//g, '\\');
  } catch (_) {}
  return null;
}

function findLibraryPaths(steamPath) {
  const libs = new Set();
  if (steamPath) libs.add(steamPath);

  const vdf = steamPath && path.join(steamPath, 'steamapps', 'libraryfolders.vdf');
  if (vdf && fs.existsSync(vdf)) {
    const text = fs.readFileSync(vdf, 'utf8');
    const re = /"path"\s+"([^"]+)"/g;
    let m;
    while ((m = re.exec(text))) libs.add(m[1].replace(/\\\\/g, '\\'));
  }
  return [...libs];
}

function findDota2Path() {
  if (process.argv[2]) return process.argv[2];
  if (process.env.DOTA2_PATH) return process.env.DOTA2_PATH;

  for (const lib of findLibraryPaths(findSteamPath())) {
    const candidate = path.join(lib, 'steamapps', 'common', 'dota 2 beta');
    if (fs.existsSync(candidate)) return candidate;
  }
  return null;
}

function ensureLink(dota2Path, source, kind) {
  const target = path.join(dota2Path, kind, 'dota_addons', ADDON_NAME);

  if (!fs.existsSync(source)) {
    console.log(`[skip] ${source} not found`);
    return;
  }

  fs.mkdirSync(path.dirname(target), { recursive: true });

  let stat;
  try {
    stat = fs.lstatSync(target);
  } catch (_) {
    stat = null;
  }

  if (stat) {
    if (stat.isSymbolicLink()) {
      let real = null;
      try { real = fs.realpathSync(target); } catch (_) {}
      if (real === fs.realpathSync(source)) {
        console.log(`[ok] ${target} already linked`);
        return;
      }
      console.log(`[skip] ${target} points elsewhere (or is broken) - remove it manually and re-run`);
      return;
    }
    console.log(`[skip] ${target} already exists and is not a link - remove it manually and re-run`);
    return;
  }

  fs.symlinkSync(source, target, 'junction');
  console.log(`[+] ${target} -> ${source}`);
}

if (process.platform !== 'win32') {
  console.error('This script creates NTFS junctions and only runs on Windows.');
  process.exit(1);
}

const dota2Path = findDota2Path();
if (!dota2Path || !fs.existsSync(dota2Path)) {
  console.error('Could not locate the Dota 2 installation.');
  console.error('Pass the path explicitly: node setup.js "F:\\SteamLibrary\\steamapps\\common\\dota 2 beta"');
  process.exit(1);
}

console.log(`Dota 2 path: ${dota2Path}`);
for (const { source, kind } of LINKS) ensureLink(dota2Path, source, kind);
