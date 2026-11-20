import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

// 用法：在仓库根目录执行 `node lib/build.mjs`
// 把 lib/client.js.tpl 里的 __OCEAN_HTML__ 占位符替换成 assets/ocean.html，
// 输出打包后的 lib/client.js（这是 DSH 实际加载的客户端产物）。
const here = path.dirname(fileURLToPath(import.meta.url))
const root = path.resolve(here, '..')
const tpl = path.join(root, 'lib', 'client.js.tpl')
const htmlPath = path.join(root, 'assets', 'ocean.html')
const outPath = path.join(root, 'lib', 'client.js')

const tplText = fs.readFileSync(tpl, 'utf8')
const html = fs.readFileSync(htmlPath, 'utf8')
if (!tplText.includes('__OCEAN_HTML__')) {
  console.error('client.js.tpl 里找不到 __OCEAN_HTML__ 占位符')
  process.exit(1)
}
const out = tplText.replace('__OCEAN_HTML__', JSON.stringify(html))
fs.writeFileSync(outPath, out)
console.log('built lib/client.js:', out.length, 'chars')