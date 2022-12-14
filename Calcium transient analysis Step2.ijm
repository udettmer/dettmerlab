//update May 2021  add calculation on peak correlation.

// updated March 2020
// 1. output ordered peak position
// 2. user choose start/end time point, and generate tiem between peaks

run("Set Measurements...", "area mean redirect=None decimal=5");

time2=getTime();

//assume the raw stack image is in raw folder, the ROI is in roi folder, with name of rawname_roi.zip

rawdir=getDirectory("User Select Raw Data Folder");
roidir=getDirectory("User Select ROI Data Folder");
resultdir=getDirectory("User Select Result Data Folder");
list=getFileList(rawdir);

// frame#
var frames, frame_interval, r, min_peak_Int=200;
// minimum peak range +/- 
var peak_t = 6, start_time=100, end_time=500;

// data to store 2D array  500 x 500  up to 500 ROIs and each roi up to 500 peaks
// roi # i and peak #j position (time value) stored in data[ i * 500 + j] 
var array_range = 500;
var data=newArray(250000), tmpdata=newArray(250000);
var count_index, total_dis;
var total_peakcount;
var min_peakcount;

parameterinput();

//varaibles. X/Y value all the peak position, intensity and guessed bg intensity level
var prominence=20, rollingball=30;
var PX=newArray(500), PY=newArray(500); BY=newArray(500);
var Intensity=newArray(20000);
var PeakCount=newArray(10000);

print("rawdir:	"+rawdir);
print("Filename	ROI#	Total_Peak#	Total_dis	Count_Dis_Count	Average_dis	STD_dis");
selectWindow("Log"); saveAs("Text", resultdir+"Sumamry.xls");
selectWindow("Log"); run("Close");

