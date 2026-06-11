// collection-view.jsx — Nexus collection view: Nexus (AI agent, default) / Sources tabs.
// The page a confirmed sheet morphs into, and where returning users land.
// Reuses window globals: lTheme, L_FONT, LIcon, LAudioGlyph, LStatusSpacer, iconBtn
// (landing-kit) · Pressable, Segmented, PivotSwipe, LiquidGlassCard, BloomMenu,
// MenuCaption (landing-app) · IOSDevice (ios-frame).
// Exports: CollectionView, CollectionBoard, NX_SOURCES, NX_TRENDING, nxFallbackSources
const { useState, useEffect, useRef } = React;

const CV_EASE = 'cubic-bezier(.2,.8,.2,1)';
const CV_ACCENT = '#7054AB'; // approved plum — selected tab tint (matches send/confirm)

// ── sample data: trending topics → 6 authoritative sources each ──
const NX_TRENDING = ['US–Iran conflict', 'AI platform shifts', 'Ozempic & longevity', 'Vision Pro 2'];

const NX_SOURCES = {
  'US–Iran conflict': [
    { mono: 'R', src: 'Reuters', title: 'US and Iran resume back-channel talks in Oman', meta: 'Article · 6 min', icon: 'globe' },
    { mono: 'B', src: 'BBC News', title: 'What’s at stake in the Strait of Hormuz', meta: 'Article · 8 min', icon: 'globe' },
    { mono: 'AJ', src: 'Al Jazeera', title: 'Timeline: US–Iran tensions since 2020', meta: 'Article · 10 min', icon: 'globe' },
    { mono: 'IS', src: 'ISW', title: 'Iran update — June 2026 assessment', meta: 'PDF · 24 pages', icon: 'file' },
    { mono: 'C', src: 'CFR · YouTube', title: 'Why the US and Iran keep colliding', meta: 'Video · 14 min', icon: 'video' },
    { mono: 'FA', src: 'Foreign Affairs', title: 'The narrow deal that could end the standoff', meta: 'Article · 12 min', icon: 'globe' },
  ],
  'AI platform shifts': [
    { mono: 'St', src: 'Stratechery', title: 'The end of the beginning for AI platforms', meta: 'Article · 8 min', icon: 'globe' },
    { mono: 'V', src: 'The Verge', title: 'Every model is a platform now', meta: 'Article · 7 min', icon: 'globe' },
    { mono: 'aX', src: 'arXiv', title: 'Scaling agentic systems: a survey', meta: 'PDF · 38 pages', icon: 'file' },
    { mono: 'YT', src: 'a16z · YouTube', title: 'Where value accrues in the AI stack', meta: 'Video · 31 min', icon: 'video' },
    { mono: 'W', src: 'WIRED', title: 'The quiet war for the AI operating layer', meta: 'Article · 11 min', icon: 'globe' },
    { mono: 'FT', src: 'Financial Times', title: 'Big tech’s capex supercycle, charted', meta: 'Article · 9 min', icon: 'globe' },
  ],
  'Ozempic & longevity': [
    { mono: 'N', src: 'Nature', title: 'GLP-1 agonists beyond weight loss', meta: 'Article · 9 min', icon: 'globe' },
    { mono: 'S', src: 'STAT News', title: 'What we actually know about GLP-1s and aging', meta: 'Article · 12 min', icon: 'globe' },
    { mono: 'A', src: 'The Atlantic', title: 'The longevity drug hiding in plain sight', meta: 'Article · 14 min', icon: 'globe' },
    { mono: 'J', src: 'JAMA', title: 'Semaglutide outcomes: 5-year follow-up', meta: 'PDF · 16 pages', icon: 'file' },
    { mono: 'YT', src: 'TED · YouTube', title: 'Metabolism, medicine and healthspan', meta: 'Video · 18 min', icon: 'video' },
    { mono: 'E', src: 'The Economist', title: 'The trillion-dollar question of living longer', meta: 'Article · 10 min', icon: 'globe' },
  ],
  'Vision Pro 2': [
    { mono: 'B', src: 'Bloomberg', title: 'Inside the lighter, cheaper Vision Pro 2', meta: 'Article · 7 min', icon: 'globe' },
    { mono: 'V', src: 'The Verge', title: 'Hands-on: what changed, what didn’t', meta: 'Article · 9 min', icon: 'globe' },
    { mono: 'SC', src: 'Six Colors', title: 'The spatial computing report card', meta: 'Article · 8 min', icon: 'globe' },
    { mono: 'YT', src: 'YouTube', title: 'Vision Pro 2 — full review', meta: 'Video · 22 min', icon: 'video' },
    { mono: 'AP', src: 'Apple Newsroom', title: 'Vision Pro 2 press release', meta: 'PDF · 6 pages', icon: 'file' },
    { mono: 'FT', src: 'Financial Times', title: 'Can headsets become the next platform?', meta: 'Article · 11 min', icon: 'globe' },
  ],
};

function nxFallbackSources(topic) {
  const tp = topic || 'this topic';
  return [
    { mono: 'W', src: 'Wikipedia', title: `${tp} — overview`, meta: 'Article · 11 min', icon: 'globe' },
    { mono: 'R', src: 'Reuters', title: `The latest reporting on ${tp.toLowerCase()}`, meta: 'Article · 6 min', icon: 'globe' },
    { mono: 'G', src: 'The Guardian', title: `${tp}: what you need to know`, meta: 'Article · 8 min', icon: 'globe' },
    { mono: 'YT', src: 'YouTube', title: `${tp}, explained in 15 minutes`, meta: 'Video · 15 min', icon: 'video' },
    { mono: 'P', src: 'Pew Research', title: `${tp} — by the numbers`, meta: 'PDF · 12 pages', icon: 'file' },
    { mono: 'E', src: 'The Economist', title: `Why ${tp.toLowerCase()} matters now`, meta: 'Article · 9 min', icon: 'globe' },
  ];
}

