// landing-app.jsx — Nexus iOS landing, as an INTERACTIVE clickthrough prototype.
// Motion modelled on the Notion app: spring button presses, sliding pivot/view
// thumbs, menus that scale-fade from their origin, screens that push from the
// right. Accent-free (only the background bloom). Exports: NexusApp
const { useState, useRef, useEffect, useLayoutEffect } = React;

const EASE = 'cubic-bezier(.2,.8,.2,1)';
const SPRING = 'cubic-bezier(.34,1.4,.64,1)';
// Pronounced overshoot for menu entrances (Notion-app feel).
const SPRING_BOUNCE = 'cubic-bezier(.18,1.5,.4,1)';
// True spring physics baked into a CSS linear() easing (k=200, c=15.5, ζ≈0.55):
// overshoots to ~1.12 then settles. Runs on the compositor — no rAF, never stalls.
const SPRING_LINEAR = 'linear(0.0035, 0.0648, 0.2067, 0.3545, 0.5093, 0.6852, 0.8131, 0.9372, 1.0144, 1.0686, 1.1067, 1.1200, 1.1204, 1.1091, 1.0935, 1.0714, 1.0528, 1.0354, 1.0176, 1.0058, 0.9969, 0.9899, 0.9866, 0.9852, 0.9857, 0.9870, 0.9894, 0.9917, 0.9940, 0.9964, 0.9981, 0.9997, 1.0007, 1.0013, 1.0017, 1.0018)';

const URL_SOURCES = [
  { key: 'website', icon: 'globe', label: 'Website', ghost: 'Paste or type a URL', seed: 'https://' },
  { key: 'youtube', icon: 'video', label: 'YouTube', ghost: 'Paste or type a video URL', seed: 'youtube.com/watch?v=' },
  { key: 'image', icon: 'photo', label: 'Image', ghost: 'Paste an image URL', seed: 'https://' },
  { key: 'pdf', icon: 'file', label: 'PDF', ghost: 'Paste a link to a PDF', seed: 'https://' },
];

// ── one-time keyframes ──
function AppStyles() {
  useEffect(() => {
    if (document.getElementById('nx-app-styles')) return;
    const s = document.createElement('style');
    s.id = 'nx-app-styles';
    s.textContent = '@keyframes nxFade{from{opacity:0;transform:translateY(7px)}to{opacity:1;transform:none}}@keyframes nxBlink{from{opacity:0}to{opacity:1}}@keyframes nxPop{0%{transform:scale(1)}32%{transform:scale(.84)}66%{transform:scale(1.09)}100%{transform:scale(1)}}';
    document.head.appendChild(s);
  }, []);
  return null;
}

// ── enter/exit presence (mount → animate in; animate out → unmount) ──
function usePresence(open, ms = 220) {
  const [mounted, setMounted] = useState(open);
  const [active, setActive] = useState(false);
  useEffect(() => {
    let raf1, raf2, to;
    if (open) {
      setMounted(true);
      raf1 = requestAnimationFrame(() => { raf2 = requestAnimationFrame(() => setActive(true)); });
    } else {
      setActive(false);
      to = setTimeout(() => setMounted(false), ms);
    }
    return () => { cancelAnimationFrame(raf1); cancelAnimationFrame(raf2); clearTimeout(to); };
  }, [open]);
  return { mounted, active };
}

// ── spring-press wrapper (every tappable uses this) ──
// `active` forces the pressed state (e.g. hold the avatar dented while its menu
// is open); pressDur/pressEase let a control opt into a bouncier release.
function Pressable({ as = 'button', onClick, style = {}, children, scale = 0.95, stop = false, active = false, pressDur = 0.24, pressEase = SPRING_BOUNCE, ...rest }) {
  const [down, setDown] = useState(false);
  const end = () => setDown(false);
  const pressed = down || active;
  return React.createElement(as, {
    onPointerDown: () => setDown(true),
    onPointerUp: end, onPointerLeave: end, onPointerCancel: end,
    onClick: (e) => { if (stop) e.stopPropagation(); onClick && onClick(e); },
    style: {
      ...style,
      transform: `scale(${pressed ? scale : 1})${style.transform ? ' ' + style.transform : ''}`,
      transition: `transform ${pressDur}s ${pressEase}`,
      WebkitTapHighlightColor: 'transparent', touchAction: 'manipulation',
    },
    ...rest,
  }, children);
}

