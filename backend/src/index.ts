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

function makeInviteCode(): string {
  return Math.random().toString(36).substring(2, 8).toUpperCase()
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
    childName?: string; birthDateMs?: number
  }>()
  if (!body.email || !body.password || !body.name) {
    return c.json({ error: 'email, password, name は必須です' }, 400)
  }

  const existing = await c.env.DB.prepare('SELECT id FROM users WHERE email = ?').bind(body.email).first()
  if (existing) return c.json({ error: 'このメールアドレスは登録済みです' }, 409)

  const householdId = crypto.randomUUID()
  const userId = crypto.randomUUID()
  const inviteCode = makeInviteCode()
  const now = Date.now()
  const hash = await hashPassword(body.password)

  await c.env.DB.batch([
    c.env.DB.prepare(
      'INSERT INTO households (id, invite_code, child_name, birth_date, is_preterm, municipality, created_at) VALUES (?, ?, ?, ?, 0, ?, ?)'
    ).bind(householdId, inviteCode, body.childName ?? 'あかちゃん', body.birthDateMs ?? now, '', now),
    c.env.DB.prepare(
      'INSERT INTO users (id, household_id, email, password_hash, name, created_at) VALUES (?, ?, ?, ?, ?, ?)'
    ).bind(userId, householdId, body.email, hash, body.name, now),
  ])

  const token = await signJWT({ sub: userId, hid: householdId, exp: jwtExp() }, c.env.JWT_SECRET)
  return c.json({ token, userId, householdId, inviteCode }, 201)
})

app.post('/auth/login', async (c) => {
  const { email, password } = await c.req.json<{ email: string; password: string }>()
  const user = await c.env.DB.prepare(
    'SELECT u.id, u.household_id, u.password_hash, h.invite_code FROM users u LEFT JOIN households h ON h.id = u.household_id WHERE u.email = ?'
  ).bind(email).first<{ id: string; household_id: string; password_hash: string; invite_code: string }>()

  if (!user || !(await verifyPassword(password, user.password_hash))) {
    return c.json({ error: 'メールアドレスまたはパスワードが間違っています' }, 401)
  }

  const token = await signJWT({ sub: user.id, hid: user.household_id, exp: jwtExp() }, c.env.JWT_SECRET)
  return c.json({ token, userId: user.id, householdId: user.household_id, inviteCode: user.invite_code })
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

app.post('/api/household/join', async (c) => {
  const { inviteCode } = await c.req.json<{ inviteCode: string }>()
  const userId = c.get('userId')
  const h = await c.env.DB.prepare('SELECT id, invite_code FROM households WHERE invite_code = ?')
    .bind(inviteCode.toUpperCase())
    .first<{ id: string; invite_code: string }>()
  if (!h) return c.json({ error: '招待コードが無効です' }, 404)
  await c.env.DB.prepare('UPDATE users SET household_id = ? WHERE id = ?').bind(h.id, userId).run()
  const token = await signJWT({ sub: userId, hid: h.id, exp: jwtExp() }, c.env.JWT_SECRET)
  return c.json({ token, householdId: h.id, inviteCode: h.invite_code })
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
  await c.env.DB.prepare(
    'INSERT INTO care_logs (id, household_id, kind, time, detail, created_at) VALUES (?, ?, ?, ?, ?, ?)'
  ).bind(id, hid, kind, timeMs, detail, now).run()
  return c.json({ id, household_id: hid, kind, time: timeMs, detail, created_at: now }, 201)
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

export default app
