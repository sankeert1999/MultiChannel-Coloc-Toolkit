/*
 * MultiChannel-Coloc-Toolkit Multichannel ROI-based Segmentation, Particle Analysis & Merge Macro
 *
 * Written by: Sankeert Satheesan
 * Contact: sankeert1999@gmail.com
 *
 * Description:
 *   - Loads a 4-channel image (one channel = DAPI, excluded from processing).
 *   - User defines one or more regions of interest (ROIs) on the image.
 *     The first ROI's size (width x height) is recorded and reused for
 *     all subsequent regions (cropped at the position the user places them).
 *   - For each region, each of the 3 non-DAPI channels is independently:
 *       duplicated -> Gaussian blurred (sigma=1) -> Otsu auto-thresholded
 *       -> particle-analyzed (user-defined min size, no upper bound).
 *   - Outputs per region/channel: mask image, ROI set (.zip), and a CSV
 *     of particle Area + centroid (X,Y).
 *   - For each region, merged composite masks are created for all
 *     pairwise and triple combinations of the 3 non-DAPI channels.
 *   - All region ROIs (on the original image) are saved as regions.zip.
 *   - A log file is written summarizing the run.
 *   - At the end, all images/ROIs/results are cleared/closed.
 */


// ============================================================
// MAIN
// ============================================================
var totalRegions = 0;

macro "Multichannel ROI Analysis" {

    run("Close All");
    roiManager("reset");
    run("Clear Results");

    // ---- Gather user inputs ----
    inputs = getUserInputs();

    inputPath   = inputs[0];
    outputDir   = inputs[1];
    chLabels    = newArray(inputs[2], inputs[3], inputs[4], inputs[5]); // channel 1-4 names
    dapiChannel = parseInt(inputs[6]);  // 1-4
    minSize     = parseInt(inputs[7]);

    // Initialize log
    logPath = outputDir + "log.txt";
    initLog(logPath, inputPath, outputDir, chLabels, dapiChannel, minSize);

    // ---- Open input image ----
    open(inputPath);
    origTitle = getTitle();
    rename("IMG");

    // Build list of non-DAPI channel indices (1-4) and their labels
    nonDapiChannels = newArray(0);
    nonDapiLabels   = newArray(0);
    for (c = 1; c <= 4; c++) {
        if (c != dapiChannel) {
            nonDapiChannels = Array.concat(nonDapiChannels, c);
            nonDapiLabels   = Array.concat(nonDapiLabels, chLabels[c-1]);
        }
    }

    // ---- ROI definition loop ----
    regionRois = newArray(0); // will store ROI indices in RoiManager for regions
    regionCount = 0;
    firstWidth = -1;
    firstHeight = -1;

    keepGoing = true;
    while (keepGoing) {
        regionCount++;

        if (regionCount == 1) {
            defineFirstRegion();
            Roi.getBounds(rx, ry, rw, rh);
            firstWidth = rw;
            firstHeight = rh;
        } else {
            defineSubsequentRegion(firstWidth, firstHeight, regionCount);
        }

        // Save this region's ROI into the ROI Manager (named Region_N)
        roiManager("add");
        idx = roiManager("count") - 1;
        roiManager("select", idx);
        roiManager("rename", "Region_" + regionCount);

        logMessage(logPath, "Region " + regionCount + " ROI recorded: x=" + rx + " y=" + ry + " w=" + rw + " h=" + rh);

        // Ask whether to continue
        keepGoing = askContinue();
    }

    totalRegions = regionCount;

    // Save all region ROIs from original image
    if (roiManager("count") > 0) {
        roiManager("deselect");
        roiManager("save", outputDir + "regions.zip");
        logMessage(logPath, "Saved region ROIs to regions.zip");
    }

    // ---- Process each region ----
    for (r = 1; r <= regionCount; r++) {
        regionDir = outputDir + "Region" + r + File.separator;
        File.makeDirectory(regionDir);
        logMessage(logPath, "Processing Region " + r + " -> " + regionDir);

        processRegion(r, regionDir, nonDapiChannels, nonDapiLabels, minSize, logPath);
    }

    logMessage(logPath, "All regions processed. Run complete.");

    // ---- Cleanup ----
    cleanupAll();
}


// ============================================================
// FUNCTION: getUserInputs
// Shows the setup dialog and returns all user-provided values
// ============================================================
function getUserInputs() {
    inputPath = File.openDialog("Select the input image file");
    outputDir = getDirectory("Select the output directory");

    Dialog.create("Channel Configuration");
    Dialog.addString("Channel 1 name:", "Channel1");
    Dialog.addString("Channel 2 name:", "Channel2");
    Dialog.addString("Channel 3 name:", "Channel3");
    Dialog.addString("Channel 4 name:", "Channel4");
    Dialog.addChoice("Which channel is DAPI?", newArray("1","2","3","4"), "1");
    Dialog.addNumber("Minimum particle size (pixels^2):", 20);
    Dialog.show();

    ch1 = Dialog.getString();
    ch2 = Dialog.getString();
    ch3 = Dialog.getString();
    ch4 = Dialog.getString();
    dapiCh = Dialog.getChoice();
    minSize = Dialog.getNumber();

    return newArray(inputPath, outputDir, ch1, ch2, ch3, ch4, dapiCh, toString(minSize));
}


