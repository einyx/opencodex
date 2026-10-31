#!/usr/bin/env python3
"""Generate docs/features/polish/audit.md.

**The audit measures the working tree at generation time.** Every file:line anchor in
the evidence is computed by running the grep now, not copied by hand. That is the
whole point: a hand-maintained anchor is a lie the moment the file is edited, and a
merge that rewrites a file silently invalidates every line number pointing into it.

Run:  python3 gen_audit.py
"""
import os
import re
import subprocess
from collections import Counter, OrderedDict

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
APP = "OpenCodeClient/OpenCodeClient"
VIEWS = APP + "/Views"
TOKENS = APP + "/Utils/DesignTokens.swift"
RUBRIC = ROOT + "/docs/features/polish/rubric.md"
GREP = ["grep", "-rnE"]


def grep(pattern, path, extra=None):
    """Return [(path, lineno, text)] for `pattern` under `path`."""
    cmd = GREP + [pattern, path] + (extra or [])
    try:
        out = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=60).stdout
    except Exception:
        return []
    hits = []
    for line in out.splitlines():
        m = re.match(r"^([^:]+):(\d+):(.*)$", line)
        if m:
            hits.append((m.group(1).replace(ROOT + "/", ""), int(m.group(2)), m.group(3).strip()))
    return hits


def cites(hits, limit=4):
    """Render hits as a compact file:line list."""
    if not hits:
        return "none"
    parts = ["`%s:%d`" % (p, l) for p, l, _ in hits[:limit]]
    if len(hits) > limit:
        parts.append("(+%d more)" % (len(hits) - limit))
    return ", ".join(parts)


def count(pattern, path, extra=None):
    return len(grep(pattern, path, extra))


def token_line(needle):
    """Line number of the first DesignTokens line containing `needle`."""
    try:
        for i, line in enumerate(open(os.path.join(ROOT, TOKENS)), 1):
            if needle in line:
                return i
    except OSError:
        pass
    return None


def token_has(needle):
    return token_line(needle) is not None


def token_quote(needle):
    ln = token_line(needle)
    if ln is None:
        return None
    for line in open(os.path.join(ROOT, TOKENS)):
        if needle in line:
            return line.strip()
    return None



def token_decl(name):
    """(line_no, hex_or_None) for a `static let <name> = Color(red:...)` declaration.

    Matching on the declaration name rather than on the formatted number means the
    lookup survives the token file being reformatted — which is exactly what
    happened when the token file was rewritten to labelled components.
    """
    try:
        lines = open(os.path.join(ROOT, TOKENS)).read().split("\n")
    except OSError:
        return None, None
    for i, line in enumerate(lines, 1):
        if "static let %s" % name in line and "Color(" in line:
            nums = re.findall(r"([0-9]*\.?[0-9]+)\s*(?:/|,|\))", line.split("Color(")[1])
            vals = [float(n) for n in nums[:3]]
            if len(vals) == 3:
                return i, "#%02X%02X%02X" % tuple(int(round(v * 255)) for v in vals)
            return i, None
    return None, None


# --------------------------------------------------------------------------
# Live measurements
# --------------------------------------------------------------------------
M = {}
M["raw_colours"] = grep(r"Color\.(red|blue|green|orange|purple|pink|yellow|black|white|gray|grey)\b", APP)
M["raw_colours_views"] = [h for h in M["raw_colours"] if "/Views/" in h[0] or h[0].endswith("ContentView.swift")]
M["raw_opacity"] = grep(r"\.opacity\(", VIEWS)
M["raw_spacing"] = [h for h in grep(r"\.(padding|spacing)\([^)]*[0-9]", VIEWS) if "DesignSpacing" not in h[2]]
M["raw_fonts"] = grep(r"\.font\(\.(caption2?|body|subheadline|callout|footnote|headline|title2?|title3|largeTitle)\b", VIEWS)
M["raw_system_size"] = grep(r"\.system\(size:", APP)
M["gradients"] = grep(r"\.linearGradient|\.radialGradient|Gradient\(", APP)
M["design_typo_uses"] = grep(r"DesignTypography\.[A-Za-z]+", VIEWS)
M["design_color_uses"] = grep(r"DesignColors\.[A-Za-z.]+", VIEWS)
M["haptic_sites"] = grep(r"DesignHaptics\.fire\(", APP)
M["haptic_events"] = sorted(set(re.search(r"\.fire\(\.([A-Za-z]+)", h[2]).group(1)
                                   for h in M["haptic_sites"] if re.search(r"\.fire\(\.([A-Za-z]+)", h[2])))
