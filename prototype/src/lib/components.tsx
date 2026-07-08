/**
 * Barrel — backward-compat re-exports.
 * The lib was split (2026-07-08) into: icons.tsx, primitives.tsx,
 * surfaces.tsx, logo.tsx. New code should import from those directly.
 */

export { Icon, ICONS, type IconName } from "./icons";
export {
  Pressable,
  IconButton,
  Avatar,
  AvatarButton,
  Segmented,
  PillTabs,
  Shimmer,
  Spinner,
  Screen,
  StatusBar,
  MobileFrame,
  TypeBadge,
  useIsNarrow,
} from "./primitives";
export {
  usePresence,
  LiquidGlassCard,
  BloomMenu,
  MenuOverlay,
  Sheet,
  EchoPulse,
  PivotSwipe,
} from "./surfaces";
export { EchoMark, NexusLockup } from "./logo";
