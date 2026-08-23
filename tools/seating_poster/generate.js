const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');
const puppeteer = require('puppeteer-core');
const QRCode = require('qrcode');

const projectRoot = path.resolve(__dirname, '..', '..');
const outputPdf = path.join(projectRoot, 'Sitzplan_A1_Landschaft.pdf');
const outputPreview = path.join(projectRoot, 'Sitzplan_A1_Vorschau.png');
const outputQrSvg = path.join(projectRoot, 'Sitzplan_QR_Code.svg');
const outputQrPng = path.join(projectRoot, 'Sitzplan_QR_Code.png');
const seatingUrl = 'https://andi-amo.github.io/hochzeitmariandi/#/seating';

function readFirebaseConfig() {
  const optionsPath = path.join(projectRoot, 'lib', 'firebase_options.dart');
  const source = fs.readFileSync(optionsPath, 'utf8');
  const webBlock = source.match(
    /static const FirebaseOptions web = FirebaseOptions\(([\s\S]*?)\);/,
  )?.[1];
  const apiKey = webBlock?.match(/apiKey:\s*'([^']+)'/)?.[1];
  const projectId = webBlock?.match(/projectId:\s*'([^']+)'/)?.[1];

  if (!apiKey || !projectId) {
    throw new Error('Could not read the web Firebase configuration.');
  }
  return { apiKey, projectId };
}

async function fetchGuests() {
  const { apiKey, projectId } = readFirebaseConfig();
  const authResponse = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ returnSecureToken: true }),
    },
  );
  if (!authResponse.ok) {
    throw new Error(`Anonymous Firebase sign-in failed (${authResponse.status}).`);
  }

  const auth = await authResponse.json();
  const documents = [];

  try {
    let pageToken = '';
    do {
      const query = new URLSearchParams({ pageSize: '300', key: apiKey });
      if (pageToken) query.set('pageToken', pageToken);
      const response = await fetch(
        `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/guests?${query}`,
        { headers: { Authorization: `Bearer ${auth.idToken}` } },
      );
      if (!response.ok) {
        throw new Error(`Guest download failed (${response.status}).`);
      }
      const page = await response.json();
      documents.push(...(page.documents ?? []));
      pageToken = page.nextPageToken ?? '';
    } while (pageToken);
  } finally {
    await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ idToken: auth.idToken }),
      },
    );
  }

  return documents;
}

function value(field) {
  if (!field) return null;
  return (
    field.stringValue ??
    field.integerValue ??
    field.booleanValue ??
    field.doubleValue ??
    null
  );
}

function buildTables(documents) {
  const tables = new Map(
    Array.from({ length: 9 }, (_, index) => [index + 1, []]),
  );

  for (const document of documents) {
    const fields = document.fields ?? {};
    if (value(fields.rsvpStatus) !== 'attending') continue;

    const table = Number(value(fields.tableId));
    const seat = Number(value(fields.seat));
    if (!tables.has(table) || !Number.isInteger(seat) || seat < 1) continue;

    tables.get(table).push({
      firstName: String(value(fields.firstName) ?? '').trim(),
      lastName: String(value(fields.lastName) ?? '').trim(),
      seat,
    });
  }

  for (const guests of tables.values()) {
    guests.sort((a, b) => a.seat - b.seat);
  }
  return tables;
}

function escapeXml(text) {
  return String(text)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
}

function fittedLine(text, y) {
  const safe = escapeXml(text || '\u00A0');
  const estimatedWidth = Math.max(1, String(text).length * 5.8);
  const fit =
    estimatedWidth > 40
      ? ' textLength="40" lengthAdjust="spacingAndGlyphs"'
      : '';
  return `<text x="0" y="${y}" text-anchor="middle" class="seat-name"${fit}>${safe}</text>`;
}

function seat(guest, x, y) {
  if (!guest) return '';
  return `
    <g transform="translate(${x.toFixed(2)} ${y.toFixed(2)})">
      <circle r="23" class="seat"/>
      ${fittedLine(guest.firstName, -2)}
      ${fittedLine(guest.lastName, 10)}
    </g>`;
}