// ── avatar button: presses smaller then springs bigger, spitting out the menu;
// replays the same bounce when the menu is absorbed (active → false) ──
function AvatarButton({ t, onClick, active }) {
  const [pop, setPop] = useState(0);
  const prev = useRef(active);
  useEffect(() => {
    if (prev.current && !active) setPop((n) => n + 1); // closed → replay bounce
    prev.current = active;
  }, [active]);
  return (
    <Pressable scale={0.84} pressDur={0.44} pressEase={SPRING_BOUNCE} onClick={onClick} aria-label="Account menu" style={{ border: 'none', background: 'transparent', padding: 0, cursor: 'pointer', borderRadius: 999 }}>
      <div key={pop} style={{ opacity: active ? 0 : 1, transition: active ? 'opacity .05s ease' : 'opacity .22s ease .04s', animation: pop ? 'nxPop .44s ease both' : 'none' }}>
        <LAvatar t={t} initials="M" />
      </div>
    </Pressable>
  );
}

// ── sliding-thumb segmented control (pivots + views).
//    `pulse`: optional CSS animation shorthand — the thumb's visual layer remounts
//    on every selection change and replays it (liquid-glass bubble squash). ──
function Segmented({ items, value, onChange, getLabel, trackStyle, itemStyle, activeItemStyle, thumbStyle, pulse, dur = 320, ease = EASE }) {
  const refs = useRef({});
  const [thumb, setThumb] = useState(null);
  useLayoutEffect(() => {
    const el = refs.current[value];
    if (el) setThumb({ left: el.offsetLeft, top: el.offsetTop, width: el.offsetWidth, height: el.offsetHeight });
  }, [value, items]);
  return (
    <div style={{ position: 'relative', ...trackStyle }}>
      {thumb && (pulse
        ? <div style={{ position: 'absolute', left: thumb.left, top: thumb.top, width: thumb.width, height: thumb.height, transition: `left ${dur}ms ${ease}, top ${dur}ms ${ease}, width ${dur}ms ${ease}` }}>
            <div key={value} style={{ width: '100%', height: '100%', animation: pulse, ...thumbStyle }} />
          </div>
        : <div style={{ position: 'absolute', left: thumb.left, top: thumb.top, width: thumb.width, height: thumb.height, transition: `left ${dur}ms ${ease}, top ${dur}ms ${ease}, width ${dur}ms ${ease}`, ...thumbStyle }} />)}
      {items.map((it) => (
        <button key={it} onClick={() => onChange(it)}
          ref={(el) => { refs.current[it] = el; }}
          style={{ position: 'relative', zIndex: 1, fontFamily: L_FONT, WebkitTapHighlightColor: 'transparent', touchAction: 'manipulation', cursor: 'pointer', ...itemStyle, ...(value === it ? activeItemStyle : {}) }}>
          {getLabel ? getLabel(it) : it}
        </button>
      ))}
    </div>
  );
}

// ── header: Recent/All pivots, avatar ──
function AppHeader({ t, pivot, setPivot, onAvatar, avatarActive, pivotDur = 320, pivotEase = EASE }) {
  return (
    <div style={{ padding: '4px 14px 0', flex: '0 0 auto' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <Segmented items={['Recent', 'All']} value={pivot} onChange={setPivot} dur={pivotDur} ease={pivotEase}
          trackStyle={{ display: 'inline-flex', gap: 4, alignItems: 'center' }}
          itemStyle={{ fontSize: 19, fontWeight: 600, letterSpacing: -0.4, color: t.faint, padding: '8px 16px', borderRadius: 999, background: 'transparent', border: 'none', cursor: 'pointer' }}
          activeItemStyle={{ color: t.text, fontWeight: 700 }}
          thumbStyle={{ background: t.surface2, borderRadius: 999 }} />
        <AvatarButton t={t} onClick={onAvatar} active={avatarActive} />
      </div>
    </div>
  );
}

// ── horizontal pivot swipe: panes slide left/right (or cross-fade) on change ──
function PivotSwipe({ pivot, items, dur, ease, motion, children }) {
  const idx = Math.max(0, items.indexOf(pivot));
  const n = items.length;
  if (motion === 'fade') {
    return (
      <div style={{ position: 'relative', flex: 1, minHeight: 0 }}>
        {items.map((p, i) => (
          <div key={p} style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column',
            opacity: i === idx ? 1 : 0, pointerEvents: i === idx ? 'auto' : 'none',
            transition: `opacity ${dur}ms ${ease}` }}>{children(p)}</div>
        ))}
      </div>
    );
  }
  return (
    <div style={{ position: 'relative', overflow: 'hidden', flex: 1, minHeight: 0 }}>
      <div style={{ display: 'flex', height: '100%', width: `${n * 100}%`,
        transform: `translateX(-${idx * (100 / n)}%)`, transition: `transform ${dur}ms ${ease}` }}>
        {items.map((p) => (
          <div key={p} style={{ width: `${100 / n}%`, height: '100%', display: 'flex', flexDirection: 'column', minHeight: 0 }}>
            {children(p)}
          </div>
        ))}
      </div>
    </div>
  );
}