// ── one-time keyframes (typing dots + title shimmer for freshly-added links) ──
function CVStyles() {
  useEffect(() => {
    if (document.getElementById('nx-cv-styles')) return;
    const s = document.createElement('style');
    s.id = 'nx-cv-styles';
    s.textContent = '@keyframes nxDot{0%,60%,100%{opacity:.25;transform:none}30%{opacity:1;transform:translateY(-3px)}}@keyframes nxShimmer{from{background-position:-400px 0}to{background-position:400px 0}}@keyframes nxBubble{0%{transform:scale(1)}38%{transform:scale(1.13,.87)}68%{transform:scale(.95,1.05)}100%{transform:scale(1)}}@keyframes nxSpin{to{transform:rotate(360deg)}}@keyframes nxEcho{0%{transform:scale(.45);opacity:0}30%{opacity:.9}100%{transform:scale(1.45);opacity:0}}@keyframes nxNodeBreathe{0%,100%{opacity:1}50%{opacity:.5}}';
    document.head.appendChild(s);
  }, []);
  return null;
}

// ── link-type icon (web / PDF / YouTube / note) — bare glyph, no box ──
function TypeIcon({ t, icon }) {
  return (
    <div style={{ width: 30, height: 30, flex: '0 0 auto', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <LIcon name={icon || 'link'} size={19} color={t.muted} />
    </div>
  );
}

function CVShimmer({ w = '70%' }) {
  return <div style={{ width: w, height: 13, borderRadius: 6, background: 'linear-gradient(90deg,#EDEAF5 25%,#F5F3FB 50%,#EDEAF5 75%)', backgroundSize: '800px 100%', animation: 'nxShimmer 1.6s ease-in-out infinite' }} />;
}

// ── a link row: flat list — bare type glyph + text + quiet remove; no card, no dividers ──
function LinkRow({ t, it, removing, onRemove }) {
  return (
    <div style={{ overflow: 'hidden', maxHeight: removing ? 0 : 70, opacity: removing ? 0 : 1, transform: removing ? 'scale(0.97)' : 'none', transition: `max-height .3s ${CV_EASE} .06s, opacity .22s ease, transform .24s ease` }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 13, padding: '11px 2px 11px 4px', animation: `nxFade .32s ${CV_EASE} both` }}>
        <TypeIcon t={t} icon={it.icon} />
        <div style={{ flex: 1, minWidth: 0 }}>
          {it.pending
            ? <CVShimmer />
            : <div style={{ fontSize: 15, fontWeight: 600, letterSpacing: -0.2, color: t.text, lineHeight: 1.3, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{it.title}</div>}
          <div style={{ fontSize: 12.5, color: t.faint, marginTop: it.pending ? 6 : 2 }}>{it.pending ? 'Fetching…' : `${it.src} · ${it.meta}`}</div>
        </div>
        <Pressable scale={0.82} onClick={onRemove} aria-label="Remove from collection" style={{ width: 34, height: 34, borderRadius: 999, flex: '0 0 auto', border: 'none', background: 'transparent', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', padding: 0 }}>
          <LIcon name="x" size={15} color={t.ghost} />
        </Pressable>
      </div>
    </div>
  );
}

// ── composer — 'ask' is the prominent one (focus ring, taller, ink audio anchor);
//    'add' is a quiet single-line pill so the Links pivot stays about the material ──
function CVComposer({ t, ghost, mode = 'add', plusOpen = false, onPlus }) {
  if (mode === 'add') {
    return (
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, width: '100%', background: t.surface, borderRadius: 999, border: `1px solid ${plusOpen ? t.borderStrong : t.border}`, boxShadow: '0 1px 2px rgba(19,14,26,0.03)', padding: '7px 8px', transition: 'border-color .18s' }}>
        <Pressable scale={0.9} onClick={onPlus} aria-label="Add" style={{ ...iconBtn(t, 32), borderColor: plusOpen ? t.borderStrong : t.border }}>
          <span style={{ display: 'inline-flex', transform: plusOpen ? 'rotate(45deg)' : 'none', transition: `transform .22s ${CV_EASE}` }}><LIcon name="plus" size={18} color={t.text} /></span>
        </Pressable>
        <span style={{ flex: 1, fontSize: 15.5, color: t.ghost, letterSpacing: -0.2, lineHeight: 1.4 }}>{ghost}</span>
        <Pressable scale={0.88} style={iconBtn(t, 32)} aria-label="Dictate"><LIcon name="mic" size={18} color={t.muted} /></Pressable>
      </div>
    );
  }
  return (
    <div style={{ width: '100%', background: t.surface, borderRadius: 24, border: `1px solid ${t.borderStrong}`, boxShadow: `0 0 0 3px ${t.surface2}, 0 2px 10px rgba(19,14,26,0.05)`, padding: '15px 13px 12px' }}>
      <div style={{ padding: '0 4px 15px' }}><span style={{ fontSize: 17, color: t.ghost, letterSpacing: -0.2, lineHeight: 1.4 }}>{ghost}</span></div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <Pressable scale={0.9} style={iconBtn(t, 32)} aria-label="Attach"><LIcon name="plus" size={18} color={t.text} /></Pressable>
        <div style={{ flex: 1 }} />
        <Pressable scale={0.88} style={iconBtn(t, 32)} aria-label="Dictate"><LIcon name="mic" size={18} color={t.muted} /></Pressable>
        <Pressable scale={0.88} aria-label="Audio mode" style={{ width: 34, height: 34, borderRadius: 999, flex: '0 0 auto', cursor: 'pointer', padding: 0, background: t.ink, border: 'none', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <LAudioGlyph color="#fff" size={19} />
        </Pressable>
      </div>
    </div>
  );
}

// ── “add a source” glass menu rows; each resolves a plausible item.
//    Media-agnostic on purpose: a source can be a link, image, or audio. ──
const CV_ADD = [
  { icon: 'globe', label: 'Website', item: { mono: 'G', src: 'The Guardian', title: 'How the story could unfold from here', meta: 'Article · 7 min', icon: 'globe' } },
  { icon: 'video', label: 'YouTube', item: { mono: 'YT', src: 'YouTube', title: 'A 12-minute briefing on where things stand', meta: 'Video · 12 min', icon: 'video' } },
  { icon: 'photo', label: 'Image', item: { mono: 'I', src: 'Photos', title: 'Strait of Hormuz — satellite view', meta: 'Image · just now', icon: 'photo' } },
  { icon: 'file', label: 'PDF', item: { mono: 'P', src: 'Upload', title: 'Background brief', meta: 'PDF · 9 pages', icon: 'file' } },
  { icon: 'mic', label: 'Audio', item: { mono: 'A', src: 'Voice Memos', title: 'Voice memo — first impressions', meta: 'Audio · 2 min', icon: 'mic' } },
  { icon: 'note', label: 'Note', item: { mono: 'N', src: 'You', title: 'Untitled note', meta: 'Note · just now', icon: 'note' } },
];

// ── Add-a-source sheet: same grammar as New Collection — describe a topic in
//    natural language → Nexus researches → review/deselect → add; or go direct
//    with a link. Rises over the collection view like the creation sheet. ──
const CV_SUGGEST = {
  'US–Iran conflict': ['Sanctions and their history', 'Views from inside Iran', 'The nuclear program, explained'],
  'AI platform shifts': ['Open-source model economics', 'The chip supply chain', 'Regulation on the horizon'],
  'Ozempic & longevity': ['Long-term side effects', 'The supply shortage', 'What insurers are doing'],
  'Vision Pro 2': ['Developer ecosystem health', 'Competitor headsets', 'Spatial video adoption'],
  default: ['Primary documents', 'Credible counter-views', 'The longer history'],
};

function CVSpinner() {
  return <div style={{ width: 15, height: 15, borderRadius: 999, flex: '0 0 auto', border: `2px solid rgba(112,84,171,0.18)`, borderTopColor: CV_ACCENT, animation: 'nxSpin .75s linear infinite' }} />;
}

function CVPhrase({ t }) {
  const phrases = ['Researching…', 'Finding authoritative sources…', 'Reading everything…'];
  const [i, setI] = useState(0);
  const [show, setShow] = useState(true);
  useEffect(() => {
    const id = setInterval(() => { setShow(false); setTimeout(() => { setI((x) => (x + 1) % phrases.length); setShow(true); }, 240); }, 1900);
    return () => clearInterval(id);
  }, []);
  return <span style={{ fontSize: 13.5, color: t.muted, letterSpacing: -0.1, opacity: show ? 1 : 0, transform: show ? 'none' : 'translateY(4px)', transition: 'opacity .22s ease, transform .22s ease' }}>{phrases[i]}</span>;
}

function CVShimRow({ t }) {
  const shim = { background: 'linear-gradient(90deg,#EDEAF5 25%,#F5F3FB 50%,#EDEAF5 75%)', backgroundSize: '800px 100%', animation: 'nxShimmer 1.6s ease-in-out infinite' };
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, background: t.surface, border: `1px solid ${t.border}`, borderRadius: 13, padding: '13px 14px', marginBottom: 9 }}>
      <div style={{ width: 34, height: 34, borderRadius: 9, flex: '0 0 auto', ...shim }} />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 8 }}>
        <div style={{ width: '72%', height: 13, borderRadius: 6, ...shim }} />
        <div style={{ width: '42%', height: 11, borderRadius: 6, ...shim }} />
      </div>
    </div>
  );
}

