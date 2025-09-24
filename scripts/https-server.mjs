import fs from 'node:fs'
import https from 'node:https'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const port = Number(process.env.PORT || 4443)
const host = process.env.HOST || '127.0.0.1'

const here = path.dirname(fileURLToPath(import.meta.url))
const repoRoot = path.resolve(here, '..')
const pfxPath =
  process.env.PFX_PATH ||
  path.join(repoRoot, process.env.PFX_FILENAME || 'servercert.pfx')
const passphrase = process.env.PFX_PASSWORD || 'pass'

if (!fs.existsSync(pfxPath)) {
  console.error(`PFX not found at ${pfxPath}`)
  process.exit(2)
}

const pfx = fs.readFileSync(pfxPath)

const sendJson = (res, statusCode, payload) => {
  const body = JSON.stringify(payload)
  res.writeHead(statusCode, {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(body),
    'Cache-Control': 'no-store',
  })
  res.end(body)
}

const server = https.createServer({ pfx, passphrase }, (req, res) => {
  if (req.method === 'GET' && req.url === '/') {
    sendJson(res, 200, { status: 'ok' })
    return
  }

  res.writeHead(404, { 'Content-Type': 'application/json' })
  res.end(JSON.stringify({ error: 'not_found' }))
})

server.on('error', (err) => {
  console.error('HTTPS server error:', err)
  process.exit(1)
})

server.listen(port, host, () => {
  console.log(
    `https server listening at https://${host}:${port} using ${pfxPath}`
  )
})
