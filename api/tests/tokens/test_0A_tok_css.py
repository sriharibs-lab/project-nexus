"""
Tests for task 0A-tok-css: Token integration (CSS custom properties from JSON)

Strategy:
- Statically parse tokens.css to validate --nx-* properties, dark-mode block,
  gradient, and counts.
- Statically parse tokens.ts to validate TS exports match the CSS.
- Statically parse globals.css for typography utility classes and .nx-pressable.
- Statically parse tailwind.config.ts for required color/utility mappings.
- Run `tsc --noEmit` and `tailwindcss` as subprocess checks.
"""

import os
import re
import subprocess
import sys

import pytest

# ─── Paths ───────────────────────────────────────────────────────────────────

WORKTREE = "/Users/srihari/Documents/Projects/Project Nexus/.claude/worktrees/wf_916c2c75-c5c-8"
PROTOTYPE = os.path.join(WORKTREE, "prototype")
TOKENS_CSS = os.path.join(PROTOTYPE, "src/styles/tokens.css")
TOKENS_TS = os.path.join(PROTOTYPE, "src/styles/tokens.ts")
GLOBALS_CSS = os.path.join(PROTOTYPE, "src/app/globals.css")
TAILWIND_CONFIG = os.path.join(PROTOTYPE, "tailwind.config.ts")


# ─── Fixtures ────────────────────────────────────────────────────────────────

@pytest.fixture(scope="module")
def tokens_css_text():
    with open(TOKENS_CSS, encoding="utf-8") as f:
        return f.read()


@pytest.fixture(scope="module")
def tokens_ts_text():
    with open(TOKENS_TS, encoding="utf-8") as f:
        return f.read()


@pytest.fixture(scope="module")
def globals_css_text():
    with open(GLOBALS_CSS, encoding="utf-8") as f:
        return f.read()


@pytest.fixture(scope="module")
def tailwind_config_text():
    with open(TAILWIND_CONFIG, encoding="utf-8") as f:
        return f.read()


# ─── CSS Token Tests ──────────────────────────────────────────────────────────

class TestTokensCss:
    def test_file_exists(self):
        assert os.path.isfile(TOKENS_CSS), f"tokens.css not found at {TOKENS_CSS}"

    def test_has_root_block(self, tokens_css_text):
        assert ":root {" in tokens_css_text

    def test_minimum_nx_properties_count(self, tokens_css_text):
        """At least 80 --nx-* properties must be declared."""
        props = re.findall(r"--nx-[\w-]+:", tokens_css_text)
        count = len(props)
        assert count >= 80, f"Expected >=80 --nx-* properties, found {count}"

    def test_brand_plum_value(self, tokens_css_text):
        """--nx-color-brand-plum must be #7054AB."""
        match = re.search(r"--nx-color-brand-plum\s*:\s*([^;]+);", tokens_css_text)
        assert match, "--nx-color-brand-plum not found"
        value = match.group(1).strip()
        assert value.upper() == "#7054AB", f"Expected #7054AB, got {value!r}"

    def test_page_gradient_contains_bloom_and_neutral(self, tokens_css_text):
        """--nx-color-page must be a radial-gradient containing #E7DCF4 and #F9F8FC."""
        match = re.search(r"--nx-color-page\s*:\s*([^;]+);", tokens_css_text)
        assert match, "--nx-color-page not found"
        value = match.group(1).upper()
        assert "RADIAL-GRADIENT" in value, "Must be a radial-gradient"
        assert "E7DCF4" in value, "Bloom color (#E7DCF4) missing from gradient"
        assert "F9F8FC" in value, "Neutral-100 (#F9F8FC) missing from gradient"

    def test_dark_mode_block_exists(self, tokens_css_text):
        """A @media (prefers-color-scheme: dark) block must override bg and text tokens."""
        assert "@media (prefers-color-scheme: dark)" in tokens_css_text

    def test_dark_mode_bg_primary(self, tokens_css_text):
        """In dark mode, --nx-color-bg-primary must be #0F0D13."""
        dark_block = tokens_css_text.split("@media (prefers-color-scheme: dark)")[-1]
        match = re.search(r"--nx-color-bg-primary\s*:\s*([^;]+);", dark_block)
        assert match, "--nx-color-bg-primary not overridden in dark mode"
        value = match.group(1).strip().upper()
        assert value == "#0F0D13", f"Expected #0F0D13 in dark mode, got {value!r}"

    def test_dark_mode_text_primary(self, tokens_css_text):
        """In dark mode, --nx-color-text-primary must be #F0EBF8."""
        dark_block = tokens_css_text.split("@media (prefers-color-scheme: dark)")[-1]
        match = re.search(r"--nx-color-text-primary\s*:\s*([^;]+);", dark_block)
        assert match, "--nx-color-text-primary not overridden in dark mode"
        value = match.group(1).strip().upper()
        assert value == "#F0EBF8", f"Expected #F0EBF8 in dark mode, got {value!r}"

    def test_press_base_scale(self, tokens_css_text):
        """--nx-scale-press-base must be 0.93."""
        match = re.search(r"--nx-scale-press-base\s*:\s*([^;]+);", tokens_css_text)
        assert match, "--nx-scale-press-base not found"
        value = match.group(1).strip()
        assert value == "0.93", f"Expected 0.93, got {value!r}"

    def test_spring_easing_defined(self, tokens_css_text):
        """--nx-ease-spring must be defined as a cubic-bezier."""
        match = re.search(r"--nx-ease-spring\s*:\s*([^;]+);", tokens_css_text)
        assert match, "--nx-ease-spring not found"
        value = match.group(1).strip()
        assert "cubic-bezier" in value, f"Expected cubic-bezier, got {value!r}"

    def test_transition_micro_uses_spring_easing(self, tokens_css_text):
        """--nx-transition-micro must reference spring easing values."""
        match = re.search(r"--nx-transition-micro\s*:\s*([^;]+);", tokens_css_text)
        assert match, "--nx-transition-micro not found"
        value = match.group(1).strip()
        # Should contain a timing + cubic-bezier
        assert "cubic-bezier" in value, f"--nx-transition-micro missing cubic-bezier: {value!r}"

    def test_display_lg_size_in_font_sizes(self, tokens_css_text):
        """--nx-text-7xl must resolve to 40px (used by .nx-text-display-lg)."""
        match = re.search(r"--nx-text-7xl\s*:\s*([^;]+);", tokens_css_text)
        assert match, "--nx-text-7xl not found"
        value = match.group(1).strip()
        assert value == "40px", f"Expected 40px, got {value!r}"


