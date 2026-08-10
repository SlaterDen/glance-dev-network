# Writing a GDN app

You are writing an app for the Glance Developer Network (GDN): an app that renders
to a Glance LED panel.

The panel is always **32 pixels tall**. Each panel module is 64 pixels wide and
panels daisy-chain up to 384 pixels wide; for best performance keep images to
192x32 or smaller and split content across multiple pages.

An app is a FOLDER with two files:

    manifest.yaml  - settings: id, name, width, height, refresh (seconds),
                     pages: [list of screen names], and inputs (the user's form).
    app.star       - Starlark (Python-like) code. Define ONE function per page:
                     def <page>(c, ctx): ...  It DRAWS a picture; it never returns
                     anything. c = the canvas, ctx.inputs = the user's values,
                     ctx.now = the current time (UTC).

Coordinates: (0,0) is top-left, x grows right, y grows down. For text and images,
(x, y) is the TOP-LEFT corner. Circles/dots center on their coordinates.

## Drawing (`c.*`)

    fill(color) / clear() ; pixel(x,y,color) ; rect(x0,y0,x1,y1,fill=,outline=)
    line(x0,y0,x1,y1,color) ; text(s,x,y,font="5x7",color="white",align="left")
    image("file.png",x,y,w=,h=) ; bitmap([[0,1,...],...],x,y,color)

Helpers (composites — prefer these):

    circle, fill_circle, round_rect, hline, vline, gradient_rect,
    text_center, text_right, text_wrapped, text_fit, progress_bar, sparkline,
    bars, badge, trend_arrow, icon("sun"), sprite, header, kv, stat, gauge,
    status_dot, table, scoreboard, grid, color.dim

Colors: names (`"green"`, `"amber"`, `"red"`, `"white"`, …) or hex (`"#00FF00"`).
Call `list_colors` for the full table.

Fonts: `"4x5"`, `"5x7"`, `"6x8"`, `"7x12"`, `"16x24"`, and others. Call
`list_fonts` for the full table with pixel heights, and `measure_text` to check a
string fits before you commit to a font.

## Hard rules

These cause silent failures or validation errors. They are not style preferences.

- **Fonts are UPPERCASE ONLY.** Call `.upper()` on any text, or nothing draws.
- **Frames are STILL IMAGES.** Don't animate or scroll; the panel re-renders on the
  manifest's `refresh` timer, so let the next refresh show new data.
- **Draw immediately with `c.*`.** There is no widget tree and you never return
  anything.
- **Lay things out by hand.** The panel is only 32px tall, so keep text short.
- **`http.get` returns a DICT you read with SUBSCRIPTS.**
  `http.get(url, headers={}, params={}, ttl_seconds=300)` →
  `resp["status_code"]`, `resp["json"]`, `resp["body"]`. NOT `resp.status_code` —
  Starlark dicts have no attribute access, so the dotted form errors.
  **ALWAYS check `resp["status_code"] == 200` before reading `resp["json"]`.**
- **Read inputs with `ctx.inputs.get("key", fallback)`.** Declare each input in the
  manifest with `app_input_type`: `free-text`, `api-key`, `dropdown`, `checkbox`,
  `date`, `date-past`, `color`, or `selection`.
- **API keys MUST use `app_input_type: api-key`**, never `free-text`. Only
  `api-key` inputs are stored encrypted. The input name of an api-key MUST NOT
  contain `_` or `-` (use `"apikey"`, never `"api_key"` or `"api-key"`);
  validation rejects api-key input names containing them.

## A panel on a wall must never show a crash

Any app that fetches data needs a designed answer for the failure cases: the API
is down, the response is empty, the user typed a ZIP that doesn't exist. Draw
something sensible instead of letting the page error.

Check both paths before calling an app finished:

- `render_app` with `simulate_offline: true` — every `http.get` fails, so you see
  the no-data screen.
- `render_app` with a nonsense input (a bad ZIP, an unknown city) — you see the
  not-found screen.

`validate_app` warns if an app crashes with no network instead of falling back.

## The loop

1. `create_app` to scaffold the folder, then write `manifest.yaml` and `app.star`.
2. `render_app` and **look at the image** — check for clipped text, overlapping
   elements, and colors that are unreadable on an LED panel. Fix and re-render.
3. Render the failure screens (above).
4. `validate_app` — the same check `gdn submit` and CI run. Fix every error.
5. `write_previews` to generate the catalog images, so the folder is
   catalog-complete.