function guestAt(tables, tableNumber, seatNumber) {
  return tables
    .get(tableNumber)
    .find((guest) => guest.seat === seatNumber);
}

function guestsAt(tables, tableNumber, seatNumbers) {
  return seatNumbers
    .map((seatNumber) => guestAt(tables, tableNumber, seatNumber))
    .filter(Boolean);
}

function distributedValues(count, start, end) {
  if (count === 0) return [];
  if (count === 1) return [(start + end) / 2];
  return Array.from(
    { length: count },
    (_, index) => start + ((end - start) * index) / (count - 1),
  );
}

function rotatePoint(cx, cy, dx, dy, angleDegrees) {
  const angle = (angleDegrees * Math.PI) / 180;
  return {
    x: cx + dx * Math.cos(angle) - dy * Math.sin(angle),
    y: cy + dx * Math.sin(angle) + dy * Math.cos(angle),
  };
}

function normalTable(tables, tableNumber, cx, cy, angleDegrees) {
  const horizontalSide = (seatNumbers, y) => {
    const guests = guestsAt(tables, tableNumber, seatNumbers);
    const positions = distributedValues(guests.length, -48, 48);
    return guests.map((guest, index) => {
      const point = rotatePoint(cx, cy, positions[index], y, angleDegrees);
      return seat(guest, point.x, point.y);
    });
  };
  const verticalSide = (seatNumbers, x) => {
    const guests = guestsAt(tables, tableNumber, seatNumbers);
    const positions = distributedValues(guests.length, -26, 26);
    return guests.map((guest, index) => {
      const point = rotatePoint(cx, cy, x, positions[index], angleDegrees);
      return seat(guest, point.x, point.y);
    });
  };

  const chairs = [
    ...horizontalSide([1, 2, 3], -65),
    ...verticalSide([4, 5], -90),
    ...verticalSide([6, 7], 90),
    ...horizontalSide([8, 9, 10], 65),
  ].join('');

  return `
    <g>
      <rect x="${cx - 67.5}" y="${cy - 35}" width="135" height="70" rx="9"
        class="table" transform="rotate(${angleDegrees} ${cx} ${cy})"/>
      ${chairs}
      <text x="${cx}" y="${cy + 8}" text-anchor="middle" class="table-label">Tisch ${tableNumber}</text>
    </g>`;
}

function longTable(tables, tableNumber, cx, cy) {
  const horizontalSide = (seatNumbers, y) => {
    const guests = guestsAt(tables, tableNumber, seatNumbers);
    const positions = distributedValues(guests.length, -135, 135);
    return guests.map((guest, index) =>
      seat(guest, cx + positions[index], cy + y),
    );
  };
  const verticalSide = (seatNumbers, x) => {
    const guests = guestsAt(tables, tableNumber, seatNumbers);
    const positions = distributedValues(guests.length, -25, 25);
    return guests.map((guest, index) =>
      seat(guest, cx + x, cy + positions[index]),
    );
  };

  const chairs = [
    ...horizontalSide([1, 2, 3, 4, 5, 6], -72),
    ...verticalSide([7, 8], -190),
    ...verticalSide([9, 10], 190),
    ...horizontalSide([11, 12, 13, 14, 15, 16], 72),
  ].join('');

  return `
    <g>
      <rect x="${cx - 155}" y="${cy - 43}" width="310" height="86" rx="10" class="table"/>
      ${chairs}
      <text x="${cx}" y="${cy + 9}" text-anchor="middle" class="table-label long-label">Tisch ${tableNumber}</text>
    </g>`;
}