// for each raw data
for(f=0;f<list.length;f++)
 {
  // open raw data file, rename to "raw", open roi file
  run("Bio-Formats Importer", "open=["+rawdir+list[f]+"] color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
  rename("raw"); //run("Mean...", "radius=2");
  roiManager("Open", roidir+list[f]+"_roi.zip");

  // get frmae#
  getDimensions(width, height, channels, slices, frames); 
  if( end_time > frames ) end_time = frames;
  frame_interval = Stack.getFrameInterval(); 
  run("Properties...", "channels=1 slices="+frames+" frames=1 pixel_width=1 pixel_height=1 voxel_depth=1.0000 frame=[1 sec]");

  // for each ROI
  roi_count=roiManager("Count"); total_peakcount=0;
  for(r=0;r<roi_count;r++)
   {
    // create "new" image for peak identification
    newImage("new", "16-bit black", frames, 3, 1);
  	
    // get ROI profile image
    selectImage("raw"); roiManager("Select", r); run("Plot Z-axis Profile"); rename("profile_"+r+1);
  
    // get ROI intensity profile values, write to image "new"
    selectImage("raw"); roiManager("Select", r); roiManager("Multi Measure");
    selectImage("new");  
    for(i=0;i<frames;i++)
     {
      Intensity[i]=getResult("Mean1", i);
      setPixel(i,1,Intensity[i]);
     }
    selectWindow("Results"); run("Close");
    
    // create background image
    selectImage("new"); run("Duplicate...", "title=bg"); selectImage("bg"); run("Subtract Background...", "rolling="+rollingball+" create");
  
    // find peak position
    selectImage("new");  run("Find Maxima...", "prominence="+prominence+" exclude output=[Point Selection]");
    roiManager("Add"); selectImage("new");  roiManager("Select", roi_count); run("Measure");  
    PeakCount[r]=nResults; 
    for(i=0;i<PeakCount[r];i++)
     {
      PX[i]=getResult("X", i);
      PY[i]=getResult("Mean", i);	
      //print("i="+i+"  "+PX[i]+"   "+PY[i]);
     }  
    selectWindow("Results"); run("Close"); selectWindow("new"); close();
    selectImage("bg"); roiManager("Select", roi_count); run("Measure");
    for(i=0;i<PeakCount[r];i++)
      BY[i]=getResult("Mean", i);	
    selectWindow("Results"); run("Close"); selectWindow("bg"); close();
    roiManager("Select", roi_count); roiManager("Delete");

    // order by PX[i].  then remove any peak that is not maxium within the peak_t range.
    // bubble algorithm
    index=PeakCount[r]; flag=1;
    while( index > 0 && flag == 1  )
     {
      flag=0;	
      for(i=0;i<index; i++)
       {
        if( PX[i] > PX[i+1] )
         {
          flag=1; 
          tmp=PX[i]; PX[i]=PX[i+1]; PX[i+1]=tmp; 
          tmp=PY[i]; PY[i]=PY[i+1]; PY[i+1]=tmp; 
          tmp=BY[i]; BY[i]=BY[i+1]; BY[i+1]=tmp; 
         }
       }
      index--; 
     }

    //remove small peak, peak value has t obe at least the maxium +/- peak_t range
    peak_t = 6; 
    for(i=0; i< PeakCount[r]; i++)
     {
      flag=0; j0=maxOf(0, PX[i]-peak_t); j1=minOf(PX[i]+peak_t, frames-1); 
      for(j=j0; j<j1; j++)
       {
        if( PY[i] < Intensity[j] - 2 )
          { flag=1;
            //print("i="+i+"   PY[i]="+PY[i]+"    j="+j+"   Intensity[j]="+Intensity[j]);
          }
       }

      //remove small peak
      if( flag == 1 )
      {
       for(j=i;j<PeakCount[r];j++)
        {
         PX[j]=PX[j+1]; PY[j]=PY[j+1]; BY[j]=BY[j+1];
        }
       PeakCount[r]=PeakCount[r]-1; i=i-1; 
      }
     }
    
    // show on profile image and write to excel file
    print("File:	"+rawdir+list[f]+"	ROI#	"+r+1+"	MinPeakInt	"+min_peak_Int);
    print("Peak#	Peak_pos	Peak_Int	Bg_Int(F0)	Delta_F	Delta_F/F0	Time_gap(s)");
    selectWindow("profile_"+r+1); run("RGB Color"); run("Line Width...", "line=2"); run("Colors...", "foreground=green background=black selection=yellow");
    index=1;
    for(i=0;i<PeakCount[r];i++)
     {
      total_peakcount = total_peakcount + PeakCount[i];	
      x=PX[i]; y=PY[i];
      toUnscaled(x, y); 
      if( (PY[i] - BY[i]*3) >= min_peak_Int && PX[i] >= start_time && PX[i] <= end_time )
       { 
        drawRect(x, y, 5, 5);
        if( index==1 )
         {
         	print(index+"	"+PX[i]+"	"+PY[i]+"	"+BY[i]*3+"	"+PY[i]-BY[i]*3+"	"+(PY[i]-BY[i]*3)/BY[i]);
         	tmp = PX[i];
         	//store time value to data array
         	data[ r * array_range + i]=PX[i]; 
         }
        if( index>1 )
         {
         	print(index+"	"+PX[i]+"	"+PY[i]+"	"+BY[i]*3+"	"+PY[i]-BY[i]*3+"	"+(PY[i]-BY[i]*3)/BY[i]+"	"+(PX[i]-tmp)*frame_interval);
         	tmp = PX[i];
         	//store time value to data array
         	data[ r * array_range + i]=PX[i];
         }
         
        index++;
       }
     } 
    run("Colors...", "foreground=red background=black selection=yellow");
    for(i=0;i<PeakCount[r];i++)
     {
      x=PX[i]; y=BY[i]*3;
      toUnscaled(x, y);
      if( (PY[i] - BY[i]*3) >= min_peak_Int && PX[i] >= start_time && PX[i] <= end_time )
       {
        drawRect(x, y, 5, 5);
       }
     }

    // save Profile image
    selectImage("profile_"+r+1);
    saveAs("Jpeg", resultdir+list[f]+"_profile_"+r+1+".jpg"); close();
    selectWindow("Log");
    saveAs("Text", resultdir+list[f]+"_peak_"+r+1+".xls"); selectWindow("Log"); run("Close");
   } // for(r=0 ...
  run("Close All"); roiManager("reset"); run("Clear Results"); 

  //calculate peak correlation in this file.
  count_index=0; total_dis=0;

  // for each roi
  for(i=0; i<roi_count; i++)
   {
   	// for each peak in ith roi
   	for(p=0;p<PeakCount[i];p++)
   	 {
      // get (i,p) time value
      tmp1 = retrieve(i,p);
      // calculate smallest dis to each different roi
      for(j=0; j<roi_count;j++)
       {
       	// calculate on different roi
        if( j != i && PeakCount[j] >= min_peakcount )
         {
          tmpmin=9999999999;
          for(k=0;k<PeakCount[j];k++)
           {
            tmp2 = retrieve(j,k);
            tmpdis = abs(tmp1 - tmp2);
            if( tmpdis < tmpmin ) tmpmin=tmpdis;
           } //for(k=0;k<peakCount[j];k++)

          // add the smallest distance to total_dis and count_index
          total_dis=total_dis + tmpmin; tmpdata[count_index]=tmpmin;  count_index++;
         } //if( j != i )
       } //for(j=0; j<roi_count;j++)
   	 } //for(p=0;p<peakCount[i];p++)
   } //for(i=0; i<roi_count; i++)

  average_dis = total_dis / count_index;   std_dis=0;
  for(k=0;k<count_index;k++)
    std_dis = std_dis + (tmpdata[k]-average_dis) * (tmpdata[k]-average_dis);
  std_dis = sqrt(std_dis/count_index);  
  
  //print("Filename	ROI#	Total_dis	Count	Average_dis");
  str = list[f]+"	"+roi_count+"	"+total_peakcount+"	"+total_dis+"	"+count_index+"	"+average_dis+"	"+std_dis;
  File.append(str, resultdir+"Sumamry.xls");

 } // for(f=0 ....

print("Macro Finished!!!");
time1=getTime();
tmp=(time1-time2)/1000/60;
print("Time Processed (min):   "+tmp);

function parameterinput()
 {
  Dialog.create("parameter");
  Dialog.addNumber("Minimum Peak Range:", 6);
  Dialog.addNumber("Starting Time Point:", 1);
  Dialog.addNumber("Ending Time Point:", 480);
  Dialog.addNumber("Min peak#:", 5);
  Dialog.show();
  peak_t = Dialog.getNumber();
  start_time = Dialog.getNumber();
  end_time = Dialog.getNumber();
  min_peakcount = Dialog.getNumber();
 }

// retrieve time value of (i,j)  i is the order of ROI, j is the order of peak.
function retrieve(i,j)
 {
  tmp = array_range * i + j;
  return data[tmp];
 }
