// fre.jsx — First-run experience: 3 candidates for "create your first collection".
// Built in the Nexus design language (accent-free, inline controls = hairline
// surfaces, floating menus = Liquid Glass, spring motion). Two intents in the
// brief: (1) name a topic → AI gathers sources; (2) paste link(s) → name it after.
// Exports: FRECanvas
const { useState, useEffect } = React;

// ── shared bits ──────────────────────────────────────────────
function Kicker({ children }) {
  const t = lTheme();
  return <div style={{ fontSize: 12, fontWeight: 600, letterSpacing: 0.8, textTransform: 'uppercase', color: t.faint, marginBottom: 14 }}>{children}</div>;
}

// rotating word — fades/slides through a list (the NotebookLM device)
function RotatingWord({ words, interval = 2200 }) {
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
  return (
    <span style={{ display: 'inline-block', color: t.text, fontWeight: 700,
      opacity: show ? 1 : 0, transform: show ? 'translateY(0)' : 'translateY(8px)',
      transition: 'opacity .26s ease, transform .26s ease' }}>{words[i]}</span>
  );
}

function Headline({ children }) {
  const t = lTheme();
  return <div style={{ fontSize: 29, fontWeight: 700, letterSpacing: -0.8, lineHeight: 1.22, color: t.muted, textWrap: 'pretty' }}>{children}</div>;
}

