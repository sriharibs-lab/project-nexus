// landing-kit.jsx — Nexus iOS landing surface primitives (light, ACCENT-FREE)
// The only colour on this surface is the soft plum bloom in the page background.
// Everything else is ink / muted / faint / hairline — hierarchy from weight alone.
// One ink-filled affordance (the audio button) gives the composer a single anchor.
// Exports (to window): lTheme, LIcon, LAvatar, LHeader, LDock, LPlusMenu,
//   LModelMenu, LAvatarMenu, LCollectionCard, LItemRow, LScreen, LStatusSpacer

// ── Theme: light only, neutral. No `accent` key by design. ──
function lTheme() {
  return {
    page: 'radial-gradient(135% 60% at 50% -8%, #E7DCF4 0%, #F9F8FC 50%)',
    surface: '#FFFFFF', surface2: '#F4F2F9', surface3: '#FBFAFD',
    text: '#130E1A', muted: '#68607A', faint: '#9A93AC', ghost: '#B7B1C4',
    border: '#E9E5F2', borderStrong: '#DCD7EA', hair: '#EEEBF5',
    ink: '#130E1A', inkInk: '#FFFFFF',
  };
}
const L_FONT = '-apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif';

// ── Thin geometric stroke icons (1.6px) — neutral, matches hairline aesthetic ──
function LIcon({ name, size = 22, color = 'currentColor', stroke = 1.6 }) {
  const p = { fill: 'none', stroke: color, strokeWidth: stroke, strokeLinecap: 'round', strokeLinejoin: 'round' };
  const paths = {
    search: <><circle cx="11" cy="11" r="7" {...p} /><path d="m20 20-3.4-3.4" {...p} /></>,
    plus: <path d="M12 5v14M5 12h14" {...p} />,
    mic: <><rect x="9" y="3" width="6" height="12" rx="3" {...p} /><path d="M5 11a7 7 0 0 0 14 0M12 18v3" {...p} /></>,
    sliders: <><path d="M4 7h9m4 0h3M4 17h3m4 0h9" {...p} /><circle cx="15" cy="7" r="2.2" {...p} /><circle cx="9" cy="17" r="2.2" {...p} /></>,
    chevDown: <path d="m6 9 6 6 6-6" {...p} />,
    chevR: <path d="m9 5 7 7-7 7" {...p} />,
    photo: <><rect x="3" y="4" width="18" height="16" rx="3" {...p} /><circle cx="8.5" cy="9.5" r="1.6" {...p} /><path d="m4 17 5-5 4 4 3-3 4 4" {...p} /></>,
    file: <><path d="M7 3h7l4 4v14H7a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1Z" {...p} /><path d="M14 3v4h4" {...p} /></>,
    camera: <><path d="M4 8a2 2 0 0 1 2-2h1.5l1.2-1.6a1 1 0 0 1 .8-.4h5a1 1 0 0 1 .8.4L17.5 6H19a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2Z" {...p} /><circle cx="12" cy="12.5" r="3.4" {...p} /></>,
    link: <><path d="M9.5 14.5 14.5 9.5" {...p} /><path d="M8 11 6 13a3.5 3.5 0 0 0 5 5l2-2" {...p} /><path d="M16 13l2-2a3.5 3.5 0 0 0-5-5l-2 2" {...p} /></>,
    globe: <><circle cx="12" cy="12" r="9" {...p}/><path d="M3 12h18" {...p}/><path d="M12 3C8 5 8 19 12 21M12 3C16 5 16 19 12 21" {...p}/></>,
    video: <><rect x="3" y="5.5" width="18" height="13" rx="3.5" {...p} /><path d="M10.5 9.3v5.4l4.4-2.7-4.4-2.7Z" fill={color} stroke={color} strokeWidth="1.2" strokeLinejoin="round" /></>,
    note: <><path d="M5 4h11l3 3v13H5Z" {...p} /><path d="M8 10h8M8 14h6" {...p} /></>,
    layers: <><path d="M12 3 21 8l-9 5-9-5 9-5Z" {...p} /><path d="M3 13l9 5 9-5" {...p} /></>,
    layersFill: <><path d="M12 3 21 8l-9 5-9-5 9-5Z" fill={color} stroke={color} strokeWidth="1.4" strokeLinejoin="round" /><path d="M3 13l9 5 9-5" {...p} /></>,
    folder: <path d="M3 7a1 1 0 0 1 1-1h5l2 2h8a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1Z" {...p} />,
    grid: <><rect x="4" y="4" width="7" height="7" rx="1.4" {...p} /><rect x="13" y="4" width="7" height="7" rx="1.4" {...p} /><rect x="4" y="13" width="7" height="7" rx="1.4" {...p} /><rect x="13" y="13" width="7" height="7" rx="1.4" {...p} /></>,
    clock: <><circle cx="12" cy="12" r="9" {...p} /><path d="M12 7v5l3 2" {...p} /></>,
    check: <path d="m5 12.5 4.5 4.5L19 7" {...p} />,
    quiz: <><path d="M4.5 6.5 6 8l2.5-3" {...p} /><path d="M12.5 7H20" {...p} /><path d="M4.5 15.5 6 17l2.5-3" {...p} /><path d="M12.5 16H20" {...p} /></>,
    play: <path d="M8 5.5v13l11-6.5-11-6.5Z" fill={color} stroke={color} strokeWidth="1.4" strokeLinejoin="round" />,
    sparkOutline: <path d="M12 3.2c.4 6 2.6 8.2 8.6 8.6-6 .4-8.2 2.6-8.6 8.6-.4-6-2.6-8.2-8.6-8.6 6-.4 8.2-2.6 8.6-8.6Z" {...p} />,
    nexus: <><g {...p}><path d="M9.25 8 A5.5 5.5 0 0 0 9.25 16" /><path d="M14.75 8 A5.5 5.5 0 0 1 14.75 16" /></g><g {...p} opacity="0.35"><path d="M6.75 4.75 A8.75 8.75 0 0 0 6.75 19.25" /><path d="M17.25 4.75 A8.75 8.75 0 0 1 17.25 19.25" /></g><circle cx="12" cy="12" r="2.3" fill={color} stroke="none" /></>,
    nexusFill: <><g stroke={color} strokeWidth="2.1" strokeLinecap="round" fill="none"><path d="M9.25 8 A5.5 5.5 0 0 0 9.25 16" /><path d="M14.75 8 A5.5 5.5 0 0 1 14.75 16" /></g><g stroke={color} strokeWidth="1.7" strokeLinecap="round" fill="none" opacity="0.5"><path d="M6.75 4.75 A8.75 8.75 0 0 0 6.75 19.25" /><path d="M17.25 4.75 A8.75 8.75 0 0 1 17.25 19.25" /></g><circle cx="12" cy="12" r="3" fill={color} stroke="none" /></>,
    book: <><path d="M5 4.5A2 2 0 0 1 7 3h11v15H7a2 2 0 0 0-2 2Z" {...p} /><path d="M5 18.5A2 2 0 0 0 7 21h11" {...p} /></>,
    arrowUp: <path d="M12 19V5m-6 6 6-6 6 6" {...p} />,
    trending: <><path d="M22 7L13.5 15.5L8.5 10.5L2 17" {...p}/><path d="M16 7h6v6" {...p}/></>,
    x: <path d="M6 6l12 12M18 6 6 18" {...p} />,
    drag: <><circle cx="9" cy="6" r="1.3" fill={color} stroke="none" /><circle cx="15" cy="6" r="1.3" fill={color} stroke="none" /><circle cx="9" cy="12" r="1.3" fill={color} stroke="none" /><circle cx="15" cy="12" r="1.3" fill={color} stroke="none" /><circle cx="9" cy="18" r="1.3" fill={color} stroke="none" /><circle cx="15" cy="18" r="1.3" fill={color} stroke="none" /></>,
  };
  return <svg width={size} height={size} viewBox="0 0 24 24" style={{ flex: '0 0 auto', display: 'block' }}>{paths[name]}</svg>;
}

