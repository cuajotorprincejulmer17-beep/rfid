---
name: pulse-figma-to-flutter
description: How to use the Figma MCP server to turn PULSE frames and variables into Flutter widgets and tokens, including fallback when Figma is unavailable. Use whenever the user shares a Figma link/frame, mentions Figma, design tokens, variables, Dev Mode, "match the design", or asks you to implement or compare a screen against a design.
---

# Figma -> Flutter (PULSE)

Figma's MCP server exposes frames as **structured design context**. It usually returns reference code in a web stack (React/Tailwind). Treat that as a **specification**, never as code to paste. You produce idiomatic Flutter.

## Preflight
1. Check the Figma MCP server is connected (list tools first; names vary by server version). If not connected or unauthorised, say so and tell me to run `codex mcp login figma` (config: `[mcp_servers.figma] url = "https://mcp.figma.com/mcp"`). Do **not** block Stage work on it: fall back to the attached reference images and `pulse-flutter-ui-ux/references/tokens.md`.
2. Ask me for the file/frame link(s) (right-click frame -> Copy link to selection) if you were not given them. PNG-only references cannot be read through MCP.

## Workflow per screen/component
1. Get node metadata/structure, design context, a **screenshot** (visual truth), and the **variables** (colors, spacing, typography) for the node.
2. Map variables to tokens: colors -> `PulseColors`, spacing -> spacing scale, text styles -> `TextTheme`. If a Figma value differs from `tokens.md`, **do not silently pick one**: list the differences and ask (contrast may be why they differ).
3. Translate layout: Auto layout -> `Row`/`Column`/`Flex` + gap + padding; "fill container" -> `Expanded`; "hug" -> intrinsic size; constraints/pinning -> `Align`/`Stack`+`Positioned` only when truly layered; fixed text frames -> flexible widgets (text must survive 2.0x scale). Effects -> `BoxShadow`; strokes -> `Border`; corner radius -> `BorderRadius` tokens.
4. Components/variants -> one reusable widget with enum/bool parameters. Reuse existing widgets before creating new ones.
5. Prototype/interaction notes in Figma -> implement per `pulse-flutter-animation`; if no motion is specified, use the motion spec there and tell me.
6. Compare your result with the Figma screenshot (and a golden test at the frame's size). List remaining visual differences honestly.
7. Keep `docs/figma-map.md`: Figma node id/link -> Flutter widget/file, plus any unresolved differences.

## Content rules
- Names, student IDs, QR codes, schedules, timestamps, attendance values in Figma are **placeholders**. Never ship them as data and never treat them as verified school information. Use the isolated, labeled sample file only for prototypes.
- Figma features that the backend does not support (Digital ID, Room Finder, Lost & Found, Library, Maps, Bank/Rewards) are built as **disabled-with-reason**, not as working screens. No Financial group.
- Do not copy another product's branding.

## If Figma returns too much or too little
Select a smaller node (one component at a time). If variables are missing, ask me to define them (modes: Dark, Light, Mono, Midnight) rather than guessing.
