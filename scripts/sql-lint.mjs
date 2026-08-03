// Catches the one SQL mistake that is invisible to the eye and fatal at runtime:
// a $$-quoted body nested inside another $$-quoted body. Postgres closes the outer
// block at the inner block's opening tag, and the error surfaces hundreds of lines
// away from the actual cause.
//
// Run: node scripts/sql-lint.mjs
import { readFileSync, readdirSync } from 'node:fs'

const dir = 'supabase/migrations'
let bad = 0

// Blank out -- comments and '...' literals, preserving newlines so reported line
// numbers still line up. A tag mentioned in prose is not a tag.
function strip(src) {
  let out = ''
  let i = 0
  while (i < src.length) {
    const two = src.slice(i, i + 2)
    if (two === '--') {
      while (i < src.length && src[i] !== '\n') { out += ' '; i++ }
    } else if (two === '/*') {
      while (i < src.length && src.slice(i, i + 2) !== '*/') { out += src[i] === '\n' ? '\n' : ' '; i++ }
      out += '  '; i += 2
    } else if (src[i] === "'") {
      out += ' '; i++
      while (i < src.length) {
        if (src[i] === "'" && src[i + 1] === "'") { out += '  '; i += 2; continue }
        if (src[i] === "'") { out += ' '; i++; break }
        out += src[i] === '\n' ? '\n' : ' '
        i++
      }
    } else {
      out += src[i]; i++
    }
  }
  return out
}

for (const file of readdirSync(dir).filter((f) => f.endsWith('.sql')).sort()) {
  const src = strip(readFileSync(`${dir}/${file}`, 'utf8'))
  const stack = []
  const re = /\$([A-Za-z_][A-Za-z0-9_]*)?\$/g
  let m

  while ((m = re.exec(src))) {
    const tag = m[1] ?? ''
    const line = src.slice(0, m.index).split('\n').length
    const top = stack.at(-1)

    if (top?.tag === tag) {
      stack.pop() // closing
    } else {
      if (stack.some((f) => f.tag === tag)) {
        console.error(
          `✗ ${file}:${line} — $${tag}$ opened while an outer $${tag}$ is still open.` +
            `\n  The outer block closes here instead. Give the inner body a distinct tag, e.g. $fn$.`
        )
        bad++
      }
      stack.push({ tag, line })
    }
  }

  if (stack.length) {
    console.error(`✗ ${file} — unclosed $${stack.at(-1).tag}$ opened at line ${stack.at(-1).line}`)
    bad++
  } else if (!bad) {
    console.log(`✓ ${file}`)
  }
}

if (bad) {
  console.error(`\n${bad} dollar-quote problem${bad === 1 ? '' : 's'}.`)
  process.exit(1)
}
console.log('\nDollar quoting is balanced in all migrations.')