// ── Audio-mode glyph: four rounded bars (the single ink-filled affordance) ──
function LAudioGlyph({ color = '#fff', size = 22 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" style={{ display: 'block' }}>
      {[[5, 8], [9.5, 15], [14, 7], [18.5, 12]].map(([x, h], i) => (
        <rect key={i} x={x - 1.4} y={12 - h / 2} width={2.8} height={h} rx={1.4} fill={color} />
      ))}
    </svg>
  );
}

// ── Avatar (initials, neutral) ──
function LAvatar({ t, initials = 'M', size = 36, ring = false }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: 999, flex: '0 0 auto',
      background: t.surface, border: `1px solid ${ring ? t.text : t.borderStrong}`,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontSize: size * 0.4, fontWeight: 600, letterSpacing: -0.2, color: t.text,
      boxShadow: ring ? `0 0 0 3px ${t.surface2}` : 'none',
    }}>{initials}</div>
  );
}

// ── Status-bar / dynamic-island clearance ──
function LStatusSpacer({ h = 60 }) { return <div style={{ height: h, flex: '0 0 auto' }} />; }

// ── Screen scaffold with the paged bloom background ──
function LScreen({ t, children }) {
  return (
    <div style={{
      minHeight: '100%', height: '100%', background: t.page, fontFamily: L_FONT,
      color: t.text, boxSizing: 'border-box', WebkitFontSmoothing: 'antialiased',
      display: 'flex', flexDirection: 'column', position: 'relative',
    }}>{children}</div>
  );
}

