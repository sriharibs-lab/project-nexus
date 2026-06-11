// landing-pieces.jsx — popovers, collection/item cards, sample data
// Exports (to window): COLLECTIONS, ITEMS, TOPICS, TYPES,
//   LPlusMenu, LModelMenu, LAvatarMenu, LScrim, LCollectionCard, LTopicGroup, LItemRow

// ── Sample content (calm, literary, on-brand) ──
const COLLECTIONS = [
  { title: 'The attention economy', items: 12, when: 'updated 2h ago', topic: 'Attention', src: ['S', 'A', 'W'] },
  { title: 'Second-brain tools', items: 7, when: 'yesterday', topic: 'Tech', src: ['N', 'V'] },
  { title: 'How memory works', items: 5, when: 'last week', topic: 'Science', src: ['Na', 'Q', 'M'] },
  { title: 'AI platform shifts', items: 9, when: '3 days ago', topic: 'Tech', src: ['St', 'T'] },
];
const TOPICS = [
  { name: 'Attention', n: 17 }, { name: 'Tech', n: 16 }, { name: 'Science', n: 5 },
];
const ITEMS = [
  { title: 'The end of the beginning for AI platforms', src: 'Stratechery', type: 'Article', when: '8 min' },
  { title: 'What we lose when machines do the reading', src: 'The Atlantic', type: 'Article', when: '12 min' },
  { title: 'A field guide to second-brain tools', src: 'figma.com', type: 'PDF', when: '2.4 MB' },
  { title: 'How the cortex files what you learn', src: 'Nature', type: 'Article', when: '9 min' },
  { title: 'On memory and forgetting — a talk', src: 'YouTube', type: 'Video', when: '23 min' },
  { title: 'Notes from "The shallows"', src: 'You', type: 'Note', when: 'edited Tue' },
];
const TYPES = [
  { name: 'Articles', n: 14, icon: 'book' }, { name: 'PDFs', n: 5, icon: 'file' },
  { name: 'Videos', n: 3, icon: 'play' }, { name: 'Notes', n: 6, icon: 'note' }, { name: 'Links', n: 9, icon: 'link' },
];

// ── Dim scrim behind popovers ──
function LScrim({ onClose }) {
  return <div onClick={onClose} style={{ position: 'absolute', inset: 0, background: 'rgba(19,14,26,0.18)', zIndex: 40 }} />;
}

// generic menu shell
// Glassmorphic, shadowless menu surface — the system's floating-menu style.
function menuCard(t, extra = {}) {
  return {
    background: 'rgba(255,255,255,0.58)',
    backdropFilter: 'blur(30px) saturate(185%)', WebkitBackdropFilter: 'blur(30px) saturate(185%)',
    border: `1px solid rgba(255,255,255,0.6)`, borderRadius: 22,
    boxShadow: 'none', overflow: 'hidden', ...extra,
  };
}
function menuRow(t, { icon, label, detail, last, check }) {
  return (
    <div key={label} style={{
      display: 'flex', alignItems: 'center', gap: 12, padding: '13px 15px', cursor: 'pointer',
      borderBottom: last ? 'none' : `1px solid ${t.hair}`,
    }}>
      {icon && <LIcon name={icon} size={19} color={t.muted} />}
      <span style={{ flex: 1, fontSize: 15.5, letterSpacing: -0.2, color: t.text }}>{label}</span>
      {detail && <span style={{ fontSize: 13.5, color: t.faint }}>{detail}</span>}
      {check && <LIcon name="check" size={17} color={t.text} />}
    </div>
  );
}

// ── + menu: attachments (Photos / Files / Camera) ──
function LPlusMenu({ t }) {
  return (
    <div style={menuCard(t, { width: 210 })}>
      {menuRow(t, { icon: 'photo', label: 'Photos' })}
      {menuRow(t, { icon: 'file', label: 'Files' })}
      {menuRow(t, { icon: 'camera', label: 'Camera', last: true })}
    </div>
  );
}