function CVPickRow({ t, s, selected, onToggle }) {
  return (
    <Pressable scale={0.985} onClick={onToggle} style={{ display: 'flex', alignItems: 'center', gap: 12, width: '100%', textAlign: 'left', background: t.surface, border: `1px solid ${t.border}`, borderRadius: 13, padding: '12px 13px', marginBottom: 9, cursor: 'pointer', fontFamily: L_FONT, animation: `nxFade .34s ${CV_EASE} both` }}>
      <div style={{ width: 34, height: 34, borderRadius: 9, flex: '0 0 auto', background: t.surface2, border: `1px solid ${t.border}`, display: 'flex', alignItems: 'center', justifyContent: 'center', opacity: selected ? 1 : 0.45, transition: 'opacity .2s ease' }}><LIcon name={s.icon || 'link'} size={17} color={t.muted} /></div>
      <div style={{ flex: 1, minWidth: 0, opacity: selected ? 1 : 0.45, transition: 'opacity .2s ease' }}>
        <div style={{ fontSize: 14.5, fontWeight: 600, letterSpacing: -0.2, color: t.text, lineHeight: 1.3, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{s.title}</div>
        <div style={{ fontSize: 12.5, color: t.faint, marginTop: 2 }}>{s.src} · {s.meta}</div>
      </div>
      <div style={{ width: 24, height: 24, borderRadius: 999, flex: '0 0 auto', border: `1.5px solid ${selected ? t.text : t.borderStrong}`, display: 'flex', alignItems: 'center', justifyContent: 'center', transition: 'border-color .2s ease' }}>
        <span style={{ display: 'inline-flex', opacity: selected ? 1 : 0, transform: selected ? 'scale(1)' : 'scale(0.5)', transition: 'opacity .18s ease, transform .22s cubic-bezier(.18,1.5,.4,1)' }}>
          <LIcon name="check" size={13} color={t.text} stroke={2.2} />
        </span>
      </div>
    </Pressable>
  );
}

function AddSourceSheet({ t, title, open, onClose, onAddMany, onAddLink, seed }) {
  const [phase, setPhase] = useState(seed || 'input'); // input | loading | review
  const [query, setQuery] = useState(seed && seed !== 'input' ? 'Sanctions and their history' : '');
  const [found, setFound] = useState(seed === 'loading' ? 1 : seed === 'review' ? 3 : 0);
  const [sel, setSel] = useState(seed ? new Set([0, 1, 2]) : new Set());
  const timers = useRef([]);
  useEffect(() => () => timers.current.forEach(clearTimeout), []);
  useEffect(() => {
    if (!open) { timers.current.forEach(clearTimeout); timers.current = []; const id = setTimeout(() => { setPhase('input'); setFound(0); }, 450); timers.current = [id]; }
  }, [open]);
  const later = (fn, ms) => timers.current.push(setTimeout(fn, ms));
  const srcs = nxFallbackSources(query).slice(0, 3);
  const run = (q) => {
    setQuery(q); setFound(0); setSel(new Set([0, 1, 2])); setPhase('loading');
    [0, 1, 2].forEach((i) => later(() => setFound(i + 1), 1700 + i * 450));
    later(() => setPhase('review'), 1700 + 3 * 450 + 200);
  };
  const toggle = (i) => setSel((p) => { const n = new Set(p); n.has(i) ? n.delete(i) : n.add(i); return n.size ? n : p; });
  const confirm = () => { onAddMany(srcs.filter((_, i) => sel.has(i))); onClose(); };
  const suggestions = CV_SUGGEST[title] || CV_SUGGEST.default;
  return (
    <>
      <div onClick={onClose} style={{ position: 'absolute', inset: 0, zIndex: 70, background: 'rgba(19,14,26,0.22)', opacity: open ? 1 : 0, pointerEvents: open ? 'auto' : 'none', transition: 'opacity .4s ease' }} />
      <div data-screen-label="Add a source sheet" style={{ position: 'absolute', inset: 0, zIndex: 80, background: t.page, transform: open ? 'translateY(8%)' : 'translateY(103%)', borderRadius: '24px 24px 0 0', overflow: 'hidden', boxShadow: '0 -12px 40px rgba(19,14,26,0.20)', transition: 'transform .5s cubic-bezier(.32,.72,.28,1)' }}>
        <div style={{ height: '92%', display: 'flex', flexDirection: 'column', position: 'relative' }}>
          <div style={{ display: 'flex', justifyContent: 'center', padding: '9px 0 2px', flex: '0 0 auto' }}>
            <div style={{ width: 36, height: 5, borderRadius: 999, background: t.borderStrong, opacity: 0.8 }} />
          </div>
          <div style={{ display: 'flex', alignItems: 'flex-start', gap: 10, padding: '8px 16px 4px', flex: '0 0 auto' }}>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 23, fontWeight: 700, letterSpacing: -0.6, lineHeight: 1.2, color: t.text, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{phase === 'input' ? 'Add a source' : query}</div>
              {phase !== 'input' && (
                <div style={{ display: 'flex', alignItems: 'center', gap: 9, marginTop: 7, minHeight: 18 }}>
                  {phase === 'review'
                    ? <span style={{ display: 'inline-flex', alignItems: 'center', gap: 7, fontSize: 13.5, color: t.muted, letterSpacing: -0.1, animation: `nxFade .3s ${CV_EASE}` }}><LIcon name="check" size={15} color={t.text} stroke={2} />Found {srcs.length} sources — tap to deselect any</span>
                    : <><CVSpinner /><CVPhrase t={t} /></>}
                </div>
              )}
            </div>
            <Pressable scale={0.86} onClick={onClose} aria-label="Close" style={{ width: 30, height: 30, borderRadius: 999, flex: '0 0 auto', border: 'none', background: t.surface2, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', padding: 0, marginTop: 2 }}>
              <LIcon name="x" size={15} color={t.muted} />
            </Pressable>
          </div>
          {phase === 'input' ? (
            <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '10px 18px 20px' }}>
              <div style={{ width: '100%', background: t.surface, borderRadius: 22, border: `1px solid ${t.border}`, boxShadow: '0 2px 10px rgba(19,14,26,0.04)', padding: '14px 12px 11px' }}>
                <div style={{ padding: '0 4px 14px' }}><span style={{ fontSize: 16, color: t.ghost, letterSpacing: -0.2 }}>Research a topic…</span></div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <div style={iconBtn(t, 32)}><LIcon name="plus" size={18} color={t.text} /></div>
                  <div style={{ flex: 1 }} />
                  <div style={iconBtn(t, 32)}><LIcon name="mic" size={18} color={t.muted} /></div>
                </div>
              </div>
              <div style={{ fontSize: 11.5, fontWeight: 600, letterSpacing: 0.8, textTransform: 'uppercase', color: t.faint, marginTop: 24, marginBottom: 12 }}>Suggested for this collection</div>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                {suggestions.map((q) => (
                  <Pressable key={q} scale={0.95} onClick={() => run(q)} style={{ display: 'inline-flex', alignItems: 'center', gap: 7, padding: '10px 14px', borderRadius: 999, background: t.surface, border: `1px solid ${t.border}`, cursor: 'pointer', fontFamily: L_FONT, fontSize: 13.5, fontWeight: 500, letterSpacing: -0.15, color: t.text }}>
                    <LIcon name="nexus" size={14} color={t.faint} />{q}
                  </Pressable>
                ))}
              </div>
              <div style={{ fontSize: 11.5, fontWeight: 600, letterSpacing: 0.8, textTransform: 'uppercase', color: t.faint, marginTop: 26, marginBottom: 12 }}>Or add a link</div>
              <div style={{ display: 'flex', gap: 7 }}>
                {[['globe', 'Website'], ['file', 'PDF'], ['video', 'YouTube']].map(([ic, lb]) => (
                  <Pressable key={lb} scale={0.9} onClick={() => onAddLink(lb)} style={{ flex: 1, height: 56, borderRadius: 16, background: t.surface, border: `1px solid ${t.border}`, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 5, cursor: 'pointer', padding: 0, fontFamily: L_FONT }}>
                    <LIcon name={ic} size={19} color={t.muted} />
                    <span style={{ fontSize: 12, fontWeight: 500, color: t.muted, letterSpacing: -0.1 }}>{lb}</span>
                  </Pressable>
                ))}
              </div>
            </div>
          ) : (
            <>
              <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '12px 16px 120px' }}>
                {srcs.map((s, i) => (i < found
                  ? <CVPickRow key={s.src + i} t={t} s={s} selected={sel.has(i)} onToggle={() => phase !== 'loading' ? toggle(i) : null} />
                  : <CVShimRow key={'sh' + i} t={t} />))}
              </div>
              <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, padding: '26px 16px 28px', background: 'linear-gradient(180deg, rgba(249,248,252,0) 0%, #F9F8FC 38%)', transform: phase === 'review' ? 'translateY(0)' : 'translateY(115%)', transition: 'transform .5s cubic-bezier(.22,1.18,.36,1)' }}>
                <Pressable scale={0.97} onClick={confirm} style={{ width: '100%', height: 50, borderRadius: 999, border: 'none', background: CV_ACCENT, color: '#fff', fontFamily: L_FONT, fontSize: 16, fontWeight: 600, letterSpacing: -0.2, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  {`Add ${sel.size} source${sel.size === 1 ? '' : 's'}`}
                </Pressable>
              </div>
            </>
          )}
        </div>
      </div>
    </>
  );
}