// ── body content: the collection list ──
function HomeBody({ t, onOpenCollection, collections = COLLECTIONS }) {
  return (
    <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '18px 16px 8px', animation: `nxFade .3s ${EASE}` }}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {collections.map((c, i) => <CardRow key={i} t={t} c={c} onClick={() => onOpenCollection(c)} />)}
      </div>
    </div>
  );
}

function CardRow({ t, c, onClick }) {
  return (
    <Pressable scale={0.985} onClick={onClick} style={{ display: 'block', width: '100%', textAlign: 'left', padding: 0, border: 'none', background: 'transparent', cursor: 'pointer' }}>
      <LCollectionCard t={t} c={c} />
    </Pressable>
  );
}

// ── floating menus — Liquid Glass + bloom-morph (shared system) ──
// Caption (no separators — hierarchy from weight + spacing alone)
function MenuCaption({ t, children }) {
  return <div style={{ padding: '8px 12px 4px', fontSize: 11.5, fontWeight: 600, letterSpacing: 0.5, textTransform: 'uppercase', color: t.faint }}>{children}</div>;
}
// One menu row — rounded hit area, spring press, NO divider
function MenuRow({ t, icon, label, detail, check, onClick }) {
  return (
    <Pressable scale={0.97} onClick={onClick} style={{ display: 'flex', alignItems: 'center', gap: 12, width: '100%', textAlign: 'left', padding: '11px 12px', borderRadius: 14, border: 'none', background: 'transparent', cursor: 'pointer' }}>
      {icon && <LIcon name={icon} size={18} color={t.muted} />}
      <span style={{ flex: 1, fontSize: 15.5, fontWeight: 500, letterSpacing: -0.2, color: t.text }}>{label}</span>
      {detail && <span style={{ fontSize: 12.5, color: t.faint }}>{detail}</span>}
      {check && <LIcon name="check" size={17} color={t.text} />}
    </Pressable>
  );
}
function UrlMenuContent({ t, onPick }) {
  return (
    <div style={{ padding: 6, fontFamily: L_FONT }}>
      <MenuCaption t={t}>Paste a URL</MenuCaption>
      {URL_SOURCES.map((s) => (
        <Pressable key={s.key} scale={0.97} onClick={() => onPick(s)} style={{ display: 'flex', alignItems: 'center', gap: 12, width: '100%', textAlign: 'left', padding: '9px 12px', borderRadius: 14, border: 'none', background: 'transparent', cursor: 'pointer' }}>
          <div style={{ width: 30, height: 30, borderRadius: 9, flex: '0 0 auto', background: 'rgba(255,255,255,0.45)', border: '1px solid rgba(255,255,255,0.55)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><LIcon name={s.icon} size={17} color={t.text} /></div>
          <span style={{ fontSize: 15.5, letterSpacing: -0.2, color: t.text }}>{s.label}</span>
        </Pressable>
      ))}
    </div>
  );
}
function PlusMenuContent({ t }) {
  const rows = [['photo', 'Photos'], ['file', 'Files'], ['camera', 'Camera']];
  return <div style={{ padding: 6, fontFamily: L_FONT }}>{rows.map(([ic, lb]) => <MenuRow key={lb} t={t} icon={ic} label={lb} />)}</div>;
}
function ModelMenuContent({ t, active = 'Standard', onPick }) {
  const models = [['Quick', 'fast drafts'], ['Standard', 'everyday'], ['Deep research', 'thorough']];
  return (
    <div style={{ padding: 6, fontFamily: L_FONT }}>
      <MenuCaption t={t}>Model</MenuCaption>
      {models.map(([label, detail]) => (
        <Pressable key={label} scale={0.97} onClick={() => onPick && onPick(label)} style={{ display: 'flex', alignItems: 'center', gap: 10, width: '100%', textAlign: 'left', padding: '10px 12px', borderRadius: 14, border: 'none', background: 'transparent', cursor: 'pointer' }}>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 15.5, letterSpacing: -0.2, color: t.text, fontWeight: active === label ? 600 : 500 }}>{label}</div>
            <div style={{ fontSize: 12.5, color: t.faint, marginTop: 1 }}>{detail}</div>
          </div>
          {active === label && <LIcon name="check" size={17} color={t.text} />}
        </Pressable>
      ))}
    </div>
  );
}