function qrArtwork(qr) {
  const size = qr.modules.size;
  const quietZone = 4;
  const total = size + quietZone * 2;
  const modules = [];

  for (let row = 0; row < size; row += 1) {
    for (let column = 0; column < size; column += 1) {
      if (qr.modules.get(row, column)) {
        modules.push(
          `<rect x="${column + quietZone}" y="${row + quietZone}" width="1" height="1"/>`,
        );
      }
    }
  }

  return `
    <g transform="translate(116 235)">
      <rect x="-18" y="-18" width="440" height="166" rx="22" class="qr-card"/>
      <circle cx="388" cy="22" r="18" class="qr-heart"/>
      <text x="388" y="30" text-anchor="middle" font-size="23" fill="#ffffff">♥</text>
      <rect width="130" height="130" rx="10" fill="#ffffff"/>
      <svg x="5" y="5" width="120" height="120" viewBox="0 0 ${total} ${total}">
        <g fill="#3f5147">${modules.join('')}</g>
      </svg>
      <text x="154" y="44" class="qr-heading">SITZPLAN ONLINE</text>
      <text x="154" y="73" class="qr-copy">Scannen &amp; den digitalen</text>
      <text x="154" y="97" class="qr-copy">Sitzplan direkt öffnen</text>
      <path d="M154 116 H355" class="gold-rule"/>
    </g>`;
}

function ivyLeaf(x, y, scale, rotation, light = false) {
  return `
    <g transform="translate(${x} ${y}) rotate(${rotation}) scale(${scale})">
      <path d="M0 15 C-1 10 -3 6 -8 5 C-15 3 -17 -3 -12 -8
        C-9 -11 -5 -8 -3 -12 C-1 -17 2 -17 5 -12
        C7 -8 11 -11 14 -8 C19 -3 16 3 9 5 C4 6 2 11 0 15Z"
        class="${light ? 'ivy-leaf-light' : 'ivy-leaf'}"/>
      <path d="M0 14 C0 7 0 -1 1 -10 M0 4 L-8 -5 M1 3 L10 -5"
        class="ivy-vein"/>
      <path d="M0 14 L0 21" class="ivy-stem"/>
    </g>`;
}

function blossom(x, y, scale, rotation, ivory = false) {
  const petalClass = ivory ? 'petal-ivory' : 'petal-rose';
  return `
    <g transform="translate(${x} ${y}) rotate(${rotation}) scale(${scale})">
      <ellipse cx="0" cy="-8" rx="5" ry="9" class="${petalClass}"/>
      <ellipse cx="7.6" cy="-2.4" rx="5" ry="9" transform="rotate(72 7.6 -2.4)"
        class="${petalClass}"/>
      <ellipse cx="4.7" cy="6.5" rx="5" ry="9" transform="rotate(144 4.7 6.5)"
        class="${petalClass}"/>
      <ellipse cx="-4.7" cy="6.5" rx="5" ry="9" transform="rotate(216 -4.7 6.5)"
        class="${petalClass}"/>
      <ellipse cx="-7.6" cy="-2.4" rx="5" ry="9" transform="rotate(288 -7.6 -2.4)"
        class="${petalClass}"/>
      <circle r="4" class="blossom-center"/>
    </g>`;
}

function headerIvy() {
  const leaves = [
    ivyLeaf(42, 77, 1.05, -58),
    ivyLeaf(80, 52, 0.86, -42, true),
    ivyLeaf(120, 35, 1.16, -26),
    ivyLeaf(166, 31, 0.78, -8, true),
    ivyLeaf(207, 43, 1.02, 17),
    ivyLeaf(242, 65, 0.72, 35, true),
  ].join('');

  const vine = `
    <path d="M0 108 C60 60 125 19 250 71" class="ivy-stem"/>
    <path d="M74 54 C53 29 76 17 91 28 C104 38 92 52 82 42"
      class="ivy-tendril"/>
    <path d="M188 36 C205 9 229 17 224 34 C221 46 207 43 211 32"
      class="ivy-tendril"/>
    ${leaves}
    ${blossom(101, 49, 0.72, -12)}
    ${blossom(222, 53, 0.52, 18, true)}
    <circle cx="255" cy="73" r="6" class="berry"/>
    <circle cx="267" cy="68" r="4" class="berry-light"/>`;

  return `
    <g transform="translate(488 10)">${vine}</g>
    <g transform="translate(1194 10) scale(-1 1)">${vine}</g>`;
}