// ── Sources tab: the material, add via + (glass menu), quiet per-row delete ──
function SourcesPane({ t, items, removing, onRemove, plusOpen, onPlus }) {
  return (
    <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
      <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '14px 16px 4px' }}>
        {items.map((it) => <LinkRow key={it.id} t={t} it={it} removing={removing === it.id} onRemove={() => onRemove(it.id)} />)}
      </div>
      <div style={{ flex: '0 0 auto', padding: '8px 16px 6px' }}>
        <Pressable scale={0.97} onClick={onPlus} aria-label="Add a source" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, width: '100%', height: 48, borderRadius: 999, background: t.surface, border: `1px solid ${plusOpen ? t.borderStrong : t.border}`, boxShadow: plusOpen ? `0 0 0 3px ${t.surface2}` : '0 1px 2px rgba(19,14,26,0.03)', cursor: 'pointer', fontFamily: L_FONT, transition: 'border-color .18s, box-shadow .18s' }}>
          <span style={{ display: 'inline-flex', transform: plusOpen ? 'rotate(45deg)' : 'none', transition: `transform .22s ${CV_EASE}` }}><LIcon name="plus" size={18} color={t.text} /></span>
          <span style={{ fontSize: 15, fontWeight: 600, letterSpacing: -0.2, color: t.text }}>Add a source</span>
        </Pressable>
      </div>
    </div>
  );
}