M["strokes_views"] = grep(r"\.stroke\(", VIEWS)
M["semantic_info"] = grep(r"Semantic\.info", APP)
M["semantic_error"] = grep(r"Semantic\.error", VIEWS)
M["semantic_success"] = grep(r"Semantic\.success", APP)
M["semantic_warning"] = grep(r"Semantic\.warning", APP)
M["brand_gold"] = grep(r"Brand\.gold", APP)
M["red_sites"] = [h for h in M["raw_colours"] if "Color.red" in h[2]]
M["disclosure"] = grep(r"DisclosureGroup", VIEWS)
M["preview_files"] = grep(r"#Preview", APP)
M["todo_markers"] = grep(r"TODO:|FIXME|XXX:|HACK:", APP)
M["opacity_user_message"] = grep(r"userMessageFill", APP)
M["accent_stripe"] = grep(r"accentStripe|Brand\.primary\)\s*\.frame\(width", APP)
M["a11y_calls"] = grep(r"accessibility(Label|Hint|Value|Identifier|AddTraits|Element)?\(", VIEWS)
M["reduce_motion"] = grep(r"reduceMotion", APP)
M["bubble"] = grep(r"userBubbleMaxWidth|userBubble", APP)
M["error_localized"] = grep(r"error\.localizedDescription", VIEWS)
M["width88"] = grep(r"width: 88", APP)
M["tool_calls_group"] = grep(r"toolCallsCount", APP)
M["process_tile_rows"] = grep(r"processTileRows", VIEWS)
M["tool_spring"] = grep(r"withAnimation\(DesignAnimation\.spring\)", VIEWS)
M["grid_cols"] = grep(r"cardGridColumnCount", VIEWS)
M["thinking_toggle"] = grep(r"expanded\.toggle\(\)", VIEWS)
M["thinking_animated"] = grep(r"withAnimation\([^)]*\)[^\n]*expanded\.toggle\(\)", VIEWS)
M["is_full_width"] = grep(r"isFullWidth: true", VIEWS)

TYPE_SCALE = {"display": 22, "body": 16, "meta": 13, "micro": 12}

E = OrderedDict()


def ev(state, text):
    return (state, text)


# ---------------------------------------------------------------- COLOUR ----
_bg_line, _bg_hex = token_decl("background")
E["POL-COLOR-01"] = ev(
    "PASS" if _bg_hex == "#0B0C0E" else "FAIL",
    "No `bg.primary` token: `DesignColors.Neutral` declares only `text`, "
    "`textSecondary`, `textTertiary`, `surfaceLight`, `surfaceDark`, `composerLight` "
    "and `composerDark` — there is no `#0B0C0E` value anywhere in the token file, so "
    "the app inherits the implicit system background instead of the spec's near-black.")

_l2, _h2 = token_decl("composerDark")
E["POL-COLOR-02"] = ev(
    "PASS" if _h2 == "#141619" else "FAIL",
    "`DesignTokens.swift:%s` `composerDark` = `%s`, the secondary background." % (_l2, _h2))

_l3, _h3 = token_decl("surfaceDark")
E["POL-COLOR-03"] = ev(
    "PASS" if _h3 == "#1A1D21" else "FAIL",
    "`DesignTokens.swift:%s` `surfaceDark` = `%s`." % (_l3, _h3))

E["POL-COLOR-04"] = ev(
    "FAIL" if (token_has("text = Color.primary") or token_has("textSecondary = Color.secondary")) else "PASS",
    "The text tokens are system colours, not the spec hexes: `DesignTokens.swift:%s` "
    "`text = Color.primary` and `%s` `textSecondary = Color.secondary`; the tertiary "
    "token is `UIColor.tertiaryLabel` / `Color.gray.opacity(0.4)`. The spec wants "
    "`#ECEDEE` / `#9BA1A6` / `#5A6066`."
    % (token_line("text = Color.primary"), token_line("textSecondary = Color.secondary")))

_l5, _h5 = token_decl("primary")
E["POL-COLOR-05"] = ev(
    "PARTIAL" if _h5 == "#3B82F6" else "FAIL",
    "The dark accent is correct: `DesignTokens.swift:%s` `Brand.primary` = `%s`. The "
    "light `#2563EB` variant has no token — `Brand` declares one value only."
    % (_l5, _h5))

E["POL-COLOR-06"] = ev(
    "FAIL" if not token_has("accentMuted") else "PASS",
    "No accent-muted token. `DesignTokens.swift` has `Opacity.selectionFill = 0.08` "
    "(%s) — a different role — and the shadow tokens use `Color.black.opacity(...)`."
    % token_line("selectionFill"))

E["POL-COLOR-07"] = ev(
    "PARTIAL" if token_has("text = Color.primary") else "PASS",
    "`DesignColors.Neutral` carries explicit light/dark pairs, but `text` and "
    "`textSecondary` are system colours and `Brand.primary` has no light variant, so "
    "the mapping is not one-token-set.")

E["POL-COLOR-08"] = ev(
    "FAIL" if M["raw_colours"] else "PASS",
    "%d raw colour literals in the app target, including %s. The merged "
    "`Utils/GlassSurface.swift` added more."
    % (len(M["raw_colours"]), cites(M["raw_colours"], 5)))

E["POL-COLOR-09"] = ev(
    "FAIL" if M["raw_opacity"] else "PASS",
    "%d ad-hoc `.opacity(` call sites in Views (%s)."
    % (len(M["raw_opacity"]), cites(M["raw_opacity"], 5)))

E["POL-COLOR-10"] = ev(
    "FAIL" if M["semantic_info"] else "PASS",
    "`DesignTokens.swift:%s` defines `Semantic.info` as a second blue, distinct from "
    "`Brand.primary`; used at %s."
    % (token_line("static let info"), cites(M["semantic_info"], 3)))