// ── interactive composer ──
function Composer({ t, source, value, active, plusOpen, onOpenUrl, onOpenPlus, onClear, onModel, onSubmit }) {
  const urlMode = !!source;
  const ring = active || urlMode;
  return (
    <div style={{
      width: '100%', background: t.surface, borderRadius: 22,
      border: `1px solid ${ring ? t.borderStrong : t.border}`,
      boxShadow: ring ? `0 0 0 3px ${t.surface2}` : '0 1px 2px rgba(19,14,26,0.03)',
      padding: '13px 12px 11px', transition: `box-shadow .18s, border-color .18s`,
    }}>
      {urlMode ? (
        <div style={{ padding: '0 4px 12px', minHeight: 22, display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, height: 28, padding: '0 4px 0 10px', borderRadius: 999, background: t.surface2, border: `1px solid ${t.border}` }}>
            <LIcon name={source.icon} size={15} color={t.text} />
            <span style={{ fontSize: 13.5, fontWeight: 600, color: t.text, letterSpacing: -0.1 }}>{source.label}</span>
            <Pressable scale={0.85} stop onClick={onClear} style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: 20, height: 20, borderRadius: 999, border: 'none', background: 'transparent', cursor: 'pointer', padding: 0 }}>
              <LIcon name="x" size={13} color={t.muted} />
            </Pressable>
          </span>
          {value
            ? <span style={{ fontSize: 16, color: t.text, letterSpacing: -0.2, lineHeight: 1.4 }}>{value}<Caret t={t} /></span>
            : <span style={{ fontSize: 16, color: t.ghost, letterSpacing: -0.2, lineHeight: 1.4 }}>{source.ghost}</span>}
        </div>
      ) : (
        <Pressable as="button" scale={0.99} onClick={onOpenUrl} aria-label="Paste a URL" style={{ display: 'block', width: '100%', textAlign: 'left', border: 'none', background: 'transparent', padding: '0 4px 12px', cursor: 'text' }}>
          <span style={{ fontSize: 16, color: t.ghost, letterSpacing: -0.2, lineHeight: 1.4 }}>Start a new collection about a topic</span>
        </Pressable>
      )}
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <Pressable scale={0.9} onClick={onOpenPlus} aria-label="Attach" style={{ ...iconBtn(t, 32), borderColor: plusOpen ? t.borderStrong : t.border }}>
          <span style={{ display: 'inline-flex', transform: plusOpen ? 'rotate(45deg)' : 'none', transition: `transform .22s ${EASE}` }}><LIcon name="plus" size={18} color={t.text} /></span>
        </Pressable>
        <div style={{ flex: 1 }} />
        {urlMode
          ? <Pressable scale={0.88} onClick={onSubmit} aria-label="Create collection" style={{ width: 32, height: 32, borderRadius: 999, flex: '0 0 auto', cursor: 'pointer', padding: 0, background: value ? t.ink : t.surface2, border: value ? 'none' : `1px solid ${t.border}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><LIcon name="arrowUp" size={18} color={value ? '#fff' : t.faint} stroke={2} /></Pressable>
          : <>
              <Pressable scale={0.88} style={iconBtn(t, 32)}><LIcon name="mic" size={18} color={t.muted} /></Pressable>
            </>}
      </div>
    </div>
  );
}

function Caret({ t }) {
  return <span style={{ display: 'inline-block', width: 1.5, height: 17, background: t.text, marginLeft: 1, verticalAlign: -3, animation: 'nxBlink 1.1s steps(1) infinite alternate' }} />;
}

// ── the home screen ──
function HomeScreen({ t, state, set, overlay, motion, onAvatar, onModel, onOpenUrl, onOpenPlus, onOpenCollection, onSubmit }) {
  const { pivot, source, value } = state;
  return (
    <div style={{ position: 'relative', height: '100%', display: 'flex', flexDirection: 'column' }}>
      <LStatusSpacer />
      <AppHeader t={t} pivot={pivot} setPivot={(p) => set({ pivot: p })} onAvatar={onAvatar} avatarActive={overlay === 'avatar'} pivotDur={motion.dur} pivotEase={motion.ease} />
      <PivotSwipe pivot={pivot} items={['Recent', 'All']} dur={motion.dur} ease={motion.ease} motion={motion.type}>
        {(p) => <HomeBody t={t} onOpenCollection={onOpenCollection} collections={p === 'Recent' ? COLLECTIONS.slice(0, 3) : COLLECTIONS} />}
      </PivotSwipe>
      <div style={{ flex: '0 0 auto', paddingBottom: 24 }}>
        <div style={{ padding: '10px 16px 0' }}>
          <Composer t={t} source={source} value={value}
            active={overlay === 'url' || overlay === 'plus'} plusOpen={overlay === 'plus'}
            onOpenUrl={onOpenUrl} onOpenPlus={onOpenPlus}
            onClear={() => set({ source: null, value: '' })}
            onModel={onModel} onSubmit={onSubmit} />
        </div>
      </div>
    </div>
  );
}

// ── pushed screen: a collection's detail ──
function CollectionScreen({ t, c, onBack }) {
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: t.page }}>
      <LStatusSpacer />
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '2px 12px 8px' }}>
        <Pressable scale={0.9} onClick={onBack} style={{ display: 'inline-flex', alignItems: 'center', gap: 3, border: 'none', background: 'transparent', cursor: 'pointer', fontFamily: L_FONT, fontSize: 15, color: t.muted, letterSpacing: -0.2, padding: '4px 6px' }}>
          <span style={{ transform: 'scaleX(-1)', display: 'inline-flex' }}><LIcon name="chevR" size={19} color={t.muted} /></span>Library
        </Pressable>
        <Pressable scale={0.9} style={iconBtn(t, 34)}><LIcon name="search" size={18} color={t.muted} /></Pressable>
      </div>
      <div style={{ padding: '4px 18px 6px' }}>
        <div style={{ fontSize: 27, fontWeight: 700, letterSpacing: -0.7, color: t.text, lineHeight: 1.15 }}>{c.title}</div>
        <div style={{ fontSize: 13.5, color: t.faint, marginTop: 6, letterSpacing: -0.1 }}>{c.items} items · {c.when}</div>
      </div>
      <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '12px 16px 8px', animation: `nxFade .32s ${EASE}` }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 9 }}>
          {ITEMS.slice(0, 5).map((it, i) => { const ty = TYPES.find((x) => x.name.startsWith(it.type)) || TYPES[0]; return <LItemRow key={i} t={t} it={it} icon={ty.icon} />; })}
        </div>
      </div>
      <div style={{ flex: '0 0 auto', paddingBottom: 24 }}>
        <div style={{ padding: '10px 16px 0' }}><StaticComposer t={t} ghost="Add to this collection" /></div>
      </div>
    </div>
  );
}

// ── pushed screen: a freshly-created collection (after add-a-source → send) ──
function NewCollectionScreen({ t, source, value, onBack }) {
  const ty = source ? source.label : 'Link';
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: t.page }}>
      <LStatusSpacer />
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '2px 12px 8px' }}>
        <Pressable scale={0.9} onClick={onBack} style={{ display: 'inline-flex', alignItems: 'center', gap: 3, border: 'none', background: 'transparent', cursor: 'pointer', fontFamily: L_FONT, fontSize: 15, color: t.muted, letterSpacing: -0.2, padding: '4px 6px' }}>
          <span style={{ transform: 'scaleX(-1)', display: 'inline-flex' }}><LIcon name="chevR" size={19} color={t.muted} /></span>Library
        </Pressable>
        <span style={{ fontSize: 15, fontWeight: 600, color: t.text }}>New collection</span>
        <span style={{ width: 56 }} />
      </div>
      <div style={{ padding: '4px 18px 4px' }}>
        <div style={{ fontSize: 27, fontWeight: 700, letterSpacing: -0.7, lineHeight: 1.15, color: t.ghost }}>Untitled collection<Caret t={t} /></div>
        <div style={{ fontSize: 13.5, color: t.faint, marginTop: 8, letterSpacing: -0.1 }}>1 item · just now · only you</div>
      </div>
      <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '14px 16px 8px', animation: `nxFade .32s ${EASE}` }}>
        <LItemRow t={t} it={{ title: value || 'Added link', src: ty, when: 'just added' }} icon={source ? source.icon : 'link'} />
        <div style={{ display: 'flex', gap: 9, marginTop: 14 }}>
          {[['link', 'Paste link'], ['note', 'Write note'], ['file', 'Upload']].map(([ic, lb]) => (
            <Pressable key={lb} scale={0.96} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 7, padding: '15px 8px', background: t.surface, border: `1px solid ${t.border}`, borderRadius: 13, cursor: 'pointer', fontFamily: L_FONT }}>
              <LIcon name={ic} size={21} color={t.muted} />
              <span style={{ fontSize: 12.5, fontWeight: 500, color: t.text, letterSpacing: -0.1 }}>{lb}</span>
            </Pressable>
          ))}
        </div>
      </div>
      <div style={{ flex: '0 0 auto', paddingBottom: 24 }}>
        <div style={{ padding: '10px 16px 0' }}><StaticComposer t={t} ghost="Add to this collection" /></div>
      </div>
    </div>
  );
}

// a non-interactive composer for secondary screens
function StaticComposer({ t, ghost }) {
  return (
    <div style={{ width: '100%', background: t.surface, borderRadius: 22, border: `1px solid ${t.border}`, boxShadow: '0 1px 2px rgba(19,14,26,0.03)', padding: '13px 12px 11px' }}>
      <div style={{ padding: '0 4px 12px' }}><span style={{ fontSize: 16, color: t.ghost, letterSpacing: -0.2 }}>{ghost}</span></div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <div style={iconBtn(t, 32)}><LIcon name="plus" size={18} color={t.text} /></div>
        <div style={{ flex: 1 }} />
        <div style={iconBtn(t, 32)}><LIcon name="mic" size={18} color={t.muted} /></div>
      </div>
    </div>
  );
}

// ── Liquid Glass material (Apple iOS 26) ──────────────────────────────────
// Glass that REFRACTS the content behind it (a lens ring + chromatic edge
// fringing — Chrome rejects backdrop-filter:url(), so refraction is faked in
// pure CSS that actually renders), REFLECTS light as a bright specular rim +
// glossy sheen, and floats above content with depth. Adapts to whatever's
// behind it via a saturated, slightly brightened backdrop blur.
//
// Layers (back→front):
//  1. frost   — backdrop blur + saturate + brightness (the translucency)
//  2. tint    — translucent fill + diagonal specular gloss (the reflection)
//  3. lens    — chromatic edge fringe + magnified bright ring (fakes refraction)
//  4. rim     — crisp bright bevel + faint inner glow (specular highlight)
//  5. content
function LiquidGlassCard({ radius = 26, width, children }) {
  const layer = { position: 'absolute', inset: 0, borderRadius: radius, pointerEvents: 'none' };
  return (
    <div style={{ position: 'relative', width, borderRadius: radius, isolation: 'isolate',
      boxShadow: '0 22px 58px rgba(19,14,26,0.22), 0 6px 18px rgba(19,14,26,0.13)' }}>
      <div style={{ ...layer, overflow: 'hidden',
        backdropFilter: 'blur(8px) saturate(195%) brightness(1.05)',
        WebkitBackdropFilter: 'blur(8px) saturate(195%) brightness(1.05)' }} />
      <div style={{ ...layer, background:
        'linear-gradient(135deg, rgba(255,255,255,0.42) 0%, rgba(255,255,255,0.10) 30%, rgba(255,255,255,0.03) 54%, rgba(255,255,255,0.13) 78%, rgba(255,255,255,0.36) 100%)' }} />
      <div style={{ ...layer, boxShadow:
        'inset 0 0 0 1px rgba(255,255,255,0.4), inset 3px 3px 8px rgba(255,255,255,0.5), inset -5px -6px 12px rgba(150,170,255,0.16), inset 5px 6px 13px rgba(255,150,205,0.11)' }} />
      <div style={{ ...layer, boxShadow:
        'inset 1.6px 1.6px 1px rgba(255,255,255,0.95), inset -1.4px -1.4px 2px rgba(255,255,255,0.5), inset 0 0 16px rgba(255,255,255,0.18)' }} />
      <div style={{ position: 'relative', zIndex: 1 }}>{children}</div>
    </div>
  );
}

// ── Avatar context-menu — Notion bloom-morph ──
// The surface springs OUT of the avatar (scale .12→overshoot→1 on a true-spring
// linear() easing); content fades in AFTER the surface arrives; the background
// blurs. Close reverses with a quick ease-in collapse — the menu is absorbed
// back into the avatar. All compositor-driven (no rAF), so it never stalls.
function BloomMenu({ open, onClose, anchor, origin, children }) {
  const p = usePresence(open, 480);
  if (!p.mounted) return null;
  const on = p.active;
  return (
    <>
      <div onClick={onClose} style={{ position: 'absolute', inset: 0, zIndex: 60, background: 'transparent' }} />
      <div style={{ position: 'absolute', zIndex: 61, transformOrigin: origin,
        transform: on ? 'scale(1)' : 'scale(0.12)',
        opacity: on ? 1 : 0,
        transition: on
          ? `transform .46s ${SPRING_LINEAR}, opacity .2s ease`
          : `transform .26s cubic-bezier(.4,0,.9,.35), opacity .22s ease .03s`, ...anchor }}>
        <div style={{
          opacity: on ? 1 : 0,
          transform: on ? 'translateY(0)' : 'translateY(6px)',
          transition: on ? 'opacity .24s ease .1s, transform .3s ease .08s' : 'opacity .12s ease' }}>
          {children}
        </div>
      </div>
    </>
  );
}

function AvatarMenuContent({ t }) {
  return (
    <LiquidGlassCard radius={26} width={238}>
      <div style={{ padding: 6, fontFamily: L_FONT }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 11, padding: '9px 10px 11px' }}>
          <LAvatar t={t} initials="M" size={40} />
          <div style={{ minWidth: 0 }}>
            <div style={{ fontSize: 15, fontWeight: 600, letterSpacing: -0.2, color: t.text }}>Mara Olsen</div>
            <div style={{ fontSize: 12.5, color: t.muted, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>mara@hey.com</div>
          </div>
        </div>
        {['Account', 'Settings', 'Feedback'].map((label) => <MenuRow key={label} t={t} label={label} />)}
      </div>
    </LiquidGlassCard>
  );
}

// ── animated menu overlay (scrim + origin-anchored popover) ──
// startScale/dur/ease are tunable so a menu can opt into a more pronounced
// spring; scrimBlur adds a soft glass dim behind the popover.
function MenuOverlay({ open, onClose, anchor, origin, enterY = -6, startScale = 0.95, dur = 0.2, opDur = 0.16, ease = SPRING, scrimBlur = false, children }) {
  const p = usePresence(open, Math.round(Math.max(dur, opDur) * 1000) + 40);
  if (!p.mounted) return null;
  return (
    <>
      <div onClick={onClose} style={{ position: 'absolute', inset: 0, background: 'rgba(19,14,26,0.18)', backdropFilter: scrimBlur ? 'blur(2px)' : 'none', WebkitBackdropFilter: scrimBlur ? 'blur(2px)' : 'none', opacity: p.active ? 1 : 0, transition: `opacity ${opDur}s ease`, zIndex: 60 }} />
      <div style={{ position: 'absolute', zIndex: 61, transformOrigin: origin, transform: p.active ? 'scale(1) translateY(0)' : `scale(${startScale}) translateY(${enterY}px)`, opacity: p.active ? 1 : 0, transition: `transform ${dur}s ${ease}, opacity ${opDur}s ease`, ...anchor }}>
        {children}
      </div>
    </>
  );
}

// ── root ──
const MOTION_EASE = { spring: 'cubic-bezier(.34,1.4,.64,1)', smooth: 'cubic-bezier(.2,.8,.2,1)', snappy: 'cubic-bezier(.4,0,.2,1)' };
function NexusApp({ tweaks }) {
  const t = lTheme();
  const motion = {
    dur: (tweaks && tweaks.motionDuration) || 380,
    ease: (tweaks && MOTION_EASE[tweaks.motionEasing]) || MOTION_EASE.smooth,
    type: (tweaks && tweaks.pivotMotion) || 'slide',
  };
  const [state, setState] = useState({ pivot: 'Recent', view: 'collection', source: null, value: '' });
  const set = (patch) => setState((s) => ({ ...s, ...patch }));
  const [overlay, setOverlay] = useState(null); // 'avatar' | 'model' | 'url' | 'plus'
  const [nav, setNav] = useState(null);          // { type, ... }

  const navPres = usePresence(!!nav, 360);
  const navRef = useRef(null);
  if (nav) navRef.current = nav;
  const navData = nav || navRef.current;

  const submit = () => { if (state.source) { setNav({ type: 'new', source: state.source, value: state.value }); set({ source: null, value: '' }); } };

  return (
    <div style={{ position: 'relative', height: '100%', overflow: 'hidden', background: t.page, fontFamily: L_FONT, color: t.text, WebkitFontSmoothing: 'antialiased' }}>
      <AppStyles />
      {/* base (home) — shifts left & dims when a screen is pushed */}
      <div style={{ position: 'absolute', inset: 0, zIndex: 0, transform: navPres.active ? 'translateX(-26px)' : 'none', filter: navPres.active ? 'brightness(0.97)' : 'none', transition: `transform .36s ${EASE}, filter .36s ease` }}>
        <HomeScreen t={t} state={state} set={set} overlay={overlay} motion={motion}
          onAvatar={() => setOverlay('avatar')} onModel={() => setOverlay('model')}
          onOpenUrl={() => setOverlay('url')} onOpenPlus={() => setOverlay((o) => (o === 'plus' ? null : 'plus'))}
          onOpenCollection={(c) => setNav({ type: 'collection', c })} onSubmit={submit} />
      </div>

      {/* pushed screen */}
      {navPres.mounted && navData && (
        <div style={{ position: 'absolute', inset: 0, zIndex: 30, transform: navPres.active ? 'translateX(0)' : 'translateX(100%)', transition: `transform .36s ${EASE}`, boxShadow: '-10px 0 30px rgba(19,14,26,0.10)' }}>
          {navData.type === 'collection'
            ? <CollectionScreen t={t} c={navData.c} onBack={() => setNav(null)} />
            : <NewCollectionScreen t={t} source={navData.source} value={navData.value} onBack={() => setNav(null)} />}
        </div>
      )}

      <BloomMenu open={overlay === 'avatar'} onClose={() => setOverlay(null)} anchor={{ top: 64, right: 14 }} origin="top right">
        <AvatarMenuContent t={t} />
      </BloomMenu>
      <BloomMenu open={overlay === 'model'} onClose={() => setOverlay(null)} anchor={{ left: 14, bottom: 92 }} origin="bottom left">
        <LiquidGlassCard radius={22} width={230}><ModelMenuContent t={t} active="Standard" /></LiquidGlassCard>
      </BloomMenu>
      <BloomMenu open={overlay === 'url'} onClose={() => setOverlay(null)} anchor={{ left: 14, bottom: 96 }} origin="bottom left">
        <LiquidGlassCard radius={22} width={250}><UrlMenuContent t={t} onPick={(s) => { set({ source: s, value: s.seed }); setOverlay(null); }} /></LiquidGlassCard>
      </BloomMenu>
      <BloomMenu open={overlay === 'plus'} onClose={() => setOverlay(null)} anchor={{ left: 14, bottom: 96 }} origin="bottom left">
        <LiquidGlassCard radius={22} width={210}><PlusMenuContent t={t} /></LiquidGlassCard>
      </BloomMenu>
    </div>
  );
}

Object.assign(window, { NexusApp, Pressable, Segmented, PivotSwipe, MenuCaption, MenuRow, LiquidGlassCard, BloomMenu, AvatarButton, AvatarMenuContent, usePresence, SPRING_BOUNCE, SPRING_LINEAR });