// ── Nexus tab: AI framing → starter prompts → chat with inline source chips ──

// inline source chip — sits inside answer text, NotebookLM-style
function SrcChip({ t, icon, label }) {
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, height: 22, padding: '0 9px', margin: '0 2px', borderRadius: 999, background: t.surface, border: `1px solid ${t.border}`, fontSize: 11.5, fontWeight: 600, color: t.muted, letterSpacing: -0.1, whiteSpace: 'nowrap', verticalAlign: -5 }}>
      <LIcon name={icon || 'globe'} size={11} color={t.faint} />{label}
    </span>
  );
}

// AI-written framing: an enticing editorial hook per topic, not an inventory
const NX_FRAMING = {
  'US–Iran conflict': 'Back-channel talks in Oman, a strait that carries a fifth of the world’s oil, and two decades of almost-deals — your sources don’t agree on where this ends.',
  'AI platform shifts': 'Every model is becoming a platform, capex is going vertical, and nobody agrees where the value lands — your sources map the whole fight.',
  'Ozempic & longevity': 'A diabetes drug is quietly rewriting what we know about aging — and your sources split on whether it’s hype or history.',
  'Vision Pro 2': 'Lighter, cheaper, and still searching for its killer app — your sources disagree on whether spatial computing finally arrives.',
};
function nxFraming(items, title) {
  const hook = NX_FRAMING[title] || `There’s a sharper story in here than the headlines suggest — what’s driving ${title}, what’s actually at stake, and where it breaks next.`;
  return `${hook} I’ve read all ${items.length} sources — ask me anything.`;
}

// the six starter prompts; answers are blocks of paragraphs / bullets with inline chips
function nxStarters(items) {
  const a = items[0] || {}, b = items[1] || {}, c = items[2] || {}, z = items[items.length - 1] || {};
  const ch = (s) => ({ chip: s.src, icon: s.icon });
  const p = (...parts) => ({ type: 'p', parts });
  const li = (...parts) => ({ type: 'li', parts });
  return [
    { q: 'What are the key ideas across these sources?', blocks: [
      p('Three threads run through this collection: what just happened, what’s at stake, and how it got here. ', ch(a), ' and ', ch(b), ' carry the freshest account, while ', ch(c), ' supplies the structure underneath — read across them and the same few ideas keep resurfacing.'),
    ] },
    { q: 'What should I read first?', blocks: [
      p(`Start with “${a.title}” `, ch(a), ' — it’s the clearest overview in the set. Then ', ch(b), ' for the background, and save the longer pieces for when you want depth.'),
    ] },
    { q: 'Summarize this collection in 3 bullets', blocks: [
      li('The newest developments — and why this moment is different — are best captured by ', ch(a), '.'),
      li('The stakes: who stands to gain or lose, laid out most sharply in ', ch(b), '.'),
      li('The long arc: ', ch(c), ' traces how things reached this point, which the daily coverage assumes.'),
    ] },
    { q: 'What questions does this collection raise?', blocks: [
      p('A few questions your sources circle but don’t settle:'),
      li('Is this a turning point or another swing of the cycle? ', ch(a)),
      li('Whose framing of the stakes is right? ', ch(b), ' and ', ch(z), ' read them quite differently.'),
      li('What single development would change the whole picture? The analysis hints, but stops short. ', ch(c)),
    ] },
    { q: 'Are there contradictions between sources?', blocks: [
      p('Aligned on the facts, split on the framing. ', ch(a), ' treats the latest developments as significant; ', ch(z), ' reads them as noise inside a longer pattern. The disagreement is about trajectory, not events — worth reading those two side by side.'),
    ] },
    { q: 'What’s missing from this collection?', blocks: [
      p('You’re strong on reporting and analysis, lighter on primary documents and data — and there’s no skeptical counter-view in the set yet. Want me to find a couple of candidates?'),
    ] },
  ];
}