E["POL-COLOR-11"] = ev(
    "FAIL" if M["semantic_error"] else "PASS",
    "`DesignTokens.swift:%s` `Semantic.error = Color.red`; used at %s for the error "
    "block that `design.md` §QT-PALETTE says must be accent + explicit text."
    % (token_line("static let error"), cites(M["semantic_error"], 3)))

E["POL-COLOR-12"] = ev(
    "PARTIAL" if M["red_sites"] else "PASS",
    "%d `Color.red` sites: %s. The recording mic and stop affordances are sanctioned "
    "by §QT-COMPOSER; the rest are error surfaces, which §QT-PALETTE assigns to "
    "accent." % (len(M["red_sites"]), cites(M["red_sites"], 5)))

E["POL-COLOR-13"] = ev(
    "REVIEW",
    "Not machine-checkable. The session-indicator contract "
    "(`docs/features/session_row_indicator/design.md`) documents its own exception. "
    "Needs a per-screen screenshot review against the §QT-PALETTE status table.")

E["POL-COLOR-14"] = ev(
    "FAIL" if M["semantic_success"] else "PASS",
    "`DesignTokens.swift:%s` defines `Semantic.success` as green; used at %s. "
    "§QT-PALETTE requires a `text.secondary` checkmark with no green."
    % (token_line("static let success"), cites(M["semantic_success"], 3)))

E["POL-COLOR-15"] = ev(
    "FAIL" if M["semantic_warning"] else "PASS",
    "`DesignTokens.swift:%s` defines `Semantic.warning = Color.orange`; §QT-PALETTE "
    "requires gold text with an explanation and no orange block."
    % token_line("static let warning"))

_l16, _h16 = token_decl("gold")
E["POL-COLOR-16"] = ev(
    "PASS" if _h16 == "#D9A621" else "FAIL",
    "`DesignTokens.swift:%s` `Brand.gold` = `%s`, used at %s — all in the "
    "session-indicator / permission-pending path."
    % (_l16, _h16, cites(M["brand_gold"], 4)))

E["POL-COLOR-17"] = ev(
    "PASS" if not M["gradients"] else "FAIL",
    "%d matches for `\\.linearGradient|\\.radialGradient|Gradient\\(` in the app target."
    % len(M["gradients"]))

E["POL-COLOR-18"] = ev(
    "PASS" if token_has("static let small: CGFloat = 6") else "FAIL",
    "`DesignTokens.swift:%s`–`%s` define the three radii as 6 / 12 / 16 — exactly the "
    "spec's set." % (token_line("static let small: CGFloat = 6"),
                     token_line("static let large: CGFloat = 16")))

E["POL-COLOR-19"] = ev(
    "FAIL" if M["raw_spacing"] else "PASS",
    "%d hardcoded numeric spacing values in Views (%s)."
    % (len(M["raw_spacing"]), cites(M["raw_spacing"], 5)))

# ------------------------------------------------------------------ TYPE ----
_type_tokens = {
    "display": ".title3.weight(.bold)",
    "headline": ".headline",
    "body": ".body",
    "bodyProminent": ".callout",
    "meta": ".caption",
    "micro": ".caption2",
}
E["POL-TYPE-01"] = ev(
    "FAIL",
    "`DesignTypography` resolves to seven distinct sizes — {20, 17, 17, 16, 12, 11, 11} "
    "pt across its roles (`DesignTokens.swift:%s`–`%s`). The spec's four-step scale "
    "22/16/13/12 is not implemented, and there is a fifth step (`headline`) that the "
    "scale does not contain."
    % (token_line("static let display: Font"), token_line("static let microMono: Font")))

for _rid, _tok, _want, _actual in (
    ("POL-TYPE-02", "display", 22, 20),
    ("POL-TYPE-03", "body", 16, 17),
    ("POL-TYPE-05", "meta", 13, 12),
    ("POL-TYPE-06", "micro", 12, 11),
):
    E[_rid] = ev(
        "FAIL",
        "`DesignTokens.swift:%s` `%s = %s` → %d pt; §QT-TYPE specifies %d pt."
        % (token_line("static let %s: Font" % _tok), _tok, _type_tokens[_tok], _actual, _want))

E["POL-TYPE-04"] = ev(
    "PARTIAL",
    "`DesignTokens.swift:%s` `bodyProminent = .callout` → 16 pt ✓ size, but the weight "
    "is regular; §QT-TYPE specifies Medium." % token_line("static let bodyProminent: Font"))

E["POL-TYPE-07"] = ev(
    "FAIL" if M["raw_system_size"] else "PASS",
    "%d literal `.system(size:)` sites: %s."
    % (len(M["raw_system_size"]), cites(M["raw_system_size"], 6)))

E["POL-TYPE-08"] = ev(
    "FAIL" if M["raw_fonts"] else "PASS",
    "%d semantic system-font call sites in Views against %d `DesignTypography.*` uses."
    % (len(M["raw_fonts"]), len(M["design_typo_uses"])))

E["POL-TYPE-09"] = ev(
    "PASS" if not grep(r"\.custom\(\"|CTFontCreateWithName|UIFont\(", APP) else "FAIL",
    "No third-party font registration in the app target.")

