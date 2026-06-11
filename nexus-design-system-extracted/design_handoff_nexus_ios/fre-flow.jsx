// fre-flow.jsx — Create-a-collection flow, end to end (interactive):
//   input screen → tap a trending topic → 90% bottom sheet (loading shimmer +
//   rolling wait phrases) → sources stream in → review/deselect → confirm →
//   the sheet dismisses down while the collection PAGE pushes in from the right
//   (Links / Ask pivots) — so back popping right matches the navigation model.
// Reuses: lTheme, L_FONT, LIcon, LStatusSpacer, iconBtn (landing-kit) ·
//   Pressable (landing-app) · CollectionView, NX_SOURCES, NX_TRENDING,
//   nxFallbackSources (collection-view) · IOSDevice (ios-frame).
// Exports: FREFlow — interactive end-to-end; pass stage="loading"|"review" to
// freeze the sheet mid-flow for static step-by-step canvas boards.
const { useState, useEffect, useRef } = React;

const FLOW_EASE = 'cubic-bezier(.2,.8,.2,1)';
const FLOW_SHEET_EASE = 'cubic-bezier(.32,.72,.28,1)';   // iOS sheet settle
const FLOW_POP = 'cubic-bezier(.22,1.18,.36,1)';          // mild overshoot (footer)
const FLOW_ACCENT = '#7054AB';                             // approved plum (send button, spinner)
const FLOW_TOPICS = ['the US–Iran conflict', 'second-brain tools', 'how memory works', 'the AI platform shift', 'anything you’re tracking'];
const FLOW_PHRASES = ['Researching…', 'Finding authoritative sources…', 'Reading everything…', 'Picking the best pieces…', 'Almost ready…'];

// ── one-time keyframes ──
function FlowStyles() {
  useEffect(() => {
    if (document.getElementById('nx-flow-styles')) return;
    const s = document.createElement('style');
    s.id = 'nx-flow-styles';
    s.textContent = '@keyframes nxShimmer{from{background-position:-400px 0}to{background-position:400px 0}}@keyframes nxSpin{to{transform:rotate(360deg)}}';
    document.head.appendChild(s);
  }, []);
  return null;
}

function FlowSpinner() {
  return <div style={{ width: 16, height: 16, borderRadius: 999, flex: '0 0 auto', border: '2px solid rgba(112,84,171,0.18)', borderTopColor: FLOW_ACCENT, animation: 'nxSpin .75s linear infinite' }} />;
}

function FlowShimmerBlock({ w = '100%', h = 13, r = 6 }) {
  return <div style={{ width: w, height: h, borderRadius: r, background: 'linear-gradient(90deg,#EDEAF5 25%,#F5F3FB 50%,#EDEAF5 75%)', backgroundSize: '800px 100%', animation: 'nxShimmer 1.6s ease-in-out infinite' }} />;
}

function FlowShimmerRow({ t }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, background: t.surface, border: `1px solid ${t.border}`, borderRadius: 13, padding: '13px 14px', marginBottom: 9 }}>
      <div style={{ width: 34, height: 34, borderRadius: 9, flex: '0 0 auto', background: 'linear-gradient(90deg,#EDEAF5 25%,#F5F3FB 50%,#EDEAF5 75%)', backgroundSize: '800px 100%', animation: 'nxShimmer 1.6s ease-in-out infinite' }} />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 8 }}>
        <FlowShimmerBlock w="72%" h={13} />
        <FlowShimmerBlock w="42%" h={11} />
      </div>
    </div>
  );
}

// rolling wait phrase
function FlowPhrase({ t }) {
  const [i, setI] = useState(0);
  const [show, setShow] = useState(true);
  useEffect(() => {
    const id = setInterval(() => {
      setShow(false);
      setTimeout(() => { setI((x) => (x + 1) % FLOW_PHRASES.length); setShow(true); }, 260);
    }, 2000);
    return () => clearInterval(id);
  }, []);
  return <span style={{ fontSize: 13.5, color: t.muted, letterSpacing: -0.1, opacity: show ? 1 : 0, transform: show ? 'none' : 'translateY(4px)', transition: 'opacity .22s ease, transform .22s ease' }}>{FLOW_PHRASES[i]}</span>;
}

// rotating headline word
function FlowRotWord({ words, interval = 2200 }) {
  const t = lTheme();
  const [i, setI] = useState(0);
  const [show, setShow] = useState(true);
  useEffect(() => {
    const id = setInterval(() => {
      setShow(false);
      setTimeout(() => { setI((x) => (x + 1) % words.length); setShow(true); }, 240);
    }, interval);
    return () => clearInterval(id);
  }, []);
  return <span style={{ display: 'inline-block', color: t.text, fontWeight: 700, opacity: show ? 1 : 0, transform: show ? 'none' : 'translateY(8px)', transition: 'opacity .26s ease, transform .26s ease' }}>{words[i]}</span>;
}