function cornerIvy() {
  const leaves = [
    ivyLeaf(34, 10, 0.9, -76),
    ivyLeaf(67, -3, 1.12, -44, true),
    ivyLeaf(105, -6, 0.78, -15),
    ivyLeaf(140, 4, 1.02, 21, true),
    ivyLeaf(166, 28, 0.72, 48),
    ivyLeaf(174, 61, 0.92, 83, true),
  ].join('');

  const vine = `
    <path d="M0 37 C45 -13 103 -25 151 5 C176 21 184 49 176 85"
      class="ivy-stem"/>
    <path d="M105 -4 C121 -29 144 -23 143 -7 C142 6 127 8 129 -5"
      class="ivy-tendril"/>
    <path d="M174 51 C199 41 208 61 197 72 C188 80 179 71 189 65"
      class="ivy-tendril"/>
    ${leaves}
    ${blossom(88, -4, 0.68, -15, true)}
    ${blossom(151, 13, 0.58, 24)}
    <circle cx="174" cy="88" r="6" class="berry"/>
    <circle cx="187" cy="91" r="4" class="berry-light"/>`;

  return `
    <g transform="translate(74 982)">${vine}</g>
    <g transform="translate(1608 982) scale(-1 1)">${vine}</g>`;
}

function embeddedFont(fontPath) {
  return fs.readFileSync(fontPath).toString('base64');
}

