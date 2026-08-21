# Third-party data

DesktopWorm contains a compact derived representation of the OpenWorm c302
connectome data.

- Source: <https://github.com/openworm/c302>
- Source revision: `6cd861f8ca4d3241ee9cf4627884caa930dab53c`
- License: MIT, Copyright (c) 2024 OpenWorm
- Primary framework citation: Gleeson P, Lung D, Grosu R, Hasani R, Larson SD.
  “c302: a multiscale framework for modelling the nervous system of
  Caenorhabditis elegans.” Phil. Trans. R. Soc. B 373 (2018), 20170379.
  <https://doi.org/10.1098/rstb.2017.0379>
- Connectome source represented by the c302 unified data: Cook et al. (2019),
  “Whole-animal connectomes of both Caenorhabditis elegans sexes.” Nature 571,
  63–71. <https://doi.org/10.1038/s41586-019-1352-7>

The MIT license text for the source project is reproduced in
`Sources/DesktopWorm/Resources/OPENWORM_LICENSE.txt`.

## Behavioral-model references

The modeled locomotion repertoire and its sustained-forward-run bias draw on:

- Albrecht DR, Bargmann CI (2011), “High-content behavioral analysis of
  Caenorhabditis elegans in precise spatiotemporal chemical environments.”
  Nature Methods 8, 599–605. <https://doi.org/10.1038/nmeth.1630>
- Gallagher T, Bjorness T, Greene R, You Y-J, Avery L (2013), “The Geometry of
  Locomotive Behavioral States in C. elegans.” PLOS ONE 8(3): e59865.
  <https://doi.org/10.1371/journal.pone.0059865>
- Roberts WM et al. (2016), “A stochastic neuronal model predicts random search
  behaviors at multiple spatial scales in C. elegans.” eLife 5:e12572.
  <https://doi.org/10.7554/eLife.12572>

These papers inform qualitative state timing and transitions. DesktopWorm's
screen scale, cursor stimulus mapping, equations and numerical gains remain
explicit modeling choices rather than measured animal parameters.

## Proprioception references

- Li W, Feng Z, Sternberg PW, Xu XZS (2006), “A C. elegans stretch receptor
  neuron revealed by a mechanosensitive TRP channel homologue.” Nature 440,
  684–687. <https://doi.org/10.1038/nature04538>
- Yeon J et al. (2018), “A sensory-motor neuron type mediates proprioceptive
  coordination of steering in C. elegans via two TRPC channels.” PLOS Biology
  16(6):e2004929. <https://doi.org/10.1371/journal.pbio.2004929>

These studies motivate the modeled DVA body-curvature and SMD head-bend
feedback paths. The implementation does not reproduce their experimental
measurements.

## Concept inspiration

DesktopWorm's transparent macOS desktop-organism concept was inspired by
Denis Shiryaev's DesktopFly: <https://github.com/DenisSergeevitch/desktop-fly>.
No DesktopFly source code, assets, or FlyWire data are bundled here.
