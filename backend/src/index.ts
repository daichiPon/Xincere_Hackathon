import { Hono } from 'hono'
import { cors } from 'hono/cors'

// ---- 型定義 ----

type Env = {
  DB: D1Database
  JWT_SECRET: string
}

type Variables = {
  userId: string
  householdId: string
}

type JWTPayload = {
  sub: string         // userId
  hid: string | null  // householdId
  exp: number
}

// ---- Crypto ヘルパー ----

async function hashPassword(password: string): Promise<string> {
  const salt = crypto.getRandomValues(new Uint8Array(16))
  const enc = new TextEncoder()
  const km = await crypto.subtle.importKey('raw', enc.encode(password), 'PBKDF2', false, ['deriveBits'])
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt, iterations: 100_000, hash: 'SHA-256' },
    km, 256
  )
  const hex = (a: Uint8Array) => Array.from(a).map(b => b.toString(16).padStart(2, '0')).join('')
  return `${hex(salt)}:${hex(new Uint8Array(bits))}`
}

async function verifyPassword(password: string, stored: string): Promise<boolean> {
  const [saltHex, hashHex] = stored.split(':')
  const fromHex = (s: string) => new Uint8Array(s.match(/.{2}/g)!.map(h => parseInt(h, 16)))
  const salt = fromHex(saltHex)
  const enc = new TextEncoder()
  const km = await crypto.subtle.importKey('raw', enc.encode(password), 'PBKDF2', false, ['deriveBits'])
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt, iterations: 100_000, hash: 'SHA-256' },
    km, 256
  )
  const computed = Array.from(new Uint8Array(bits)).map(b => b.toString(16).padStart(2, '0')).join('')
  return computed === hashHex
}

function b64u(s: string): string {
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
}

async function signJWT(payload: JWTPayload, secret: string): Promise<string> {
  const h = b64u(JSON.stringify({ alg: 'HS256', typ: 'JWT' }))
  const b = b64u(JSON.stringify(payload))
  const enc = new TextEncoder()
  const key = await crypto.subtle.importKey('raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'])
  const sig = await crypto.subtle.sign('HMAC', key, enc.encode(`${h}.${b}`))
  return `${h}.${b}.${b64u(String.fromCharCode(...new Uint8Array(sig)))}`
}

