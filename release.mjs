#!/usr/bin/env zx

const pubspecPath = 'pubspec.yaml';

function getCurrentVersion() {
    const { version: currentVersion } = YAML.parse(fs.readFileSync(pubspecPath, 'utf-8'));

    return currentVersion;
}

function bumpVersion(currentVersion, segmentToBump) {
    const [major, minor, patch, build] = currentVersion.split(/[\.+]/).map(Number);
    switch (segmentToBump) {
        case 'major':
            return `${major + 1}.0.0+${build + 1}`;
        case 'minor':
            return `${major}.${minor + 1}.0+${build + 1}`;
        case 'patch':
            return `${major}.${minor}.${patch + 1}+${build + 1}`;
        default:
            echo(chalk.red('Invalid version argument!'));
            echo(`USAGE: ./release.mjs [major|minor|patch]`);
            process.exit(1);
    }
}

function updateVersion(currentVersion, newVersion) {
    const pubspecContent = fs.readFileSync(pubspecPath, 'utf-8');
    const updatedPubspecContent = pubspecContent.replace(
        `version: "${currentVersion}"`,
        `version: "${newVersion}"`
    );
    fs.writeFileSync(pubspecPath, updatedPubspecContent);
}

const prevVersion = getCurrentVersion();
const [segmentToBump] = argv._;
const versionWithBuild = bumpVersion(prevVersion, segmentToBump);
updateVersion(prevVersion, versionWithBuild);

const [version] = versionWithBuild.split('+');

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
await $`gh release create --draft v${version} -t 'v${version}' ${newPath}`;