function SendBtn({ icon = 'sparkOutline', solid = true }) {
  const t = lTheme();
  return (
    <Pressable scale={0.84} style={{ width: 42, height: 42, borderRadius: 999, flex: '0 0 auto', padding: 0, border: solid ? 'none' : `1px solid ${t.border}`, background: solid ? t.ink : t.surface2, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
      <LIcon name={icon} size={19} color={solid ? '#fff' : t.faint} stroke={1.8} />
    </Pressable>
  );
}

function ModeChip({ on = true, label = 'Auto', icon = 'sparkOutline', onClick }) {
  const t = lTheme();
  return (
    <Pressable scale={0.93} onClick={onClick} style={{ display: 'inline-flex', alignItems: 'center', gap: 6, height: 34, padding: '0 12px', borderRadius: 999, background: on ? t.surface2 : t.surface, border: `1px solid ${on ? t.borderStrong : t.border}`, cursor: 'pointer', fontFamily: L_FONT, fontSize: 13, fontWeight: 600, color: on ? t.text : t.muted, letterSpacing: -0.1 }}>
      <LIcon name={icon} size={15} color={on ? t.text : t.muted} />{label}
    </Pressable>
  );
}

// shared inline "create" box (an inline control → hairline surface, not glass)
function CreateBox({ children, focus = false, onClick }) {
  const t = lTheme();
  return (
    <div onClick={onClick} style={{ width: '100%', background: t.surface, borderRadius: 24, border: `1px solid ${focus ? t.borderStrong : t.border}`, boxShadow: focus ? `0 0 0 3px ${t.surface2}` : '0 2px 10px rgba(19,14,26,0.04)', padding: '16px 14px 12px', transition: 'box-shadow .18s, border-color .18s', cursor: onClick ? 'text' : 'default' }}>
      {children}
    </div>
  );
}

function GhostLine({ children }) {
  const t = lTheme();
  return <div style={{ padding: '2px 4px 16px', minHeight: 28 }}><span style={{ fontSize: 17, color: t.ghost, letterSpacing: -0.2, lineHeight: 1.4 }}>{children}</span></div>;
}

function ValueLine({ children }) {
  const t = lTheme();
  return <div style={{ padding: '2px 4px 16px', minHeight: 28 }}><span style={{ fontSize: 17, color: t.text, letterSpacing: -0.2, lineHeight: 1.4 }}>{children}<span style={{ display: 'inline-block', width: 1.5, height: 18, background: t.text, marginLeft: 1, verticalAlign: -3, animation: 'nxBlink 1.1s steps(1) infinite alternate' }} /></span></div>;
}

function Helper({ children }) {
  const t = lTheme();
  return <div style={{ fontSize: 13.5, color: t.faint, letterSpacing: -0.1, lineHeight: 1.45, textAlign: 'center', marginTop: 16, padding: '0 8px', textWrap: 'pretty' }}>{children}</div>;
}

function Shell({ children }) {
  const t = lTheme();
  return (
    <IOSDevice>
      <div style={{ height: '100%', background: t.page, fontFamily: L_FONT, color: t.text, display: 'flex', flexDirection: 'column', position: 'relative', WebkitFontSmoothing: 'antialiased' }}>
        <LStatusSpacer h={64} />
        {children}
      </div>
    </IOSDevice>
  );
}

const TOPICS = ['the US–Iran conflict', 'second-brain tools', 'how memory works', 'the AI platform shift', 'anything you’re tracking'];

// ════════════════════════════════════════════════════════════
// A — One smart box (auto-detects topic vs link)
// ════════════════════════════════════════════════════════════
function FRE_A() {
  const t = lTheme();
  const [auto, setAuto] = useState(true);
  return (
    <Shell>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', padding: '0 22px 70px' }}>
        <Kicker>New collection</Kicker>
        <Headline>Create a collection about<br /><RotatingWord words={TOPICS} /></Headline>
        <div style={{ height: 26 }} />
        <CreateBox focus>
          <GhostLine>Name a topic, or paste a link…</GhostLine>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <ModeChip on={auto} label={auto ? 'Auto' : 'Manual'} icon="sparkOutline" onClick={() => setAuto((v) => !v)} />
            <div style={{ flex: 1 }} />
            <SendBtn icon="sparkOutline" />
          </div>
        </CreateBox>
        <Helper>Type a topic and Nexus gathers the latest sources for you — or paste links and we’ll ask you to name it.</Helper>
        <div style={{ display: 'flex', justifyContent: 'center', marginTop: 22 }}>
          <Pressable scale={0.96} style={{ border: 'none', background: 'transparent', cursor: 'pointer', fontFamily: L_FONT, fontSize: 14, fontWeight: 500, color: t.muted, letterSpacing: -0.1, padding: '6px 10px' }}>Create an empty collection</Pressable>
        </div>
      </div>
    </Shell>
  );
}

// ════════════════════════════════════════════════════════════
// B — Topic-first + trending chips + compact source bar
// ════════════════════════════════════════════════════════════

const ACCENT = '#7054AB'; // plum derived from page bloom
const EASE_NAV = 'cubic-bezier(.2,.8,.2,1)';

// Inject shimmer + spinner keyframes once
function FREStyles() {
  useEffect(() => {
    if (document.getElementById('fre-styles')) return;
    const s = document.createElement('style');
    s.id = 'fre-styles';
    s.textContent = '@keyframes nxShimmer{from{background-position:-400px 0}to{background-position:400px 0}}@keyframes nxSpin{to{transform:rotate(360deg)}}';
    document.head.appendChild(s);
  }, []);
  return null;
}

function SpinnerDot() {
  return <div style={{ width: 16, height: 16, borderRadius: 999, flex: '0 0 auto', border: '2px solid rgba(112,84,171,0.18)', borderTopColor: ACCENT, animation: 'nxSpin .75s linear infinite' }} />;
}

function ShimmerBlock({ w = '100%', h = 14, radius = 6 }) {
  return <div style={{ width: w, height: h, borderRadius: radius, background: 'linear-gradient(90deg,#EDEAF5 25%,#F5F3FB 50%,#EDEAF5 75%)', backgroundSize: '800px 100%', animation: 'nxShimmer 1.6s ease-in-out infinite' }} />;
}

function ShimmerRow({ t }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, background: t.surface, border: `1px solid ${t.border}`, borderRadius: 13, padding: '13px 14px' }}>
      <div style={{ width: 34, height: 34, borderRadius: 9, flex: '0 0 auto', background: 'linear-gradient(90deg,#EDEAF5 25%,#F5F3FB 50%,#EDEAF5 75%)', backgroundSize: '800px 100%', animation: 'nxShimmer 1.6s ease-in-out infinite' }} />
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 8 }}>
        <ShimmerBlock w="72%" h={13} />
        <ShimmerBlock w="42%" h={11} />
      </div>
    </div>
  );
}

