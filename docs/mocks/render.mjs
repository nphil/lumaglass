// Renders every mock to docs/mocks/shots/*.png at 1920×1080 with the system Chromium.
// Usage: node render.mjs [name ...]   (names from SHOTS below; none = all)
import { chromium } from '/data/home/lucent-ha/node_modules/playwright-core/index.mjs';
import { fileURLToPath } from 'url';
import path from 'path';

const dir = path.dirname(fileURLToPath(import.meta.url));
const SHOTS = [
  ['01-settings-picture', '01-settings-picture.html'],
  ['01-settings-picture-light', '01-settings-picture.html?theme=light'],
  ['02-settings-sound', '02-settings-sound.html'],
  ['03-settings-remote', '03-settings-remote.html'],
  ['04-settings-ai-access', '04-settings-ai-access.html'],
  ['04-settings-ai-access-light', '04-settings-ai-access.html?theme=light'],
  ['05-ai-request-prompt', '05-ai-request-prompt.html'],
  ['06-confirm-dialog', '06-confirm-dialog.html'],
  ['07-toast', '07-toast.html'],
  ['08-input-picker', '08-input-picker.html'],
  ['09-search-keyboard', '09-search-keyboard.html'],
];
const only = process.argv.slice(2);
const browser = await chromium.launch({ executablePath: '/usr/bin/chromium', args: ['--no-sandbox', '--force-device-scale-factor=1'] });
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
const problems = [];
for (const [name, file] of SHOTS) {
  if (only.length && !only.some(o => name.startsWith(o))) continue;
  await page.goto('file://' + path.join(dir, file));
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(80);
  const overflow = await page.evaluate(() => {
    const out = [];
    document.querySelectorAll('.t,.d,.v,.name,.line,.mt,.ms,.tab,.seg>span,.btn,.chip,.sub,h1,p,.k,.a,.q,.e .what').forEach(e => {
      if (e.scrollWidth > e.clientWidth + 1 && getComputedStyle(e).overflow !== 'hidden') out.push(`overflow: "${e.textContent.trim().slice(0, 40)}" ${e.scrollWidth}>${e.clientWidth}`);
      const fs = parseFloat(getComputedStyle(e).fontSize);
      if (e.textContent.trim() && fs < 21) out.push(`small ${fs}px: "${e.textContent.trim().slice(0, 30)}"`);
    });
    const page = document.querySelector('.page-body, .dialog, .sheet');
    if (page && page.scrollHeight > page.clientHeight + 1) out.push(`page overflows vertically ${page.scrollHeight}>${page.clientHeight}`);
    return out;
  });
  if (overflow.length) problems.push(name + ': ' + [...new Set(overflow)].join(' | '));
  await page.screenshot({ path: path.join(dir, 'shots', name + '.png'), type: 'png' });
  console.log('rendered', name);
}
await browser.close();
if (problems.length) { console.log('\nCHECKS:\n' + problems.join('\n')); }
