%%Load Detector
load('stereoParamsDev2.mat');
vehDetector=vision.CascadeObjectDetector(...
    'CarTraindata.xml','MergeThreshold',8,'UseROI',true);
pplDetector=vision.PeopleDetector('ClassificationModel',...
    'UprightPeople_96x48','ClassificationThreshold',3,'UseROI',true);

ROI=[1,200,640,280];

%%Read videos
leftVid=vision.VideoFileReader('adas_Dev_left.avi');
rightVid=vision.VideoFileReader('adas_Dev_right.avi');

%%Step Through Video
figure
framecount=1;
table = cell(200,5);
tic
while ~isDone(leftVid)
    
    leftframe=step(leftVid);
    rightframe=step(rightVid);
%     framecount=framecount+1;
    %%Detection
    bbox=step(vehDetector,leftframe,ROI);
    pbbox=step(pplDetector,leftframe,ROI);
%imshow(dispFrame);
%%Rectify Images (takes two images and get them aligned)
[J1,J2]=rectifyStereoImages(leftframe,...
    rightframe,stereoParamsDev2); 
%Align two images and tells the disparity of two cameras, prepare for 
%further video shooting

%%Generate A Disparity Map
grayLeft=rgb2gray(J1);
grayRight=rgb2gray(J2);
disparityRange=[0 64];
disparityMap=disparity(grayLeft,grayRight,...
    'DisparityRange',disparityRange);
%Generate A Point Cloud
min(disparityMap(:));
%%Find Centroid
max(disparityMap(:));
colormap('jet');
points3D=reconstructScene(disparityMap,stereoParamsDev2);
thresholds=[-5000 5000;0 2000;0 15000]; %thresholds for 3 dimensions
ptCloud=thresholdPC(points3D,thresholds);

vehcentroids=[round(bbox(:,1)+bbox(:,3)/2),...
    round(bbox(:,2)+bbox(:,4)/2)];
pplcentroids=[round(pbbox(:,1)+pbbox(:,3)/2),...
    round(pbbox(:,2)+pbbox(:,4)/2)];
a = size(disparityMap);
b = size(disparityMap);
if max(vehcentroids(:,1))>a(2)
    continue
end
if max(pplcentroids(:,1))>a(2)
    continue
end

vehcentroidsIdx=sub2ind(size(disparityMap),...
    vehcentroids(:,2),vehcentroids(:,1));
pplcentroidsIdx=sub2ind(size(disparityMap),...
    pplcentroids(:,2),pplcentroids(:,1));

%% EXtract Distance
X=points3D(:,:,1);
Y=points3D(:,:,2);
Z=points3D(:,:,3);
vehcentroids3D=[X(vehcentroidsIdx)';Y(vehcentroidsIdx)';Z(vehcentroidsIdx)'];
X=points3D(:,:,1);
Y=points3D(:,:,2);
Z=points3D(:,:,3);
pplcentroids3D=[X(pplcentroidsIdx)';Y(pplcentroidsIdx)';Z(pplcentroidsIdx)'];
vehdists=sqrt(sum(vehcentroids3D.^2));
ppldists=sqrt(sum(pplcentroids3D.^2));
vehdistMeters=vehdists/1000;
ppldistMeters=ppldists/1000;
%distInMeters=join(num2str(distMeters),m);
dispFrame=leftframe;
if ~isempty(bbox)
    labelsVeh = cell(1, numel(vehdistMeters));
    for i = 1:numel(vehdistMeters)
        labelsVeh{i} = sprintf('%0.2f meters', vehdistMeters(i));
    end
    dispFrame = insertObjectAnnotation(dispFrame, 'rectangle', bbox, labelsVeh,...
        'color','green');
end
if ~isempty(pbbox)
    labelsPpl = cell(1, numel(ppldistMeters));
    for i = 1:numel(ppldistMeters)
        labelsPpl{i} = sprintf('%0.2f meters', ppldistMeters(i));
    end
    dispFrame = insertObjectAnnotation(dispFrame, 'rectangle', pbbox, labelsPpl,...
   'color','blue');
end

% % stopwatch=stopwatch+toc;
% timeRecord{framecount}=toc;
imshow(dispFrame)
framecount=framecount+1;

table{framecount,1}=toc;
table{framecount,2}=numel(vehdistMeters);
table{framecount,3}=vehdistMeters;
table{framecount,4}=numel(ppldistMeters);
table{framecount,5}=ppldistMeters;
end
%% .csv file output
table{1,1}='time';
table{1,2}='#veh';
table{1,3}='vehdist';
table{1,4}='#ped';
table{1,5}='peddist';
table;
filename='adas_data.xlsx';
sheet=1;
xlRange='A1';
xlswrite(filename,table,sheet,xlRange)