function posterHtml(tables, qr) {
  const gabriola = embeddedFont('C:\\Windows\\Fonts\\Gabriola.ttf');
  const georgiaItalic = embeddedFont('C:\\Windows\\Fonts\\georgiaz.ttf');
  const topY = 430;
  const bottomY = 805;
  const columns = [680, 930, 1180, 1430];
  const artwork = [
    normalTable(tables, 7, columns[0], topY, -60),
    normalTable(tables, 5, columns[1], topY, -60),
    normalTable(tables, 3, columns[2], topY, -60),
    normalTable(tables, 1, columns[3], topY, -60),
    longTable(tables, 9, 310, bottomY),
    normalTable(tables, 8, columns[0], bottomY, 60),
    normalTable(tables, 6, columns[1], bottomY, 60),
    normalTable(tables, 4, columns[2], bottomY, 60),
    normalTable(tables, 2, columns[3], bottomY, 60),
  ].join('');

  return `<!doctype html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <title>Sitzplan – Hochzeit von Mariandi</title>
  <style>
    @font-face {
      font-family: "Poster Gabriola";
      src: url(data:font/ttf;base64,${gabriola}) format("truetype");
      font-style: normal;
      font-weight: 400;
    }
    @font-face {
      font-family: "Poster Georgia";
      src: url(data:font/ttf;base64,${georgiaItalic}) format("truetype");
      font-style: italic;
      font-weight: 700;
    }
    @page { size: 841mm 594mm; margin: 0; }
    html, body {
      width: 841mm;
      height: 594mm;
      margin: 0;
      overflow: hidden;
      background: #fbf7f1;
    }
    svg {
      display: block;
      width: 841mm;
      height: 594mm;
      font-family: Arial, Helvetica, sans-serif;
      text-rendering: geometricPrecision;
    }
    .room { fill: url(#roomGradient); stroke: #738376; stroke-width: 3; }
    .room-inner { fill: none; stroke: #c7ad7e; stroke-width: 1.5; }
    .table {
      fill: url(#tableGradient);
      stroke: #9f6757;
      stroke-width: 3;
      filter: url(#softShadow);
    }
    .seat {
      fill: url(#seatGradient);
      stroke: #718075;
      stroke-width: 1.8;
    }
    .seat-name {
      fill: #3f5749;
      font-family: "Poster Georgia", Georgia, serif;
      font-size: 10.5px;
      font-style: italic;
      font-weight: 700;
    }
    .table-label {
      fill: #754b46;
      font-family: "Poster Gabriola", Gabriola, Georgia, serif;
      font-size: 30px;
      font-weight: 400;
    }
    .long-label { font-size: 36px; }
    .qr-card {
      fill: #fffdf9;
      stroke: #c7ad7e;
      stroke-width: 2;
      filter: url(#softShadow);
    }
    .qr-heart { fill: #b9786c; }
    .qr-heading { fill: #465a4e; font-size: 18px; font-weight: 700; letter-spacing: 1px; }
    .qr-copy { fill: #75665e; font-size: 15px; }
    .gold-rule { fill: none; stroke: #c7ad7e; stroke-width: 2; }
    .ivy-stem {
      fill: none;
      stroke: #657c68;
      stroke-width: 2;
      stroke-linecap: round;
      stroke-linejoin: round;
    }
    .ivy-tendril {
      fill: none;
      stroke: #839783;
      stroke-width: 1.3;
      stroke-linecap: round;
    }
    .ivy-leaf { fill: #71876f; stroke: #586e5d; stroke-width: .7; }
    .ivy-leaf-light { fill: #a8b9a2; stroke: #71876f; stroke-width: .7; }
    .ivy-vein {
      fill: none;
      stroke: #eef2e9;
      stroke-width: .7;
      stroke-linecap: round;
      opacity: .72;
    }
    .berry { fill: #c47f78; stroke: #a96763; stroke-width: 1; }
    .berry-light { fill: #d9a39a; }
    .petal-rose { fill: #d9a39a; stroke: #b9786c; stroke-width: .8; }
    .petal-ivory { fill: #fffaf2; stroke: #c7ad7e; stroke-width: .8; }
    .blossom-center { fill: #c7ad7e; stroke: #aa8d5e; stroke-width: .7; }
  </style>
</head>
<body>
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1682 1189"
    role="img" aria-label="Sitzplan Hochzeit von Mariandi">
    <defs>
      <linearGradient id="paperGradient" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stop-color="#fffdf9"/>
        <stop offset="1" stop-color="#f7efe7"/>
      </linearGradient>
      <linearGradient id="roomGradient" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="#f5f8f1"/>
        <stop offset="1" stop-color="#e9f0e5"/>
      </linearGradient>
      <linearGradient id="tableGradient" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stop-color="#e9aa92"/>
        <stop offset="1" stop-color="#d68d78"/>
      </linearGradient>
      <linearGradient id="seatGradient" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="#fffdf9"/>
        <stop offset="1" stop-color="#e8e1d9"/>
      </linearGradient>
      <filter id="softShadow" x="-30%" y="-30%" width="160%" height="160%">
        <feDropShadow dx="0" dy="4" stdDeviation="5" flood-color="#5c5048" flood-opacity=".16"/>
      </filter>
      <pattern id="paperDots" width="18" height="18" patternUnits="userSpaceOnUse">
        <circle cx="2" cy="2" r=".8" fill="#c7ad7e" opacity=".14"/>
      </pattern>
    </defs>

    <rect width="1682" height="1189" fill="url(#paperGradient)"/>
    <rect width="1682" height="1189" fill="url(#paperDots)"/>

    ${headerIvy()}

    <rect x="625" y="7" width="432" height="27" rx="13.5" fill="#fbf7f1" opacity=".94"/>
    <text x="841" y="26" text-anchor="middle" font-size="15" fill="#9a7568"
      letter-spacing="4">WILLKOMMEN ZU UNSERER HOCHZEIT</text>
    <text x="841" y="104" text-anchor="middle" font-size="58" font-style="italic"
      font-family="Georgia, 'Times New Roman', serif" fill="#465a4e">Maria &amp; Andi</text>
    <g transform="translate(841 137)">
      <line x1="-185" y1="0" x2="-42" y2="0" class="gold-rule"/>
      <path d="M0 8 C-19 -4 -20 -21 -7 -24 C-1 -25 4 -20 7 -14 C11 -22 20 -25 27 -20 C42 -9 27 7 7 19Z"
        fill="#b9786c" transform="translate(-7 -8) scale(.72)"/>
      <line x1="42" y1="0" x2="185" y2="0" class="gold-rule"/>
    </g>
    <text x="841" y="169" text-anchor="middle" font-size="21" font-weight="700"
      fill="#8b7065" letter-spacing="7">SITZPLAN</text>

    <rect x="60" y="190" width="1562" height="890" rx="34" class="room"/>
    <rect x="72" y="202" width="1538" height="866" rx="27" class="room-inner"/>

    ${cornerIvy()}
    <g transform="translate(98 630)">
      <rect x="-25" y="-65" width="50" height="130" rx="14" fill="#fffdf9"
        stroke="#c7ad7e" stroke-width="2"/>
      <text x="0" y="7" text-anchor="middle" font-size="18" font-weight="700"
        fill="#465a4e" letter-spacing="2" transform="rotate(90)">EINGANG</text>
    </g>
    ${artwork}
    ${qrArtwork(qr)}
    <text x="841" y="1128" text-anchor="middle" font-family="Georgia, serif"
      font-style="italic" font-size="22" fill="#8b7065">Schön, dass ihr mit uns feiert</text>
    <text x="841" y="1160" text-anchor="middle" font-size="14" fill="#9b8a80"
      letter-spacing="3">05 · 09 · 2026</text>
  </svg>
</body>
</html>`;
}

