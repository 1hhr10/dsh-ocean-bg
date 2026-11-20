/**
 * dsh-ocean-bg — host half.
 *
 * The whole feature lives in the client half (a blob iframe under the chat).
 * The host half exists only so the bundle has something to load; it must never
 * throw, because a broken host half would take the app down.
 */
export const name = 'dsh-ocean-bg'
export const inject = []

export function apply(ctx) {
  try {
    ctx.logger?.info?.('[dsh-ocean-bg] host half loaded (client renders the ocean)')
  } catch (e) {
    /* logging must never break startup */
  }
}

const plugin = { name, inject, apply }
export default plugin