// ── Model menu ──
function LModelMenu({ t, active = 'Standard' }) {
  const models = [
    { label: 'Quick', detail: 'fast drafts' },
    { label: 'Standard', detail: 'everyday' },
    { label: 'Deep research', detail: 'thorough' },
  ];
  return (
    <div style={menuCard(t, { width: 230 })}>
      <div style={{ padding: '10px 15px 8px', fontSize: 11.5, fontWeight: 600, letterSpacing: 0.5, textTransform: 'uppercase', color: t.faint, borderBottom: `1px solid ${t.hair}` }}>Model</div>
      {models.map((m, i) => (
        <div key={m.label} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '12px 15px', cursor: 'pointer', borderBottom: i === models.length - 1 ? 'none' : `1px solid ${t.hair}` }}>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 15.5, letterSpacing: -0.2, color: t.text, fontWeight: active === m.label ? 600 : 400 }}>{m.label}</div>
            <div style={{ fontSize: 12.5, color: t.faint, marginTop: 1 }}>{m.detail}</div>
          </div>
          {active === m.label && <LIcon name="check" size={17} color={t.text} />}
        </div>
      ))}
    </div>
  );
}

// ── Avatar menu: profile header + Account / Settings / Feedback (no separators) ──
function LAvatarMenu({ t }) {
  const rows = ['Account', 'Settings', 'Feedback'];
  return (
    <div style={menuCard(t, { width: 236, padding: 6 })}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 11, padding: '8px 10px 10px' }}>
        <LAvatar t={t} initials="M" size={40} />
        <div style={{ minWidth: 0 }}>
          <div style={{ fontSize: 15, fontWeight: 600, letterSpacing: -0.2, color: t.text }}>Mara Olsen</div>
          <div style={{ fontSize: 12.5, color: t.faint, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>mara@hey.com</div>
        </div>
      </div>
      {rows.map((label) => (
        <div key={label} style={{ padding: '11px 12px', borderRadius: 13, fontSize: 15.5, letterSpacing: -0.2, color: t.text, cursor: 'pointer' }}>{label}</div>
      ))}
    </div>
  );
}

// ── Collection card (By Collection view) ──
function LCollectionCard({ t, c }) {
  return (
    <div style={{ background: t.surface, border: `1px solid ${t.border}`, borderRadius: 14, padding: '15px 16px' }}>
      <div style={{ fontSize: 17, fontWeight: 650, letterSpacing: -0.4, color: t.text, lineHeight: 1.25 }}>{c.title}</div>
      <div style={{ fontSize: 13, color: t.faint, marginTop: 4, letterSpacing: -0.1 }}>{c.items} items · {c.when}</div>
    </div>
  );
}

// ── Topic group (By Topic view) ──
function LTopicGroup({ t, name, n, children }) {
  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', padding: '0 2px 9px' }}>
        <span style={{ fontSize: 12, fontWeight: 600, letterSpacing: 0.6, textTransform: 'uppercase', color: t.muted }}>{name}</span>
        <span style={{ fontSize: 12, color: t.faint }}>{n}</span>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 9 }}>{children}</div>
    </div>
  );
}

// ── Item row (By Type view) ──
function LItemRow({ t, it, icon }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, background: t.surface, border: `1px solid ${t.border}`, borderRadius: 13, padding: '12px 14px' }}>
      <div style={{ width: 34, height: 34, borderRadius: 9, flex: '0 0 auto', background: t.surface2, border: `1px solid ${t.border}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <LIcon name={icon} size={17} color={t.muted} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 14.5, fontWeight: 600, letterSpacing: -0.2, color: t.text, lineHeight: 1.3, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{it.title}</div>
        <div style={{ fontSize: 12.5, color: t.faint, marginTop: 2 }}>{it.src} · {it.when}</div>
      </div>
    </div>
  );
}

Object.assign(window, { COLLECTIONS, ITEMS, TOPICS, TYPES, LScrim, LPlusMenu, LModelMenu, LAvatarMenu, LCollectionCard, LTopicGroup, LItemRow, LMenuCard: menuCard });