const PROCESSING = [
  'Scanning the web…',
  'Finding recent sources…',
  'Reading articles…',
  'Picking the best pieces…',
  'Almost ready…',
];

function LoadingContent({ t, topic, onBack }) {
  const [phraseIdx, setPhraseIdx] = useState(0);
  const [phraseVisible, setPhraseVisible] = useState(true);
  useEffect(() => {
    const id = setInterval(() => {
      setPhraseVisible(false);
      setTimeout(() => { setPhraseIdx((i) => (i + 1) % PROCESSING.length); setPhraseVisible(true); }, 280);
    }, 2000);
    return () => clearInterval(id);
  }, []);
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: t.page }}>
      <LStatusSpacer h={60} />
      <div style={{ display: 'flex', alignItems: 'center', padding: '2px 12px 8px' }}>
        <Pressable scale={0.9} onClick={onBack} style={{ display: 'inline-flex', alignItems: 'center', gap: 3, border: 'none', background: 'transparent', cursor: 'pointer', fontFamily: L_FONT, fontSize: 15, color: t.muted, letterSpacing: -0.2, padding: '4px 6px' }}>
          <span style={{ transform: 'scaleX(-1)', display: 'inline-flex' }}><LIcon name="chevR" size={19} color={t.muted} /></span>Back
        </Pressable>
      </div>
      <div style={{ padding: '4px 18px 10px' }}>
        <div style={{ fontSize: 25, fontWeight: 700, letterSpacing: -0.6, color: t.text, lineHeight: 1.2 }}>{topic}</div>
        <div style={{ fontSize: 13.5, color: t.faint, marginTop: 5, letterSpacing: -0.1 }}>Building your collection…</div>
      </div>
      <div style={{ padding: '10px 18px 16px', display: 'flex', alignItems: 'center', gap: 10 }}>
        <SpinnerDot />
        <span style={{ fontSize: 14, color: t.muted, letterSpacing: -0.1, fontFamily: L_FONT, opacity: phraseVisible ? 1 : 0, transform: phraseVisible ? 'none' : 'translateY(4px)', transition: 'opacity .22s ease, transform .22s ease' }}>{PROCESSING[phraseIdx]}</span>
      </div>
      <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '0 16px 20px' }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 9 }}>
          {[0, 1, 2, 3].map((i) => <ShimmerRow key={i} t={t} />)}
        </div>
      </div>
    </div>
  );
}

const TRENDING = ['US–Iran conflict', 'AI platform shifts', 'Ozempic & longevity', 'Vision Pro 2'];