# ─── TypeScript Token Mirror Tests ───────────────────────────────────────────

class TestTokensTs:
    def test_file_exists(self):
        assert os.path.isfile(TOKENS_TS), f"tokens.ts not found at {TOKENS_TS}"

    def test_exports_color(self, tokens_ts_text):
        assert "export const color" in tokens_ts_text

    def test_exports_typography(self, tokens_ts_text):
        assert "export const typography" in tokens_ts_text

    def test_exports_motion(self, tokens_ts_text):
        assert "export const motion" in tokens_ts_text

    def test_exports_spacing(self, tokens_ts_text):
        assert "export const spacing" in tokens_ts_text

    def test_brand_plum_value(self, tokens_ts_text):
        """color.brand.plum must match CSS token."""
        match = re.search(r'plum\s*:\s*"([^"]+)"', tokens_ts_text)
        assert match, "plum not found in tokens.ts"
        assert match.group(1).upper() == "#7054AB"

    def test_exports_vars(self, tokens_ts_text):
        """vars export with CSS variable references must exist."""
        assert "export const vars" in tokens_ts_text

    def test_press_base_scale_value(self, tokens_ts_text):
        """motion.scale.pressBase must be 0.93."""
        match = re.search(r"pressBase\s*:\s*([\d.]+)", tokens_ts_text)
        assert match, "pressBase not found in tokens.ts"
        assert float(match.group(1)) == pytest.approx(0.93)

    def test_font_size_7xl_value(self, tokens_ts_text):
        """typography.fontSize['7xl'] must be '40px'."""
        match = re.search(r'"7xl"\s*:\s*"([^"]+)"', tokens_ts_text)
        assert match, "'7xl' font size not found in tokens.ts"
        assert match.group(1) == "40px"

    def test_const_assertions(self, tokens_ts_text):
        """Exports should use 'as const' for type safety."""
        assert "as const" in tokens_ts_text


# ─── globals.css Tests ────────────────────────────────────────────────────────

