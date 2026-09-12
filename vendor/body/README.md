# The anatomical figure

The four bodies in `tools/body_source.json` — male and female, front and back —
are the SVG paths from **react-native-body-highlighter**, MIT licensed,
© 2022 ELABBASSI Hicham. `LICENSE` beside this file is that project's licence,
kept verbatim as the MIT terms require.

    https://www.npmjs.com/package/react-native-body-highlighter

Nothing of that project runs here: it is a React Native component and this is a
plain web app. Only the path data is used, converted by `tools/build_body.py`
into the `BODY` block spliced into `app.js`.

## Why this rather than a drawn one

There was a generated figure before this: an artist's mannequin, then a
hand-authored anatomical one built out of smoothed point lists. Both were
honest attempts and both looked drawn — good enough to read, not good enough to
sit next to the rest of the app. Twenty curves by hand does not reach what an
illustrator does, and the useful thing about MIT-licensed anatomy is that it
does not have to.

`tools/build_body.py` still owns the mapping from these paths to the fourteen
regions the app tracks, so the art and the scoring stay separable: the source
can be swapped for better art without touching a single muscle share.