function FRE_B() {
  const t = lTheme();
  const [val, setVal] = useState('');
  const [active, setActive] = useState(false);
  const [screen, setScreen] = useState('input'); // 'input' | 'loading'
  const [topic, setTopic] = useState('');
  const focused = active || !!val;
  const sources = [['globe', 'Website'], ['file', 'PDF'], ['video', 'YouTube']];

  const handleSubmit = () => {
    if (!val.trim()) return;
    setTopic(val);
    setScreen('loading');
  };

  return (
    <IOSDevice>
      <FREStyles />
      <div style={{ height: '100%', background: t.page, fontFamily: L_FONT, color: t.text, position: 'relative', overflow: 'hidden', WebkitFontSmoothing: 'antialiased' }}>
        {/* Input screen */}
        <div style={{ position: 'absolute', inset: 0, transform: screen === 'loading' ? 'translateX(-28px)' : 'none', filter: screen === 'loading' ? 'brightness(0.96)' : 'none', transition: `transform .36s ${EASE_NAV}, filter .36s ease` }}>
          <LStatusSpacer h={64} />
          <div style={{ display: 'flex', flexDirection: 'column', justifyContent: 'center', padding: '0 22px 70px', height: 'calc(100% - 64px)', boxSizing: 'border-box' }}>
            <Kicker>New collection</Kicker>
            <Headline>Start a collection on<br /><RotatingWord words={TOPICS} /></Headline>
            <div style={{ height: 24 }} />
            <CreateBox focus={focused} onClick={() => setActive(true)}>
              {val ? <ValueLine>{val}</ValueLine> : <GhostLine>Describe a topic to research…</GhostLine>}
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <div style={iconBtn(t, 32)}><LIcon name="plus" size={18} color={t.text} /></div>
                <div style={{ flex: 1 }} />
                {focused
                  ? <Pressable scale={0.84} onClick={handleSubmit} style={{ width: 42, height: 42, borderRadius: 999, flex: '0 0 auto', padding: 0, border: 'none', background: !!val ? ACCENT : t.surface2, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
                      <LIcon name="arrowUp" size={19} color={!!val ? '#fff' : t.faint} stroke={1.8} />
                    </Pressable>
                  : <div style={iconBtn(t, 32)}><LIcon name="mic" size={18} color={t.muted} /></div>}
              </div>
            </CreateBox>
            <div style={{ marginTop: 20, display: 'flex', flexWrap: 'wrap', gap: 8 }}>
              {TRENDING.map((c) => (
                <Pressable key={c} scale={0.95} onClick={() => { setVal(c); setActive(true); }} style={{ display: 'inline-flex', alignItems: 'center', gap: 6, height: 34, padding: '0 13px', borderRadius: 999, background: t.surface, border: `1px solid ${t.border}`, cursor: 'pointer', fontFamily: L_FONT, fontSize: 13.5, fontWeight: 500, color: t.text, letterSpacing: -0.1 }}>
                  <LIcon name="trending" size={13} color={t.faint} />{c}
                </Pressable>
              ))}
            </div>
            <div style={{ marginTop: 26 }}>
              <span style={{ fontSize: 13, color: t.faint, letterSpacing: -0.1, display: 'block', marginBottom: 10 }}>Or add links</span>
              <div style={{ display: 'flex', gap: 7 }}>
                {sources.map(([ic, lb]) => (
                  <Pressable key={lb} scale={0.9} style={{ flex: 1, height: 50, borderRadius: 999, background: t.surface, border: `1px solid ${t.border}`, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 5, cursor: 'pointer', padding: 0 }}>
                    <LIcon name={ic} size={19} color={t.muted} />
                    <span style={{ fontFamily: L_FONT, fontSize: 12, fontWeight: 500, color: t.muted, letterSpacing: -0.1 }}>{lb}</span>
                  </Pressable>
                ))}
              </div>
            </div>
          </div>
        </div>
        {/* Loading screen — slides in from the right */}
        <div style={{ position: 'absolute', inset: 0, transform: screen === 'loading' ? 'translateX(0)' : 'translateX(100%)', transition: `transform .36s ${EASE_NAV}`, boxShadow: '-8px 0 28px rgba(19,14,26,0.09)' }}>
          <LoadingContent t={t} topic={topic} onBack={() => setScreen('input')} />
        </div>
      </div>
    </IOSDevice>
  );
}

// ════════════════════════════════════════════════════════════
// C — Two intents, one box (segmented; repurposes the Model switcher)
// ════════════════════════════════════════════════════════════
function FRE_C() {
  const t = lTheme();
  const [mode, setMode] = useState('Ask AI');
  const ai = mode === 'Ask AI';
  return (
    <Shell>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', padding: '0 22px 70px' }}>
        <Kicker>New collection</Kicker>
        <div style={{ fontSize: 29, fontWeight: 700, letterSpacing: -0.8, lineHeight: 1.2, color: t.text }}>What do you want to collect?</div>
        <div style={{ height: 22 }} />
        <Segmented items={['Ask AI', 'Add links']} value={mode} onChange={setMode} dur={300} ease={SPRING_BOUNCE}
          trackStyle={{ display: 'inline-flex', gap: 2, padding: 3, background: t.surface2, borderRadius: 999, border: `1px solid ${t.hair}`, marginBottom: 14, alignSelf: 'flex-start' }}
          itemStyle={{ fontSize: 13.5, fontWeight: 500, letterSpacing: -0.1, padding: '7px 15px', borderRadius: 999, color: t.muted, background: 'transparent', border: 'none', cursor: 'pointer' }}
          activeItemStyle={{ color: t.text, fontWeight: 600 }}
          thumbStyle={{ background: t.surface, borderRadius: 999, border: `1px solid ${t.border}` }} />
        <CreateBox focus>
          <div key={mode} style={{ animation: 'nxFade .26s cubic-bezier(.2,.8,.2,1)' }}>
            {ai
              ? <div style={{ padding: '2px 4px 16px', minHeight: 28 }}><span style={{ fontSize: 17, color: t.ghost, letterSpacing: -0.2 }}>Describe a topic — I’ll gather </span><RotatingWord words={['the latest news', 'key articles', 'videos & PDFs', 'expert takes']} /></div>
              : <GhostLine>Paste one or more links…</GhostLine>}
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <ModeChip on={ai} label={ai ? 'Researching' : 'Links'} icon={ai ? 'sparkOutline' : 'link'} />
            <div style={{ flex: 1 }} />
            <SendBtn icon={ai ? 'sparkOutline' : 'arrowUp'} solid={ai} />
          </div>
        </CreateBox>
        <Helper>{ai
          ? 'Nexus finds and adds the latest sources automatically — no setup.'
          : 'Add your links first, then give the collection a name.'}</Helper>
      </div>
    </Shell>
  );
}

// ── canvas: every screen so far, one horizontal row per flow ──
function FRECanvas() {
  const homeTweaks = { pivotMotion: 'slide', motionDuration: 500, motionEasing: 'smooth' };
  return (
    <DesignCanvas>
      <DCSection id="home" title="Home — collection list" subtitle="Returning users land here; a collection opens on its Nexus tab">
        <DCArtboard id="home-list" label="Collection list" width={402} height={874}><IOSDevice><NexusApp tweaks={homeTweaks} /></IOSDevice></DCArtboard>
        <DCArtboard id="home-col" label="→ Collection · Nexus tab" width={402} height={874}><CollectionBoard pivot="Nexus" /></DCArtboard>
      </DCSection>
      <DCSection id="fre" title="Create a collection (FRE)" subtitle="Topic in natural language → Nexus researches → review → collection · first board is fully interactive">
        <DCArtboard id="fre-1" label="1 · Input · interactive — tap a chip" width={402} height={874}><FREFlow /></DCArtboard>
        <DCArtboard id="fre-2" label="2 · Researching" width={402} height={874}><FREFlow stage="loading" /></DCArtboard>
        <DCArtboard id="fre-3" label="3 · Review sources" width={402} height={874}><FREFlow stage="review" /></DCArtboard>
        <DCArtboard id="fre-4" label="4 · → Collection · Nexus tab" width={402} height={874}><CollectionBoard pivot="Nexus" /></DCArtboard>
      </DCSection>
      <DCSection id="ask" title="Ask Nexus" subtitle="Hero → Echo pulse → grounded answer with inline citations → created artifact">
        <DCArtboard id="ask-1" label="1 · Hero · framing + create + ask" width={402} height={874}><CollectionBoard pivot="Nexus" /></DCArtboard>
        <DCArtboard id="ask-2" label="2 · Thinking · Echo pulse" width={402} height={874}><CollectionBoard pivot="Nexus" nexusSeed="thinking" /></DCArtboard>
        <DCArtboard id="ask-3" label="3 · Answer · inline source chips" width={402} height={874}><CollectionBoard pivot="Nexus" nexusSeed="answered" /></DCArtboard>
        <DCArtboard id="ask-4" label="4 · Create · audio summary" width={402} height={874}><CollectionBoard pivot="Nexus" nexusSeed="artifact" /></DCArtboard>
      </DCSection>
      <DCSection id="sources" title="Manage sources" subtitle="Flat list → add a source: research a topic or drop a link → review → added">
        <DCArtboard id="src-1" label="1 · Sources tab" width={402} height={874}><CollectionBoard pivot="Sources" /></DCArtboard>
        <DCArtboard id="src-2" label="2 · Add a source · sheet" width={402} height={874}><CollectionBoard pivot="Sources" addSeed="input" /></DCArtboard>
        <DCArtboard id="src-3" label="3 · Researching" width={402} height={874}><CollectionBoard pivot="Sources" addSeed="loading" /></DCArtboard>
        <DCArtboard id="src-4" label="4 · Review → add" width={402} height={874}><CollectionBoard pivot="Sources" addSeed="review" /></DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

Object.assign(window, { FRECanvas });