class TestGlobalsCss:
    def test_file_exists(self):
        assert os.path.isfile(GLOBALS_CSS)

    def test_imports_tokens_css(self, globals_css_text):
        assert "@import" in globals_css_text and "tokens.css" in globals_css_text

    def test_body_uses_page_gradient(self, globals_css_text):
        """body background must reference --nx-color-page."""
        assert "var(--nx-color-page)" in globals_css_text

    def test_nx_text_display_lg_class(self, globals_css_text):
        """.nx-text-display-lg must be defined."""
        assert ".nx-text-display-lg" in globals_css_text

    def test_display_lg_uses_7xl(self, globals_css_text):
        """Display-lg must reference --nx-text-7xl (40px)."""
        # Extract the block after .nx-text-display-lg
        idx = globals_css_text.find(".nx-text-display-lg")
        block = globals_css_text[idx:idx+300]
        assert "var(--nx-text-7xl)" in block, "display-lg should use --nx-text-7xl"

    def test_display_lg_font_weight_bold(self, globals_css_text):
        """Display-lg must use bold weight (700)."""
        idx = globals_css_text.find(".nx-text-display-lg")
        block = globals_css_text[idx:idx+300]
        assert "var(--nx-weight-bold)" in block or "700" in block

    def test_display_lg_leading_tight(self, globals_css_text):
        """Display-lg must use tight line-height (1.2)."""
        idx = globals_css_text.find(".nx-text-display-lg")
        block = globals_css_text[idx:idx+300]
        assert "var(--nx-leading-tight)" in block

    def test_display_lg_tracking_tightest(self, globals_css_text):
        """Display-lg must use tightest letter-spacing (-0.8px)."""
        idx = globals_css_text.find(".nx-text-display-lg")
        block = globals_css_text[idx:idx+300]
        assert "var(--nx-tracking-tightest)" in block or "-0.8px" in block

    def test_nx_pressable_class_exists(self, globals_css_text):
        assert ".nx-pressable" in globals_css_text

    def test_pressable_uses_transition_micro(self, globals_css_text):
        idx = globals_css_text.find(".nx-pressable")
        block = globals_css_text[idx:idx+300]
        assert "var(--nx-transition-micro)" in block

    def test_pressable_active_scale_press_base(self, globals_css_text):
        """On :active, .nx-pressable must scale to --nx-scale-press-base (0.93)."""
        assert "var(--nx-scale-press-base)" in globals_css_text

    def test_tailwind_directives_present(self, globals_css_text):
        """@tailwind base/components/utilities must be present."""
        assert "@tailwind base" in globals_css_text
        assert "@tailwind components" in globals_css_text
        assert "@tailwind utilities" in globals_css_text


# ─── Tailwind Config Tests ────────────────────────────────────────────────────

class TestTailwindConfig:
    def test_file_exists(self):
        assert os.path.isfile(TAILWIND_CONFIG)

    def test_nx_plum_color_mapped(self, tailwind_config_text):
        """bg-nx-plum must map to --nx-color-brand-plum."""
        assert '"nx-color-brand-plum"' in tailwind_config_text or "--nx-color-brand-plum" in tailwind_config_text

    def test_nx_text_inverse_mapped(self, tailwind_config_text):
        """text-nx-text-inverse must be available (maps to --nx-color-text-inverse)."""
        assert "text-inverse" in tailwind_config_text

    def test_spacing_tokens_present(self, tailwind_config_text):
        assert "nx-space-" in tailwind_config_text or "var(--nx-space-" in tailwind_config_text

    def test_border_radius_tokens_present(self, tailwind_config_text):
        assert "nx-radius-" in tailwind_config_text or "var(--nx-radius-" in tailwind_config_text

    def test_font_size_tokens_present(self, tailwind_config_text):
        assert "nx-7xl" in tailwind_config_text or "var(--nx-text-7xl)" in tailwind_config_text

    def test_content_paths_configured(self, tailwind_config_text):
        assert "src/app/**" in tailwind_config_text or "./src/app" in tailwind_config_text


# ─── CLI Check Tests ──────────────────────────────────────────────────────────

_TSC_BIN = os.path.join(PROTOTYPE, "node_modules", ".bin", "tsc")
_TW_BIN = os.path.join(PROTOTYPE, "node_modules", ".bin", "tailwindcss")
_DEPS_INSTALLED = os.path.isfile(_TSC_BIN) and os.path.isfile(_TW_BIN)


class TestCliChecks:
    """Run tsc and tailwindcss CLI to verify zero-error compilation."""

    @pytest.mark.skipif(not _DEPS_INSTALLED, reason="npm install required in /prototype")
    def test_typescript_compilation_no_errors(self):
        """tsc --noEmit must pass with zero errors in /prototype."""
        result = subprocess.run(
            [_TSC_BIN, "--noEmit"],
            cwd=PROTOTYPE,
            capture_output=True,
            text=True,
            timeout=60,
        )
        assert result.returncode == 0, (
            f"tsc --noEmit failed (exit {result.returncode}):\n"
            f"STDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
        )

    @pytest.mark.skipif(not _DEPS_INSTALLED, reason="npm install required in /prototype")
    def test_tailwind_config_parses_cleanly(self):
        """tailwindcss must parse the config without errors."""
        result = subprocess.run(
            [_TW_BIN, "--input", "/dev/null", "-o", "/dev/null"],
            cwd=PROTOTYPE,
            capture_output=True,
            text=True,
            timeout=60,
        )
        # tailwindcss may warn but should not hard-error
        assert result.returncode == 0, (
            f"tailwindcss config parse failed (exit {result.returncode}):\n"
            f"STDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
        )
