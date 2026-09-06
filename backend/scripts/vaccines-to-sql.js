#!/usr/bin/env node
// data/vaccines.csv を vaccine_schedule テーブル用の INSERT SQL に変換する。
//
// 使い方:
//   node scripts/vaccines-to-sql.js data/vaccines.csv > data/vaccines.generated.sql
//   npx wrangler d1 execute xincere-db --local --file=data/vaccines.generated.sql
//
// id は vaccine_name|dose_label から決定的に生成し INSERT OR REPLACE を出力するので、
// CSV を直して再実行すれば安全に上書き反映できる。

const fs = require('fs');
const crypto = require('crypto');

function parseCSV(text) {
  const rows = [];
  let row = [], field = '', inQuotes = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (inQuotes) {
      if (c === '"') {
        if (text[i + 1] === '"') { field += '"'; i++; } else { inQuotes = false; }
      } else field += c;
    } else if (c === '"') inQuotes = true;
    else if (c === ',') { row.push(field); field = ''; }
    else if (c === '\n') { row.push(field); rows.push(row); row = []; field = ''; }
    else if (c === '\r') { /* skip */ }
    else field += c;
  }
  if (field.length || row.length) { row.push(field); rows.push(row); }
  return rows.filter(r => !(r.length === 1 && r[0].trim() === ''));
}

const sqlEscape = (v) => `'${String(v ?? '').replace(/'/g, "''")}'`;
const toIntOrNull = (v) => {
  const s = String(v ?? '').trim();
  if (s === '') return 'NULL';
  const n = parseInt(s, 10);
  return Number.isFinite(n) ? String(n) : 'NULL';
};
const toRealOrNull = (v) => {
  const s = String(v ?? '').trim();
  if (s === '') return 'NULL';
  const n = Number(s);
  return Number.isFinite(n) ? String(n) : 'NULL';
};

const inputPath = process.argv[2] || 'data/vaccines.csv';
const rows = parseCSV(fs.readFileSync(inputPath, 'utf8'));
const header = rows[0].map(h => h.trim());
const dataRows = rows.slice(1).filter(r => r.some(c => c.trim() !== ''));

const idx = (name) => header.indexOf(name);
for (const col of ['vaccine_name', 'dose_label', 'source_url', 'fetched_at']) {
  if (idx(col) < 0) { console.error(`必須列 "${col}" がありません`); process.exit(1); }
}

const statements = [];
let hasError = false;

dataRows.forEach((r, i) => {
  const get = (name) => (r[idx(name)] ?? '').trim();
  const lineNo = i + 2;
  if (!get('source_url')) { console.error(`行 ${lineNo}: source_url が空です`); hasError = true; return; }
  if (!get('fetched_at')) { console.error(`行 ${lineNo}: fetched_at が空です`); hasError = true; return; }

  const id = crypto.createHash('sha1')
    .update(`${get('vaccine_name')}|${get('dose_label')}`)
    .digest('hex').slice(0, 32);

  const values = [
    sqlEscape(id),
    sqlEscape(get('vaccine_name')),
    sqlEscape(get('dose_label')),
    toIntOrNull(get('dose_number') || '1'),
    sqlEscape(get('category') || '定期'),
    sqlEscape(get('disease')),
    toRealOrNull(get('start_age_months')),
    toRealOrNull(get('end_age_months')),
    sqlEscape(get('interval_note')),
    sqlEscape(get('notes')),
    sqlEscape(get('source_url')),
    sqlEscape(get('fetched_at')),
    String(Date.now()),
  ].join(', ');

  statements.push(
    `INSERT OR REPLACE INTO vaccine_schedule (id, vaccine_name, dose_label, dose_number, category, disease, start_age_months, end_age_months, interval_note, notes, source_url, fetched_at, created_at) VALUES (${values});`
  );
});

if (hasError) { console.error('\nエラーがあるため中断しました。'); process.exit(1); }
if (statements.length === 0) { console.error('取り込める行がありません。'); process.exit(1); }

process.stdout.write(statements.join('\n') + '\n');
console.error(`${statements.length} 件のINSERT文を生成しました。`);
