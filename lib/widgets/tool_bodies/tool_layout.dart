/// Width at/above which a tool body shows its richer desktop-canvas layout.
/// Above the widest real phone (~430 logical px), so phones always get the
/// compact layout (mobile parity); canvas wide/xwide cards (560/640) get the
/// rich one. Standard 380 cards stay compact until the user resizes wider.
const double kToolCanvasWide = 460;
