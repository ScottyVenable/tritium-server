import fs from 'node:fs';
import path from 'node:path';
import url from 'node:url';
import { createRequire } from 'node:module';
import { getRepoRoot, getRuntimeLocation } from './runtime-paths.js';

const __dirname = path.dirname(url.fileURLToPath(import.meta.url));
const REQUIRED_PACKAGES = ['ws', 'better-sqlite3'];

function findMissingPackages(serverRoot) {
  const requireFromServer = createRequire(path.join(serverRoot, 'package.json'));
  const missing = [];
  for (const name of REQUIRED_PACKAGES) {
    try {
      requireFromServer.resolve(`${name}/package.json`);
    } catch {
      missing.push(name);
    }
  }
  return missing;
}

export function checkRuntimeInstall(repoRoot = getRepoRoot()) {
  const location = getRuntimeLocation(repoRoot);
  const nodeModulesDir = path.join(location.serverRoot, 'node_modules');
  const missingPackages = fs.existsSync(path.join(location.serverRoot, 'package.json'))
    ? findMissingPackages(location.serverRoot)
    : REQUIRED_PACKAGES.slice();
  const usingRepoInstall = path.resolve(location.serverRoot) === path.resolve(location.repoServerRoot);

  return {
    ok: missingPackages.length === 0 && (!location.needsWorkaround || (!usingRepoInstall && location.stageFresh)),
    ...location,
    nodeModulesPresent: fs.existsSync(nodeModulesDir),
    missingPackages,
  };
}

export function formatRuntimeInstallHelp(result) {
  const lines = [
    result.needsWorkaround
      ? 'error: Tritium runtime staging is required here, but the staged runtime is missing, stale, or incomplete.'
      : `error: Tritium runtime dependencies are not installed or not loadable from ${result.serverRoot}.`,
  ];

  if (result.needsWorkaround && !result.stageFresh) {
    lines.push(`expected staged runtime: ${result.stageRoot}`);
  }

  if (!result.nodeModulesPresent && !result.needsWorkaround) {
    lines.push('node_modules/ is missing.');
  } else if (result.missingPackages.length > 0) {
    lines.push(`missing packages: ${result.missingPackages.join(', ')}`);
  }

  if (result.needsWorkaround) {
    lines.push(
      'run:',
      '  bash scripts/runtime-deps.sh ensure',
      '  cd runtime/server',
      '  npm run doctor',
      '',
      'Tritium will stage runtime/server under ~/.tritium-os/ on Linux-native storage,',
      'run npm ci there, and use that staged path for doctor / serve.'
    );
    if (result.sharedStorage) {
      lines.push(
        '',
        'This checkout appears to be on Android/shared storage.',
        'npm needs to create node_modules/.bin symlinks there, and that often fails with:',
        '  EACCES: permission denied, symlink ... node_modules/.bin/...'
      );
    } else if (!result.symlinksSupported) {
      lines.push(
        '',
        'This filesystem failed a symlink probe inside runtime/server.',
        'The staged workaround avoids running npm ci on that path.'
      );
    }
  } else {
    lines.push(
      'run:',
      '  cd runtime/server',
      '  npm ci'
    );
  }

  lines.push(
    '',
    'If better-sqlite3 later reports a binary mismatch, run:',
    '  npm rebuild better-sqlite3'
  );

  return lines.join('\n');
}

if (import.meta.url === url.pathToFileURL(process.argv[1] ?? '').href) {
  const result = checkRuntimeInstall();
  if (result.ok) {
    const mode = result.stageActive ? `staged runtime ${result.serverRoot}` : result.serverRoot;
    console.log(`[tritium] runtime preflight OK (${REQUIRED_PACKAGES.join(', ')}) via ${mode}`);
    process.exit(0);
  }

  console.error(formatRuntimeInstallHelp(result));
  process.exit(2);
}