function NxParts({ t, parts }) {
  return <>{parts.map((s, i) => (typeof s === 'string' ? s : <SrcChip key={i} t={t} icon={s.icon} label={s.chip} />))}</>;
}

function NxBlocks({ t, blocks }) {
  const txt = { fontSize: 15, lineHeight: 1.6, letterSpacing: -0.2, color: t.text, textWrap: 'pretty' };
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
      {blocks.map((b, i) => (b.type === 'li'
        ? <div key={i} style={{ display: 'flex', gap: 11 }}><span style={{ color: t.faint, lineHeight: 1.6, fontSize: 15 }}>•</span><span style={txt}><NxParts t={t} parts={b.parts} /></span></div>
        : <div key={i} style={txt}><NxParts t={t} parts={b.parts} /></div>))}
    </div>
  );
}

function StarterChip({ t, q, onClick, nowrap }) {
  return (
    <Pressable scale={0.95} onClick={onClick} style={{ display: 'inline-flex', alignItems: 'center', padding: '10px 15px', borderRadius: 999, background: t.surface, border: `1px solid ${t.border}`, cursor: 'pointer', fontFamily: L_FONT, fontSize: 13.5, fontWeight: 500, letterSpacing: -0.15, color: t.text, textAlign: 'left', lineHeight: 1.3, whiteSpace: nowrap ? 'nowrap' : 'normal', flex: '0 0 auto' }}>{q}</Pressable>
  );
}

// ── the four "Nexus can make things" actions — icon-annotated cards ──
const NX_CREATE = [
  { q: 'Create an audio summary', label: 'Audio summary', kind: 'audio', icon: 'audio', blocks: [{ type: 'p', parts: ['Two hosts, one conversation — your collection as a listen:'] }] },
  { q: 'Generate an infographic', label: 'Infographic', kind: 'info', icon: 'trending', blocks: [{ type: 'p', parts: ['The whole collection, distilled into one visual:'] }] },
  { q: 'Quiz me on this', label: 'Quiz me', kind: 'quiz', icon: 'quiz', blocks: [{ type: 'p', parts: ['Let’s see what stuck — five questions, straight from your sources:'] }] },
  { q: 'Write a paper', label: 'Write a paper', kind: 'paper', icon: 'note', blocks: [{ type: 'p', parts: ['A structured draft, built only from what’s in this collection:'] }] },
];

function CreateCard({ t, item, onClick }) {
  return (
    <Pressable scale={0.95} onClick={onClick} style={{ display: 'flex', alignItems: 'center', gap: 10, background: t.surface, border: `1px solid ${t.border}`, borderRadius: 14, padding: '13px 13px', cursor: 'pointer', fontFamily: L_FONT, textAlign: 'left' }}>
      {item.icon === 'audio'
        ? <LAudioGlyph color={CV_ACCENT} size={18} />
        : <LIcon name={item.icon} size={19} color={CV_ACCENT} stroke={1.8} />}
      <span style={{ fontSize: 13.5, fontWeight: 600, letterSpacing: -0.2, color: t.text }}>{item.label}</span>
    </Pressable>
  );
}

// ── mock artifacts the create actions return ──
function NxArtifact({ t, kind, items, title }) {
  const a = items[0] || {}, b = items[1] || {};
  const card = { background: t.surface, border: `1px solid ${t.border}`, borderRadius: 16 };
  if (kind === 'audio') {
    return (
      <div style={{ ...card, display: 'flex', alignItems: 'center', gap: 12, padding: '12px 14px' }}>
        <div style={{ width: 40, height: 40, borderRadius: 999, background: t.ink, display: 'flex', alignItems: 'center', justifyContent: 'center', flex: '0 0 auto' }}><LIcon name="play" size={17} color="#fff" /></div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 14.5, fontWeight: 600, letterSpacing: -0.2, color: t.text }}>Audio overview</div>
          <div style={{ fontSize: 12.5, color: t.faint, marginTop: 2 }}>Two hosts · 4:32</div>
        </div>
        <LAudioGlyph color={t.muted} size={20} />
      </div>
    );
  }
  if (kind === 'info') {
    return (
      <div style={{ ...card, overflow: 'hidden' }}>
        <div style={{ height: 116, background: t.surface2, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 7 }}>
          <LIcon name="trending" size={26} color={t.ghost} />
          <span style={{ fontSize: 12, color: t.faint }}>Generating preview…</span>
        </div>
        <div style={{ padding: '10px 14px', fontSize: 13.5, fontWeight: 600, letterSpacing: -0.2, color: t.text }}>{title} — in 5 numbers</div>
      </div>
    );
  }
  if (kind === 'quiz') {
    return (
      <div style={{ ...card, padding: '13px 14px' }}>
        <div style={{ fontSize: 11, fontWeight: 600, letterSpacing: 0.7, textTransform: 'uppercase', color: t.faint }}>Question 1 of 5</div>
        <div style={{ fontSize: 15, fontWeight: 600, letterSpacing: -0.2, color: t.text, marginTop: 7, lineHeight: 1.4, textWrap: 'pretty' }}>Which outlet published “{a.title}”?</div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 7, marginTop: 11 }}>
          {[a.src, b.src].map((c) => (
            <Pressable key={c} scale={0.97} style={{ width: '100%', textAlign: 'left', padding: '10px 13px', borderRadius: 12, background: t.surface3, border: `1px solid ${t.hair}`, cursor: 'pointer', fontFamily: L_FONT, fontSize: 13.5, fontWeight: 500, color: t.text }}>{c}</Pressable>
          ))}
        </div>
      </div>
    );
  }
  return (
    <div style={{ ...card, padding: '13px 14px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 7, fontSize: 11, fontWeight: 600, letterSpacing: 0.7, textTransform: 'uppercase', color: t.faint }}><LIcon name="note" size={13} color={t.faint} />Draft outline</div>
      <div style={{ fontSize: 15, fontWeight: 600, letterSpacing: -0.2, color: t.text, marginTop: 7 }}>{title}: what the sources say</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 5, marginTop: 9, fontSize: 13, color: t.muted, lineHeight: 1.5 }}>
        <span>I. The story so far</span>
        <span>II. Where the sources disagree</span>
        <span>III. What happens next</span>
      </div>
    </div>
  );
}

