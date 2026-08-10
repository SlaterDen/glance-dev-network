# The Coop -- a static welcome card: logo on the left, greeting on the right.
# Glance panels only ever show still frames (refreshed on a timer), so this
# is deliberately not an animation -- see gifs/the-coop/ in the repo root for
# an animated version, which only works where GIF playback is supported.

LOGO_H = 20
LOGO_W = 36
LOGO_X = 4
LOGO_Y = 6

TEAL = "#2CBABE"

def main(c, ctx):
    c.fill("black")
    c.image("logo.png", LOGO_X, LOGO_Y, w = LOGO_W, h = LOGO_H)

    msg = "WELCOME TO THE COOP"
    text_x0 = LOGO_X + LOGO_W + 6
    tw = c.text_width(msg, "5x7b")
    x = text_x0 + max(0, (c.width - text_x0 - tw) // 2)
    y = (c.height - 7) // 2
    c.text(msg, x, y, font = "5x7b", color = TEAL)