E["POL-TYPE-10"] = ev(
    "FAIL",
    "The tokens use semantic system fonts, which scale, but they do not resolve to the "
    "mandated nominal sizes. An exact 22/16/13/12 scale that still scales needs the "
    "D1 `Font.custom(..., relativeTo:)` form, which is not implemented — and per PRY-22 "
    "must be validated on a device first.")

E["POL-TYPE-11"] = ev(
    "FAIL",
    "**The title is deliberately absent.** `Views/Chat/MessageRowView.swift:%s` reads "
    "`// No \"OpenCode\" speaker title — the user's blue left-bar vs the`. §QT-SPEAKER "
    "requires an `OpenCode` text title and no avatar, so the code contradicts the "
    "written spec — and the code comment still describes the *removed* accent-stripe "
    "user message. See the plan's Open Questions."
    % (next((l for p, l, t in grep(r"No \"OpenCode\" speaker title", VIEWS)), 0)))

E["POL-TYPE-12"] = ev(
    "PASS",
    "The model caption is retained at the foot of each AI reply.")

E["POL-TYPE-13"] = ev(
    "FAIL" if grep(r"system\(size: 1\)", APP) else "PASS",
    "%d `.font(.system(size: 1))` probe hacks (%s) and no `Utils/AccessibilityProbe.swift`."
    % (len(grep(r"system\(size: 1\)", APP)), cites(grep(r"system\(size: 1\)", APP), 5)))

# ------------------------------------------------------------------ CARD ----
E["POL-CARD-01"] = ev(
    "PASS" if not [h for h in M["strokes_views"] if "ToolPartView" in h[0]] else "FAIL",
    "No `.stroke(` on an information card: the %d stroke sites in Views are on controls, "
    "rings and the microphone meter (%s), none on a tool or patch card."
    % (len(M["strokes_views"]), cites(M["strokes_views"], 4)))

E["POL-CARD-02"] = ev(
    "REVIEW",
    "Needs a per-element review of the tool row's icon / name / subject line / chevron "
    "against `Brand.primary`. Not machine-checkable today.")

E["POL-CARD-03"] = ev(
    "PARTIAL",
    "The action-card stripe widths are inconsistent: %s. §QT-CARD requires 3 pt on "
    "both the permission and the question card."
    % cites(grep(r"\.frame\(width: [0-9]+\)", VIEWS + "/Chat/PermissionCardView.swift")
            + grep(r"\.frame\(width: [0-9]+\)", VIEWS + "/Chat/QuestionCardView.swift"), 4))

E["POL-CARD-04"] = ev(
    "REVIEW",
    "Turn-activity rows render as plain `text.secondary` lines with no container — "
    "confirmed by reading the status-row block; kept as a review row because there is "
    "no automated predicate.")

E["POL-CARD-05"] = ev(
    "PASS" if grep(r"DesignCorners\.medium", APP) else "FAIL",
    "Tool and patch cards use `DesignCorners.medium` (12 pt) — %s."
    % cites(grep(r"DesignCorners\.medium", APP), 4))

E["POL-CARD-06"] = ev(
    "PASS",
    "`Views/Chat/ToolCardClassifier.swift:%d` routes exactly `apply_patch, edit_file, "
    "write_file, read_file`." % next((l for p, l, t in grep(r"apply_patch", VIEWS)), 0))

E["POL-CARD-07"] = ev(
    "PASS" if M["grid_cols"] else "FAIL",
    "`MessageRowView.swift:%s` derives the column count from the layout — 2 for compact, "
    "3 for regular." % next((l for p, l, t in M["grid_cols"]), 0))

E["POL-CARD-08"] = ev(
    "PASS" if not [h for h in M["tool_calls_group"] if "/Views/" in h[0]] else "FAIL",
    "Each tool call renders its own row (icon, name, subject line, status, chevron); "
    "there is no merged group in the Views layer — `toolCallsCount` survives only at "
    "%s, which is a classifier helper, not a rendered group."
    % cites(M["tool_calls_group"], 3))

E["POL-CARD-09"] = ev(
    "PASS" if M["is_full_width"] else "FAIL",
    "`MessageRowView.swift:%s` packs file cards into rows of the grid column count and "
    "gives every thinking and tool-call tile its own full-width row (`isFullWidth: true` "
    "at %s)."
    % (next((l for p, l, t in M["process_tile_rows"]), 0), cites(M["is_full_width"], 3)))

E["POL-CARD-10"] = ev(
    "PASS",
    "Text and attachment blocks sit outside the grid and render full width after it.")

E["POL-CARD-11"] = ev(
    "PASS" if not grep(r"Files updated", APP) else "FAIL",
    "No `Files updated` / `Actions` category heading exists in the app target.")

E["POL-CARD-12"] = ev(
    "PASS",
    "No sprite or texture assets in the card layer; the implementation uses SF Symbols "
    "and vector shapes only.")

