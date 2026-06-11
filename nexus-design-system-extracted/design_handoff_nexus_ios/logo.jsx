// logo.jsx — Nexus brand: final mark (Echo) + wordmark lockup.
// Two facing arcs hold a single point of contact; a second, lighter pair
// radiates outward — the signal propagating from the moment of connection.
// Strictly monochrome (in-hue opacity only): plum on white, white on ink.
// Exports: LogoCanvas, NexusMark, NexusLockup

const NX_PLUM = '#7054AB';
const NX_INK = '#130E1A';
const LOGO_FONT = "'Geist', -apple-system, 'SF Pro Display', 'Segoe UI', sans-serif";

// ── the mark ──
function NexusMark({ c = NX_PLUM, s = 48 }) {
  return (
    <svg width={s} height={s} viewBox="0 0 48 48" style={{ display: 'block', flex: '0 0 auto' }}>
      <g stroke={c} strokeWidth="3" strokeLinecap="round" fill="none">
        <path d="M18.5 16 A11 11 0 0 0 18.5 32"></path>
        <path d="M29.5 16 A11 11 0 0 1 29.5 32"></path>
      </g>
      <g stroke={c} strokeWidth="2.2" strokeLinecap="round" fill="none" opacity="0.32">
        <path d="M13.5 9.5 A17.5 17.5 0 0 0 13.5 38.5"></path>
        <path d="M34.5 9.5 A17.5 17.5 0 0 1 34.5 38.5"></path>
      </g>
      <circle cx="24" cy="24" r="4.4" fill={c}></circle>
    </svg>
  );
}

// ── wordmark lockup ──
function NexusLockup({ c = NX_PLUM, wordColor, iconSize = 38, fontSize = 30 }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: Math.round(iconSize * 0.36) }}>
      <NexusMark c={c} s={iconSize} />
      <span style={{ fontFamily: LOGO_FONT, fontSize, fontWeight: 600, letterSpacing: '-0.035em', color: wordColor || c, lineHeight: 1 }}>Nexus</span>
    </div>
  );
}

// ── the spec sheet: hero, lockup, scale run, dark panel, app tiles ──
function FinalBoard() {
  return (
    <div style={{ width: '100%', height: '100%', background: '#FFFFFF', display: 'flex', flexDirection: 'column', fontFamily: LOGO_FONT }}>
      <div style={{ padding: '18px 22px 0' }}>
        <div style={{ fontSize: 11.5, fontWeight: 600, letterSpacing: 0.8, color: '#9A93AC' }}>NEXUS · BRAND MARK</div>
        <div style={{ fontSize: 15, fontWeight: 600, letterSpacing: -0.2, color: NX_INK, marginTop: 3 }}>Echo</div>
        <div style={{ fontSize: 12, color: '#9A93AC', marginTop: 4, lineHeight: 1.5, textWrap: 'pretty' }}>Two facing arcs hold a single point of contact; a lighter pair radiates outward — the signal propagating from the moment of connection.</div>
      </div>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 30 }}>
        <NexusMark c={NX_PLUM} s={104} />
        <NexusLockup c={NX_PLUM} wordColor={NX_INK} />
      </div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 24, padding: '0 0 28px' }}>
        <NexusMark c={NX_PLUM} s={32} />
        <NexusMark c={NX_PLUM} s={22} />
        <NexusMark c={NX_PLUM} s={15} />
      </div>
      <div style={{ background: NX_INK, padding: '24px 24px 22px', display: 'flex', flexDirection: 'column', gap: 20 }}>
        <NexusLockup c="#FFFFFF" wordColor="#FFFFFF" iconSize={30} fontSize={24} />
        <div style={{ display: 'flex', alignItems: 'center', gap: 18 }}>
          <div style={{ width: 56, height: 56, borderRadius: 14, background: NX_PLUM, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <NexusMark c="#FFFFFF" s={32} />
          </div>
          <div style={{ width: 56, height: 56, borderRadius: 14, background: '#FFFFFF', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <NexusMark c={NX_PLUM} s={32} />
          </div>
          <NexusMark c="#FFFFFF" s={22} />
        </div>
      </div>
    </div>
  );
}

function LogoCanvas() {
  return (
    <DesignCanvas>
      <DCSection id="final" title="Nexus — brand mark" subtitle="Echo · final · monochrome in-hue: plum on white, white on ink">
        <DCArtboard id="echo-final" label="Echo · final mark" width={400} height={640}>
          <FinalBoard />
        </DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

Object.assign(window, { LogoCanvas, NexusMark, NexusLockup });