// ============================================================
// FUNCTION: initLog
// Writes the initial header info to the log file
// ============================================================
function initLog(logPath, inputPath, outputDir, chLabels, dapiChannel, minSize) {
    f = File.open(logPath);
    print(f, "=== Multichannel ROI Analysis Log ===");
    print(f, "Date/Time: " + getTimeStamp());
    print(f, "Input file: " + inputPath);
    print(f, "Output directory: " + outputDir);
    print(f, "Channel 1 label: " + chLabels[0]);
    print(f, "Channel 2 label: " + chLabels[1]);
    print(f, "Channel 3 label: " + chLabels[2]);
    print(f, "Channel 4 label: " + chLabels[3]);
    print(f, "DAPI channel: " + dapiChannel);
    print(f, "Minimum particle size: " + minSize);
    print(f, "");
    File.close(f);
}


// ============================================================
// FUNCTION: logMessage
// Appends a timestamped line to the log file
// ============================================================
function logMessage(logPath, msg) {
    File.append(getTimeStamp() + " - " + msg, logPath);
}


// ============================================================
// FUNCTION: getTimeStamp
// Returns a formatted date/time string
// ============================================================
function getTimeStamp() {
    getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
    months = newArray("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
    ts = "" + dayOfMonth + "-" + months[month] + "-" + year + " " + IJ.pad(hour,2) + ":" + IJ.pad(minute,2) + ":" + IJ.pad(second,2);
    return ts;
}


// ============================================================
// FUNCTION: defineFirstRegion
// Lets the user draw the first ROI of any size, then confirm
// ============================================================
function defineFirstRegion() {
    selectWindow("IMG");
    setTool("rectangle");
    waitForUser("Define Region 1", "Draw a rectangular ROI for Region 1 on the image, then click OK.");

    if (selectionType() == -1) {
        exit("No ROI was selected. Macro stopped.");
    }
}


// ============================================================
// FUNCTION: defineSubsequentRegion
// Places a fixed-size ROI (matching the first region's dimensions)
// for the user to reposition, then confirm
// ============================================================
function defineSubsequentRegion(w, h, regionNum) {
    selectWindow("IMG");

    // Place a default ROI of the required size near the top-left corner
    makeRectangle(0, 0, w, h);

    setTool("rectangle");
    waitForUser("Define Region " + regionNum,
        "A region of fixed size (" + w + " x " + h + " px) has been placed.\n" +
        "Drag it to the desired position (do not resize it), then click OK.");

    if (selectionType() == -1) {
        exit("No ROI was selected. Macro stopped.");
    }

    // Enforce exact size in case the user resized it
    Roi.getBounds(bx, by, bw, bh);
    if (bw != w || bh != h) {
        makeRectangle(bx, by, w, h);
    }
}


// ============================================================
// FUNCTION: askContinue
// Asks the user whether they want to define another region
// Returns true/false
// ============================================================
function askContinue() {
    choice = getBoolean("Do you want to define another region?");
    return choice;
}


// ============================================================
// FUNCTION: processRegion
// Crops the region from IMG, then processes each non-DAPI channel
// (segmentation, particle analysis, saving) and creates merged masks
// ============================================================
function processRegion(regionNum, regionDir, nonDapiChannels, nonDapiLabels, minSize, logPath) {

    nCh = nonDapiChannels.length;
    maskTitles = newArray(nCh); // will hold "Mask of <label>" titles

    for (i = 0; i < nCh; i++) {
        chNum = nonDapiChannels[i];
        chLabel = nonDapiLabels[i];

        maskTitle = processChannelInRegion(regionNum, regionDir, chNum, chLabel, minSize, logPath);
        maskTitles[i] = maskTitle;
    }

    // ---- Merged composites: pairwise + triple ----
    createMerges(regionNum, regionDir, nonDapiLabels, maskTitles, logPath);

    // Close any leftover mask windows for this region before moving on
    for (i = 0; i < nCh; i++) {
        if (isOpen(maskTitles[i])) {
            selectWindow(maskTitles[i]);
            close();
        }
    }
}


// ============================================================
// FUNCTION: processChannelInRegion
// Crops the given channel to the region ROI, runs the segmentation +
// particle analysis pipeline, and saves mask/ROI/CSV outputs.
// Returns the title of the resulting mask window ("Mask of <label>")
// ============================================================
function processChannelInRegion(regionNum, regionDir, chNum, chLabel, minSize, logPath) {

    selectWindow("IMG");
    Stack.setChannel(chNum);

    // Select the region ROI for this region
    roiManager("select", regionNum - 1);

    // Duplicate -> cropped single-channel image, renamed to chLabel
    run("Duplicate...", "title=" + chLabel + " duplicate channels=" + chNum);
    selectWindow(chLabel);

    // Segmentation pipeline (as previously agreed)
    run("Gaussian Blur...", "sigma=1");
    run("Auto Threshold", "method=Otsu ignore_black ignore_white white show stack");
    setOption("BlackBackground", false);

    // Particle analysis
    run("Set Measurements...", "area centroid redirect=None decimal=3");
    run("Analyze Particles...", "size=" + minSize + "-Infinity show=Masks display add");

    maskTitle = "Mask of " + chLabel;

    // ---- Save mask image ----
    if (isOpen(maskTitle)) {
        selectWindow(maskTitle);
        saveAs("Tiff", regionDir + chLabel + "_mask.tif");
        // saveAs renames the window to the new filename; rename back for consistency
        rename(maskTitle);
    }

    // ---- Save particle ROIs ----
    nParticleRois = roiManager("count");
    if (nParticleRois > 0) {
        // Save only the particle ROIs (all entries currently in manager
        // besides the region ROIs already saved earlier are particle ROIs
        // from this channel; save the full current set then reset)
        roiManager("deselect");
        roiManager("save", regionDir + chLabel + "_rois.zip");
    }

    // ---- Save particle CSV (Area, X, Y) ----
    nResults = nResults();
    if (nResults > 0) {
        saveAs("Results", regionDir + chLabel + "_particles.csv");
    }

    logMessage(logPath, "Region " + regionNum + " - Channel '" + chLabel + "': " + nResults + " particles detected.");

    // ---- Clear ROI manager of particle ROIs and results table for next channel ----
    // Remove all entries except the original region ROIs (indices 0..regionCount-1
    // are region ROIs; particle ROIs were appended after). We only know this
    // region's region-ROI index, so remove everything added after it.
    clearParticleRois(regionNum);
    run("Clear Results");

    // Close the duplicated/processed source image (chLabel window),
    // keep the mask window open (closed by caller after merges)
    if (isOpen(chLabel)) {
        selectWindow(chLabel);
        close();
    }

    return maskTitle;
}


// ============================================================
// FUNCTION: clearParticleRois
// Removes particle ROIs added by Analyze Particles, keeping only
// the region ROIs (indices 0 .. total region count - 1 at the start
// of the run). Since region ROIs occupy the first N slots and are
// never removed, we delete everything from index = numRegionRois
// onward each time.
// ============================================================
function clearParticleRois(regionNum) {
    total = roiManager("count");
    // Region ROIs occupy indices 0..(regionTotalCount-1). We need that
    // count; pass it via a workaround: store as a global-like macro variable.
    // Simplify: keep track using a fixed marker - regions were added first,
    // so numRegionRois = regionNum if we are mid-loop is not reliable across
    // all regions. Instead, we rely on the fact that all region ROIs are
    // added BEFORE any processing begins (see main loop), so total region
    // count is fixed and known as 'totalRegions' globally.
    if (total > totalRegions) {
        for (k = total - 1; k >= totalRegions; k--) {
            roiManager("select", k);
            roiManager("delete");
        }
    }
}


// ============================================================
// FUNCTION: createMerges
// Creates pairwise and triple merged mask composites for a region
// using "Merge Channels..." with create+keep, and saves each.
// ============================================================
function createMerges(regionNum, regionDir, labels, maskTitles, logPath) {

    A = labels[0]; B = labels[1]; C = labels[2];
    mA = maskTitles[0]; mB = maskTitles[1]; mC = maskTitles[2];

    // A+B
    run("Merge Channels...", "c1=[" + mA + "] c2=[" + mB + "] create keep");
    saveAs("Tiff", regionDir + "Merge_" + A + "_" + B + ".tif");
    close();

    // A+C
    run("Merge Channels...", "c1=[" + mA + "] c2=[" + mC + "] create keep");
    saveAs("Tiff", regionDir + "Merge_" + A + "_" + C + ".tif");
    close();

    // B+C
    run("Merge Channels...", "c1=[" + mB + "] c2=[" + mC + "] create keep");
    saveAs("Tiff", regionDir + "Merge_" + B + "_" + C + ".tif");
    close();

    // A+B+C
    run("Merge Channels...", "c1=[" + mA + "] c2=[" + mB + "] c3=[" + mC + "] create keep");
    saveAs("Tiff", regionDir + "Merge_" + A + "_" + B + "_" + C + ".tif");
    close();

    logMessage(logPath, "Region " + regionNum + " - merged composites saved (AB, AC, BC, ABC).");
}


// ============================================================
// FUNCTION: cleanupAll
// Closes all images, resets ROI manager, clears results/log windows
// ============================================================
function cleanupAll() {
    run("Close All");
    roiManager("reset");
    run("Clear Results");
    if (isOpen("Log")) {
        selectWindow("Log");
        run("Close");
    }
    if (isOpen("ROI Manager")) {
        selectWindow("ROI Manager");
        run("Close");
    }
}