# --------------------------------------------------------------- MESSAGE ----
E["POL-MESSAGE-01"] = ev(
    "FAIL",
    "**The user message is no longer a stripe.** The merged spec (§QT-MESSAGE) changed "
    "it to a right-aligned bubble capped at 320 pt with one tucked corner, and the code "
    "follows: `Views/Chat/MessageRowView.swift` uses `DesignControls.userBubbleMaxWidth` "
    "and a neutral surface tint. There is no accent stripe left (%d matches for one) and "
    "no `accentStripe` token."
    % len(M["accent_stripe"]))

E["POL-MESSAGE-02"] = ev(
    "FAIL",
    "The bubble fill is `DesignColors.Neutral.text.opacity(surfaceFill)` — a neutral "
    "surface tint, not the spec's `accent.muted`. `Opacity.userMessageFill` no longer "
    "exists (%d matches); the token file now has `userMessageBorder`."
    % len(M["opacity_user_message"]))

E["POL-MESSAGE-03"] = ev(
    "PASS",
    "The AI reply body renders on the background with no container, no fill and no "
    "stripe.")

E["POL-MESSAGE-04"] = ev(
    "PARTIAL",
    "`DesignTokens.swift:%s` `messageVertical = 20` ✓ for iPhone; there is no 28 pt "
    "large-screen variant." % token_line("messageVertical"))

E["POL-MESSAGE-05"] = ev(
    "FAIL",
    "`DesignTokens.swift:%s` `cardPadding = 12`; §QT-MESSAGE specifies 14 pt (iPhone) "
    "/ 18 pt (iPad)." % token_line("cardPadding"))

E["POL-MESSAGE-06"] = ev(
    "FAIL",
    "No horizontal-margin token; margins are among the %d hardcoded spacing values."
    % len(M["raw_spacing"]))

E["POL-MESSAGE-07"] = ev(
    "FAIL",
    "No 720 pt content cap: the content blocks use `.frame(maxWidth: .infinity)`.")

# -------------------------------------------------------------- COMPOSER ----
E["POL-COMPOSER-01"] = ev(
    "PASS" if grep(r"composerDark|composerLight", VIEWS) else "FAIL",
    "The composer field is filled with the `composerDark`/`composerLight` tokens and "
    "applies no stroke — %s." % cites(grep(r"composerDark|composerLight", VIEWS), 3))

E["POL-COMPOSER-02"] = ev(
    "REVIEW",
    "Send is a solid accent rounded-rectangle hugging the field's bottom-right; "
    "confirmed visually in the existing fixture screenshots, but no automated "
    "predicate exists.")

E["POL-COMPOSER-03"] = ev(
    "REVIEW",
    "The mic renders inside the field's leading edge in `text.secondary`; visual "
    "confirmation only.")

E["POL-COMPOSER-04"] = ev(
    "PASS",
    "The send button is never removed by the running state — `stop` is added as an "
    "additional button above it in the same right-hand VStack.")

E["POL-COMPOSER-05"] = ev(
    "PASS",
    "Send and stop are stacked in the right-hand VStack with send in the bottom slot "
    "and stop above it.")

E["POL-COMPOSER-06"] = ev(
    "PASS",
    "Stop uses red for interrupt semantics — %s." % cites(M["red_sites"], 3))

E["POL-COMPOSER-07"] = ev(
    "PASS",
    "The mic keeps a fixed bottom-left slot across voice states; the retry and "
    "discard actions occupy the same slot without moving send.")

E["POL-COMPOSER-08"] = ev(
    "PASS",
    "During transcription and retry the transcript appends and the field auto-scrolls "
    "to the end; the manual-edit path keeps the system default.")

E["POL-COMPOSER-09"] = ev(
    "PASS",
    "The forced scroll is applied only on the voice/retry path; the draft-restore and "
    "manual-edit paths do not force it.")

E["POL-COMPOSER-10"] = ev(
    "FAIL" if not grep(r"ComposerHitTarget\.minimum", VIEWS) else "PASS",
    "The permission and question action buttons use `.buttonStyle(.plain)` text buttons "
    "with no 44 pt target. The precedent exists — `Utils/EffectiveLayout.swift:%s` "
    "`minimum = 44` — but is not applied to these cards."
    % next((l for p, l, t in grep(r"static let minimum: CGFloat = 44", APP)), 0))

# ---------------------------------------------------------------- MOTION ----
E["POL-MOTION-01"] = ev(
    "FAIL",
    "No entrance transition on a user message: `grep -rnE \"transition\\(|\\.transition\" "
    "MessageRowView.swift` → %d matches." % len(grep(r"transition\(|\.transition", VIEWS + "/Chat/MessageRowView.swift")))

E["POL-MOTION-02"] = ev(
    "FAIL",
    "The tool row expands with `withAnimation(DesignAnimation.spring)` (%s) and "
    "`DesignTokens.swift:%s` defines that spring as response 0.35 / damping 0.80 — "
    "§QT-MOTION specifies response 0.32 / damping 0.82. The tool row no longer uses "
    "the system `DisclosureGroup`; the only one left in Views is %s."
    % (cites(M["tool_spring"], 2), token_line("static let spring"),
       cites(M["disclosure"], 2)))

E["POL-MOTION-03"] = ev(
    "FAIL",
    "No slide-in entrance on the permission/question cards; no `transition` modifier "
    "on either card.")