async function verifyJWT(token: string, secret: string): Promise<JWTPayload | null> {
  try {
    const parts = token.split('.')
    if (parts.length !== 3) return null
    const [h, b, s] = parts
    const enc = new TextEncoder()
    const key = await crypto.subtle.importKey('raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['verify'])
    const sigBytes = Uint8Array.from(atob(s.replace(/-/g, '+').replace(/_/g, '/')), c => c.charCodeAt(0))
    const ok = await crypto.subtle.verify('HMAC', key, sigBytes, enc.encode(`${h}.${b}`))
    if (!ok) return null
    const payload = JSON.parse(atob(b.replace(/-/g, '+').replace(/_/g, '/'))) as JWTPayload
    if (payload.exp < Date.now() / 1000) return null
    return payload
  } catch { return null }
}

// 招待コードは 10 分で失効・1 回限り。
const INVITE_TTL_MS = 10 * 60 * 1000

// 紛らわしい文字(0/O, 1/I/L)を除いた 30 種から 8 文字。30^8 ≈ 6.6e11。
function makeInviteCode(): string {
  const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'
  const bytes = crypto.getRandomValues(new Uint8Array(8))
  return Array.from(bytes, (b) => alphabet[b % alphabet.length]).join('')
}

// 新しい招待コードを1件発行する(既存の未使用コードは失効させる)。
async function issueInvite(db: D1Database, householdId: string): Promise<{ code: string; expiresAt: number }> {
  const now = Date.now()
  const expiresAt = now + INVITE_TTL_MS
  const code = makeInviteCode()
  await db.batch([
    db.prepare('UPDATE household_invites SET expires_at = 0 WHERE household_id = ? AND used_at IS NULL').bind(householdId),
    db.prepare('INSERT INTO household_invites (code, household_id, expires_at, used_at, created_at) VALUES (?, ?, ?, NULL, ?)')
      .bind(code, householdId, expiresAt, now),
  ])
  return { code, expiresAt }
}

function jwtExp(): number {
  return Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 90  // 90日
}

// ---- アプリ ----

const app = new Hono<{ Bindings: Env; Variables: Variables }>()

app.use('*', cors({
  origin: '*',
  allowMethods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowHeaders: ['Content-Type', 'Authorization'],
}))

// 認証ミドルウェア
app.use('/api/*', async (c, next) => {
  const auth = c.req.header('Authorization')
  if (!auth?.startsWith('Bearer ')) return c.json({ error: 'Unauthorized' }, 401)
  const payload = await verifyJWT(auth.slice(7), c.env.JWT_SECRET)
  if (!payload) return c.json({ error: 'Unauthorized' }, 401)
  c.set('userId', payload.sub)
  c.set('householdId', payload.hid ?? '')
  await next()
})

// ---- 認証 ----

app.post('/auth/register', async (c) => {
  const body = await c.req.json<{
    email: string; password: string; name: string
    childName?: string; birthDateMs?: number; municipality?: string
  }>()
  if (!body.email || !body.password || !body.name) {
    return c.json({ error: 'email, password, name は必須です' }, 400)
  }

  const existing = await c.env.DB.prepare('SELECT id FROM users WHERE email = ?').bind(body.email).first()
  if (existing) return c.json({ error: 'このメールアドレスは登録済みです' }, 409)

  const householdId = crypto.randomUUID()
  const userId = crypto.randomUUID()
  const now = Date.now()
  const hash = await hashPassword(body.password)

  await c.env.DB.batch([
    c.env.DB.prepare(
      'INSERT INTO households (id, invite_code, child_name, birth_date, is_preterm, municipality, created_at) VALUES (?, ?, ?, ?, 0, ?, ?)'
    ).bind(householdId, crypto.randomUUID(), body.childName ?? 'あかちゃん', body.birthDateMs ?? now, body.municipality ?? '', now),
    c.env.DB.prepare(
      'INSERT INTO users (id, household_id, email, password_hash, name, created_at) VALUES (?, ?, ?, ?, ?, ?)'
    ).bind(userId, householdId, body.email, hash, body.name, now),
  ])

  const token = await signJWT({ sub: userId, hid: householdId, exp: jwtExp() }, c.env.JWT_SECRET)
  return c.json({ token, userId, householdId }, 201)
})

app.post('/auth/login', async (c) => {
  const { email, password } = await c.req.json<{ email: string; password: string }>()
  const user = await c.env.DB.prepare(
    'SELECT id, household_id, password_hash FROM users WHERE email = ?'
  ).bind(email).first<{ id: string; household_id: string; password_hash: string }>()

  if (!user || !(await verifyPassword(password, user.password_hash))) {
    return c.json({ error: 'メールアドレスまたはパスワードが間違っています' }, 401)
  }

  const token = await signJWT({ sub: user.id, hid: user.household_id, exp: jwtExp() }, c.env.JWT_SECRET)
  return c.json({ token, userId: user.id, householdId: user.household_id })
})

// ---- 世帯 ----

app.get('/api/household', async (c) => {
  const h = await c.env.DB.prepare('SELECT * FROM households WHERE id = ?').bind(c.get('householdId')).first()
  if (!h) return c.json({ error: 'Not found' }, 404)
  return c.json(h)
})

app.patch('/api/household', async (c) => {
  const body = await c.req.json<Record<string, unknown>>()
  const fields: string[] = []
  const values: unknown[] = []
  if (body.childName !== undefined) { fields.push('child_name = ?'); values.push(body.childName) }
  if (body.birthDateMs !== undefined) { fields.push('birth_date = ?'); values.push(body.birthDateMs) }
  if (body.isPreterm !== undefined) { fields.push('is_preterm = ?'); values.push(body.isPreterm ? 1 : 0) }
  if (body.municipality !== undefined) { fields.push('municipality = ?'); values.push(body.municipality) }
  if (!fields.length) return c.json({ error: 'No fields to update' }, 400)
  values.push(c.get('householdId'))
  await c.env.DB.prepare(`UPDATE households SET ${fields.join(', ')} WHERE id = ?`).bind(...values).run()
  const h = await c.env.DB.prepare('SELECT * FROM households WHERE id = ?').bind(c.get('householdId')).first()
  return c.json(h)
})

// 現在有効な招待コードを返す(無ければ null)。
app.get('/api/household/invite', async (c) => {
  const row = await c.env.DB.prepare(
    'SELECT code, expires_at FROM household_invites WHERE household_id = ? AND used_at IS NULL AND expires_at > ? ORDER BY created_at DESC LIMIT 1'
  ).bind(c.get('householdId'), Date.now()).first<{ code: string; expires_at: number }>()
  return c.json(row ? { code: row.code, expiresAt: row.expires_at } : { code: null, expiresAt: null })
})

// 新しい招待コードを発行する(10分有効・1回限り)。
app.post('/api/household/invite', async (c) => {
  const invite = await issueInvite(c.env.DB, c.get('householdId'))
  return c.json(invite, 201)
})

app.post('/api/household/join', async (c) => {
  const { inviteCode } = await c.req.json<{ inviteCode: string }>()
  const userId = c.get('userId')
  const code = (inviteCode ?? '').trim().toUpperCase()
  if (!code) return c.json({ error: '招待コードを入力してください' }, 400)

  const invite = await c.env.DB.prepare(
    'SELECT household_id, expires_at, used_at FROM household_invites WHERE code = ?'
  ).bind(code).first<{ household_id: string; expires_at: number; used_at: number | null }>()

  if (!invite) return c.json({ error: '招待コードが見つかりません' }, 404)
  if (invite.used_at !== null) return c.json({ error: 'この招待コードは使用済みです' }, 410)
  if (invite.expires_at <= Date.now()) return c.json({ error: '招待コードの有効期限が切れています。相手に再発行してもらってください。' }, 410)

  const now = Date.now()
  await c.env.DB.batch([
    c.env.DB.prepare('UPDATE household_invites SET used_at = ? WHERE code = ?').bind(now, code),
    c.env.DB.prepare('UPDATE users SET household_id = ? WHERE id = ?').bind(invite.household_id, userId),
  ])

  const token = await signJWT({ sub: userId, hid: invite.household_id, exp: jwtExp() }, c.env.JWT_SECRET)
  return c.json({ token, householdId: invite.household_id })
})

// ---- 記録ログ ----

app.get('/api/logs', async (c) => {
  const { results } = await c.env.DB.prepare(
    'SELECT * FROM care_logs WHERE household_id = ? ORDER BY time DESC'
  ).bind(c.get('householdId')).all()
  return c.json(results)
})

app.post('/api/logs', async (c) => {
  const hid = c.get('householdId')
  const { kind, timeMs, detail } = await c.req.json<{ kind: string; timeMs: number; detail: string }>()
  const id = crypto.randomUUID()
  const now = Date.now()
  const me = await c.env.DB.prepare('SELECT name FROM users WHERE id = ?')
    .bind(c.get('userId')).first<{ name: string }>()
  const recordedBy = me?.name ?? ''
  await c.env.DB.prepare(
    'INSERT INTO care_logs (id, household_id, kind, time, detail, recorded_by, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)'
  ).bind(id, hid, kind, timeMs, detail, recordedBy, now).run()
  return c.json({ id, household_id: hid, kind, time: timeMs, detail, recorded_by: recordedBy, created_at: now }, 201)
})

app.delete('/api/logs/:id', async (c) => {
  await c.env.DB.prepare('DELETE FROM care_logs WHERE id = ? AND household_id = ?')
    .bind(c.req.param('id'), c.get('householdId')).run()
  return c.json({ ok: true })
})

// ---- 計測 ----

app.get('/api/measurements', async (c) => {
  const { results } = await c.env.DB.prepare(
    'SELECT * FROM measurements WHERE household_id = ? ORDER BY date ASC'
  ).bind(c.get('householdId')).all()
  return c.json(results)
})

app.post('/api/measurements', async (c) => {
  const hid = c.get('householdId')
  const { ageMonths, dateMs, heightCm, weightKg, headCm } =
    await c.req.json<{ ageMonths: number; dateMs: number; heightCm: number; weightKg: number; headCm: number }>()
  const id = crypto.randomUUID()
  const now = Date.now()
  await c.env.DB.prepare(
    'INSERT INTO measurements (id, household_id, age_months, date, height_cm, weight_kg, head_cm, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
  ).bind(id, hid, ageMonths, dateMs, heightCm, weightKg, headCm, now).run()
  return c.json({ id, household_id: hid, age_months: ageMonths, date: dateMs, height_cm: heightCm, weight_kg: weightKg, head_cm: headCm }, 201)
})

app.delete('/api/measurements/:id', async (c) => {
  await c.env.DB.prepare('DELETE FROM measurements WHERE id = ? AND household_id = ?')
    .bind(c.req.param('id'), c.get('householdId')).run()
  return c.json({ ok: true })
})

// ---- タスク ----

app.get('/api/tasks', async (c) => {
  const { results } = await c.env.DB.prepare(
    'SELECT * FROM procedure_tasks WHERE household_id = ? ORDER BY created_at ASC'
  ).bind(c.get('householdId')).all()
  return c.json(results)
})

app.post('/api/tasks', async (c) => {
  const hid = c.get('householdId')
  const b = await c.req.json<Record<string, unknown>>()
  const id = crypto.randomUUID()
  await c.env.DB.prepare(
    'INSERT INTO procedure_tasks (id, household_id, title, category, due_date, status, assignee, summary, documents, counter, online_available, source_title, source_url, fetched_at, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
  ).bind(
    id, hid, b.title, b.category, b.dueDateMs ?? null,
    b.status ?? 'scheduled', b.assignee ?? 'unassigned',
    b.summary ?? '', JSON.stringify(b.documents ?? []),
    b.counter ?? '', b.onlineAvailable ? 1 : 0,
    b.sourceTitle ?? '', b.sourceUrl ?? '', b.fetchedAt ?? '', Date.now()
  ).run()
  return c.json({ id }, 201)
})

app.put('/api/tasks/:id', async (c) => {
  const hid = c.get('householdId')
  const b = await c.req.json<Record<string, unknown>>()
  const fields: string[] = []
  const values: unknown[] = []
  if (b.status !== undefined) { fields.push('status = ?'); values.push(b.status) }
  if (b.assignee !== undefined) { fields.push('assignee = ?'); values.push(b.assignee) }
  if (b.dueDateMs !== undefined) { fields.push('due_date = ?'); values.push(b.dueDateMs) }
  if (!fields.length) return c.json({ error: 'No fields' }, 400)
  values.push(c.req.param('id'), hid)
  await c.env.DB.prepare(`UPDATE procedure_tasks SET ${fields.join(', ')} WHERE id = ? AND household_id = ?`)
    .bind(...values).run()
  const t = await c.env.DB.prepare('SELECT * FROM procedure_tasks WHERE id = ?').bind(c.req.param('id')).first()
  return c.json(t)
})

app.delete('/api/tasks/:id', async (c) => {
  await c.env.DB.prepare('DELETE FROM procedure_tasks WHERE id = ? AND household_id = ?')
    .bind(c.req.param('id'), c.get('householdId')).run()
  return c.json({ ok: true })
})

// ---- 制度マスタ(program_master)----
// 23区の子育て支援制度。世帯データとは独立した全ユーザー共通の参照データ。

type ProgramRow = {
  id: string
  ward: string
  category: string
  program_name: string
  min_age_months: number | null
  max_age_months: number | null
  income_condition: string
  program_type: string
  amount_or_content: string
  application_channel: string
  required_documents: string
  has_deadline: number
  deadline_rule: string
  source_url: string
  fetched_at: string
  reviewed_by: string
  notes: string
  created_at: number
}

// 制度一覧。ward / category / hasDeadline / ageMonths / q で絞り込める。
app.get('/api/programs', async (c) => {
  const { ward, category, hasDeadline, ageMonths, q } = c.req.query()
  const where: string[] = []
  const binds: unknown[] = []

  if (ward) { where.push('ward = ?'); binds.push(ward) }
  if (category) { where.push('category = ?'); binds.push(category) }
  if (hasDeadline === '0' || hasDeadline === '1') {
    where.push('has_deadline = ?'); binds.push(Number(hasDeadline))
  }
  if (ageMonths !== undefined && ageMonths !== '' && Number.isFinite(Number(ageMonths))) {
    const m = Number(ageMonths)
    where.push('(min_age_months IS NULL OR min_age_months <= ?)')
    where.push('(max_age_months IS NULL OR max_age_months >= ?)')
    binds.push(m, m)
  }
  if (q) {
    where.push('(program_name LIKE ?1 OR amount_or_content LIKE ?1 OR notes LIKE ?1)')
    binds.push(`%${q}%`)
  }

  const sql =
    'SELECT * FROM program_master' +
    (where.length ? ` WHERE ${where.join(' AND ')}` : '') +
    ' ORDER BY ward, category, program_name'

  const { results } = await c.env.DB.prepare(sql).bind(...binds).all<ProgramRow>()
  return c.json({ total: results.length, items: results })
})

// カテゴリ一覧(件数つき)。フィルタUI用。
app.get('/api/programs/categories', async (c) => {
  const ward = c.req.query('ward')
  const sql = ward
    ? 'SELECT category, COUNT(*) AS count FROM program_master WHERE ward = ? GROUP BY category ORDER BY category'
    : 'SELECT category, COUNT(*) AS count FROM program_master GROUP BY category ORDER BY category'
  const stmt = ward ? c.env.DB.prepare(sql).bind(ward) : c.env.DB.prepare(sql)
  const { results } = await stmt.all()
  return c.json(results)
})

app.get('/api/programs/:id', async (c) => {
  const row = await c.env.DB.prepare('SELECT * FROM program_master WHERE id = ?')
    .bind(c.req.param('id')).first<ProgramRow>()
  if (!row) return c.json({ error: 'Not found' }, 404)
  return c.json(row)
})

// deadline_rule の自由記述から締切日をベストエフォートで推定する。
// 解釈できない表現は null を返し、締切なしタスク(status=scheduled)として登録する。
function estimateDueDate(rule: string, birthMs: number): number | null {
  const r = rule ?? ''
  const addMonths = (base: number, months: number): number => {
    const d = new Date(base)
    d.setMonth(d.getMonth() + months)
    return d.getTime()
  }
  let m: RegExpMatchArray | null
  if ((m = r.match(/満?(\d+)\s*歳になるまで/)) || (m = r.match(/(\d+)\s*歳の年度末/))) {
    return addMonths(birthMs, parseInt(m[1], 10) * 12)
  }
  if (/0\s*歳児|1\s*歳になるまで|満1\s*歳/.test(r)) {
    return addMonths(birthMs, 12)
  }
  if ((m = r.match(/出生(?:届出?)?(?:から|後)\s*(\d+)\s*日以内/))) {
    return birthMs + parseInt(m[1], 10) * 86_400_000
  }
  return null
}

function splitDocs(s: string): string[] {
  return (s ?? '')
    .split(/[、・,\/／\n]/)
    .map((x) => x.trim())
    .filter(Boolean)
}

function addMonths(base: number, months: number): number {
  const d = new Date(base)
  d.setMonth(d.getMonth() + months)
  return d.getTime()
}

type TaskFields = {
  title: string
  category: string
  dueDate: number | null
  summary: string
  documents: string[]
  counter: string
  onlineAvailable: number
  sourceTitle: string
  sourceUrl: string
  fetchedAt: string
}

// program_master の1行 → procedure_tasks に入れるフィールド一式。
function programToTask(p: ProgramRow, birthMs: number, dueOverride?: number | null): TaskFields {
  const due = dueOverride !== undefined ? dueOverride : estimateDueDate(p.deadline_rule, birthMs)
  return {
    title: p.program_name,
    category: p.category,
    dueDate: due,
    summary: [
      p.amount_or_content && `内容: ${p.amount_or_content}`,
      p.income_condition && `所得条件: ${p.income_condition}`,
      p.deadline_rule && `期限: ${p.deadline_rule}`,
      p.notes && `備考: ${p.notes}`,
    ].filter(Boolean).join('\n'),
    documents: splitDocs(p.required_documents),
    counter: p.application_channel,
    onlineAvailable: /オンライン/.test(p.application_channel) ? 1 : 0,
    sourceTitle: `${p.ward} ${p.category}`,
    sourceUrl: p.source_url,
    fetchedAt: p.fetched_at,
  }
}

type VaccineRow = {
  id: string
  vaccine_name: string
  dose_label: string
  dose_number: number
  category: string
  disease: string
  start_age_months: number | null
  end_age_months: number | null
  interval_note: string
  notes: string
  source_url: string
  fetched_at: string
}

function vaccineToTask(v: VaccineRow, birthMs: number): TaskFields {
  const due = v.start_age_months != null ? addMonths(birthMs, Math.round(v.start_age_months)) : null
  return {
    title: `${v.vaccine_name} ${v.dose_label}`,
    category: '予防接種',
    dueDate: due,
    summary: [
      v.disease && `予防できる病気: ${v.disease}`,
      `区分: ${v.category}接種`,
      v.interval_note && `間隔: ${v.interval_note}`,
      v.notes && `備考: ${v.notes}`,
    ].filter(Boolean).join('\n'),
    documents: ['母子健康手帳', '予診票'],
    counter: '委託医療機関(かかりつけ医)',
    onlineAvailable: 0,
    sourceTitle: `予防接種スケジュール(${v.vaccine_name})`,
    sourceUrl: v.source_url,
    fetchedAt: v.fetched_at,
  }
}

// 指定フィールドから procedure_tasks への INSERT ステートメントを1つ作る。
function insertTaskStmt(c: { env: Env }, hid: string, f: TaskFields, now: number) {
  const soon = f.dueDate !== null && f.dueDate - now < 14 * 86_400_000
  return c.env.DB.prepare(
    'INSERT INTO procedure_tasks (id, household_id, title, category, due_date, status, assignee, summary, documents, counter, online_available, source_title, source_url, fetched_at, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
  ).bind(
    crypto.randomUUID(), hid, f.title, f.category, f.dueDate,
    soon ? 'dueSoon' : 'scheduled', 'unassigned', f.summary,
    JSON.stringify(f.documents), f.counter, f.onlineAvailable,
    f.sourceTitle, f.sourceUrl, f.fetchedAt, now
  )
}

// 世帯の区(municipality)に該当する「締切あり制度」から procedure_tasks を生成する。
// 既に同じ制度(source_url + title)から作られたタスクがあればスキップする。
app.post('/api/tasks/generate', async (c) => {
  const hid = c.get('householdId')
  const body = await c.req.json<{ ward?: string; dryRun?: boolean }>().catch(() => ({} as { ward?: string; dryRun?: boolean }))

  const household = await c.env.DB.prepare(
    'SELECT municipality, birth_date FROM households WHERE id = ?'
  ).bind(hid).first<{ municipality: string; birth_date: number }>()
  if (!household) return c.json({ error: 'Household not found' }, 404)

  const ward = (body.ward || household.municipality || '').trim()
  if (!ward) return c.json({ error: '区(municipality)が未設定です。世帯情報を先に登録してください。' }, 400)

  const { results: programs } = await c.env.DB.prepare(
    'SELECT * FROM program_master WHERE ward = ? AND has_deadline = 1 ORDER BY category, program_name'
  ).bind(ward).all<ProgramRow>()

  const { results: existing } = await c.env.DB.prepare(
    'SELECT title, source_url FROM procedure_tasks WHERE household_id = ?'
  ).bind(hid).all<{ title: string; source_url: string }>()
  const existingKeys = new Set(existing.map((e) => `${e.title} ${e.source_url}`))

  const now = Date.now()
  const toCreate: ProgramRow[] = programs.filter(
    (p) => !existingKeys.has(`${p.program_name} ${p.source_url}`)
  )

  if (body.dryRun) {
    return c.json({
      ward,
      created: 0,
      skipped: programs.length - toCreate.length,
      candidates: toCreate.map((p) => p.program_name),
    })
  }

  const stmts = toCreate.map((p) =>
    insertTaskStmt(c, hid, programToTask(p, household.birth_date), now)
  )

  if (stmts.length) await c.env.DB.batch(stmts)

  return c.json({
    ward,
    created: toCreate.length,
    skipped: programs.length - toCreate.length,
  })
})

// 制度1件を「やること」に追加する。dueDate を明示すればそれを、なければ推定値を使う。
app.post('/api/tasks/from-program', async (c) => {
  const hid = c.get('householdId')
  const body = await c.req.json<{ programId?: string; dueDateMs?: number | null }>().catch(() => ({}))
  if (!body.programId) return c.json({ error: 'programId は必須です' }, 400)

  const household = await c.env.DB.prepare('SELECT birth_date FROM households WHERE id = ?')
    .bind(hid).first<{ birth_date: number }>()
  if (!household) return c.json({ error: 'Household not found' }, 404)

  const p = await c.env.DB.prepare('SELECT * FROM program_master WHERE id = ?')
    .bind(body.programId).first<ProgramRow>()
  if (!p) return c.json({ error: 'Program not found' }, 404)

  const dup = await c.env.DB.prepare(
    'SELECT id FROM procedure_tasks WHERE household_id = ? AND title = ? AND source_url = ?'
  ).bind(hid, p.program_name, p.source_url).first<{ id: string }>()
  if (dup) return c.json({ created: 0, alreadyExists: true, taskId: dup.id })

  const fields = programToTask(p, household.birth_date, body.dueDateMs ?? undefined)
  await insertTaskStmt(c, hid, fields, Date.now()).run()
  return c.json({ created: 1 })
})

// ---- 予防接種スケジュール(vaccine_schedule)----

app.get('/api/vaccines', async (c) => {
  const category = c.req.query('category')
  const sql = category
    ? 'SELECT * FROM vaccine_schedule WHERE category = ? ORDER BY start_age_months, vaccine_name, dose_number'
    : 'SELECT * FROM vaccine_schedule ORDER BY start_age_months, vaccine_name, dose_number'
  const stmt = category ? c.env.DB.prepare(sql).bind(category) : c.env.DB.prepare(sql)
  const { results } = await stmt.all<VaccineRow>()
  return c.json({ total: results.length, items: results })
})

// 予防接種1件を「やること」に追加する。期限は 誕生日 + 推奨月齢 で自動計算する。
app.post('/api/tasks/from-vaccine', async (c) => {
  const hid = c.get('householdId')
  const body = await c.req.json<{ vaccineId?: string }>().catch(() => ({}))
  if (!body.vaccineId) return c.json({ error: 'vaccineId は必須です' }, 400)

  const household = await c.env.DB.prepare('SELECT birth_date FROM households WHERE id = ?')
    .bind(hid).first<{ birth_date: number }>()
  if (!household) return c.json({ error: 'Household not found' }, 404)

  const v = await c.env.DB.prepare('SELECT * FROM vaccine_schedule WHERE id = ?')
    .bind(body.vaccineId).first<VaccineRow>()
  if (!v) return c.json({ error: 'Vaccine not found' }, 404)

  const fields = vaccineToTask(v, household.birth_date)
  const dup = await c.env.DB.prepare(
    'SELECT id FROM procedure_tasks WHERE household_id = ? AND title = ? AND source_url = ?'
  ).bind(hid, fields.title, fields.sourceUrl).first<{ id: string }>()
  if (dup) return c.json({ created: 0, alreadyExists: true, taskId: dup.id })

  await insertTaskStmt(c, hid, fields, Date.now()).run()
  return c.json({ created: 1 })
})

export default app