// ── wait experience (chosen): the brand mark broadcasting — arc pairs ripple
//    out from the breathing node while Nexus works ──
function EchoPulse() {
  const ring = (delay) => (
    <g style={{ transformOrigin: '24px 24px', animation: `nxEcho 1.7s ${delay}s cubic-bezier(.2,.6,.4,1) infinite` }} stroke={CV_ACCENT} strokeWidth="3" strokeLinecap="round" fill="none">
      <path d="M18.5 16 A11 11 0 0 0 18.5 32"></path>
      <path d="M29.5 16 A11 11 0 0 1 29.5 32"></path>
    </g>
  );
  return (
    <div style={{ padding: '12px 0' }}>
      <svg width="36" height="36" viewBox="0 0 48 48">
        <circle cx="24" cy="24" r="4.4" fill={CV_ACCENT} style={{ animation: 'nxNodeBreathe 1.7s ease-in-out infinite' }}></circle>
        {ring(0)}
        {ring(0.85)}
      </svg>
    </div>
  );
}

function NexusPane({ t, items, title, seed }) {
  const starters = nxStarters(items);
  // seed: freeze a chat state for static canvas boards — 'thinking' | 'answered' | 'artifact'
  const seedMsgs = seed === 'thinking' ? [{ role: 'user', text: starters[0].q }]
    : seed === 'answered' ? [{ role: 'user', text: starters[1].q }, { role: 'nexus', blocks: starters[1].blocks }]
    : seed === 'artifact' ? [{ role: 'user', text: NX_CREATE[0].q }, { role: 'nexus', blocks: NX_CREATE[0].blocks, kind: 'audio' }]
    : [];
  const [msgs, setMsgs] = useState(seedMsgs);
  const [busy, setBusy] = useState(seed === 'thinking');
  const scRef = useRef(null);
  const timers = useRef([]);
  useEffect(() => () => timers.current.forEach(clearTimeout), []);
  useEffect(() => { const el = scRef.current; if (el) el.scrollTop = el.scrollHeight; }, [msgs, busy]);
  const ask = (qa) => {
    if (busy) return;
    setMsgs((m) => [...m, { role: 'user', text: qa.q }]);
    setBusy(true);
    timers.current.push(setTimeout(() => { setMsgs((m) => [...m, { role: 'nexus', blocks: qa.blocks, kind: qa.kind }]); setBusy(false); }, 1500));
  };
  const asked = new Set(msgs.filter((m) => m.role === 'user').map((m) => m.text));
  const remaining = [...NX_CREATE, ...starters].filter((s) => !asked.has(s.q));
  const empty = msgs.length === 0;

  return (
    <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
      <div ref={scRef} style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '12px 18px 8px' }}>
        {empty ? (
          <div style={{ paddingTop: 16, animation: `nxFade .32s ${CV_EASE}` }}>
            <LIcon name="nexus" size={27} color={t.text} />
            <div style={{ fontSize: 16.5, fontWeight: 500, lineHeight: 1.55, letterSpacing: -0.25, color: t.text, marginTop: 14, textWrap: 'pretty' }}>{nxFraming(items, title)}</div>
            <div style={{ fontSize: 11.5, fontWeight: 600, letterSpacing: 0.8, textTransform: 'uppercase', color: t.faint, marginTop: 28, marginBottom: 12 }}>Create</div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
              {NX_CREATE.map((s) => <CreateCard key={s.q} t={t} item={s} onClick={() => ask(s)} />)}
            </div>
            <div style={{ fontSize: 11.5, fontWeight: 600, letterSpacing: 0.8, textTransform: 'uppercase', color: t.faint, marginTop: 24, marginBottom: 12 }}>Or ask</div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
              {starters.map((s) => <StarterChip key={s.q} t={t} q={s.q} onClick={() => ask(s)} />)}
            </div>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16, paddingTop: 4 }}>
            {msgs.map((m, i) => (m.role === 'user'
              ? <div key={i} style={{ alignSelf: 'flex-end', maxWidth: '82%', background: t.surface2, border: `1px solid ${t.hair}`, borderRadius: 18, padding: '10px 14px', fontSize: 15, letterSpacing: -0.2, color: t.text, lineHeight: 1.4, animation: `nxFade .26s ${CV_EASE}` }}>{m.text}</div>
              : <div key={i} style={{ animation: `nxFade .34s ${CV_EASE}` }}><NxBlocks t={t} blocks={m.blocks} />{m.kind && <div style={{ marginTop: 12 }}><NxArtifact t={t} kind={m.kind} items={items} title={title} /></div>}</div>))}
            {busy && <EchoPulse />}
          </div>
        )}
      </div>
      {!empty && remaining.length > 0 && (
        <div style={{ flex: '0 0 auto', display: 'flex', gap: 8, overflowX: 'auto', padding: '6px 16px 4px', scrollbarWidth: 'none' }}>
          {remaining.slice(0, 3).map((s) => <StarterChip key={s.q} t={t} q={s.q} nowrap onClick={() => ask(s)} />)}
        </div>
      )}
      <div style={{ flex: '0 0 auto', padding: '6px 16px 6px' }}>
        <CVComposer t={t} ghost="Ask Nexus anything" mode="ask" />
      </div>
    </div>
  );
}

