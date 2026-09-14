#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// Read appinfo.json
const repoRoot = path.resolve(__dirname, '..');
const appinfoPath = path.join(repoRoot, 'appinfo.json');
const appinfo = JSON.parse(fs.readFileSync(appinfoPath, 'utf8'));

const version = appinfo.version;
const id = appinfo.id;

// Get IPK path from arguments
if (process.argv.length < 3) {
    console.error('Usage: gen-manifest.js <ipk-path> [output-file]');
    process.exit(1);
}

const ipkPath = process.argv[2];
const outputFile = process.argv[3] || null;

// Verify IPK exists
if (!fs.existsSync(ipkPath)) {
    console.error(`Error: IPK not found: ${ipkPath}`);
    process.exit(1);
}

// Compute SHA256 hash of IPK
const fileBuffer = fs.readFileSync(ipkPath);
const hashSum = crypto.createHash('sha256');
hashSum.update(fileBuffer);
const sha256 = hashSum.digest('hex');

// Construct manifest
const ipkFilename = path.basename(ipkPath);
const ipkUrl = `https://github.com/nphil/lumaglass/releases/download/v${version}/${ipkFilename}`;
const iconUri = 'https://raw.githubusercontent.com/nphil/lumaglass/main/assets/icon160.png';
const sourceUrl = 'https://github.com/nphil/lumaglass';

const manifest = {
    id,
    version,
    type: 'web',
    title: appinfo.title,
    appDescription: appinfo.appDescription,
    iconUri,
    sourceUrl,
    rootRequired: true,
    ipkUrl,
    ipkHash: {
        sha256
    }
};

// Output
const output = JSON.stringify(manifest, null, 2);

if (outputFile) {
    fs.writeFileSync(outputFile, output + '\n', 'utf8');
    console.log(`Generated: ${outputFile}`);
    console.log(`  Version: ${version}`);
    console.log(`  SHA256: ${sha256}`);
} else {
    console.log(output);
}