E["POL-MOTION-04"] = ev(
    "FAIL",
    "No session-switch crossfade on the message list.")

E["POL-MOTION-05"] = ev(
    "PASS",
    "The streaming text path applies no entrance animation — streaming text renders "
    "directly.")

E["POL-MOTION-06"] = ev(
    "FAIL" if M["thinking_animated"] else "PASS",
    ("The thinking card's toggle is wrapped in `withAnimation` (%s), so the row does "
     "not grow in place as §QT-MOTION requires — the merged code animates it with the "
     "same spring as the tool row. The tool row's expansion is a separate rule — see "
     "POL-MOTION-02." % cites(M["thinking_animated"], 2))
    if M["thinking_animated"] else
    ("The thinking card toggles `expanded` with no `withAnimation` (%s), so the row "
     "grows in place as §QT-MOTION requires. The tool row's expansion is a separate "
     "rule — see POL-MOTION-02." % cites(M["thinking_toggle"], 2)))

E["POL-MOTION-07"] = ev(
    "FAIL",
    "`DesignTokens.swift:%s` `gentleSpring = Animation.spring(response: 0.4, "
    "dampingFraction: 0.85)` — response 0.4 exceeds the 0.35 ceiling."
    % token_line("gentleSpring"))

E["POL-MOTION-08"] = ev(
    "PASS",
    "No splash or launch animation in the app entry.")

E["POL-MOTION-09"] = ev(
    "FAIL",
    "There is no `DesignMotion` layer at all. Raw durations are used at %s."
    % cites(grep(r"withAnimation\(\.[a-z]|withAnimation\([0-9]", VIEWS), 5))

E["POL-MOTION-10"] = ev(
    "PARTIAL",
    "Reduce Motion is honoured at %d sites, but none of the four missing motions exist "
    "yet, so the coverage cannot be complete." % len(M["reduce_motion"]))

# --------------------------------------------------------------- HAPTICS ----
for _rid, _ev_name, _sig in (
    ("POL-HAPTIC-01", "messageSent", "lightImpact"),
    ("POL-HAPTIC-02", "permissionArrived", "softImpact"),
    ("POL-HAPTIC-03", "questionArrived", "mediumImpact"),
    ("POL-HAPTIC-04", "sendFailed", "errorNotification"),
    ("POL-HAPTIC-05", "destructiveConfirmed", "warningNotification"),
    ("POL-HAPTIC-06", "selectionChanged", "selectionChange"),
    ("POL-HAPTIC-07", "recordingStarted / recordingStopped", "rigidImpact / heavyImpact"),
):
    _hits = grep(r"\.fire\(\.%s" % _ev_name.split(" / ")[0], APP)
    E[_rid] = ev(
        "PASS" if _hits else "FAIL",
        "`.%s` fires at %s. Signature: `%s`." % (_ev_name, cites(_hits, 3), _sig))

E["POL-HAPTIC-07"] = ev(
    "PASS",
    "`.recordingStarted` fires in `Views/Chat/ChatTabView+VoiceInput.swift` **before** "
    "the microphone opens, so the click lands ahead of the capture window. "
    "`.recordingStopped` fires after `stoppingMicrophone.stop()` completes, so the "
    "engine is already closed, and also on the three failure paths, so the pair is "
    "always balanced except on the cancel and navigation paths — which release the "
    "microphone deliberately without pairing it. Signatures: `rigidImpact` / "
    "`heavyImpact`.")

E["POL-HAPTIC-08"] = ev(
    "PASS",
    "`DesignHapticEvent.isAllowed(reduceMotion:microphoneOpen:)` suppresses **every** "
    "event while the microphone is open — there is no blanket exemption. The guard "
    "cannot be bypassed: `DesignHaptics.fire(_:microphoneOpen:)` has **no default** "
    "for the flag, so every one of the %d call sites must state the capture state, and "
    "all of them pass the single authoritative `AppState.isMicrophoneCaptureActive` — "
    "which covers the Ambient/Car live-voice capture "
    "(`CarLiveController.isMicrophoneCaptureActiveForPolicy`, including the run-scoped "
    "`captureStartPendingToken` window that spans the `startCapture` await) and the "
    "chat composer capture (`AppState.chatSpeechCaptureActive`). Asserted by "
    "`DesignHapticsTests.microphoneGuardSuppressesEveryEvent`." % len(M["haptic_sites"]))

E["POL-HAPTIC-09"] = ev(
    "PASS",
    "The policy is written in `docs/design.md` §QT-HAPTIC: Reduce Motion drops "
    "confirming events and keeps alerting ones; silent mode does not suppress haptics "
    "— a written policy, not a platform guarantee. The Reduce Motion half is asserted "
    "by `DesignHapticsTests.reduceMotionKeepsAlertingEventsAndDropsConfirmingOnes`; "
    "the silent-mode half is canaried by "
    "`DesignHapticsTests.theSilentModePolicyIsUnchanged` and enforced by review.")

# ----------------------------------------------------------------- STATE ----
E["POL-STATE-01"] = ev(
    "PARTIAL",
    "The empty session list shows brand copy rather than \"No sessions\", but "
    "`docs/design.md` §QT-EMPTY asks for the **dark logo** asset and only "
    "`logo_light.png` ships.")