// ── the collection view: header + Nexus/Sources tabs (glass capsule + swipe) ──
function CollectionView({ t, title, meta, initialItems, startPivot = 'Nexus', onBack, backLabel = 'Home', nexusSeed, addSeed }) {
  const [pivot, setPivot] = useState(startPivot);
  const [items, setItems] = useState(initialItems);
  const [removing, setRemoving] = useState(null);
  const [plusOpen, setPlusOpen] = useState(!!addSeed);
  const timers = useRef([]);
  useEffect(() => () => timers.current.forEach(clearTimeout), []);

  const remove = (id) => {
    setRemoving(id);
    timers.current.push(setTimeout(() => { setItems((arr) => arr.filter((x) => x.id !== id)); setRemoving(null); }, 340));
  };
  const addMany = (list) => {
    const now = Date.now();
    setItems((arr) => [...list.map((s, i) => ({ id: 'm' + now + i, ...s })), ...arr]);
  };
  const addLink = (label) => {
    setPlusOpen(false);
    const o = CV_ADD.find((x) => x.label === label);
    if (o) add(o);
  };

  return (
    <div data-screen-label="Collection view" style={{ position: 'relative', flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column', fontFamily: L_FONT, color: t.text }}>
      <CVStyles />
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '2px 12px 4px', flex: '0 0 auto' }}>
        <Pressable scale={0.84} pressDur={0.44} pressEase={SPRING_BOUNCE} onClick={onBack} aria-label="Back" style={{ width: 40, height: 40, borderRadius: 999, flex: '0 0 auto', border: `1px solid ${t.borderStrong}`, background: t.surface, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', padding: 0 }}>
          <span style={{ transform: 'scaleX(-1)', display: 'inline-flex' }}><LIcon name="chevR" size={20} color={t.text} stroke={1.8} /></span>
        </Pressable>
      </div>
      <div style={{ padding: '2px 18px 6px', flex: '0 0 auto' }}>
        <div style={{ fontSize: 26, fontWeight: 700, letterSpacing: -0.7, lineHeight: 1.15, color: t.text }}>{title}</div>
        <div style={{ fontSize: 13.5, color: t.faint, marginTop: 5, letterSpacing: -0.1 }}>{items.length} sources · {meta}</div>
      </div>
      <PivotSwipe pivot={pivot} items={['Nexus', 'Sources']} dur={380} ease={CV_EASE} motion="slide">
        {(p) => (p === 'Sources'
          ? <SourcesPane t={t} items={items} removing={removing} onRemove={remove} plusOpen={plusOpen} onPlus={() => setPlusOpen((v) => !v)} />
          : <NexusPane t={t} items={items} title={title} seed={nexusSeed} />)}
      </PivotSwipe>
      {/* bottom pivot — Photos-style floating Liquid Glass capsule, centered in thumb reach.
          The glass thumb springs between tabs (true-spring linear() — the focus visibly travels). */}
      <div style={{ flex: '0 0 auto', display: 'flex', justifyContent: 'center', padding: '6px 0 24px' }}>
        <LiquidGlassCard radius={999}>
          <Segmented items={['Nexus', 'Sources']} value={pivot} onChange={setPivot} dur={520} ease={SPRING_LINEAR}
            pulse={`nxBubble .56s ${CV_EASE}`}
            getLabel={(it) => {
              const sel = pivot === it;
              const tint = sel ? CV_ACCENT : t.muted;
              return (
                <span style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3 }}>
                  <LIcon name={it === 'Nexus' ? (sel ? 'nexusFill' : 'nexus') : (sel ? 'layersFill' : 'layers')} size={26} color={tint} stroke={1.7} />
                  <span style={{ fontSize: 11.5, fontWeight: 600, letterSpacing: -0.1, color: tint, transition: 'color .25s ease' }}>{it}</span>
                </span>
              );
            }}
            trackStyle={{ display: 'flex', gap: 2, padding: 4 }}
            itemStyle={{ padding: '8px 30px 7px', borderRadius: 999, background: 'transparent', border: 'none', cursor: 'pointer' }}
            activeItemStyle={{}}
            thumbStyle={{ background: 'rgba(255,255,255,0.66)', borderRadius: 999, boxShadow: 'inset 0 0 0 1px rgba(255,255,255,0.85), inset 0 1.5px 1px rgba(255,255,255,0.95), 0 5px 16px rgba(19,14,26,0.18)' }} />
        </LiquidGlassCard>
      </div>
      <AddSourceSheet t={t} title={title} open={plusOpen} onClose={() => setPlusOpen(false)} onAddMany={addMany} onAddLink={addLink} seed={addSeed} />
    </div>
  );
}

// ── standalone artboard wrapper (returning-user entry from the landing page) ──
function CollectionBoard({ pivot = 'Nexus', nexusSeed, addSeed }) {
  const t = lTheme();
  const items = NX_SOURCES['US–Iran conflict'].map((s, i) => ({ id: 's' + i, ...s }));
  return (
    <IOSDevice>
      <div style={{ height: '100%', background: t.page, display: 'flex', flexDirection: 'column', WebkitFontSmoothing: 'antialiased' }}>
        <LStatusSpacer h={56} />
        <CollectionView t={t} title="US–Iran conflict" meta="updated 2h ago" initialItems={items} startPivot={pivot} onBack={() => {}} nexusSeed={nexusSeed} addSeed={addSeed} />
      </div>
    </IOSDevice>
  );
}

Object.assign(window, { CollectionView, CollectionBoard, NX_SOURCES, NX_TRENDING, nxFallbackSources });
