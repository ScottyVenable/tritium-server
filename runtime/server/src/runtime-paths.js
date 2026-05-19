import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import url from 'node:url';

const __dirname = path.dirname(url.fileURLToPath(import.meta.url));
const DEFAULT_SERVER_ROOT = path.resolve(__dirname, '..');
const DEFAULT_REPO_ROOT = path.resolve(DEFAULT_SERVER_ROOT, '..', '..');
const STAGE_MARKER_NAME = '.tritium-runtime-stage.json';

function normalizePath(targetPath) {
  return path.resolve(targetPath).replace(/\\/g, '/');
}

function getRepoKey(repoRoot) {
  return crypto.createHash('sha256').update(normalizePath(repoRoot)).digest('hex').slice(0, 16);
}

function readJsonFile(filePath) {
  if (!fs.existsSync(filePath)) {
    return null;
  }
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch {
    return null;
  }
}

function getStageMarker(serverRoot = getServerRoot()) {
  return readJsonFile(path.join(serverRoot, STAGE_MARKER_NAME));
}

export function getServerRoot() {
  if (process.env.TRITIUM_RUNTIME_SERVER_ROOT) {
    return path.resolve(process.env.TRITIUM_RUNTIME_SERVER_ROOT);
  }
  return DEFAULT_SERVER_ROOT;
}

export function getRepoRoot() {
  if (process.env.TRITIUM_REPO_ROOT) {
    return path.resolve(process.env.TRITIUM_REPO_ROOT);
  }
  const stageMarker = getStageMarker(DEFAULT_SERVER_ROOT);
  if (stageMarker?.repoRoot) {
    return path.resolve(stageMarker.repoRoot);
  }
  return DEFAULT_REPO_ROOT;
}

export function getRepoServerRoot(repoRoot = getRepoRoot()) {
  return path.join(repoRoot, 'runtime', 'server');
}

export function getTritiumHome() {
  return process.env.TRITIUM_HOME
    ? path.resolve(process.env.TRITIUM_HOME)
    : path.join(os.homedir(), '.tritium-os');
}

export function isSharedStoragePath(targetPath) {
  const normalized = normalizePath(targetPath);
  return normalized.startsWith('/storage/')
    || normalized.startsWith('/sdcard/')
    || normalized.startsWith('/mnt/sdcard/');
}

export function probeSymlinkSupport(targetDir) {
  if (!fs.existsSync(targetDir)) {
    return false;
  }

  let probeDir = null;
  try {
    probeDir = fs.mkdtempSync(path.join(targetDir, '.tritium-symlink-probe-'));
    const targetFile = path.join(probeDir, 'target');
    const linkFile = path.join(probeDir, 'link');
    fs.writeFileSync(targetFile, 'ok\n');
    fs.symlinkSync(targetFile, linkFile);
    return fs.lstatSync(linkFile).isSymbolicLink();
  } catch {
    return false;
  } finally {
    if (probeDir) {
      fs.rmSync(probeDir, { recursive: true, force: true });
    }
  }
}

export function getRuntimeStageRecordPath(repoRoot = getRepoRoot()) {
  return path.join(getTritiumHome(), 'state', 'runtime-deps', `${getRepoKey(repoRoot)}.json`);
}

export function getRuntimeStageRoot(repoRoot = getRepoRoot()) {
  return path.join(getTritiumHome(), 'runtime-server', getRepoKey(repoRoot));
}

export function getPackageLockHash(serverRoot = getRepoServerRoot()) {
  const lockfile = path.join(serverRoot, 'package-lock.json');
  if (!fs.existsSync(lockfile)) {
    return null;
  }
  return crypto.createHash('sha256').update(fs.readFileSync(lockfile)).digest('hex');
}

export function readRuntimeStageRecord(repoRoot = getRepoRoot()) {
  const record = readJsonFile(getRuntimeStageRecordPath(repoRoot));
  if (!record?.stageRoot || !record?.repoRoot) {
    return null;
  }
  if (path.resolve(record.repoRoot) !== path.resolve(repoRoot)) {
    return null;
  }
  return record;
}

function hasStagePackage(serverRoot) {
  return fs.existsSync(path.join(serverRoot, 'package.json'));
}

export function getRuntimeLocation(repoRoot = getRepoRoot()) {
  const repoServerRoot = getRepoServerRoot(repoRoot);
  const currentServerRoot = getServerRoot();
  const stageRecord = readRuntimeStageRecord(repoRoot);
  const stageMarker = getStageMarker(currentServerRoot);
  const currentLockHash = getPackageLockHash(repoServerRoot);
  const sharedStorage = isSharedStoragePath(repoRoot);
  const symlinksSupported = probeSymlinkSupport(repoServerRoot);
  const needsWorkaround = sharedStorage || !symlinksSupported;

  const recordedStageRoot = stageRecord?.stageRoot
    ? path.resolve(stageRecord.stageRoot)
    : getRuntimeStageRoot(repoRoot);
  const runningFromStage = stageMarker?.stageRoot
    && path.resolve(stageMarker.stageRoot) === path.resolve(currentServerRoot);
  const stageRoot = runningFromStage
    ? path.resolve(currentServerRoot)
    : recordedStageRoot;
  const stageLockHash = stageMarker?.lockHash ?? stageRecord?.lockHash ?? null;
  const stageFresh = Boolean(
    stageRoot
      && currentLockHash
      && stageLockHash
      && currentLockHash === stageLockHash
      && hasStagePackage(stageRoot)
  );

  return {
    repoRoot,
    repoServerRoot,
    serverRoot: runningFromStage ? currentServerRoot : (stageFresh ? stageRoot : repoServerRoot),
    stageRoot,
    stageFresh,
    stageRecord,
    currentLockHash,
    sharedStorage,
    symlinksSupported,
    needsWorkaround,
    runningFromStage,
    stageActive: runningFromStage || stageFresh,
  };
}
