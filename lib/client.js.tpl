/* dsh-ocean-bg — client half (v11).
 *
 * 只有四层，从上到下：
 *   1. 海（固定 iframe，最底层）
 *   2. 一层柔光纱（渐变压暗四角，让文字有底）
 *   3. DSH 自己的界面（透明，只给侧栏、中栏、菜单上色）
 *   4. 右下角的海洋设置
 *
 * 不再「扫描所有 div 套玻璃」——那是 v10 越叠越黑的原因。
 * 也不碰 backdrop-filter 压整层 WebGL 的写法，只在菜单上用它自带的口子。 */

window.__ModuleLoader__.load({
  id: 'dsh-ocean-bg',
  factory: function (require) {
    const OCEAN_HTML = __OCEAN_HTML__


    const STORE_KEY = 'dsh-ocean-bg:settings:v13'
    const SIDE_BG = 'linear-gradient(180deg, rgba(6,14,24,.52) 0%, rgba(6,14,24,.52) 100%)'
    const MAIN_BG = 'linear-gradient(180deg, rgba(6,14,24,.50) 0%, rgba(6,14,24,.58) 100%)'
    const DEFAULTS = { blur: 16, tint: 40, on: true, chat: 0, chatRgb: '8, 16, 26', gm: 'teal', gmAmt: 22, sb: 55, sbBlur: 30, comp: 62, compBlur: 22, compSync: true, corner: 'convex', cornerR: 22, cornerRot: 0, preset: '正午' }
    const WAVES = [
      ['amplitude', '浪高', 0, 2], ['scale', '尺度', 0, 2], ['choppiness', '碎浪', 0, 2],
      ['speed', '波速', 0, 2], ['turn', '转向', -1.6, 1.6], ['group', '波群', 0, 2],
      ['foam', '白沫', 0, 2], ['aurora', '极光', 0, 2], ['stars', '星空', 0, 2]
    ]

    let settings = Object.assign({}, DEFAULTS)
    let mounted = false
    let seaEl = null
    let gearEl = null
    let panelEl = null
    let observer = null
    let bootDone = false

    function q(sel, root) { return (root || document).querySelector(sel) }
    function el(tag, cls, text) {
      const n = document.createElement(tag)
      if (cls) n.className = cls
      if (text != null) n.textContent = text
      return n
    }

    function loadSettings() {
      try {
        const raw = window.localStorage.getItem(STORE_KEY)
        if (raw) settings = Object.assign({}, DEFAULTS, JSON.parse(raw))
        /* 老版本存下来的角形状（挖。旧内凹）已经废弃，统一迁到阴角圆弧。           否则改了 CSS 也看不到变化 */
        if (settings.corner !== 'convex' && settings.corner !== 'sharp' && settings.corner !== 'inset') {
          settings.corner = 'convex'
        }
        if (!(Number(settings.cornerR) >= 8)) settings.cornerR = 22
      } catch (e) { /* defaults are fine */ }
    }
    function saveSettings() {
      try { window.localStorage.setItem(STORE_KEY, JSON.stringify(settings)) } catch (e) {}
    }

    /* ---------- 样式 ---------- */

    function buildStyle() {
      const css = `
html.dsh-obg, html.dsh-obg #root { background: transparent !important; }
/* 窗口比页面高，最底下会露出一条桌面黑边；给它铺海水的底色，别露黑 */
html.dsh-obg body { background: #071019 !important; }
/* 应用层必须抬到海和纱之上，否则整块界面会。iframe 压到背后 */
html.dsh-obg #root { position: relative; z-index: 2; }
html.dsh-obg .mP3x-q_frame { background: transparent !important; }

/* 侧栏：一整块淡玻璃，靠海的亮部透出。*/
html.dsh-obg [data-obg-pane="side"] {
  background: rgba(4, 7, 12, var(--obg-sb, .88)) !important;
  backdrop-filter: blur(var(--obg-sb-blur, 18px)) saturate(1.1);
  box-shadow: inset -1px 0 0 rgba(255,255,255,.07);
}
/* ============ 全局青色（浅色）——必须挂。body 上，html 会被 body 默认值压。============ */
html.dsh-obg,
html.dsh-obg body {
  --dsw-static-deepseek-400: #0d9c8f !important;
  --dsw-static-deepseek-450: #0d9c8f !important;
  --dsw-static-deepseek-500: #14b5a5 !important;
  --dsw-static-blue-500: #0d9c8f !important;

  /* 主按钮（发。保存/确认这类实心按钮）：青绿 */
  --dsw-alias-button-primary-fill: #0d9c8f !important;
  --dsw-alias-button-primary-hover: #14b5a5 !important;
  --dsw-alias-button-primary-dimmed: #b6e3dd !important;
  --dsw-alias-button-info-fill: #0d9c8f !important;
  --dsw-alias-button-info-hover: #14b5a5 !important;
  /* 侧栏"新建会话"这类浅底按钮 */
  --dsw-alias-button-elevated-fill: #e8f7f4 !important;
  --dsw-alias-button-floating-fill: #f2fbf9 !important;
  --dsw-alias-button-floating-hover: #e0f5f1 !important;
  --dsw-alias-button-ghost-active-fill: rgba(13,156,143,.14) !important;
  --dsw-alias-button-ghost-active-hover: rgba(13,156,143,.2) !important;
  --dsw-alias-button-ghost-active-border: rgba(13,156,143,.45) !important;
  --dsw-alias-button-tool-bar-fill: rgba(13,156,143,.16) !important;
  --dsw-alias-button-tool-bar-hover: rgba(13,156,143,.26) !important;
  --dsw-alias-button-tool-bar-fill-invisible: rgba(13,156,143,.1) !important;
  /* 设置页：下拉/切换器底板、左侧选中项、卡。*/
  --dsw-alias-bg-module-platform: #e6f6f3 !important;
  --dsw-specific-sidebar-nav-item-active: #c9ebe5 !important;
  --dsw-specific-selector: #d9f2ee !important;
  --dsw-alias-card-fill: #f1faf8 !important;
  --dsw-alias-card-fill-hover: #e6f6f3 !important;
  --dsw-alias-settings-card-fill: #f2fbf9 !important;
  --dsw-alias-settings-card-stroke: rgba(13,156,143,.22) !important;
  /* 悬停/选中/聚焦 */
  --dsw-alias-interactive-bg-hover: rgba(13,156,143,.1) !important;
  --dsw-alias-interactive-bg-active: rgba(13,156,143,.18) !important;
  --dsw-alias-interactive-bg-hover-accent: rgba(13,156,143,.22) !important;
  --dsw-alias-border-selected: #0d9c8f !important;
  --dsw-alias-bg-document-selection: color-mix(in srgb, #0d9c8f 32%, transparent) !important;
  --dsw-alias-trajectory-accent: #0d9c8f !important;
  --dsw-alias-onboarding-accent: #0d9c8f !important;
  --dsw-specific-menu: rgba(247,252,251,.97) !important;

}
/* ============ 全局青色（深色） ============ */
html.dsh-obg body[data-ds-dark-theme] {
  --dsw-static-deepseek-400: #00b3a4 !important;
  --dsw-static-deepseek-450: #00a294 !important;
  --dsw-static-deepseek-500: #00c4b4 !important;
  --dsw-static-blue-500: #00b3a4 !important;

  --dsw-alias-button-primary-fill: #00b3a4 !important;
  --dsw-alias-button-primary-hover: #00cbb9 !important;
  --dsw-alias-button-primary-dimmed: #0a5b55 !important;
  --dsw-alias-button-info-fill: #00a294 !important;
  --dsw-alias-button-info-hover: #00c2b0 !important;
  --dsw-alias-button-elevated-fill: #123f3b !important;
  --dsw-alias-button-floating-fill: #123f3b !important;
  --dsw-alias-button-floating-hover: #17534d !important;
  --dsw-alias-button-ghost-active-fill: rgba(0,196,180,.22) !important;
  --dsw-alias-button-ghost-active-hover: rgba(0,196,180,.3) !important;
  --dsw-alias-button-ghost-active-border: rgba(0,220,205,.5) !important;
  --dsw-alias-button-tool-bar-fill: rgba(0,150,138,.42) !important;
  --dsw-alias-button-tool-bar-hover: rgba(0,196,180,.34) !important;
  --dsw-alias-button-tool-bar-fill-invisible: rgba(0,120,112,.28) !important;
  --dsw-alias-bg-module-platform: #0d3b37 !important;
  --dsw-specific-sidebar-nav-item-active: #16544e !important;
  --dsw-specific-selector: #0a3a36 !important;
  --dsw-alias-card-fill: #0b2f2c !important;
  --dsw-alias-card-fill-hover: #0e3a36 !important;
  --dsw-alias-settings-card-fill: #0a2f2c !important;
  --dsw-alias-settings-card-stroke: rgba(0,220,205,.22) !important;
  --dsw-alias-interactive-bg-hover: rgba(0,196,180,.14) !important;
  --dsw-alias-interactive-bg-active: rgba(0,196,180,.24) !important;
  --dsw-alias-interactive-bg-hover-accent: rgba(0,196,180,.3) !important;
  --dsw-alias-border-selected: rgba(0,212,198,.8) !important;
  --dsw-alias-bg-document-selection: color-mix(in srgb, #00b3a4 40%, transparent) !important;
  --dsw-alias-trajectory-accent: #00b3a4 !important;
  --dsw-alias-onboarding-accent: #00b3a4 !important;
  --dsw-specific-menu: rgba(6,40,38,.94) !important;

}



/* ============ 二级菜单 / 设置面板：毛玻璃，跟侧栏同一。============ */
html.dsh-obg [class*="AnXs9G_panel"] {
  background: rgba(233, 246, 243, .66) !important;
  backdrop-filter: blur(44px) saturate(1.25) !important;
  box-shadow: 0 28px 72px rgba(0, 40, 38, .22) !important;
}
html.dsh-obg body[data-ds-dark-theme] [class*="AnXs9G_panel"] {
  background: rgba(6, 26, 30, .64) !important;
  box-shadow: 0 28px 72px rgba(0, 0, 0, .5) !important;
}

/* 下拉菜单同款玻璃 */
html.dsh-obg [role="menu"],
html.dsh-obg [class*="_menuSurface"] {
  backdrop-filter: blur(22px) saturate(1.1) !important;
}
html.dsh-obg body[data-ds-dark-theme] [role="menu"],
html.dsh-obg body[data-ds-dark-theme] [class*="_menuSurface"] {
  background: rgba(6, 30, 32, .9) !important;
  box-shadow: 0 20px 48px rgba(0, 0, 0, .45) !important;
}

/* ============ 其它二级菜单 / 弹窗：同款玻璃，保持一。============ */
html.dsh-obg :is([role="dialog"], [role="menu"], [role="listbox"], [role="tooltip"], [class*="menuSurface"], [class*="MenuSurface"], [class*="_popover"]),
html.dsh-obg [class*="_dialog"]:not([class*="_dialogButton"]):not([class*="_dialogIcon"]) {
  background: rgba(233, 246, 243, .69) !important;
  backdrop-filter: blur(36px) saturate(1.2) !important;
  border: none !important;
  outline: none !important;
  box-shadow: 0 24px 60px rgba(0, 40, 38, .2) !important;
}
html.dsh-obg body[data-ds-dark-theme] :is([role="dialog"], [role="menu"], [role="listbox"], [class*="menuSurface"], [class*="MenuSurface"], [class*="_popover"]),
html.dsh-obg body[data-ds-dark-theme] [class*="_dialog"]:not([class*="_dialogButton"]):not([class*="_dialogIcon"]) {
  background: rgba(6, 28, 30, .68) !important;
  box-shadow: 0 24px 60px rgba(0, 0, 0, .48) !important;
}

/* ============ 表面 token 全面半透：让所有页。菜单/卡片自动变成海洋玻璃 ============ */
html.dsh-obg body {
  --dsw-alias-bg-base: rgba(244, 251, 250, .7) !important;
  --dsw-alias-bg-layer-1: rgba(255, 255, 255, .62) !important;
  --dsw-alias-bg-layer-2: rgba(250, 255, 254, .72) !important;
  --dsw-alias-bg-layer-3: rgba(247, 253, 252, .78) !important;
  --dsw-alias-bg-layer-4: rgba(255, 255, 255, .88) !important;
  --dsw-alias-bg-elevated: rgba(255, 255, 255, .86) !important;
  --dsw-alias-bg-overlay: rgba(250, 255, 254, .78) !important;
  --dsw-alias-bg-document-preview: rgba(255, 255, 255, .66) !important;
  --dsw-menu-surface-fill: rgba(249, 255, 254, .92) !important;
  --dsw-alias-card-fill: rgba(255, 255, 255, .55) !important;
  --dsw-alias-card-fill-hover: rgba(230, 246, 243, .68) !important;
  --dsw-alias-card-tile-fill: rgba(255, 255, 255, .5) !important;
  --dsw-alias-bg-skeleton: rgba(13, 156, 143, .12) !important;
  --obg-comp-rgb: 248, 255, 254;
}
html.dsh-obg body[data-ds-dark-theme] {
  --dsw-alias-bg-base: rgba(6, 20, 24, .62) !important;
  --dsw-alias-bg-layer-1: rgba(8, 26, 30, .56) !important;
  --dsw-alias-bg-layer-2: rgba(8, 28, 32, .68) !important;
  --dsw-alias-bg-layer-3: rgba(10, 32, 36, .72) !important;
  --dsw-alias-bg-layer-4: rgba(12, 38, 42, .8) !important;
  --dsw-alias-bg-elevated: rgba(10, 34, 38, .84) !important;
  --dsw-alias-bg-overlay: rgba(4, 16, 20, .72) !important;
  --dsw-alias-bg-document-preview: rgba(8, 26, 30, .58) !important;
  --dsw-menu-surface-fill: rgba(6, 30, 32, .92) !important;
  --dsw-alias-card-fill: rgba(9, 34, 38, .5) !important;
  --dsw-alias-card-fill-hover: rgba(13, 48, 52, .62) !important;
  --dsw-alias-card-tile-fill: rgba(9, 34, 38, .46) !important;
  --dsw-alias-bg-skeleton: rgba(0, 196, 180, .14) !important;
  --obg-comp-rgb: 6, 26, 30;
}
/* 旧版右下角齿轮按钮：已由 OceanDock 取代，彻底移。*/
#dsh-obg-gear { display: none !important; }

/* 渐隐。JS 精确挂到"消息滚动容器"上，。fadeScroller()：CSS 选择器分不清容器和输入框，一铺就吃人。*/
/* 中栏：同一块玻璃，直角铺满，不留四角「耳朵。*/
html.dsh-obg [data-obg-pane="main"] {
  background: rgba(var(--obg-chat-rgb, 8, 16, 26), var(--obg-chat, .08)) !important;
  border-radius: 0 !important;
  box-shadow: inset 0 0 0 1px rgba(255,255,255,.05);
}

/* 顶栏：不要那条黑。*/
html.dsh-obg [data-windows-titlebar],
html.dsh-obg [data-windows-titlebar] > * { background: transparent !important; }


/* 这块原来是裂谷的根：同一块颜色被叠了两遍——[data-obg-pane="main"] 一层。   [data-obg-glass="main"] 又一层。两个节点范围不一样（后者不含输入区），
   于是消息区深、输入区浅，交界就是一道直边。全页只能有一层载体，统一交给 pane。*/
html.dsh-obg [data-obg-glass="main"]:not([data-obg-pane]) {
  background: transparent !important;
}
html.dsh-obg [data-obg-glass="side"] {
  background: rgba(4, 7, 12, var(--obg-sb, .88)) !important;

}
html.dsh-obg [data-obg-noglass] { background: transparent !important; }
/* 外壳链：这一整条。body 到对话区都不该有底色 */
html.dsh-obg #root,
html.dsh-obg #root > *,
html.dsh-obg .mP3x-q_frame,
html.dsh-obg .mP3x-q_frame > *,
html.dsh-obg .mP3x-q_mainPanel,
html.dsh-obg .mP3x-q_centerCol,
html.dsh-obg .mP3x-q_sidebarCol,
html.dsh-obg [class*="an3WzG_root"],
html.dsh-obg [class*="an3WzG_body"],
html.dsh-obg [class*="an3WzG_viewArea"],
html.dsh-obg [class*="an3WzG_scrollBody"],
html.dsh-obg [class*="an3WzG_mainPanel"],
html.dsh-obg [class*="V4vHZW_"],
html.dsh-obg [class*="wtg9ga_root"] { background: transparent !important; }
html.dsh-obg [data-obg-clear] { background: transparent !important; }
html.dsh-obg [data-obg-fade] { background-image: none !important; }
/* 。CSS 兜底：外壳那几层的实底（顶栏/页签条的底往往是外壳的直系子节点，
   不靠 JS 认类名也能戳穿）。只戳直系子层，不动卡片。*/
html.dsh-obg,
html.dsh-obg body { background: transparent !important; }
html.dsh-obg [class*="centerCol"] > *,
html.dsh-obg [class*="mainPanel"] > *,
html.dsh-obg [class*="frame"] > *,
html.dsh-obg [class*="rightbarCol"] > *,
html.dsh-obg [class*="sidebarCol"] > * {
  background-color: transparent !important;
  background-image: none !important;
}
/* 输入区外层叠了一串半透明底（docks + card + stats 那几层），层层叠加就成了一。裂谷"。   凡是包着输入卡片的祖先，背景统统撤掉，只留字和按钮。   原来。*:has([data-composer-card]) —。那条会让样式引擎在每。DOM 变动后对全文档做一。:has 匹配。   输入流式输出时一直在触发，是卡顿的主因之一。改。JS 一次性把祖先链打。data-obg-shell。*/
html.dsh-obg [data-obg-shell] {
  background: transparent !important;
  background-image: none !important;
  box-shadow: none !important;
  border-color: transparent !important;
}
html.dsh-obg [data-obg-shell]::before,
html.dsh-obg [data-obg-shell]::after {
  background: transparent !important;
  background-image: none !important;
}
html.dsh-obg [class*="tabBar"],
html.dsh-obg [class*="tabs"],
html.dsh-obg [class*="topBar"],
html.dsh-obg [class*="titlebar"],
html.dsh-obg [class*="titleBar"],
html.dsh-obg [class*="header"] {
  background-color: transparent !important;
  background-image: none !important;
}

/* 捋直左上 */
html.dsh-obg [data-obg-pane="side"],
html.dsh-obg [data-obg-pane="top"],
html.dsh-obg [data-obg-pane="top"] > *,
html.dsh-obg .mP3x-q_frame > div {
  border-radius: 0 !important;
}
/* 统一：顶部条和侧栏行都跟对话区同一块底 */
html.dsh-obg [data-obg-pane="main"] header,
html.dsh-obg [data-obg-pane="main"] [class*="header"],
html.dsh-obg [data-obg-pane="main"] [class*="toolbar"],
html.dsh-obg [data-obg-pane="main"] [class*="titleBar"],
html.dsh-obg [data-obg-pane="side"] [class*="row"],
html.dsh-obg [data-obg-pane="side"] [class*="button"],
html.dsh-obg [data-obg-pane="side"] [class*="entry"],
html.dsh-obg [data-obg-pane="side"] [class*="item"] {
  background-color: transparent !important;
  background-image: none !important;
}
html.dsh-obg [data-obg-pane="top"] { background: transparent !important; }
html.dsh-obg [data-obg-clear] { background: transparent !important; }
/* 对话区底部那条黑色渐变遮罩，直接掐掉 */
html.dsh-obg [data-obg-pane="main"] [class*="ade"] { background: transparent !important; }
html.dsh-obg [data-obg-fade],
html.dsh-obg [data-obg-pane="main"] [class*="omposer"] > div {
  background: transparent !important;
  background-image: none !important;
  box-shadow: none !important;
}
/* 输入框：跟侧栏同一套毛玻璃，模糊和浓度都在"海洋设置"里调。   只给唯一的卡片层上玻璃——[class*="omposer"] 可能是外层包壳，
   两层同时上玻璃就又变成叠色，专门盯住这一点。*/
html.dsh-obg [data-obg-pane="main"] [class*="omposer"] {
  background: transparent !important;
  background-image: none !important;
  backdrop-filter: none !important;
  box-shadow: none !important;
  border-color: transparent !important;
}
html.dsh-obg [data-obg-pane="main"] [class*="omposer"] input,
html.dsh-obg [data-obg-pane="main"] [class*="omposer"] textarea {
  background: rgba(10, 18, 28, .28) !important;
}
/* 那条黑渐变的真实职能：遮住滚到输入框下面的内容。   改成给滚动容器本身加遮罩——内容自己淡出，不再靠一块黑去盖。*/
html.dsh-obg [data-obg-pane="main"] [class*="scrollBody"],
html.dsh-obg [data-obg-pane="main"] [class*="scrollArea"] {
  -webkit-mask-image: linear-gradient(to bottom, #000 calc(100% - 130px), rgba(0, 0, 0, 0) 100%);
  mask-image: linear-gradient(to bottom, #000 calc(100% - 130px), rgba(0, 0, 0, 0) 100%);
}
html.dsh-obg [data-composer-card],
html.dsh-obg [data-obg-pane="main"] [class*="omposer"] {
  background: rgba(12, 22, 34, .40) !important;
  border: 1px solid rgba(255, 255, 255, .10) !important;
  box-shadow: none !important;
}

/* 菜单/弹层/卡片：一律淡绿玻璃（高斯模糊 + 半透明青），不再用实色深蓝。
   浅色主题一套、深色主题一套，两套都是"青绿透明的玻璃"，只是底子深浅不同。*/
html.dsh-obg, html.dsh-obg body {
  --dsw-menu-backdrop-filter: blur(24px) saturate(1.25);
  --dsw-specific-menu: rgba(228, 250, 246, .56);
  --dsw-menu-surface-fill: rgba(228, 250, 246, .56);
  --dsw-specific-selector: rgba(214, 246, 240, .60);
  --dsw-specific-tip: rgba(214, 246, 240, .60);

  /* 统一色板：所有「莫名黑」都换成同一块玻璃 */
  --dsw-specific-bubble: rgba(228, 250, 246, .34);
  --dsw-specific-bubble-highlight: rgba(0, 179, 164, .16);
  --dsw-specific-input-major: rgba(232, 252, 248, .40);
  --dsw-specific-sidebar-fill: transparent;
  --dsw-alias-bg-l1: transparent;
  --dsw-alias-bg-l2: transparent;
  --dsw-alias-bg-layer-1: rgba(232, 252, 248, .52);
  --dsw-alias-bg-layer-2: rgba(226, 250, 245, .56);
  --dsw-alias-bg-layer-3: rgba(220, 248, 242, .58);
  --dsw-alias-bg-layer-4: rgba(214, 246, 240, .60);
  --dsw-alias-bg-elevated: rgba(230, 251, 247, .58);
  --dsw-alias-card-fill: rgba(228, 250, 246, .46);
  --dsw-alias-card-fill-hover: rgba(214, 246, 240, .58);
  --dsw-alias-card-tile-fill: rgba(228, 250, 246, .40);
  --dsw-alias-bg-overlay: rgba(228, 250, 246, .58);
  --dsw-alias-bg-module-platform: rgba(222, 249, 243, .56);
  --dsw-alias-button-elevated-fill: rgba(255, 255, 255, .30);
  --dsw-alias-button-floating-fill: rgba(255, 255, 255, .28);
  --dsw-alias-button-floating-hover: rgba(255, 255, 255, .42);
  --dsw-alias-button-ghost-active-fill: rgba(0, 179, 164, .16);
  --dsw-alias-button-tool-bar-fill: rgba(255, 255, 255, .26);
  --dsw-alias-button-tool-bar-fill-invisible: rgba(255, 255, 255, .18);
  --dsw-alias-button-tool-bar-hover: rgba(255, 255, 255, .40);
}

html.dsh-obg body[data-ds-dark-theme] {
  --dsw-menu-backdrop-filter: blur(24px) saturate(1.25);
  --dsw-specific-menu: rgba(6, 40, 38, .56);
  --dsw-menu-surface-fill: rgba(6, 40, 38, .56);
  --dsw-specific-selector: rgba(10, 48, 45, .60);
  --dsw-specific-tip: rgba(10, 48, 45, .60);

  --dsw-specific-bubble: rgba(6, 40, 38, .34);
  --dsw-specific-bubble-highlight: rgba(0, 220, 205, .18);
  --dsw-specific-input-major: rgba(4, 34, 32, .40);
  --dsw-alias-bg-layer-1: rgba(5, 36, 34, .52);
  --dsw-alias-bg-layer-2: rgba(6, 40, 38, .56);
  --dsw-alias-bg-layer-3: rgba(7, 44, 41, .58);
  --dsw-alias-bg-layer-4: rgba(8, 48, 45, .60);
  --dsw-alias-bg-elevated: rgba(6, 38, 36, .58);
  --dsw-alias-card-fill: rgba(5, 36, 34, .46);
  --dsw-alias-card-fill-hover: rgba(9, 46, 43, .58);
  --dsw-alias-card-tile-fill: rgba(5, 34, 32, .40);
  --dsw-alias-bg-overlay: rgba(6, 36, 34, .58);
  --dsw-alias-bg-module-platform: rgba(8, 44, 41, .56);
  --dsw-alias-button-elevated-fill: rgba(255, 255, 255, .08);
  --dsw-alias-button-floating-fill: rgba(255, 255, 255, .08);
  --dsw-alias-button-floating-hover: rgba(255, 255, 255, .14);
  --dsw-alias-button-ghost-active-fill: rgba(255, 255, 255, .12);
  --dsw-alias-button-tool-bar-fill: rgba(255, 255, 255, .08);
  --dsw-alias-button-tool-bar-fill-invisible: rgba(255, 255, 255, .05);
  --dsw-alias-button-tool-bar-hover: rgba(255, 255, 255, .14);
}

/* 代码块：以前的深蓝实底，改成同一套青绿玻璃。 */
html.dsh-obg :is(pre, [class*="codeBlock"], [class*="CodeBlock"], [class*="code-block"]),
html.dsh-obg body[data-ds-dark-theme] :is(pre, [class*="codeBlock"], [class*="CodeBlock"], [class*="code-block"]) {
  background: rgba(6, 44, 42, .62) !important;
  background-image: none !important;
  -webkit-backdrop-filter: blur(18px) saturate(1.2) !important;
  backdrop-filter: blur(18px) saturate(1.2) !important;
  border: 1px solid rgba(0, 220, 205, .16) !important;
  border-radius: 10px !important;
}
html.dsh-obg :is([role="menu"], [class*="_menuSurface"], [class*="MenuSurface"], [class*="_popover"], [class*="_tip"]),
html.dsh-obg body[data-ds-dark-theme] :is([role="menu"], [class*="_menuSurface"], [class*="MenuSurface"], [class*="_popover"], [class*="_tip"]) {
  -webkit-backdrop-filter: blur(24px) saturate(1.25) !important;
  backdrop-filter: blur(24px) saturate(1.25) !important;
}

/* 输入。/ 发送区：一块玻璃，去掉四角多余的边和阴。*/
/* 整块输入区只有一层：底板从输入框上沿起、一路铺到窗口底边，
   上面两个圆角、底下不留边。卡片自己不再有自己的底和边。   所以看不见"卡片压在一条带子上"的那道缝。*/
html.dsh-obg [data-obg-compstack] {
  position: relative !important;
  background: rgba(var(--obg-comp-rgb, 6, 26, 30), var(--obg-comp, .62)) !important;
  background-image: none !important;
  backdrop-filter: blur(var(--obg-comp-blur, 22px)) saturate(1.18) !important;
  border-radius: 0 !important;
  border: none !important;
  box-shadow: 0 -10px 30px rgba(0, 0, 0, .16) !important;
}
/* 上沿形状四档；外凸档的圆角写成椭圆，转向滑杆连续改长轴方向，0°正圆。0°压扁 */
html.dsh-obg[data-obg-corner="convex"] [data-obg-compstack] {
  border-top-left-radius: var(--obg-rx, 22px) var(--obg-ry, 22px) !important;
  border-top-right-radius: var(--obg-rx, 22px) var(--obg-ry, 22px) !important;
}
html.dsh-obg[data-obg-corner="convex"] [data-obg-compstack] {
  border-top-left-radius: var(--obg-rx, 22px) var(--obg-ry, 22px) !important;
  border-top-right-radius: var(--obg-rx, 22px) var(--obg-ry, 22px) !important;
}
html.dsh-obg [data-obg-compstack] [data-composer-card] {
  background: transparent !important;
  background-image: none !important;
  backdrop-filter: none !important;
  border: none !important;
  border-radius: 0 !important;
  box-shadow: none !important;
}
html.dsh-obg [data-composer-card] {
  background: rgba(12,22,34,.40) !important;
  border: 1px solid rgba(255,255,255,.10) !important;
  border-radius: 14px !important;
  box-shadow: none !important;
}
html.dsh-obg [data-composer-card] [class*="corner"],
html.dsh-obg [data-composer-card] [class*="Corner"] {
  display: none !important;
}

/* 海：用半分辨率渲染再放大 2 倍。省 3/4 的像素，边缘自然软，看起来就是磨砂，
   也不用再来一层全。filter（那玩意每帧都在跑，就是卡的元凶）。*/
#dsh-obg-sea {
  position: fixed; left: 0; top: 0; right: 0; bottom: 0;
  width: 100%; height: 100%;
  border: 0; margin: 0; padding: 0;
  z-index: 0; pointer-events: none;
  background: #071019;
}

/* 柔光纱：中间透，四角和底部压一点，文字才压得住 */
#dsh-obg-veil {
  position: fixed; inset: 0; z-index: 0;
  pointer-events: none;
  background: radial-gradient(120% 90% at 50% 40%, rgba(4,9,16,0) 52%, rgba(4,9,16,.22) 100%);
}

/* 全局遮罩：海的上层、Web 界面的下层。整屏一层纯色，浓度由面板控制。*/
#dsh-obg-globalmask {
  position: fixed; inset: 0; z-index: 1;
  pointer-events: none;
  background: rgba(var(--obg-gm-rgb, 0, 92, 84), var(--obg-gm, .22));
  transition: background .18s linear;
}

#dsh-obg-gear {
  position: fixed; right: 120px; bottom: 104px; z-index: 2147483000;
  height: 26px; padding: 0 12px; border-radius: 999px;
  display: flex; align-items: center; justify-content: center;
  font: 12px/1 "Microsoft YaHei", system-ui, sans-serif; letter-spacing: .06em;
  cursor: pointer; user-select: none;
  color: #f2fffd;
  background: linear-gradient(180deg,#00c2b0,#00877c);
  border: 1px solid rgba(255,255,255,.18);
  box-shadow: inset 0 1px 0 rgba(255,255,255,.14);
  opacity: .92; transition: opacity .2s;
}
#dsh-obg-gear:hover { opacity: 1; }

#dsh-obg-panel {
  position: static; flex: 0 0 264px; align-self: stretch;
  height: auto; overflow-y: auto;
  background: rgba(9, 15, 25, .97) !important;
  backdrop-filter: blur(16px);
  box-shadow: inset 0 1px 0 rgba(255,255,255,.08), 0 10px 30px rgba(2,7,14,.45);
  margin-top: auto;
  margin: 8px 10px 10px; max-height: 42vh; overflow-y: auto;
  padding: 12px; border-radius: 12px;
  color: #e9f1fb; font: 12px/1.7 "Microsoft YaHei", system-ui, sans-serif;
  background: rgba(14,22,34,.78);
  border: 1px solid rgba(255,255,255,.12);
  box-shadow: inset 0 1px 0 rgba(255,255,255,.10), 0 18px 44px rgba(2,7,14,.42);
  display: none;
}
#dsh-obg-panel[data-open="1"] { display: block; }
#dsh-obg-panel .obg-h { font-size: 11px; letter-spacing: .08em; opacity: .5; margin: 12px 0 6px; }
#dsh-obg-panel .obg-h:first-child { margin-top: 0; }
#dsh-obg-panel .obg-row { display: flex; align-items: center; gap: 8px; margin: 5px 0; }
#dsh-obg-panel .obg-name { width: 40px; opacity: .78; flex: none; }
#dsh-obg-panel .obg-val { width: 38px; text-align: right; opacity: .6; flex: none; font-variant-numeric: tabular-nums; }
#dsh-obg-panel input[type=range] { flex: 1; height: 16px; accent-color: #00b3a4; }
#dsh-obg-panel .obg-chips { display: flex; flex-wrap: wrap; gap: 6px; }
#dsh-obg-panel .obg-chip {
  padding: 4px 9px; border-radius: 999px; cursor: pointer; user-select: none;
  background: rgba(255,255,255,.06); border: 1px solid rgba(255,255,255,.12);
}
#dsh-obg-panel .obg-chip[data-on="1"] { background: rgba(0,179,164,.30); border-color: rgba(0,220,205,.55); }
/* 对话区遮罩：直接。DSH 原本那层（an3WzG_root 。#151517），只改它的 alpha */
/* 官方那层遮罩：改它自己的 token，而不是另叠一。*/
html.dsh-obg,
html.dsh-obg body {
  --dsw-linear-gradient-think: none !important;
  --dsw-linear-think-select: none !important;
}

/* 遮罩最后声明：必须排在「外壳透明」之后，否则。!important 覆盖。   颜色/浓度都来自设置面板（--obg-chat-rgb / --obg-chat），不写死。*/
html.dsh-obg [data-obg-pane="main"],
html.dsh-obg [data-obg-glass="main"] {
  background: rgba(var(--obg-chat-rgb, 8, 16, 26), var(--obg-chat, .2)) !important;
}
html.dsh-obg [data-obg-pane="side"] {
  background: rgba(4, 7, 12, var(--obg-sb, .88)) !important;
}
`

      const style = document.createElement('style')
      style.id = 'dsh-obg-style'
      style.textContent = css
      document.head.appendChild(style)
    }

    /* ---------- 海面 ---------- */

    function ensureSea() {
      if (seaEl && seaEl.parentNode) return
      const frame = el('iframe')
      frame.id = 'dsh-obg-sea'
      frame.setAttribute('aria-hidden', 'true')
      frame.setAttribute('tabindex', '-1')
      frame.setAttribute('scrolling', 'no')
      /* srcdoc 。blob 稳，同源，能拿到 window.Ocean */
      frame.srcdoc = OCEAN_HTML
      frame.addEventListener('load', function () {
        applySeaBlur()
        applyPreset()
        window.setTimeout(function () { applySeaBlur(); applyPreset() }, 600)
      })
      document.body.appendChild(frame)
      seaEl = frame

      if (!document.getElementById('dsh-obg-veil')) {
        const veil = el('div')
        veil.id = 'dsh-obg-veil'
        veil.setAttribute('aria-hidden', 'true')
        document.body.appendChild(veil)
      }
      if (!document.getElementById('dsh-obg-globalmask')) {
        const gm = el('div')
        gm.id = 'dsh-obg-globalmask'
        gm.setAttribute('aria-hidden', 'true')
        document.body.appendChild(gm)
      }
    }

    function oceanWin() {
      try { return seaEl && seaEl.contentWindow ? seaEl.contentWindow.Ocean : null } catch (e) { return null }
    }

    function applyPreset() {
      try {
        const w = oceanWin()
        if (!w) return
        if (settings.preset && typeof w.setPreset === 'function') w.setPreset(settings.preset)
        if (typeof w.setPaused === 'function') w.setPaused(false)
      } catch (e) {}
    }

    /* ---------- 认领 DSH 自己的两块面。----------
     * 类名带构建哈希（an3WzG_root / wtg9ga_root），升级就变。     * 所以按「位。+ 尺寸 + 不透明深色底」来认，不写死类名。     */
    function tagPanes() {
      const frame = document.querySelector('.mP3x-q_frame') || document.getElementById('root')
      if (!frame) return
      const vw = innerWidth, vh = innerHeight
      /* 先还原上一轮的面板，否则量到的是插件自己铺的透明渐变，认不出原面。*/
      unpaintPanes()
      const old = document.querySelectorAll('[data-obg-pane]')
      for (let i = 0; i < old.length; i++) {
        /* 上一代写。inline !important 底色，会盖过设置滑杆。CSS 变量，一并还。*/
        old[i].removeAttribute('data-obg-pane')
        old[i].style.removeProperty('background')
        if (old[i].__obgBg) { old[i].style.background = old[i].__obgBg; old[i].__obgBg = undefined }
      }
      const clr = document.querySelectorAll('[data-obg-clear]')
      for (let i = 0; i < clr.length; i++) clr[i].removeAttribute('data-obg-clear')
      const cands = []
      frame.querySelectorAll('div, header, section').forEach(function (n) {
        const r = n.getBoundingClientRect()
        if (r.y < 8 && r.height < 90 && r.width > vw * 0.5) {
          n.setAttribute('data-obg-pane', 'top')
          return
        }
        if (r.width < vw * 0.08 || r.height < vh * 0.5) return
        cands.push({ n: n, r: r, area: r.width * r.height })
      })
      /* 只按几何认面板：最左边那条窄的是侧栏，剩下最大的那块是对话区。         不再按底色认——底色已经被我们自己改成透明，按颜色会认不到。*/
      cands.sort(function (a, b) { return b.area - a.area })
      let side = null, main = null
      cands.forEach(function (c) {
        if (!side && c.r.x <= 4 && c.r.width < vw * 0.34) side = c
        else if (!main && c.r.x > vw * 0.05 && c.r.width > vw * 0.4) main = c
      })
      paintPane(side, 'side')
      paintPane(main, 'main')
      if (side) clearInner(side.n)
      if (main) clearInner(main.n)
      if (main) killFades(main.n)
    }

    /* 面板认领之后。2 秒最多补一次：清内层、杀底部渐变。       这一步以前是。250ms 全量跑，渲染进程就是被它拖死的。*/
    /* 性能读数（诊断用）：实测 rAF 帧间隔，滚动窗口约 15 秒。
       面板里那行"性能"读的就是它，用来判断是不是真的在掉帧、掉在哪。 */
    var obgPerf = { dts: [], last: 0, worst: 0, at: 0, txt: '—' }
    ;(function () {
      function tick(t) {
        var p = obgPerf
        if (p.last) {
          var dt = t - p.last
          p.dts.push(dt)
          if (p.dts.length > 900) p.dts.shift()
          if (dt > 40) p.worst++
        }
        p.last = t
        var sec = Math.round(t / 1000)
        if (p.dts.length > 60 && sec !== p.at) {
          p.at = sec
          var sum = 0, mx = 0
          for (var i = 0; i < p.dts.length; i++) { sum += p.dts[i]; if (p.dts[i] > mx) mx = p.dts[i] }
          p.txt = Math.round(1000 / (sum / p.dts.length)) + ' fps · 最慢 ' + Math.round(mx) + ' ms · 卡顿 ' + p.worst
          var el = document.getElementById('obg-perf')
          if (el) el.textContent = p.txt
        }
        requestAnimationFrame(tick)
      }
      requestAnimationFrame(tick)
    })()

    /* ---------- 卡顿取证：把每一次长帧和长任务打到本机 127.0.0.1:8899 ---------- */
    ;(function () {
      var EP = 'http://127.0.0.1:8899/log'
      var q = [], sending = false
      function flush() {
        if (sending || !q.length) return
        sending = true
        var batch = q.splice(0, q.length)
        try {
          fetch(EP, { method: 'POST', mode: 'no-cors', body: JSON.stringify({ t: Date.now(), n: batch.length, ev: batch }) })
            .then(function () { sending = false }, function () { sending = false })
        } catch (e) { sending = false }
      }
      function push(o) { q.push(o); if (q.length > 60) q.shift(); flush() }
      try { window.__obgPush = push } catch (e) {}
      function counts() {
        return {
          pane: document.querySelectorAll('[data-obg-pane]').length,
          glass: document.querySelectorAll('[data-obg-glass]').length,
          stack: document.querySelectorAll('[data-obg-compstack]').length,
          clear: document.querySelectorAll('[data-obg-clear]').length,
          shell: document.querySelectorAll('[data-obg-shell]').length,
          bf: document.querySelectorAll('[data-obg-pane],[data-obg-glass],[data-obg-compstack]').length,
          df: (function () { try { return document.querySelectorAll('*').length } catch (e) { return -1 } })(),
          scroll: (function () {
            var s = document.querySelector('[data-obg-scrollfade]')
            return s ? Math.round(s.scrollTop) : null
          })()
        }
      }
      push({ k: 'boot', ua: navigator.userAgent, scr: [screen.width, screen.height, devicePixelRatio] })
      var last = 0, worst = 0
      function tick(t) {
        if (last) {
          var dt = t - last
          if (dt > 60) {
            var c = counts()
            push({ k: 'stall', dt: Math.round(dt), hid: document.hidden, dr: c.df, bf: c.bf, sc: c.scroll, heap: (performance.memory ? Math.round(performance.memory.usedJSHeapSize / 1048576) : -1) })
            worst = Math.max(worst, dt)
          }
        }
        last = t
        requestAnimationFrame(tick)
      }
      requestAnimationFrame(tick)
      try {
        new PerformanceObserver(function (list) {
          list.getEntries().forEach(function (e) {
            push({ k: 'longtask', d: Math.round(e.duration), nm: String(e.name || '').slice(0, 24) })
          })
        }).observe({ entryTypes: ['longtask'] })
      } catch (e) {}
      setInterval(function () { push({ k: 'beat', worst: Math.round(worst), hid: document.hidden }) }, 15000)
    })()

    let lastSoft = 0, softSig = ''
    function softPass() {
      const now = Date.now()
      if (now - lastSoft < 2000) return
      lastSoft = now
      const side = document.querySelector('[data-obg-pane="side"]')
      const main = document.querySelector('[data-obg-pane="main"]')
      const card = document.querySelector('[data-composer-card]')
      if (side) syncSideEdge()
      /* 下面几步都要遍历子树并逐个 getBoundingClientRect，是最贵的部分。
         以前每 2 秒无条件跑一遍，界面就每隔两秒顿一下。
         现在先比对布局签名，只有侧栏/对话区/输入卡片的尺寸或位置真的变了才做。 */
      const sr = side ? side.getBoundingClientRect() : null
      const mr = main ? main.getBoundingClientRect() : null
      const cr = card ? card.getBoundingClientRect() : null
      const sig = [
        sr ? Math.round(sr.width) + 'x' + Math.round(sr.height) : '-',
        mr ? Math.round(mr.width) + 'x' + Math.round(mr.height) : '-',
        cr ? Math.round(cr.top) + 'x' + Math.round(cr.height) : '-',
        document.body.childElementCount
      ].join('|')
      if (sig === softSig) return
      softSig = sig
      const T = []
      const mark = function (k) { T.push(k + ':' + Math.round(performance.now() - t0)) }
      const t0 = performance.now()
      if (side) { clearInner(side); mark('inner_side') }
      clearTopGlobal(); mark('top')
      paintCompSlab(); mark('slab')
      if (main) { clearInner(main); mark('inner_main'); killFades(main); mark('fade'); fadeScroller(main); mark('scroll') }
      if (window.__obgPush) window.__obgPush({ k: 'pass', ms: T })
    }

    /* 对话区最底部那条黑色渐变：短、贴底、背景是 linear-gradient。       只认这几条特征，掐掉背景图，别的一概不动。*/
    function killFades(pane) {
      const pr = pane.getBoundingClientRect()
      if (!pr.height) return
      pane.querySelectorAll('div').forEach(function (n) {
        if (n.hasAttribute('data-obg-fade')) return
        const r = n.getBoundingClientRect()
        if (r.height > 300 || r.height < 6) return
        if (r.width < pr.width * 0.4) return
        const st = getComputedStyle(n)
        const bg = st.backgroundImage
        if (bg.indexOf('gradient') < 0) return
        /* 只认「往下压暗」的那种：渐变里出现黑色/深色，或者本身就是遮罩条 */
        if (!/rgba?\((0|1|2|3|4|5|6|7|8)\b/.test(bg) && !/gradient\(to bottom/i.test(bg)) return
        n.setAttribute('data-obg-fade', '1')
      })
    }

    /* 渐隐只贴"装消息的那一。，绝不碰输入框。       官方 ConversationRoot 。seat observer 把输入区实测高度写成 --dsh-composer-height（兜。152px），
       输入框长高、下面弹出任务条/挂件时它会自己变，所以这里也吃同一个变量，底边永远贴输入框上沿。       之所以用 JS 挑容器：CSS 选择器认不出哪一层是容器、哪一层包着输入框，一铺就连输入框一起吃掉。*/
    var FADE_MASK = 'linear-gradient(to bottom, #000 calc(100% - var(--dsh-composer-height, 152px) - 120px), rgba(0, 0, 0, .82) calc(100% - var(--dsh-composer-height, 152px) - 72px), rgba(0, 0, 0, .35) calc(100% - var(--dsh-composer-height, 152px) - 28px), rgba(0, 0, 0, 0) calc(100% - var(--dsh-composer-height, 152px) - 2px))'
    /* 海洋设置按钮位置固定，宽度跟侧栏走：量侧栏宽度写进 --obg-side-width，按钮 width 吃这个变量。       用 ResizeObserver 盯侧栏本身，比轮询稳。*/
    var sideRO = null, sideROTarget = null
    function syncSideEdge() {
      const side = document.querySelector('[data-obg-pane="side"]')
      if (!side) return
      const w = Math.round(side.getBoundingClientRect().width)
      document.documentElement.style.setProperty('--obg-side-width', Math.max(60, w) + 'px')
      if (window.ResizeObserver && side !== sideROTarget) {
        if (sideRO) sideRO.disconnect()
        sideROTarget = side
        sideRO = new ResizeObserver(function () { syncSideEdge() })
        sideRO.observe(side)
      }
    }

    /* 顶栏（会话标题、对。轨迹/上下文那排页签）压着一层自己的白底。       虽然样式表里写了 header/class*="header" 透明，但实际那层底壳的类名不叫这个，所以得按几何位置找。       贴着面板顶部、宽度占过半、高。20。60 的实底容器，一律戳穿。*/
    function clearTop(pane) {
      const pr = pane.getBoundingClientRect()
      if (!pr.width) return
      const list = [pane].concat([].slice.call(pane.querySelectorAll('div, header, section, nav')))
      list.forEach(function (n) {
        if (n.hasAttribute('data-obg-pane')) return
        if (n.getAttribute('data-obg-clear') === '1') return
        const r = n.getBoundingClientRect()
        if (r.height < 20 || r.height > 160) return
        if (r.width < pr.width * 0.4) return
        if (r.top > pr.top + 140) return
        const st = getComputedStyle(n)
        if (st.backgroundImage.indexOf('url') >= 0) return
        const m = /rgba?[(](\d+), (\d+), (\d+)(?:, ([\d.]+))?[)]/.exec(st.backgroundColor)
        if (!m) return
        const a = m[4] === undefined ? 1 : Number(m[4])
        if (a < 0.35) return
        n.setAttribute('data-obg-clear', '1')
      })
    }

    /* 顶栏那层白底不一定在 main 面板里面（可能是 centerCol 的兄弟节点），所以按视口位置扫全文档。       贴着视口顶部、宽度占过半、高。20。60、纯色实底的容器，一律戳穿。*/
    function clearTopGlobal() {
      const vw = innerWidth
      /* 以前这里是 document.body.querySelectorAll('div, header, section, nav, aside')，
         一万个节点时一次 75–440ms，就是"卡半秒"的来源。顶栏只可能在 body 往下三层，
         或者类名带 header/topBar/titleBar。候选集从两千多降到几十。 */
      const cands = []
      const seen = new Set()
      const add = function (n) {
        if (!n || seen.has(n)) return
        if (n.getAttribute('data-obg-clear') === '1') return
        seen.add(n); cands.push(n)
      }
      let level = [document.body]
      for (let d = 0; d < 3; d++) {
        const next = []
        for (let i = 0; i < level.length; i++) {
          for (let c = level[i].firstElementChild; c; c = c.nextElementSibling) {
            const tg = c.tagName
            if (tg === 'DIV' || tg === 'HEADER' || tg === 'SECTION' || tg === 'NAV' || tg === 'ASIDE') add(c)
            next.push(c)
          }
        }
        level = next
      }
      ;['[class*="header"]', '[class*="topBar"]', '[class*="titleBar"]', '[role="banner"]'].forEach(function (sel) {
        try { document.querySelectorAll(sel).forEach(add) } catch (e) {}
      })
      cands.forEach(function (n) {
        if (n.hasAttribute('data-obg-pane')) return
        const r = n.getBoundingClientRect()
        if (r.height < 20 || r.height > 160) return
        if (r.width < vw * 0.4) return
        if (r.top > 150) return
        if (r.left > vw * 0.3) return
        const st = getComputedStyle(n)
        if (st.backgroundImage.indexOf('url') >= 0) return
        const m = /rgba?[(](\d+), (\d+), (\d+)(?:, ([\d.]+))?[)]/.exec(st.backgroundColor)
        if (!m) return
        const a = m[4] === undefined ? 1 : Number(m[4])
        if (a < 0.35) return
        n.setAttribute('data-obg-clear', '1')
      })
      document.documentElement.setAttribute('data-obg-clear', '1')
      document.body.setAttribute('data-obg-clear', '1')
    }

    /* 找输入区底座：从卡片往上，第一个高度只比卡片略大、底边贴到窗口底的容器。       记住只取"第一。，继续往上就会爬到整个应用外壳，把全页刷成玻璃。*/
    /* R 角：两段二次贝塞尔，rot 0°=外凸。0°=平切。80°=内凹。70°=平切。60°=外凸 */
    function cornerPath(w, h, r, rot) {
      const k = Math.cos((rot || 0) * Math.PI / 180)
      const c = r * (1 - k) / 2
      const n = 16
      const q = function (x0, y0, cx, cy, x1, y1, u) {
        const v = 1 - u
        return [v * v * x0 + 2 * v * u * cx + u * u * x1, v * v * y0 + 2 * v * u * cy + u * u * y1]
      }
      const pts = []
      for (let i = 0; i <= n; i++) pts.push(q(0, r, c, c, r, 0, i / n))
      for (let i = 0; i <= n; i++) pts.push(q(w - r, 0, w - c, c, w, r, i / n))
      pts.push([w, h], [0, h])
      return 'polygon(' + pts.map(function (p) {
        return p[0].toFixed(1) + 'px ' + p[1].toFixed(1) + 'px'
      }).join(', ') + ')'
    }

    function paintCompSlab() {
      const card = document.querySelector('[data-composer-card]')
      if (!card) return
      const cr = card.getBoundingClientRect()
      let best = null
      let n = card.parentElement
      const chain = []
      while (n && !n.hasAttribute('data-obg-pane') && n !== document.body) {
        chain.push(n)
        const r = n.getBoundingClientRect()
        if (r.height > cr.height && r.height <= cr.height + 132 && r.bottom >= innerHeight - 2) { best = n; break }
        n = n.parentElement
      }
      document.querySelectorAll('[data-obg-compstack]').forEach(function (el) {
        if (el !== best) el.removeAttribute('data-obg-compstack')
      })
      if (best) best.setAttribute('data-obg-compstack', '1')
      /* 输入区祖先链打标记，等价于原来的 *:has([data-composer-card])，但不用让样式引擎反复算 :has */
      const marked = document.querySelectorAll('[data-obg-shell]')
      for (let i = 0; i < marked.length; i++) {
        if (chain.indexOf(marked[i]) < 0) marked[i].removeAttribute('data-obg-shell')
      }
      for (let j = 0; j < chain.length; j++) chain[j].setAttribute('data-obg-shell', '1')
    }

    function fadeScroller(main) {
      if (!main) return
      const root = main.querySelector('[data-conversation-scroll]') || main
      root.querySelectorAll('div').forEach(function (n) {
        const st = getComputedStyle(n)
        if (st.overflowY !== 'auto' && st.overflowY !== 'scroll') return
        if (n.clientHeight < 200) return
        if (n.querySelector('[data-composer-card]') || n.querySelector('[class*="omposer"]')) return
        if (n.querySelector('[data-obg-pane]')) return
        n.style.setProperty('-webkit-mask-image', FADE_MASK)
        n.style.setProperty('mask-image', FADE_MASK)
        n.setAttribute('data-obg-scrollfade', '1')
      })
    }

    /* 面板里面还有一层不透明的底色（wtg9ga_root / an3WzG_root），
       不把这层戳透，海就永远透不上来。只戳「跟面板一样大」的那层。*/
    function clearInner(pane) {
      const pr = pane.getBoundingClientRect()
      const area = pr.width * pr.height
      if (!area) return
      pane.querySelectorAll('div, header, section, main').forEach(function (n) {
        const r = n.getBoundingClientRect()
        if (r.width * r.height < area * 0.85) return
        const st = getComputedStyle(n)
        const m = /rgba?\((\d+), (\d+), (\d+)(?:, ([\d.]+))?\)/.exec(st.backgroundColor)
        if (!m) return
        const a = m[4] === undefined ? 1 : Number(m[4])
        if (a < 0.5) return
        n.setAttribute('data-obg-clear', '1')
      })
    }

    /* 不再。inline 底色：inline !important 盖过样式表，遮罩浓度/黑白滑杆就成了摆设。       底色一律交给样式表里的 var(--obg-chat) / var(--obg-sb)，面板只负责打标记。*/
    let sideNode = null, mainNode = null
    function paintPane(c, tag) {
      if (!c) return
      if (tag === 'side') sideNode = c.n
      if (tag === 'main') mainNode = c.n
      c.n.setAttribute('data-obg-pane', tag)
    }
    function unpaintPanes() {
      ;[sideNode, mainNode].forEach(function (n) {
        if (!n) return
        n.style.removeProperty('background')
        if (n.__obgBg) n.style.background = n.__obgBg
        n.__obgBg = undefined
      })
      sideNode = null
      mainNode = null
    }

    function watchPanes() {
      if (observer) return
      const target = document.querySelector('.mP3x-q_frame') || document.getElementById('root')
      if (!target || !window.MutationObserver) return
      let t = 0
      observer = new MutationObserver(function () {
        clearTimeout(t)
        t = setTimeout(function () {
          /* 面板认领过一次就够了。之后只做低成本补丁，别每次全量重扫。*/
          const side = document.querySelector('[data-obg-pane="side"]')
          const main = document.querySelector('[data-obg-pane="main"]')
          if (side && main) softPass()
          else tagPanes()
        }, 250)
      })
      observer.observe(target, { childList: true, subtree: true })
    }

    /* ---------- 控制面板 ---------- */

    function oceanState() {
      try {
        const w = oceanWin()
        return w && typeof w.state === 'function' ? w.state() : null
      } catch (e) { return null }
    }


    /* 把里层真实的圆角值同步到上玻璃的那一层，玻璃沿着同一条曲线裁 */
    function squareBig() {
      try {
        var vw = innerWidth, vh = innerHeight
        var panes = document.querySelectorAll('[data-obg-pane="side"], [data-obg-pane="main"]')
        for (var p = 0; p < panes.length; p++) {
          var pane = panes[p]
          var best = 0
          var kids = pane.querySelectorAll('div, section, main')
          for (var i = 0; i < kids.length; i++) {
            var el = kids[i]
            var r = el.getBoundingClientRect()
            if (r.width < vw * 0.30 || r.height < vh * 0.30) continue
            var cs = getComputedStyle(el)
            var v = parseFloat(cs.borderTopLeftRadius) || 0
            var v2 = parseFloat(cs.borderBottomLeftRadius) || 0
            var v3 = parseFloat(cs.borderTopRightRadius) || 0
            var v4 = parseFloat(cs.borderBottomRightRadius) || 0
            best = Math.max(best, v, v2, v3, v4)
          }
          if (best > 0) {
            /* 找到这个自带圆角的最大节点，玻璃只挂它，外层让出。*/
            var host = null
            for (var k = 0; k < kids.length; k++) {
              var kk = kids[k]
              var kr = kk.getBoundingClientRect()
              if (kr.width < vw * 0.30 || kr.height < vh * 0.30) continue
              var kcs = getComputedStyle(kk)
              if ((parseFloat(kcs.borderTopLeftRadius) || 0) >= best - 0.5) { host = kk; break }
            }
            if (host) host.setAttribute('data-obg-clear', '1')
          }
        }
      } catch (e) {}
    }

    function buildControl() {
      return /* 已废弃：改用 DSH 插槽渲染，见文件末尾 OceanDock */
      /* 先清掉上一版留下的按钮和面板，再建新的 */
      ;['dsh-obg-panel', 'dsh-obg-gear'].forEach(function (id) {
        const olds = document.querySelectorAll('#' + id)
        for (let i = 0; i < olds.length; i++) olds[i].remove()
      })
      gearEl = null
      panelEl = null

      if (gearEl && gearEl.isConnected) return
      gearEl = el('div', '', '海洋')
      gearEl.id = 'dsh-obg-gear'
      gearEl.title = '海洋设置（Ctrl+Shift+O）'
      gearEl.style.cssText = [
        'position:fixed', 'z-index:2147483646',
        'display:flex', 'align-items:center', 'height:26px', 'padding:0 12px',
        'border-radius:999px', 'font:12px/1 "Microsoft YaHei",system-ui,sans-serif',
        'letter-spacing:.06em', 'color:#dce9f7', 'background:rgba(18,30,44,.78)',
        'border:1px solid rgba(255,255,255,.22)', 'cursor:pointer', 'user-select:none'
      ].join(';')
      gearEl.addEventListener('click', function () { togglePanel() })
      document.documentElement.appendChild(gearEl)
      try {
        var r0 = gearEl.getBoundingClientRect()
      } catch (e) {}

      panelEl = el('div')
      panelEl.id = 'dsh-obg-panel'
      panelEl.setAttribute('data-open', '1')
      panelEl.style.display = 'none'
      panelEl.style.cssText = 'display:block'
      const frame = document.querySelector('.mP3x-q_frame')
      if (frame) frame.appendChild(panelEl)
      else document.body.appendChild(panelEl)

      /* 这个壳里固定定位只有贴顶那一段能稳定画出来，入口就放在右上角 */
      function place() {
        try {
          gearEl.style.right = '120px'
          gearEl.style.bottom = '104px'
          panelEl.style.position = 'static'
        } catch (e) {}
      }
      place()
      window.addEventListener('resize', place)

      /* 键盘也能开：右下角那颗按钮万一被别的东西压住，还有这条。*/
      if (window.__obgKey) window.removeEventListener('keydown', window.__obgKey)
      window.__obgKey = function (ev) {
        if (ev.ctrlKey && ev.shiftKey && (ev.key === 'O' || ev.key === 'o')) {
          ev.preventDefault()
          togglePanel()
        }
      }
      window.addEventListener('keydown', window.__obgKey)
    }

    function togglePanel() {
      if (!panelEl) return
      /* 被别处扫掉、还留在内存里的情况：先挂回去再开 */
      const fr = document.querySelector('.mP3x-q_frame') || document.body
      if (panelEl.parentNode !== fr) fr.appendChild(panelEl)
      panelEl.style.position = 'fixed'
      panelEl.style.left = 'auto'
      panelEl.style.right = '16px'
      panelEl.style.top = '56px'
      panelEl.style.width = '240px'
      const open = panelEl.getAttribute('data-open') === '1'
      panelEl.setAttribute('data-open', open ? '0' : '1')
      panelEl.style.display = open ? 'none' : 'block'
      if (!open) refreshPanel()
    }

    /* 磨砂靠外面那层半分辨率放大来软（每帧零成本）。       海文档里不要再加 filter —。全屏滤镜每帧重算，就是卡顿的来源。*/
    function applySeaBlur() {
      try {
        const d = seaEl && seaEl.contentDocument
        if (!d || !d.head) return
        let st = d.getElementById('dsh-obg-scope')
        if (!st) {
          st = d.createElement('style')
          st.id = 'dsh-obg-scope'
          d.head.appendChild(st)
        }
        st.textContent =
          'html,body{overflow:hidden!important;background:#071019!important}' +
          'body{transform:scale(1.03);transform-origin:50% 50%}'
      } catch (e) {}
    }

    function ctlApi() {
      return {
        get: function () { return Object.assign({}, settings) },
        set: function (key, value) {
          settings[key] = value
          saveSettings()
          applyLook()
        },
        presets: function () {
          const w = oceanWin()
          const list = (w && w.presets) || []
          return list.filter(function (n) { return typeof n === 'string' })
        },
        setPreset: function (name) {
          settings.preset = name
          saveSettings()
          try { const w = oceanWin(); if (w && w.setPreset) w.setPreset(name) } catch (e) {}
        },
        state: function () {
          const w = oceanWin()
          return (w && typeof w.state === 'function' && w.state()) || {}
        },
        waves: function () { return WAVES.map(function (b) { return [b[0], b[1], b[2], b[3]] }) },
        setWave: function (key, value) {
          const w = oceanWin()
          if (!w) return
          const st = (typeof w.state === 'function' && w.state()) || {}
          const out = { key: value }
          const payload = {}
          WAVES.forEach(function (p) { payload[p[0]] = typeof st[p[0]] === 'number' ? st[p[0]] : 0 })
          payload[key] = value
          try { w.setWaves(payload) } catch (e) {}
        },
        togglePause: function () {
          const w = oceanWin()
          const st = (w && w.state && w.state()) || {}
          try { w.setPaused(!st.paused) } catch (e) {}
        },
        toggleOrbit: function () {
          const w = oceanWin()
          const st = (w && w.state && w.state()) || {}
          try { w.setAutoOrbit(!st.autoOrbit) } catch (e) {}
        }
      }
    }

    function applyLook() {
      try {
        applySeaBlur()
        /* 模糊滑杆不再。filter：改成降低渲染分辨率再放大，
           一次改尺寸、之后每帧零成本，肉眼看就是更糊。*/
        const root = document.documentElement.style
        const num = function (v, dft) {
          const n = Number(v)
          return isFinite(n) ? n : dft
        }
        root.setProperty('--obg-chat', String(num(settings.chat, 20) / 100))
        root.setProperty('--obg-chat-rgb', settings.chatRgb || '8, 16, 26')
        /* 全局遮罩：压在海之上、界面之下的一整层。颜色四选一，浓度独立。 */
        const gmMap = { none: null, black: '0, 0, 0', white: '255, 255, 255', teal: '0, 92, 84' }
        const gmMode = gmMap[settings.gm] === undefined ? 'teal' : settings.gm
        const gmRgb = gmMap[gmMode]
        root.setProperty('--obg-gm-rgb', gmRgb || '0, 92, 84')
        root.setProperty('--obg-gm', gmMode === 'none' ? '0' : String(num(settings.gmAmt, 22) / 100))
        document.documentElement.setAttribute('data-obg-gm', gmMode)
        root.setProperty('--obg-sb', String(num(settings.sb, 55) / 100))
        root.setProperty('--obg-sb-blur', num(settings.sbBlur, 30) + 'px')
        /* 输入框跟侧栏用同一套毛玻璃：一个开关，开了就吃侧栏的两个。*/
        const syncComp = settings.compSync !== false
        const compV = syncComp ? num(settings.sb, 55) : num(settings.comp, 62)
        const compBV = syncComp ? num(settings.sbBlur, 30) : num(settings.compBlur, 22)
        root.setProperty('--obg-comp', String(compV / 100))
        root.setProperty('--obg-comp-blur', compBV + 'px')
        document.documentElement.setAttribute('data-obg-corner', settings.corner || 'convex')
        root.setProperty('--obg-comp-radius', num(settings.cornerR, 18) + 'px')
        const rBase = Math.max(0, num(settings.cornerR, 22))
        const rCos = Math.cos(num(settings.cornerRot, 0) * Math.PI / 180)
        root.setProperty('--obg-rx', Math.max(0, rBase * (1 + 0 * rCos)).toFixed(1) + 'px')
        root.setProperty('--obg-ry', Math.max(0, rBase * (1 - 0 * rCos)).toFixed(1) + 'px')
        try { paintCompSlab() } catch (e) {}
        const t = Math.max(0, Math.min(100, settings.tint)) / 100
        document.documentElement.style.setProperty('--obg-a', String(0.34 + t * 0.34).slice(0, 5))
        document.documentElement.style.setProperty('--obg-a2', String(0.42 + t * 0.34).slice(0, 5))
      } catch (e) {}
    }

    function refreshPanel() {
      if (!panelEl) return
      panelEl.textContent = ''
      const w = oceanWin()
      const st = (w && typeof w.state === 'function') ? (w.state() || {}) : {}

      panelEl.appendChild(el('div', 'obg-h', '对话区遮罩'))
      const shade = el('div', 'obg-chips')
      ;[['无', '8, 16, 26'], ['白', '255, 255, 255']].forEach(function (pair) {
        const chip = el('div', 'obg-chip', pair[0])
        chip.setAttribute('data-on', String(settings.chatRgb || '8, 16, 26') === pair[1] ? '1' : '0')
        chip.addEventListener('click', function () {
          settings.chatRgb = pair[1]
          saveSettings(); applyLook(); refreshPanel()
        })
        shade.appendChild(chip)
      })
      panelEl.appendChild(shade)
      panelEl.appendChild(slider('chat', '浓度', 0, 60, 1, settings.chat, function (v) {
        settings.chat = v; saveSettings(); applyLook()
      }))

      panelEl.appendChild(el('div', 'obg-h', '侧栏毛玻璃'))
      panelEl.appendChild(slider('sbBlur', '模糊', 0, 40, 1, settings.sbBlur, function (v) {
        settings.sbBlur = v; saveSettings(); applyLook()
      }))
      panelEl.appendChild(slider('sb', '浓度', 40, 100, 1, settings.sb, function (v) {
        settings.sb = v; saveSettings(); applyLook()
      }))

      panelEl.appendChild(el('div', 'obg-h', '海水'))

      /* 时刻：Ocean.presets 是名字数组，之前读错了字段，所以这几颗按钮「消失」了 */
      panelEl.appendChild(el('div', 'obg-h', '时刻'))
      const names = [].concat((w && w.presets) || [], st.presets || [])
        .filter(function (n) { return typeof n === 'string' })
      const chips = el('div', 'obg-chips')
      names.forEach(function (name) {
        const c = el('div', 'obg-chip', name)
        c.setAttribute('data-on', st.preset === name ? '1' : '0')
        c.addEventListener('click', function () {
          settings.preset = name
          saveSettings()
          try { w.setPreset(name) } catch (e) {}
          refreshPanel()
        })
        chips.appendChild(c)
      })
      if (!names.length) chips.appendChild(el('div', 'obg-chip', '海还没加载好'))
      panelEl.appendChild(chips)

      panelEl.appendChild(el('div', 'obg-h', '海浪'))
      WAVES.forEach(function (b) {
        const key = b[0]
        const cur = typeof st[key] === 'number' ? st[key] : 0
        panelEl.appendChild(slider(key, b[1], b[2], b[3], 0.05, cur, function (v) {
          try { w.setWaves(withWaves(key, v)) } catch (e) {}
        }))
      })

      panelEl.appendChild(el('div', 'obg-h', '播放'))
      const row = el('div', 'obg-chips')
      const pause = el('div', 'obg-chip', st.paused ? '继续' : '暂停')
      pause.addEventListener('click', function () {
        try { w.setPaused(!st.paused) } catch (e) {}
        window.setTimeout(refreshPanel, 80)
      })
      row.appendChild(pause)
      const orbit = el('div', 'obg-chip', st.autoOrbit ? '环绕 开' : '环绕 关')
      orbit.addEventListener('click', function () {
        try { w.setAutoOrbit(!st.autoOrbit) } catch (e) {}
        window.setTimeout(refreshPanel, 80)
      })
      row.appendChild(orbit)
      panelEl.appendChild(row)
    }

    function withWaves(key, value) {
      const w = oceanWin()
      const st = w && typeof w.state === 'function' ? w.state() : {}
      const out = {}
      WAVES.forEach(function (p) { out[p[0]] = typeof st[p[0]] === 'number' ? st[p[0]] : 0 })
      out[key] = value
      return out
    }

    function slider(key, label, min, max, step, value, onInput) {
      const row = el('div', 'obg-row')
      row.appendChild(el('span', 'obg-name', label))
      const input = document.createElement('input')
      input.type = 'range'
      input.min = String(min)
      input.max = String(max)
      input.step = String(step)
      input.value = String(value)
      row.appendChild(input)
      const val = el('span', 'obg-val', Number(value).toFixed(2))
      row.appendChild(val)
      input.addEventListener('input', function () {
        const v = Number(input.value)
        val.textContent = v.toFixed(2)
        onInput(v)
      })
      return row
    }

    /* ---------- 挂载 ---------- */

    const GEN = (window.__obgGen = (window.__obgGen || 0) + 1)

    function mount() {
      if (mounted) return
      mounted = true
      function step(name, fn) {
        try { fn() } catch (e) { console.warn('[dsh-ocean-bg] ' + name, e) }
      }
      step('settings', loadSettings)
      /* 上一轮热重载留下的节点先清掉，不然一夜下来会叠十几层 */
      step('sweep', function () {
        ;['dsh-obg-style', 'dsh-obg-sea', 'dsh-obg-veil', 'dsh-obg-gear', 'dsh-obg-panel'].forEach(function (id) {
          document.querySelectorAll('#' + id).forEach(function (n) { n.remove() })
        })
        seaEl = null; gearEl = null; panelEl = null
      })
      step('class', function () {
        document.documentElement.classList.add('dsh-obg')
        console.log('[dsh-ocean-bg] mounted gen', GEN)
      })
      step('style', buildStyle)
      step('sea', ensureSea)
      step('look', applyLook)
      step('square', squareBig)
      step('control', buildControl)
      step('panes', tagPanes)
      step('watch', watchPanes)
      step('topclear', clearTopGlobal)
    }

    function unmount() {
      mounted = false
      /* 已经有更新的一代接手了，别去拆它建好的节点 */
      if (window.__obgGen !== GEN) return
      if (observer) { try { observer.disconnect() } catch (e) {} }
      observer = null
      const root = document.documentElement
      root.classList.remove('dsh-obg')
      ;['dsh-obg-style', 'dsh-obg-sea', 'dsh-obg-veil', 'dsh-obg-gear', 'dsh-obg-panel'].forEach(function (id) {
        const n = document.getElementById(id)
        if (n && n.parentNode) n.parentNode.removeChild(n)
      })
      seaEl = null; gearEl = null; panelEl = null
    }

    const React = (function () {
      try { return require('react') } catch (e) { return null }
    })()

    function OceanDock() {
      const h = React.createElement
      const [open, setOpen] = React.useState(false)
      const [s, setS] = React.useState(function () {
        try { return settings } catch (e) { return {} }
      })

      function upd(key, value) {
        const next = Object.assign({}, s)
        next[key] = value
        setS(next)
        try {
          const r = document.documentElement.style
          if (key === 'gm') {
            const gmMap2 = { none: null, black: '0, 0, 0', white: '255, 255, 255', teal: '0, 92, 84' }
            const m2 = gmMap2[value] === undefined ? 'teal' : value
            document.documentElement.setAttribute('data-obg-gm', m2)
            r.setProperty('--obg-gm-rgb', gmMap2[m2] || '0, 92, 84')
            r.setProperty('--obg-gm', m2 === 'none' ? '0' : String(Number(next.gmAmt == null ? 22 : next.gmAmt) / 100))
          }
          if (key === 'gmAmt') {
            const m3 = next.gm || 'teal'
            r.setProperty('--obg-gm', m3 === 'none' ? '0' : String(Number(value) / 100))
          }
          if (key === 'chat') r.setProperty('--obg-chat', String(Number(value) / 100))
          if (key === 'chatRgb') r.setProperty('--obg-chat-rgb', String(value))
          if (key === 'sb') r.setProperty('--obg-sb', String(Number(value) / 100))
          if (key === 'sbBlur') r.setProperty('--obg-sb-blur', Number(value) + 'px')
          /* 输入框跟侧栏同步时，动侧栏就等于动输入框 */
          const sync = next.compSync !== false
          if (key === 'sb' && sync) r.setProperty('--obg-comp', String(Number(value) / 100))
          if (key === 'sbBlur' && sync) r.setProperty('--obg-comp-blur', Number(value) + 'px')
          if (key === 'compSync') {
            const sbV = Number(next.sb == null ? 55 : next.sb)
            const sbB = Number(next.sbBlur == null ? 30 : next.sbBlur)
            if (sync) {
              r.setProperty('--obg-comp', String(sbV / 100))
              r.setProperty('--obg-comp-blur', sbB + 'px')
            } else {
              r.setProperty('--obg-comp', String(Number(next.comp == null ? 62 : next.comp) / 100))
              r.setProperty('--obg-comp-blur', Number(next.compBlur == null ? 22 : next.compBlur) + 'px')
            }
          }
    if (key === 'comp') r.setProperty('--obg-comp', String(Number(value) / 100))
    if (key === 'compBlur') r.setProperty('--obg-comp-blur', Number(value) + 'px')
    if (key === 'cornerR') r.setProperty('--obg-comp-radius', Number(value) + 'px')
    if (key === 'cornerR' || key === 'cornerRot') {
      const rB = Number(settings.cornerR != null ? settings.cornerR : 22)
      const rC = Math.cos(Number(settings.cornerRot || 0) * Math.PI / 180)
      if (key === 'cornerR') r.setProperty('--obg-comp-radius', rB + 'px')
      r.setProperty('--obg-rx', Math.max(0, rB * (1 + 0 * rC)).toFixed(1) + 'px')
      r.setProperty('--obg-ry', Math.max(0, rB * (1 - 0 * rC)).toFixed(1) + 'px')
    }
    if (key === 'corner') document.documentElement.setAttribute('data-obg-corner', String(value))
        } catch (e) {}
        try { window.__obgCtl.set(key, value) } catch (e) {}
      }

      function row(label, node) {
        return h('div', { style: { display: 'flex', alignItems: 'center', gap: 8, margin: '4px 0' } },
          h('span', { style: { width: 42, opacity: .7, fontSize: 11 } }, label), node)
      }

      function range(key, min, max, step, shownValue, onChange) {
        return h('input', {
          type: 'range', min: min, max: max, step: step,
          value: shownValue != null ? shownValue : (s[key] == null ? min : s[key]),
          style: { flex: 1, accentColor: '#00b3a4' },
          onChange: onChange || function (ev) { upd(key, Number(ev.target.value)) }
        })
      }

      function chip(text, on, onClick) {
        return h('span', {
          onClick: onClick,
          style: {
            padding: '3px 9px', borderRadius: 999, cursor: 'pointer', fontSize: 11,
            background: on ? 'rgba(0,179,164,.34)' : 'rgba(0,120,110,.20)',
            border: '1px solid ' + (on ? 'rgba(0,220,205,.65)' : 'rgba(120,220,210,.22)')
          }
        }, text)
      }

      const panel = open ? h('div', {
        style: {
          width: 252, padding: 12, borderRadius: 12, marginBottom: 8,
          background: 'rgba(3,32,31,.96)', color: '#e6fffb',
          border: '1px solid rgba(0,190,175,.32)',
          font: '12px/1.6 "Microsoft YaHei",system-ui,sans-serif'
        }
      },
        h('div', { style: { opacity: .55, fontSize: 11, marginBottom: 4 } }, '全局遮罩'),
        h('div', { style: { display: 'flex', gap: 6, marginBottom: 4, flexWrap: 'wrap' } },
          chip('无', (s.gm || 'teal') === 'none', function () { upd('gm', 'none') }),
          chip('黑', (s.gm || 'teal') === 'black', function () { upd('gm', 'black') }),
          chip('白', (s.gm || 'teal') === 'white', function () { upd('gm', 'white') }),
          chip('主题绿', (s.gm || 'teal') === 'teal', function () { upd('gm', 'teal') })),
        row('浓度', range('gmAmt', 0, 90, 1)),
        h('div', { style: { opacity: .55, fontSize: 11, margin: '8px 0 4px' } }, '侧栏毛玻璃'),
        row('模糊', range('sbBlur', 0, 40, 1)),
        row('浓度', range('sb', 0, 100, 1)),
        h('div', { style: { opacity: .55, fontSize: 11, margin: '8px 0 4px' } }, '输入框毛玻璃'),
        h('div', { style: { display: 'flex', gap: 6, flexWrap: 'wrap', margin: '0 0 4px' } },
          chip('跟侧栏一致', s.compSync !== false, function () { upd('compSync', true) }),
          chip('单独设置', s.compSync === false, function () { upd('compSync', false) })),
        row('模糊', range('compBlur', 0, 40, 1,
          s.compSync !== false ? (s.sbBlur == null ? 30 : s.sbBlur) : null,
          function (ev) { upd('compSync', false); upd('compBlur', Number(ev.target.value)) })),
        row('浓度', range('comp', 0, 100, 1,
          s.compSync !== false ? (s.sb == null ? 55 : s.sb) : null,
          function (ev) { upd('compSync', false); upd('comp', Number(ev.target.value)) })),
        h('div', { style: { opacity: .55, fontSize: 11, margin: '8px 0 4px' } }, '输入框上沿'),
        h('div', { style: { display: 'flex', gap: 6, flexWrap: 'wrap' } },
          [['圆角', 'convex'], ['直角', 'sharp']].map(function (p) {
            return chip(p[0], (s.corner || 'convex') === p[1], function () { upd('corner', p[1]) })
          })),
        row('圆角', range('cornerR', 0, 40, 1)),
        h('div', { style: { opacity: .55, fontSize: 11, margin: '8px 0 4px' } }, '时刻'),
        h('div', { style: { display: 'flex', gap: 6, flexWrap: 'wrap' } },
          ['正午', '黄昏', '极夜'].map(function (n) {
            return chip(n, s.preset === n, function () {
              upd('preset', n)
              try { window.__obgCtl.setPreset(n) } catch (e) {}
            })
          })),

        h('div', { style: { opacity: .55, fontSize: 11, margin: '8px 0 4px' } }, '性能'),
        h('div', { id: 'obg-perf', style: { fontSize: 11, opacity: .8 } }, obgPerf.txt),

        h('div', { style: { opacity: .55, fontSize: 11, margin: '8px 0 4px' } }, '海浪'),
        (function () {
          let list = []
          try { list = window.__obgCtl.waves() } catch (e) {}
          let st = {}
          try { st = window.__obgCtl.state() } catch (e) {}
          return list.map(function (b) {
            const cur = typeof st[b[0]] === 'number' ? st[b[0]] : 0
            return h('div', { key: b[0], style: { display: 'flex', alignItems: 'center', gap: 8, margin: '3px 0' } },
              h('span', { style: { width: 42, opacity: .7, fontSize: 11 } }, b[1]),
              h('input', {
                type: 'range', min: b[2], max: b[3], step: 0.05, value: cur,
                style: { flex: 1, accentColor: '#00b3a4' },
                onChange: function (ev) {
                  try { window.__obgCtl.setWave(b[0], Number(ev.target.value)) } catch (e) {}
                }
              }))
          })
        })(),

        h('div', { style: { opacity: .55, fontSize: 11, margin: '8px 0 4px' } }, '播放'),
        h('div', { style: { display: 'flex', gap: 6 } },
          chip('暂停 / 继续', false, function () { try { window.__obgCtl.togglePause() } catch (e) {} }),
          chip('环绕 开 / 关', false, function () { try { window.__obgCtl.toggleOrbit() } catch (e) {} }))
      ) : null

      return h('div', {
        style: {
          position: 'fixed', left: 10, bottom: 96, zIndex: 2147483000,
          display: 'flex', flexDirection: 'column', alignItems: 'stretch',
          width: 'calc(var(--obg-side-width, 262px) - 20px)', minWidth: 96, maxWidth: 300,
          font: '12px/1.6 "Microsoft YaHei",system-ui,sans-serif'
        }
      },
        panel,
        h('span', {
          onClick: function () { setOpen(!open) },
          style: {
            padding: '7px 0', borderRadius: 10, cursor: 'pointer', userSelect: 'none',
            fontSize: 12, color: '#f2fffd', textAlign: 'center',
            background: 'linear-gradient(180deg,#00c2b0,#00877c)',
            border: '1px solid rgba(255,255,255,.16)'
          }
        }, open ? '海洋设置  收起' : '海洋设置')
      )
    }

    return {
      inject: ['slots'],
      apply: function (ctx) {
        try {
          if (ctx && ctx.slots && ctx.slots.inject && React) {
            ctx.slots.inject('shell.overlay', function () {
              return ctx.slots.register({
                name: 'shell.overlay',
                id: 'dsh-ocean-bg-dock',
                order: 5
              }, OceanDock)
            })
          }
        } catch (e) {
          console.warn('[dsh-ocean-bg] slot register failed', e)
        }
        if (bootDone) return
        bootDone = true
        try { window.__obgCtl = ctlApi() } catch (e) {}
        try {
          if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', mount, { once: true })
            window.setTimeout(function () { if (!mounted) mount() }, 1500)
          } else {
            mount()
          }
        } catch (e) {
          console.warn('[dsh-ocean-bg] apply failed', e)
        }
      }
    }
  }
})