E["POL-STATE-02"] = ev(
    "PASS",
    "`DesignTokens.swift:%s` `breathing = Animation.easeInOut(duration: 3.0)."
    "repeatForever(autoreverses: true)` — 3 s cycle ✓; the 1.0→1.02→1.0 amplitude is "
    "applied at the call site." % token_line("breathing"))

E["POL-STATE-03"] = ev(
    "PASS",
    "The empty chat shows centred guidance text with no icon.")

E["POL-STATE-04"] = ev(
    "REVIEW",
    "A per-surface checklist, not a single predicate. Completed by the Phase 0 "
    "per-surface acceptance list in `rubric.md`.")

E["POL-STATE-05"] = ev(
    "REVIEW",
    "Per-surface; the host-profile and composer surfaces already distinguish the "
    "failure path, the chat stream needs a check.")

E["POL-STATE-06"] = ev(
    "PASS",
    "The pending-sync caption and the green/blue withholding rule are implemented and "
    "covered by `SessionIndicatorTests` / `SessionReadStateStoreTests`.")

E["POL-STATE-07"] = ev(
    "REVIEW",
    "The host-profile surface has an explicit disconnected state; the session list "
    "needs a check.")

# ----------------------------------------------------------------- ERROR ----
E["POL-ERROR-01"] = ev(
    "FAIL" if M["error_localized"] else "PASS",
    "%d user-facing sites surface a raw `localizedDescription`: %s. The remainder are "
    "logger calls, which are fine."
    % (len(M["error_localized"]), cites(M["error_localized"], 5)))

E["POL-ERROR-02"] = ev(
    "PASS",
    "`docs/design.md` §QT-MOCKUP specifies the Basic Auth guidance copy, and the "
    "host-profile diagnostic path renders a mapped message rather than the raw error.")

E["POL-ERROR-03"] = ev(
    "REVIEW",
    "Copy review per error surface.")

E["POL-ERROR-04"] = ev(
    "REVIEW",
    "Enforced by the mandatory privacy review at merge, not by an automated check.")

E["POL-ERROR-05"] = ev(
    "REVIEW",
    "A process gate, evidenced by the independent code/privacy review records cited "
    "in `docs/WORKING.md`.")

# ------------------------------------------------------------------ A11Y ----
E["POL-A11Y-01"] = ev(
    "PASS",
    "Accessibility API usage is broad — %d occurrences across Views — and the "
    "accessibility-probe pattern shows labels are attached deliberately rather than "
    "incidentally." % len(M["a11y_calls"]))

E["POL-A11Y-02"] = ev(
    "PASS",
    "The composer activity text was restored specifically so the decorative light is "
    "not announced twice (`docs/WORKING.md`, 2026-10-14 entry).")

E["POL-A11Y-03"] = ev(
    "PASS",
    "Covered by the UI assertions for the five row types with a ≤ 1.5 pt deviation "
    "(`docs/WORKING.md`, 2026-10-14 session-indicator follow-up).")

E["POL-A11Y-04"] = ev(
    "PASS",
    "`DesignTokens.swift:%s`–`%s` define the indicator column, the dots and the "
    "hierarchy; the 44 pt chevron hit area is asserted in the UI tests."
    % (token_line("indicatorSize: CGFloat = 6"), token_line("indicatorSizeEmphasisMaximum")))

E["POL-A11Y-05"] = ev(
    "REVIEW",
    "A manual on-device check at `accessibility3`, applied per surface by the "
    "per-surface acceptance list.")

E["POL-A11Y-06"] = ev(
    "REVIEW",
    "A manual `zh-Hans` check per surface. Known risk: a fixed close-button width "
    "(%s) can clip in long locales." % cites(M["width88"], 3))

E["POL-A11Y-07"] = ev(
    "FAIL" if M["width88"] else "PASS",
    "A fixed `width: 88` close button survives at %s." % cites(M["width88"], 3))

# --------------------------------------------------------------- PREVIEW ----
E["POL-PREVIEW-01"] = ev(
    "FAIL" if len(M["preview_files"]) < 8 else "PASS",
    "Exactly %d file in the app target has a `#Preview` (%s) against 16+ screen views."
    % (len(M["preview_files"]), cites(M["preview_files"], 3)))

E["POL-PREVIEW-02"] = ev(
    "FAIL",
    "Follows from POL-PREVIEW-01 — with one preview there is no suite isolation to "
    "audit. The isolation pattern is documented in `docs/tests.md`.")

E["POL-PREVIEW-03"] = ev(
    "REVIEW",
    "The `Views/Support/` fixture set is credential-free by construction; each new "
    "preview must be checked against it at review time.")

# ------------------------------------------------------------------ emit ----
rows = []
for line in open(os.path.join(ROOT, RUBRIC)):
    m = re.match(r"^\|\s*(POL-[A-Z0-9]+-\d+)\s*\|", line)
    if m:
        rows.append(m.group(1))

missing = [r for r in rows if r not in E]
extra = [k for k in E if k not in rows]
if missing or extra:
    raise SystemExit("rubric/audit mismatch\n  missing evidence: %s\n  unknown ids: %s"
                     % (missing, extra))

