# Credits

## Project

DesktopWorm was created by [Apoorv Darshan](https://github.com/apoorvdarshan).
The application code and original visual design in this repository are released
under the [MIT License](LICENSE).

## Concept inspiration

The idea of a connectome-driven organism living in a transparent macOS desktop
overlay was inspired by Denis Shiryaev's
[DesktopFly](https://github.com/DenisSergeevitch/desktop-fly).

DesktopWorm is a separate implementation for *Caenorhabditis elegans*. It does
not bundle DesktopFly source code, assets, or FlyWire data.

## Connectome data and tooling

The bundled compact graph is derived from the
[OpenWorm c302](https://github.com/openworm/c302) project at revision
`6cd861f8ca4d3241ee9cf4627884caa930dab53c`. Thanks to the OpenWorm
contributors for maintaining the c302 framework and unified worm data.

Please cite:

- Gleeson P, Lung D, Grosu R, Hasani R, Larson SD (2018), “c302: a multiscale
  framework for modelling the nervous system of *Caenorhabditis elegans*.”
  *Philosophical Transactions of the Royal Society B* 373:20170379.
  <https://doi.org/10.1098/rstb.2017.0379>
- Cook SJ et al. (2019), “Whole-animal connectomes of both *Caenorhabditis
  elegans* sexes.” *Nature* 571, 63–71.
  <https://doi.org/10.1038/s41586-019-1352-7>

OpenWorm c302 is MIT-licensed. Its license text is bundled at
`Sources/DesktopWorm/Resources/OPENWORM_LICENSE.txt`.

## Behavioral and proprioception references

The qualitative locomotion repertoire and state timing are informed by:

- Albrecht DR, Bargmann CI (2011), *Nature Methods* 8, 599–605.
  <https://doi.org/10.1038/nmeth.1630>
- Gallagher T, Bjorness T, Greene R, You Y-J, Avery L (2013), *PLOS ONE*
  8(3):e59865. <https://doi.org/10.1371/journal.pone.0059865>
- Roberts WM et al. (2016), *eLife* 5:e12572.
  <https://doi.org/10.7554/eLife.12572>

The modeled SMD and DVA proprioceptive feedback is motivated by:

- Li W, Feng Z, Sternberg PW, Xu XZS (2006), “A *C. elegans* stretch receptor
  neuron revealed by a mechanosensitive TRP channel homologue.” *Nature* 440,
  684–687. <https://doi.org/10.1038/nature04538>
- Yeon J et al. (2018), “A sensory-motor neuron type mediates proprioceptive
  coordination of steering in *C. elegans* via two TRPC channels.”
  *PLOS Biology* 16(6):e2004929.
  <https://doi.org/10.1371/journal.pbio.2004929>

These publications inform model structure and qualitative behavior. They do
not make DesktopWorm a validated biological reproduction; neural equations,
synaptic signs where uncertain, screen physics, sensory conversion, and
numerical gains remain explicit modeling choices.
