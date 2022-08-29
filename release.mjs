#!/usr/bin/env zx

function getVersion() {
    const [versionArg] = argv._;

    if (String(versionArg).match(/^\d+\.\d+\.\d+$/)) {
        return versionArg;
    }

    const { version: currentVersion } = YAML.parse(fs.readFileSync('pubspec.yaml', 'utf-8'));
    const [major, minor, patch] = currentVersion.split('.').map(Number);
    switch (versionArg) {
        case 'major':
            return `${major + 1}.0.0`;
        case 'minor':
            return `${major}.${minor + 1}.0`;
        case 'patch':
            return `${major}.${minor}.${patch + 1}`;
        default:
            echo(chalk.red('Invalid version argument!'));
            echo(`USAGE: ./release.mjs [major|minor|patch|X.Y.Z]`);
            process.exit(1);
    }
}

const version = getVersion();

await $`sed -i 's/^version: ".*"/version: "${version}"/' pubspec.yaml`;
await $`git add pubspec.yaml`;
await $`git commit -m "v${version}"`;
await $`git push`;
await $`flutter build apk --release`;

const apkDir = 'build/app/outputs/flutter-apk';
const originalName = 'app-release.apk';
const originalPath = path.join(apkDir, originalName);
const newName = `slides-android-v${version}.apk`;
const newPath = path.join(apkDir, newName);
fs.renameSync(originalPath, newPath);
await $`gh release create v${version} -t 'v${version}' ${newPath}`;
