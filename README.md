# MultiChannel Coloc Toolkit

An ImageJ/Fiji macro for region-based, multichannel image segmentation, particle analysis, and channel-mask merging.

**Author:** Sankeert Satheesan
**Contact:** sankeert1999@gmail.com

## Overview

This macro processes a 4-channel image (one channel assumed to be DAPI and excluded from analysis). The user defines one or more rectangular regions of interest (ROIs) on the image — the first ROI sets the size, and all subsequent regions are constrained to that same size. For each region, the three non-DAPI channels are independently segmented and analyzed, and merged composite masks are generated for all channel combinations.

## Features

- Interactive selection of input image and output directory
- User-defined channel names and DAPI channel selection
- Configurable minimum particle size (applied globally to all channels)
- Multi-region workflow: define as many regions as needed, all matching the size of the first
- Per channel, per region:
  - Gaussian blur (sigma = 1)
  - Otsu auto-thresholding
  - Particle analysis with mask, ROI set, and CSV output (area + centroid)
- Pairwise and triple merged mask composites (AB, AC, BC, ABC) per region
- All region ROIs saved for later reuse (`regions.zip`)
- Full run log (`log.txt`)
- Automatic cleanup (closes images, clears ROI Manager and Results) at the end

## Requirements

- [Fiji](https://fiji.sc/) (ImageJ with bundled plugins, including Auto Threshold)

## Usage

1. Open Fiji.
2. Drag and drop `Multichannel_ROI_Analysis.ijm` onto the Fiji toolbar, or open via **Plugins > Macros > Edit...** and run.
3. Follow the prompts:
   - Select the input image file
   - Select an output directory
   - Enter names for each of the 4 channels
   - Specify which channel is DAPI
   - Set the minimum particle size (pixels²)
4. Draw the first region ROI on the image and click **OK**.
5. For each additional region, reposition the fixed-size ROI and click **OK**. Choose whether to add more regions when prompted.

## Output Structure

```
output_directory/
├── log.txt
├── regions.zip
├── Region1/
│   ├── <ChannelA>_mask.tif
│   ├── <ChannelA>_rois.zip
│   ├── <ChannelA>_particles.csv
│   ├── <ChannelB>_mask.tif
│   ├── <ChannelB>_rois.zip
│   ├── <ChannelB>_particles.csv
│   ├── <ChannelC>_mask.tif
│   ├── <ChannelC>_rois.zip
│   ├── <ChannelC>_particles.csv
│   ├── Merge_<ChannelA>_<ChannelB>.tif
│   ├── Merge_<ChannelA>_<ChannelC>.tif
│   ├── Merge_<ChannelB>_<ChannelC>.tif
│   └── Merge_<ChannelA>_<ChannelB>_<ChannelC>.tif
├── Region2/
│   └── ...
└── ...
```

## Notes

- The DAPI channel is excluded entirely from processing.
- Segmentation parameters (Gaussian blur sigma, Otsu thresholding) are fixed and not user-configurable, to ensure consistency across channels and regions.
- Particle CSVs include Area and centroid (X, Y) coordinates only.

## License