// ── a found source in the sheet: tap to deselect (row dims, circle empties) ──
function SourcePickRow({ t, s, selected, onToggle }) {
  return (
    <Pressable scale={0.985} onClick={onToggle} style={{ display: 'flex', alignItems: 'center', gap: 12, width: '100%', textAlign: 'left', background: t.surface, border: `1px solid ${t.border}`, borderRadius: 13, padding: '12px 13px', marginBottom: 9, cursor: 'pointer', fontFamily: L_FONT, animation: `nxFade .34s ${FLOW_EASE} both` }}>
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

// ════════════════════════════════════════════════════════════
// The flow
// ════════════════════════════════════════════════════════════
function FREFlow({ stage }) {
  const t = lTheme();
  const [val, setVal] = useState('');
  const [active, setActive] = useState(false);
  const [topic, setTopic] = useState(stage ? 'US–Iran conflict' : '');
  const [phase, setPhase] = useState(stage || 'input'); // input | loading | review | collection | closing
  const [found, setFound] = useState(stage === 'loading' ? 3 : stage === 'review' ? 6 : 0);
  const [sel, setSel] = useState(stage ? new Set([0, 1, 2, 3, 4, 5]) : new Set());
  const [avOpen, setAvOpen] = useState(false); // account menu (avatar bloom)
  const [colItems, setColItems] = useState([]);
  const [pageIn, setPageIn] = useState(false); // collection page slid into place
  const timers = useRef([]);
  const closeDir = useRef('y'); // 'y' = sheet slides down, 'x' = page pops right
  useEffect(() => () => timers.current.forEach(clearTimeout), []);
  const later = (fn, ms) => timers.current.push(setTimeout(fn, ms));
  const clearTimers = () => { timers.current.forEach(clearTimeout); timers.current = []; };

  const srcs = NX_SOURCES[topic] || nxFallbackSources(topic);
  const sheetUp = phase === 'loading' || phase === 'review';
  const full = phase === 'collection';
  // page stays mounted while it pops off to the right
  const pageMounted = full || (phase === 'closing' && closeDir.current === 'x');

  // tap a trending chip (or send) → sheet rises and gathering begins.
  // NB: don't touch the composer here — a chip tap goes straight to the sheet
  // (pre-filling it caused a mic→send flash behind the rising sheet).
  const start = (tp) => {
    clearTimers();
    const list = NX_SOURCES[tp] || nxFallbackSources(tp);
    setTopic(tp); setFound(0); setPageIn(false);
    closeDir.current = 'y';
    setSel(new Set(list.map((_, i) => i)));
    later(() => setPhase('loading'), 200);
    list.forEach((_, i) => later(() => setFound(i + 1), 2400 + i * 430));
    later(() => setPhase('review'), 2400 + list.length * 430 + 240);
  };
  // dir 'y': the 90% sheet is absorbed downward. dir 'x': the collection is a
  // PAGE, so back pops it off to the right like any pushed screen.
  const dismiss = (dir = 'y') => {
    closeDir.current = dir;
    clearTimers();
    setPhase('closing');
    if (dir === 'x') setPageIn(false);
    later(() => { setPhase('input'); setVal(''); setActive(false); setFound(0); }, 580);
  };
  const toggle = (i) => setSel((prev) => {
    const n = new Set(prev);
    n.has(i) ? n.delete(i) : n.add(i);
    return n.size === 0 ? prev : n; // keep at least one
  });
  // confirm: the sheet dismisses DOWN while the collection page pushes in from
  // the RIGHT — reads as "sheet closed, navigation happened".
  const confirm = () => {
    setColItems(srcs.filter((_, i) => sel.has(i)).map((s, i) => ({ id: 'c' + i, ...s })));
    setPhase('collection');
    later(() => setPageIn(true), 40); // mount off-right first, then slide in
  };

  const sheetTransform = sheetUp ? 'translateY(9.5%)' : 'translateY(103%)';

  return (
    <IOSDevice>
      <FlowStyles />
      <div style={{ position: 'relative', height: '100%', overflow: 'hidden', background: '#16121D', fontFamily: L_FONT, color: t.text, WebkitFontSmoothing: 'antialiased' }}>

        {/* ── input screen (scales back behind the sheet, iOS-style; while the full
            page covers it, it idles at .97 so dismissal zooms it smoothly to 1) ── */}
        <div data-screen-label="FRE input" style={{ position: 'absolute', inset: 0, zIndex: 0, background: t.page, overflow: 'hidden', transformOrigin: 'top center', transform: sheetUp ? 'scale(0.945)' : full ? 'scale(0.97)' : 'none', borderRadius: (sheetUp || full) ? 22 : 0, transition: `transform .52s ${FLOW_SHEET_EASE}, border-radius .52s ${FLOW_SHEET_EASE}` }}>
          <LStatusSpacer h={64} />
          {/* avatar — top right; the account menu blooms from its corner (top-right pin) */}
          <div style={{ position: 'absolute', top: 64, right: 14, zIndex: 5 }}>
            <AvatarButton t={t} onClick={() => setAvOpen(true)} active={avOpen} />
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', justifyContent: 'center', padding: '0 22px 70px', height: 'calc(100% - 64px)', boxSizing: 'border-box' }}>
            <div style={{ fontSize: 12, fontWeight: 600, letterSpacing: 0.8, textTransform: 'uppercase', color: t.faint, marginBottom: 14 }}>New collection</div>
            <div style={{ fontSize: 29, fontWeight: 700, letterSpacing: -0.8, lineHeight: 1.22, color: t.muted, textWrap: 'pretty' }}>Start a collection on<br /><FlowRotWord words={FLOW_TOPICS} /></div>
            <div style={{ height: 24 }} />
            <div style={{ width: '100%', background: t.surface, borderRadius: 24, border: `1px solid ${active || val ? t.borderStrong : t.border}`, boxShadow: active || val ? `0 0 0 3px ${t.surface2}` : '0 2px 10px rgba(19,14,26,0.04)', padding: '16px 14px 12px', transition: 'box-shadow .18s, border-color .18s', cursor: 'text' }} onClick={() => setActive(true)}>
              {val
                ? <div style={{ padding: '2px 4px 16px', minHeight: 28 }}><span style={{ fontSize: 17, color: t.text, letterSpacing: -0.2, lineHeight: 1.4 }}>{val}<span style={{ display: 'inline-block', width: 1.5, height: 18, background: t.text, marginLeft: 1, verticalAlign: -3, animation: 'nxBlink 1.1s steps(1) infinite alternate' }} /></span></div>
                : <div style={{ padding: '2px 4px 16px', minHeight: 28 }}><span style={{ fontSize: 17, color: t.ghost, letterSpacing: -0.2, lineHeight: 1.4 }}>Research a topic…</span></div>}
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <div style={iconBtn(t, 32)}><LIcon name="plus" size={18} color={t.text} /></div>
                <div style={{ flex: 1 }} />
                {(active || val)
                  ? <Pressable scale={0.84} onClick={() => val.trim() && start(val.trim())} aria-label="Create" style={{ width: 42, height: 42, borderRadius: 999, flex: '0 0 auto', padding: 0, border: 'none', background: val ? FLOW_ACCENT : t.surface2, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
                      <LIcon name="arrowUp" size={19} color={val ? '#fff' : t.faint} stroke={1.8} />
                    </Pressable>
                  : <div style={iconBtn(t, 32)}><LIcon name="mic" size={18} color={t.muted} /></div>}
              </div>
            </div>
            <div style={{ marginTop: 20, display: 'flex', flexWrap: 'wrap', gap: 8 }}>
              {NX_TRENDING.map((c) => (
                <Pressable key={c} scale={0.95} onClick={() => start(c)} style={{ display: 'inline-flex', alignItems: 'center', gap: 6, height: 34, padding: '0 13px', borderRadius: 999, background: t.surface, border: `1px solid ${t.border}`, cursor: 'pointer', fontFamily: L_FONT, fontSize: 13.5, fontWeight: 500, color: t.text, letterSpacing: -0.1 }}>
                  <LIcon name="trending" size={13} color={t.faint} />{c}
                </Pressable>
              ))}
            </div>
            <div style={{ marginTop: 26 }}>
              <span style={{ fontSize: 13, color: t.faint, letterSpacing: -0.1, display: 'block', marginBottom: 10 }}>Or start with a link</span>
              <div style={{ display: 'flex', gap: 7 }}>
                {[['globe', 'Website'], ['file', 'PDF'], ['video', 'YouTube']].map(([ic, lb]) => (
                  <Pressable key={lb} scale={0.9} style={{ flex: 1, height: 50, borderRadius: 999, background: t.surface, border: `1px solid ${t.border}`, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 5, cursor: 'pointer', padding: 0 }}>
                    <LIcon name={ic} size={19} color={t.muted} />
                    <span style={{ fontFamily: L_FONT, fontSize: 12, fontWeight: 500, color: t.muted, letterSpacing: -0.1 }}>{lb}</span>
                  </Pressable>
                ))}
              </div>
            </div>
          </div>
          <BloomMenu open={avOpen} onClose={() => setAvOpen(false)} anchor={{ top: 64, right: 14 }} origin="top right">
            <AvatarMenuContent t={t} />
          </BloomMenu>
        </div>

        {/* ── scrim (only while the sheet is at 90%) ── */}
        <div onClick={() => dismiss('y')} style={{ position: 'absolute', inset: 0, zIndex: 40, background: 'rgba(19,14,26,0.22)', opacity: sheetUp ? 1 : 0, pointerEvents: sheetUp ? 'auto' : 'none', transition: 'opacity .4s ease' }} />

        {/* ── the sheet: 90% cover; dismisses down on close OR confirm ── */}
        <div data-screen-label="Sources sheet" style={{ position: 'absolute', inset: 0, zIndex: 50, background: t.page, transform: sheetTransform, borderRadius: '24px 24px 0 0', overflow: 'hidden', boxShadow: '0 -12px 40px rgba(19,14,26,0.20)', transition: phase === 'input' ? 'none' : `transform .48s ${FLOW_SHEET_EASE}` }}>
          {phase !== 'input' && (
            <div key="gather" style={{ height: '90.5%', display: 'flex', flexDirection: 'column', position: 'relative' }}>
              {/* grabber */}
              <div style={{ display: 'flex', justifyContent: 'center', padding: '9px 0 2px', flex: '0 0 auto' }}>
                <div style={{ width: 36, height: 5, borderRadius: 999, background: t.borderStrong, opacity: 0.8 }} />
              </div>
              {/* header: topic + status line + close */}
              <div style={{ display: 'flex', alignItems: 'flex-start', gap: 10, padding: '8px 16px 4px', flex: '0 0 auto' }}>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 23, fontWeight: 700, letterSpacing: -0.6, lineHeight: 1.2, color: t.text, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{topic}</div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 9, marginTop: 7, minHeight: 18 }}>
                    {phase === 'review'
                      ? <span style={{ display: 'inline-flex', alignItems: 'center', gap: 7, fontSize: 13.5, color: t.muted, letterSpacing: -0.1, animation: `nxFade .3s ${FLOW_EASE}` }}><LIcon name="check" size={15} color={t.text} stroke={2} />Found {srcs.length} sources — tap to deselect any</span>
                      : <><FlowSpinner /><FlowPhrase t={t} /></>}
                  </div>
                </div>
                <Pressable scale={0.86} onClick={() => dismiss('y')} aria-label="Close" style={{ width: 30, height: 30, borderRadius: 999, flex: '0 0 auto', border: 'none', background: t.surface2, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', padding: 0, marginTop: 2 }}>
                  <LIcon name="x" size={15} color={t.muted} />
                </Pressable>
              </div>
              {/* sources stream in over shimmer placeholders */}
              <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '12px 16px 130px' }}>
                {srcs.map((s, i) => (i < found
                  ? <SourcePickRow key={s.src + i} t={t} s={s} selected={sel.has(i)} onToggle={() => phase !== 'loading' ? toggle(i) : null} />
                  : <FlowShimmerRow key={'sh' + i} t={t} />))}
              </div>
              {/* confirm footer — slides up when everything is found */}
              <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, padding: '26px 16px 28px', background: 'linear-gradient(180deg, rgba(249,248,252,0) 0%, #F9F8FC 38%)', transform: phase === 'review' ? 'translateY(0)' : 'translateY(115%)', transition: `transform .5s ${FLOW_POP}` }}>
                <Pressable scale={0.97} onClick={confirm} style={{ width: '100%', height: 50, borderRadius: 999, border: 'none', background: FLOW_ACCENT, color: '#fff', fontFamily: L_FONT, fontSize: 16, fontWeight: 600, letterSpacing: -0.2, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  {`Create collection · ${sel.size} source${sel.size === 1 ? '' : 's'}`}
                </Pressable>
              </div>
            </div>
          )}
        </div>

        {/* ── the collection PAGE: pushes in from the right on confirm, pops back right ── */}
        {pageMounted && (
          <div data-screen-label="Collection page" style={{ position: 'absolute', inset: 0, zIndex: 60, background: t.page, transform: pageIn ? 'translateX(0)' : 'translateX(103%)', boxShadow: '-10px 0 30px rgba(19,14,26,0.14)', transition: `transform .48s ${FLOW_EASE}`, display: 'flex', flexDirection: 'column' }}>
            <LStatusSpacer h={56} />
            <CollectionView t={t} title={topic} meta="just now" initialItems={colItems} onBack={() => dismiss('x')} backLabel="Home" />
          </div>
        )}
      </div>
    </IOSDevice>
  );
}

Object.assign(window, { FREFlow });