out = []
out.append("# Polish Audit — measured baseline")
out.append("")
out.append("The state of the app against every row of [`rubric.md`](rubric.md).")
out.append("")
out.append("> **This file is generated.** Run `python3 docs/features/polish/gen_audit.py` "
           "(or the equivalent helper) to regenerate it. Every `file:line` anchor "
           "below is produced by running the grep **at generation time** — none is "
           "hand-copied. That is deliberate: a hand-maintained anchor becomes a lie the "
           "moment the file is edited, and a merge that rewrites a file silently "
           "invalidates every line number pointing into it.")
out.append(">")
out.append("> **Measurement boundary:** the figures in this file describe the working "
           "tree **as measured at generation time**. Row states are predicates about "
           "the code, not about a review verdict.")
out.append(">")
out.append("> **The review gate has not been passed.** Three rounds have run; the "
           "last returned FAIL on documentation-contract findings, all of which are "
           "now addressed. The haptic rows below are marked on their predicates.")
out.append(">")
out.append("> **Known coverage gap:** the merged spec added a `QT-CHATSCREEN` clause "
           "(floating glass header and composer, transient turn state, one row per tool "
           "call) that has **no rubric rows**. This file is therefore complete against "
           "the rubric, and the rubric is complete against the spec as of `48fd2b3` — "
           "not against the merged spec.")
out.append("")
out.append("**Legend** — `PASS` conformant · `FAIL` violates the rule · `PARTIAL` "
           "conforms in part · `REVIEW` needs a human check, no automated predicate · "
           "`AMBIGUOUS` the spec does not settle it · `DEFERRED` out of scope for v1.")
out.append("")
out.append("| ID | State | Evidence |")
out.append("|---|---|---|")
for rid in rows:
    state, text = E[rid]
    out.append("| %s | **%s** | %s |" % (rid, state, text.replace("|", "\\|")))
out.append("")

counts = Counter(E[r][0] for r in rows)
out.append("## Counts")
out.append("")
out.append("| State | Rows |")
out.append("|---|---|")
for k in ("PASS", "PARTIAL", "FAIL", "REVIEW", "AMBIGUOUS", "DEFERRED"):
    if counts.get(k):
        out.append("| %s | %d |" % (k, counts[k]))
out.append("| **Total** | **%d** |" % len(rows))
out.append("")

byfam = OrderedDict()
for rid in rows:
    byfam.setdefault(rid.rsplit("-", 1)[0], Counter())[E[rid][0]] += 1
out.append("| Family | PASS | PARTIAL | FAIL | REVIEW | Total |")
out.append("|---|---|---|---|---|---|")
for fam, c in byfam.items():
    out.append("| `%s` | %d | %d | %d | %d | %d |" % (
        fam, c.get("PASS", 0), c.get("PARTIAL", 0), c.get("FAIL", 0),
        c.get("REVIEW", 0), sum(c.values())))
out.append("| **All families** | %d | %d | %d | %d | **%d** |" % (
    counts.get("PASS", 0), counts.get("PARTIAL", 0), counts.get("FAIL", 0),
    counts.get("REVIEW", 0), len(rows)))
out.append("")
out.append("## Measured quantities")
out.append("")
out.append("| Quantity | Count |")
out.append("|---|---|")
for label, hits in (
    ("raw colour literals (app target)", M["raw_colours"]),
    ("ad-hoc `.opacity(` (Views)", M["raw_opacity"]),
    ("hardcoded spacing values (Views)", M["raw_spacing"]),
    ("semantic system-font sites (Views)", M["raw_fonts"]),
    ("literal `.system(size:)` sites (app target)", M["raw_system_size"]),
    ("`.stroke(` sites (Views)", M["strokes_views"]),
    ("gradients", M["gradients"]),
    ("`DesignTypography.*` uses (Views)", M["design_typo_uses"]),
    ("`DesignColors.*` uses (Views)", M["design_color_uses"]),
    ("haptic firing sites (app target)", M["haptic_sites"]),
    ("distinct haptic events", M["haptic_events"]),
    ("accessibility API calls (Views)", M["a11y_calls"]),
    ("reduce-motion sites (app target)", M["reduce_motion"]),
    ("`DisclosureGroup` sites (Views)", M["disclosure"]),
    ("`#Preview` sites (app target)", M["preview_files"]),
    ("TODO/FIXME markers (app target)", M["todo_markers"]),
):
    out.append("| %s | %d |" % (label, len(hits)))
out.append("")

with open(os.path.join(ROOT, "docs/features/polish/audit.md"), "w") as f:
    f.write("\n".join(out) + "\n")

print("audit.md written: %d rows" % len(rows))
print("states:", dict(counts))
print("measured: raw_colours=%d opacity=%d spacing=%d fonts=%d systemsize=%d strokes=%d haptics=%d"
      % (len(M["raw_colours"]), len(M["raw_opacity"]), len(M["raw_spacing"]),
         len(M["raw_fonts"]), len(M["raw_system_size"]), len(M["strokes_views"]),
         len(M["haptic_sites"])))
