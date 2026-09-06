#!/usr/bin/env node
// data/programs.csv を program_master テーブル用の INSERT SQL に変換する。
//
// 使い方:
//   node scripts/csv-to-sql.js data/programs.csv > data/programs.generated.sql
//   npx wrangler d1 execute xincere-db --local --file=data/programs.generated.sql
//
// 本番(リモートD1)に反映する場合は --local を --remote に変える
// (Cloudflareの認証情報が必要なので、権限を持つ人が実行すること)。

const fs = require('fs');
const crypto = require('crypto');

function parseCSV(text) {
  const rows = [];
  let row = [];
  let field = '';
  let inQuotes = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (inQuotes) {
      if (c === '"') {
        if (text[i + 1] === '"') { field += '"'; i++; }
        else { inQuotes = false; }
      } else {
        field += c;
      }
    } else if (c === '"') {
      inQuotes = true;
    } else if (c === ',') {
      row.push(field); field = '';
    } else if (c === '\n') {
      row.push(field); rows.push(row); row = []; field = '';
    } else if (c === '\r') {
      // skip
    } else {
      field += c;
    }
  }
  if (field.length || row.length) { row.push(field); rows.push(row); }
  return rows.filter(r => !(r.length === 1 && r[0].trim() === ''));
}

function sqlEscape(v) {
  return `'${String(v ?? '').replace(/'/g, "''")}'`;
}

function toIntOrNull(v) {
  if (v === undefined || v === null || String(v).trim() === '') return 'NULL';
  const n = parseInt(v, 10);
  return Number.isFinite(n) ? String(n) : 'NULL';
}

const inputPath = process.argv[2] || 'data/programs.csv';
const text = fs.readFileSync(inputPath, 'utf8');
const rows = parseCSV(text);
const header = rows[0].map(h => h.trim());
const dataRows = rows.slice(1).filter(r => r.some(c => c.trim() !== ''));

const required = ['ward', 'category', 'program_name', 'source_url', 'fetched_at'];
for (const col of required) {
  if (!header.includes(col)) {
    console.error(`必須列 "${col}" がCSVにありません`);
    process.exit(1);
  }
}

const idx = (name) => header.indexOf(name);
const statements = [];
let hasError = false;

dataRows.forEach((r, i) => {
  const get = (name) => (r[idx(name)] ?? '').trim();
  const lineNo = i + 2; // ヘッダ行分 +1、1始まり分 +1

  if (get('ward').startsWith('(サンプル)')) return; // テンプレのサンプル行はスキップ

  if (!get('source_url')) {
    console.error(`行 ${lineNo}: source_url が空です。出典なしのデータは登録できません。`);
    hasError = true;
    return;
  }
  if (!get('fetched_at')) {
    console.error(`行 ${lineNo}: fetched_at が空です。取得日は必須です。`);
    hasError = true;
    return;
  }

  // id は ward|category|program_name から決定的に生成する。
  // 同じCSVからは常に同じ id が出るので、INSERT OR REPLACE で何度でも再投入できる。
  const id = crypto.createHash('sha1')
    .update(`${get('ward')}|${get('category')}|${get('program_name')}`)
    .digest('hex')
    .slice(0, 32);
  const createdAt = Date.now();
  const hasDeadline = get('has_deadline') === '' ? 1 : (get('has_deadline') === '0' ? 0 : 1);

  const values = [
    sqlEscape(id),
    sqlEscape(get('ward')),
    sqlEscape(get('category')),
    sqlEscape(get('program_name')),
    toIntOrNull(get('min_age_months')),
    toIntOrNull(get('max_age_months')),
    sqlEscape(get('income_condition')),
    sqlEscape(get('program_type')),
    sqlEscape(get('amount_or_content')),
    sqlEscape(get('application_channel')),
    sqlEscape(get('required_documents')),
    String(hasDeadline),
    sqlEscape(get('deadline_rule')),
    sqlEscape(get('source_url')),
    sqlEscape(get('fetched_at')),
    sqlEscape(get('reviewed_by')),
    sqlEscape(get('notes')),
    String(createdAt),
  ].join(', ');

  statements.push(
    `INSERT OR REPLACE INTO program_master (id, ward, category, program_name, min_age_months, max_age_months, income_condition, program_type, amount_or_content, application_channel, required_documents, has_deadline, deadline_rule, source_url, fetched_at, reviewed_by, notes, created_at) VALUES (${values});`
  );
});

if (hasError) {
  console.error('\nエラーがあるため中断しました。CSVを直してから再実行してください。');
  process.exit(1);
}

if (statements.length === 0) {
  console.error('取り込める行がありませんでした(サンプル行しかない、または空)。');
  process.exit(1);
}

process.stdout.write(statements.join('\n') + '\n');
console.error(`${statements.length} 件のINSERT文を生成しました。`);