function findChrome() {
  const candidates = [
    'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
    'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
  ];
  const executable = candidates.find((candidate) => fs.existsSync(candidate));
  if (!executable) throw new Error('Chrome or Edge is required to create the PDF.');
  return executable;
}

async function renderPdf(html) {
  const temporaryHtml = path.join(__dirname, '.poster-preview.html');
  fs.writeFileSync(temporaryHtml, html, 'utf8');

  const browser = await puppeteer.launch({
    executablePath: findChrome(),
    headless: true,
    args: ['--no-sandbox', '--disable-gpu'],
  });

  try {
    const page = await browser.newPage();
    await page.goto(pathToFileURL(temporaryHtml).href, {
      waitUntil: 'networkidle0',
    });
    await page.pdf({
      path: outputPdf,
      width: '841mm',
      height: '594mm',
      margin: { top: 0, right: 0, bottom: 0, left: 0 },
      printBackground: true,
      preferCSSPageSize: true,
      displayHeaderFooter: false,
      pageRanges: '1',
    });
    await page.screenshot({
      path: outputPreview,
      fullPage: true,
    });
  } finally {
    await browser.close();
    fs.rmSync(temporaryHtml, { force: true });
  }
}

function verifyPdf() {
  const source = fs.readFileSync(outputPdf).toString('latin1');
  const pages = source.match(/\/Type\s*\/Page\b/g)?.length ?? 0;
  const mediaBoxes = [...source.matchAll(/\/MediaBox\s*\[([^\]]+)\]/g)];
  const isA1Landscape = mediaBoxes.some((match) => {
    const values = match[1].trim().split(/\s+/).map(Number);
    return (
      Math.abs(values[2] - 2383.94) < 1 &&
      Math.abs(values[3] - 1683.78) < 1
    );
  });
  if (pages !== 1 || !isA1Landscape) {
    throw new Error('Generated PDF is not a one-page A1 landscape document.');
  }
}

async function main() {
  console.log('Downloading current seating assignments...');
  const documents = await fetchGuests();
  const tables = buildTables(documents);
  const qr = QRCode.create(seatingUrl, { errorCorrectionLevel: 'H' });

  await QRCode.toFile(outputQrSvg, seatingUrl, {
    type: 'svg',
    errorCorrectionLevel: 'H',
    margin: 4,
    color: { dark: '#302b27', light: '#ffffff' },
  });
  await QRCode.toFile(outputQrPng, seatingUrl, {
    type: 'png',
    errorCorrectionLevel: 'H',
    margin: 4,
    width: 2400,
    color: { dark: '#302b27', light: '#ffffff' },
  });

  await renderPdf(posterHtml(tables, qr));
  verifyPdf();

  const seatedCount = [...tables.values()].reduce(
    (sum, guests) => sum + guests.length,
    0,
  );
  console.log(`Created A1 poster for ${seatedCount} seated guests:`);
  console.log(`  ${outputPdf}`);
  console.log(`  ${outputPreview}`);
  console.log(`  ${outputQrSvg}`);
  console.log(`  ${outputQrPng}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
