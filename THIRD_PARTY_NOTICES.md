# Third-party data

DesktopWorm contains a compact derived representation of the OpenWorm c302
connectome data.

- Source: <https://github.com/openworm/c302>
- Source revision: `6cd861f8ca4d3241ee9cf4627884caa930dab53c`
- License: MIT, Copyright (c) 2024 OpenWorm
- Primary framework citation: Gleeson P, Lung D, Grosu R, Hasani R, Larson SD.
  “c302: a multiscale framework for modelling the nervous system of
  Caenorhabditis elegans.” Phil. Trans. R. Soc. B 373 (2018), 20170379.
- Connectome source represented by the c302 unified data: Cook et al. (2019),
  “Whole-animal connectomes of both Caenorhabditis elegans sexes.” Nature.

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
