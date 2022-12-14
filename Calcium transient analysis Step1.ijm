run("Colors...", "foreground=white background=black selection=yellow");
run("Options...", "iterations=1 count=1 black do=Nothing");

rawdir=getDirectory("User Select Raw Data Folder");
resultdir=getDirectory("User Select Result Data Folder");
list=getFileList(rawdir);

// for each raw data
for(f=0;f<list.length;f++)
 {
  // open raw data file, rename to "raw", open roi file
  run("Bio-Formats Importer", "open=["+rawdir+list[f]+"] color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
  rename("raw"); run("Mean...", "radius=2");
 
  run("Z Project...", "projection=[Standard Deviation]");
  setAutoThreshold("Triangle dark");
  setOption("BlackBackground", true);
  run("Convert to Mask");
  run("Fill Holes");
  run("Watershed");
  run("Open");
  run("Analyze Particles...", "size=30-Infinity pixel circularity=0.00-1.00 exclude clear add");

  roiManager("Save", resultdir+list[f]+"_roi.zip");
  run("Close All"); roiManager("reset"); run("Clear Results");
 }

 print("MACRO FINISHED!!!");