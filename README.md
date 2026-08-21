# DesktopWorm 🪱

A native macOS desktop organism driven by the complete 302-neuron
*Caenorhabditis elegans* hermaphrodite connectome from OpenWorm c302.

DesktopWorm crawls across the desktop, treats the cursor as a weak chemical
attractant, reverses after fast nearby cursor movement, and exposes a live
connectome activity window. The model includes:

- all 302 neurons;
- 5,806 neuron-to-neuron edges;
- all 95 body-wall muscles;
- 926 neuron-to-muscle edges;
- chemical synapses and electrical gap junctions;
- sensory, interneuron and motor-neuron activity visualization.

The desktop body is a translucent ivory/amber rendering with a tapered head
and tail, subtle pharynx and intestine, and fine cuticle rings. Its articulated
40-point centerline holds a fixed body length. A traveling curvature wave
generates traction rather than letting the worm slide independently of its
body motion. The behavior controller supports forward crawling, touch-driven
reversal, sensory pauses, exploratory head sweeps, shallow turns, deep turns,
slow approaches, dwelling, omega turns, collision recovery and pause. Cursor
chemotaxis is staged: the worm samples a target, visibly reorients its body,
then approaches the sampled position instead of being continuously dragged by
the pointer.

The Living Connectome opens as a compact 520 × 340 floating HUD in the
bottom-right of the active display. It shows all 302 neurons inside a
whole-worm nervous-system schematic: a dense head-ganglia and nerve-ring field, longitudinal
cords, the numbered ventral-cord motor classes ordered along the body, body
sensory cells and a posterior ganglia cluster. Activity-weighted connections,
the most active cells, command-interneuron drive, dorsal and ventral muscle
activity, and the current autonomous behavior remain live. Resize it larger to
reveal the rolling history, transmitters and expanded scientific boundary.

c302 does not provide measured per-neuron spatial coordinates in the compact
source used here. The display therefore labels this as a region- and
class-derived anatomy schematic; it does not claim that dot positions are
microscopy coordinates. Colors still identify sensory, interneuron and motor
roles, while edges and neuron identities remain c302-derived.

## Run

Requirements: macOS 13+ and Xcode Command Line Tools.

```sh
./script/build_and_run.sh
```

The Living Connectome is the app's only control window. Use the 🪱 menu-bar item
to reopen it, inject touch or food stimuli, choose the crawl speed, hide or show
internal anatomy, pause, reset or quit. Movement selection remains autonomous.
The app does not request Accessibility, keyboard, camera, microphone or network
permissions.

## Verify

```sh
./script/test.sh
./script/build_and_run.sh --build-only
./script/build_and_run.sh --verify
```

## What is real—and what is modelled

The neuron list, cell roles, neurotransmitter annotations, anatomical edge
weights, gap-junction labels, muscle list and neuromuscular edges are derived
from OpenWorm c302 data. The graded neural dynamics, uncertain synaptic signs,
cursor-to-sensory conversion, locomotor rhythm, body mechanics and rendering
are explicit modelling choices.

This is a connectome-constrained interactive visualization, not a faithful
digital organism and not a conscious or living animal.

See `THIRD_PARTY_NOTICES.md` for data provenance and citations.