// ── Header: Recent / All pivots, per-pivot view switch, avatar ──
// viewSwitch: 'segmented' (default) | 'inline' | 'dropdown' | 'none'
function LHeader({ t, pivot = 'Recent', view = 'By Collection', viewSwitch = 'segmented', onAvatar }) {
  const views = ['By Collection', 'By Topic', 'By Type'];
  const Pivot = ({ label }) => {
    const on = pivot === label;
    return (
      <span style={{
        fontSize: 19, fontWeight: on ? 700 : 600, letterSpacing: -0.4, cursor: 'pointer',
        color: on ? t.text : t.faint, padding: '8px 16px', borderRadius: 999,
        background: on ? t.surface2 : 'transparent', transition: 'background .15s, color .15s',
      }}>{label}</span>
    );
  };
  return (
    <div style={{ padding: '4px 14px 0', flex: '0 0 auto' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', gap: 4, alignItems: 'center' }}>
          <Pivot label="Recent" /><Pivot label="All" />
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <button onClick={onAvatar} style={{ border: 'none', background: 'transparent', padding: 0, cursor: 'pointer' }}>
            <LAvatar t={t} initials="M" />
          </button>
        </div>
      </div>

      {viewSwitch === 'segmented' && (
        <div style={{ display: 'inline-flex', gap: 2, marginTop: 14, marginLeft: 4, padding: 3, background: t.surface2, borderRadius: 999, border: `1px solid ${t.hair}` }}>
          {views.map((v) => {
            const on = view === v;
            return (
              <span key={v} style={{
                fontSize: 13, fontWeight: on ? 600 : 500, letterSpacing: -0.1, padding: '6px 13px', borderRadius: 999,
                color: on ? t.text : t.muted, background: on ? t.surface : 'transparent',
                border: on ? `1px solid ${t.border}` : '1px solid transparent', cursor: 'pointer',
              }}>{v.replace('By ', '')}</span>
            );
          })}
        </div>
      )}
      {viewSwitch === 'inline' && (
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginTop: 16, marginLeft: 4 }}>
          {views.map((v) => {
            const on = view === v;
            return (
              <span key={v} style={{ fontSize: 14, fontWeight: on ? 600 : 500, letterSpacing: -0.1, color: on ? t.text : t.faint, cursor: 'pointer', textDecoration: on ? 'underline' : 'none', textUnderlineOffset: 5, textDecorationThickness: 1.5 }}>{v}</span>
            );
          })}
        </div>
      )}
      {viewSwitch === 'dropdown' && (
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 16, marginLeft: 4 }}>
          <span style={{ fontSize: 13, color: t.faint, letterSpacing: -0.1 }}>Grouped</span>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, fontSize: 13.5, fontWeight: 600, letterSpacing: -0.1, color: t.text, padding: '6px 10px', background: t.surface, border: `1px solid ${t.border}`, borderRadius: 9, cursor: 'pointer' }}>
            {view}<LIcon name="chevDown" size={14} color={t.muted} />
          </span>
        </div>
      )}
    </div>
  );
}

function iconBtn(t, s = 36) {
  return { width: s, height: s, borderRadius: 999, flex: '0 0 auto', cursor: 'pointer',
    background: t.surface, border: `1px solid ${t.border}`, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 0 };
}

// ── The bottom dock: full-width composer (search removed) ──
// source: null | { icon, label } — when set, the composer is in URL-entry mode
function LDock({ t, ghost = 'Start a new collection about a topic', active = false,
  modeLabel = 'Model', value = '', tall = false, source = null }) {
  const urlMode = !!source;
  return (
    <div style={{ padding: '10px 16px 14px' }}>
      {/* composer */}
      <div style={{
        width: '100%', minWidth: 0, background: t.surface, borderRadius: 22,
        border: `1px solid ${active || urlMode ? t.borderStrong : t.border}`,
        boxShadow: active || urlMode ? `0 0 0 3px ${t.surface2}` : '0 1px 2px rgba(19,14,26,0.03)',
        padding: '13px 12px 11px', transition: 'box-shadow .15s, border-color .15s',
      }}>
        <div style={{ padding: '0 4px 12px', minHeight: tall ? 44 : 22, display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
          {urlMode && (
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, height: 28, padding: '0 6px 0 10px', borderRadius: 999, background: t.surface2, border: `1px solid ${t.border}` }}>
              <LIcon name={source.icon} size={15} color={t.text} />
              <span style={{ fontSize: 13.5, fontWeight: 600, color: t.text, letterSpacing: -0.1 }}>{source.label}</span>
              <span style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: 18, height: 18, borderRadius: 999, marginLeft: 1 }}><LIcon name="x" size={13} color={t.muted} /></span>
            </span>
          )}
          {value
            ? <span style={{ fontSize: 16, color: t.text, letterSpacing: -0.2, lineHeight: 1.4 }}>{value}<span style={{ display: 'inline-block', width: 1.5, height: 17, background: t.text, marginLeft: 1, verticalAlign: -3, opacity: 0.85 }} /></span>
            : <span style={{ fontSize: 16, color: t.ghost, letterSpacing: -0.2, lineHeight: 1.4 }}>{urlMode ? source.ghost : ghost}</span>}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <button style={iconBtn(t, 32)} aria-label="Add source"><LIcon name="plus" size={18} color={t.text} /></button>
          <button style={{
            display: 'inline-flex', alignItems: 'center', gap: 5, height: 32, padding: '0 11px', borderRadius: 999,
            background: t.surface, border: `1px solid ${t.border}`, cursor: 'pointer',
            fontFamily: L_FONT, fontSize: 13, fontWeight: 500, color: t.muted, letterSpacing: -0.1,
          }}>
            <LIcon name="sliders" size={15} color={t.muted} />{modeLabel}<LIcon name="chevDown" size={13} color={t.faint} />
          </button>
          <div style={{ flex: 1 }} />
          {urlMode
            ? <button style={{ width: 32, height: 32, borderRadius: 999, flex: '0 0 auto', cursor: 'pointer', padding: 0, background: value ? t.ink : t.surface2, border: value ? 'none' : `1px solid ${t.border}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }} aria-label="Add"><LIcon name="arrowUp" size={18} color={value ? '#fff' : t.faint} stroke={2} /></button>
            : <>
                <button style={iconBtn(t, 32)} aria-label="Dictate"><LIcon name="mic" size={18} color={t.muted} /></button>
                <button style={{ width: 32, height: 32, borderRadius: 999, flex: '0 0 auto', cursor: 'pointer', padding: 0, background: t.ink, border: 'none', display: 'flex', alignItems: 'center', justifyContent: 'center' }} aria-label="Audio mode"><LAudioGlyph color="#fff" size={18} /></button>
              </>}
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { lTheme, L_FONT, LIcon, LAudioGlyph, LAvatar, LStatusSpacer, LScreen, LHeader, LDock, iconBtn });
