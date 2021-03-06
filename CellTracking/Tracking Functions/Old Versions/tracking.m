clear;
close all;
clc;

% Ensures the path to necessary functions is available to the rest of the
% script
addpath(genpath('Tracking Functions'));
addpath(genpath('Kovesi Filters'));

%% Get Images and Metadata
disp('Creating Pre-Processed Images.')
experiment = Experiment;
% Scaling is the same in X and Y; convert from meters to microns
pixelSize = experiment.metadata.scalingX*1000000;
scaleFactor = (experiment.metadata.scalingX*1000000)/0.1625;
disp('Done.')
disp(scaleFactor)
disp(pixelSize)

%% Initial Image cropping (cannot be undone except by restarting script)
[experiment.images,experiment.fluorImg,experiment.cellImg,roiBounds1] = experiment.cropImgs;

%% Final Pre-processing Before Finding Local Maxima
clear roiCell;
[experiment.ppOptions,experiment.masks] = experiment.preprocess;
[roiImgs,roiMasks,roiCell,roiBounds,roiZeros,redoCheck] = experiment.cropImgs2;

while redoCheck == 1
    experiment = Experiment(experiment.images,experiment.cellImg,experiment.fluorImg,experiment.metadata);
    [experiment.ppOptions,experiment.masks] = experiment.preprocess;
    pixelSize = experiment.metadata.scalingX*1000000;
    scaleFactor = (experiment.metadata.scalingX*1000000)/0.165;
    disp('Scale Factor:')
    disp(scaleFactor)
    [roiImgs,roiMasks,roiCell,roiBounds,roiZeros,redoCheck] = experiment.cropImgs2;
end


% Create a gaussian filtered version of original to decrease false local
% maxima
ppImagesGauss = double(imgaussfilt(roiImgs,1.75));

% Multiply the gaussian image by the mask image to isolate regions of
% interest
ppImagesGaussMask = roiMasks.*ppImagesGauss;

%%
ppImagesMask = roiMasks.*double(roiImgs);
%%
for i = 1:size(roiMasks,3)
    temp = roiMasks(:,:,i);
    low = mean(mean(temp(temp>0)));
    
    high = max(max(roiMasks(:,:,i)));
    temp(temp>0) = high*(1);
    temp = (temp/high)*(i^2/size(roiMasks,3)^2);
    
roiMasks2(:,:,i) = temp;
end
maxMasks = permute(max(permute(roiMasks2,[3 1 2])),[2 3 1]);
pillarView = figure;
imshow(maxMasks,[])
filePath = cd;
savefile = [filePath '\Tracking_pillarView.tif'];
export_fig(pillarView,savefile,'-native');
%% A mean filter for an image stack (resulting data may or may not be used in trajectories.m)
h = fspecial('average', [5,5]);
roiImgsMeanFilt = roiImgs;
for i = 1:size(roiImgs,3)
    roiImgsMeanFilt(:,:,i) = filter2(h, roiImgs(:,:,i));
end

%% subpixmax using Kilfoil Object detection 'feature2D'
clear subpixMaxima
for i = 1:size(roiImgs,3)
    clear temp
    currentImg = roiMasks(:,:,i);
temp = feature2D(currentImg,1,round((experiment.ppOptions{2})/pixelSize),0,1);

if temp == -1
else
subpixMaxima(1:size(temp,1),1,i) = temp(:,1);
subpixMaxima(1:size(temp,1),2,i) = temp(:,2);
subpixMaxima(1:size(temp,1),3,i) = i;
end
end

%% Object Detection Plot
detections = figure;
imshow(roiZeros)
hold on
for i = 1:size(subpixMaxima,3) %size(subpixMaxima,3)-10
    scatter3(subpixMaxima(:,1,i),subpixMaxima(:,2,i),subpixMaxima(:,3,i),'.')
end
hold off

filePath = cd;
savefile = [filePath '\Tracking_Unlinked Detections.tif'];
export_fig(detections,savefile,'-native');
%%
% Linking objects to pillars
% The plan is to create several metrics for determining whether a local 2D
% maxima belongs to a 'pillar' group of maxima by comparing the xy distance
% between the object of interest and the nearest neighbors on frames before
% and after.

disp('Linking Dots Between Frames.')
% Set a maximum linking distance in microns that any object can still be
% considered part of a pillar. Smaller values will speed up code.
maxLinkDistance = 1.8;
maxLD = maxLinkDistance/pixelSize;
disp(['Max Link Distance (Microns): ',num2str(maxLinkDistance)])
% Set a maximum number of frames to look for a linked object before giving
% up (maxJumpDistance)
maxJD = 3;
disp(['Max Jump Distance (Frames): ',num2str(maxJD)])

% The LinkMaxima function checks for the closest match for an object in
% later frames. Maxima with multiple matches favor pillars with a greater
% number of constituents

[subpixMaxima2,noPillars] = LinkMaxima(subpixMaxima,maxLD,maxJD);
%[subpixMaxima2,noPillars,nunBook] = LinkMaxima2(subpixMaxima,maxLD,maxJD);
% Binning Pillars Based on Location

%Rationale: The following section links objects between frames based on
%proximity. One of the steps is a lookup of potential candidates for making
%a match. That lookup gets exponentially longer the larger an image stack
%is. This section should reduce computational time for any given image.

% ********WIP******************

%
% Creating Pillar Book for Easy Export
clear pBook tempInd1 tempInd2
disp('Sorting Linked Dots.')
pBSkip = 0; %Counts the number of skipped Pillars
pBSkipCheck = 0; %Toggles when a pillar is skipped
pBook = zeros(size(ppImagesGauss,3),5,noPillars);
for i = 1:noPillars
    if i == 1000 || i == 5000 || i == 10000 || i == 15000 || i == 20000
        disp(strcat('Sorted ',num2str(i),' of ', num2str(noPillars)))
    end
    %Find indices of members of current pillar
    [tempInd1,tempInd2] = find(subpixMaxima2(:,6,:)==i);
    %If the pillar is longer than threshold pillar size
    if size(tempInd1,1) > round(size(roiImgs,3)/4)
        %Then for every member of the pillar
        for j = 1:size(tempInd1,1)
            pBook(j,1,i-pBSkip) = subpixMaxima2(tempInd1(j,1),1,tempInd2(j,1)); %record X
            pBook(j,2,i-pBSkip) = subpixMaxima2(tempInd1(j,1),2,tempInd2(j,1)); %record Y
            pBook(j,3,i-pBSkip) = subpixMaxima2(tempInd1(j,1),3,tempInd2(j,1)); %record Z
            pBook(j,4,i-pBSkip) = i-pBSkip; %record new pillar number
            
            %if an intensity values is available, record it
            if round(pBook(j,1,i-pBSkip)) > 0 && round(pBook(j,2,i-pBSkip))>0 && round(pBook(j,3,i-pBSkip))>0
                pBook(j,5,i-pBSkip) = roiImgs(round(pBook(j,2,i-pBSkip)),round(pBook(j,1,i-pBSkip)),pBook(j,3,i-pBSkip)); %Intensity value from roiImgs
                pBook(j,6,i-pBSkip) = ppImagesGauss(round(pBook(j,2,i-pBSkip)),round(pBook(j,1,i-pBSkip)),pBook(j,3,i-pBSkip)); %Intensity value from ppImagesGauss
                pBook(j,7,i-pBSkip) = roiImgsMeanFilt(round(pBook(j,2,i-pBSkip)),round(pBook(j,1,i-pBSkip)),pBook(j,3,i-pBSkip)); %Intensity value from ppImagesGauss
            else
                %otherwise set intensity to zero
                pBook(j,5,i-pBSkip) = 0;
            end
        end
    else
        %If not larger than threshold, toggle pillar skip check
        pBSkipCheck = 1;
    end
    %If Skip Check is On, increment Pillar Skip and Toggle Off
    if pBSkipCheck == 1
        pBSkip=pBSkip+1;
        pBSkipCheck = 0;
    end
end

%Truncate PBook
pBookFinal = pBook(:,:,1:(noPillars-(pBSkip)));

%
%2D Plot of points color coded by pillar and connected
disp('Plotting Linked Paths.')
detections2 = figure;
imshow(maxMasks)
hold on
clear tempInd1 tempInd2
for j = 1:size(pBookFinal,3)
    clear tempPillar
    tempInd1 = find(pBookFinal(:,1,j),1,'first');
    tempInd2 = find(pBookFinal(:,1,j),1,'last');
    tempPillar = pBookFinal(tempInd1:tempInd2,:,j);
    plot3(tempPillar(:,1),tempPillar(:,2),tempPillar(:,3))
end
%
disp('Plotting Linked Paths.')
detections3 = figure;
imshow(roiZeros)
hold on
clear tempInd1 tempInd2
for j = 1:size(pBookFinal,3)
    clear tempPillar
    tempInd1 = find(pBookFinal(:,1,j),1,'first');
    tempInd2 = find(pBookFinal(:,1,j),1,'last');
    tempPillar = pBookFinal(tempInd1:tempInd2,:,j);
    plot3(tempPillar(:,1),tempPillar(:,2),tempPillar(:,3))
end
% Detections and Links
detectionsAndLinks = figure;
imshow(roiZeros)
hold on
for i = 1:size(subpixMaxima,3) %size(subpixMaxima,3)-10
    scatter3(subpixMaxima(:,1,i),subpixMaxima(:,2,i),subpixMaxima(:,3,i),'.')
end
clear tempInd1 tempInd2
for j = 1:size(pBookFinal,3)
    clear tempPillar
    tempInd1 = find(pBookFinal(:,1,j),1,'first');
    tempInd2 = find(pBookFinal(:,1,j),1,'last');
    tempPillar = pBookFinal(tempInd1:tempInd2,:,j);
    plot3(tempPillar(:,1),tempPillar(:,2),tempPillar(:,3))
end
hold off

%%
hold off
savefile = [filePath '\Tracking_Linked Detections on pillarView.tif'];
export_fig(detections2,savefile,'-native');


savefile = [filePath '\Tracking_Linked Detections on Black.tif'];
export_fig(detections3,savefile,'-native');

%%
disp('Creating Text File for trajectories.m.')
createTxtForTrajectories(pBookFinal);
parametersObj{1} = experiment.ppOptions;
parametersObj{2} = maxLinkDistance;
parametersObj{3} = maxJD;
parametersObj{4} = pixelSize;
parametersObj{5} = scaleFactor;

paraTxt = fopen('parameters.txt','wt');
fprintf(paraTxt,strcat('Original File Name: ', experiment.metadata.filename, '\n'));    
p1Format = 'Remove Large?';
    if ismember(2,parametersObj{1,1}{1,1})==1
    fprintf(paraTxt,p1Format);
    fprintf(paraTxt,' yes \n');
    p1Format = 'Remove Large Size(microns squared): %d \n';
    fprintf(paraTxt,p1Format,parametersObj{1,1}{1,4});
    else
        fprintf(paraTxt,p1Format);
        fprintf(paraTxt,' no \n');
    end
    
    p1Format = 'Approximate Feature Diameter: %0.2f \n';
    fprintf(paraTxt,p1Format,parametersObj{1,1}{1,2});
    
    p1Format = 'Threshold After DoG: %d \n';
    fprintf(paraTxt,p1Format,parametersObj{1,1}{1,3});
    
    p1Format = 'Subtract 95pct Last Frame?';
    if ismember(1,parametersObj{1,1}{1,1})==1
    fprintf(paraTxt,p1Format);
    fprintf(paraTxt,' yes \n');
    else
    fprintf(paraTxt,p1Format);
    fprintf(paraTxt,' no \n');
    end


    
    p1Format = 'Max Link Distance: %0.2f \n';
    fprintf(paraTxt,p1Format,parametersObj{2});
    
    p1Format = 'Max Jump Distance: %i \n';
    fprintf(paraTxt,p1Format,parametersObj{3});
    
    p1Format = 'Pixel Size: %f \n';
    fprintf(paraTxt,p1Format,parametersObj{4}); 
        
    p1Format = 'Scale Factor: %f \n';
    fprintf(paraTxt,p1Format,parametersObj{5});
    
    fclose(paraTxt);

%% Older 2D maxima approach using Kovessi subpix2D
% %% 2D maxima approach
% % Taking a break from working with 3D maxima because too many data points
% % are lost in the process, and it is seeming like it will not be a good way
% % to eventually identify ellipsoids and their strain/displacement. Will now
% % attempt to create ellipsoids by identifying all local 2D maxima belonging
% % to a single pillar, and tracing the the major axis of individual
% % ellipsoids through local maxima.
% clear maxR maxC maxS maxSubR maxSubC subpixMaxima tempInd1 tempInd2 products maxIndices
% close all
% disp('Finding Dots.')
% % Find local maxima in 2D (pixel resolution)
% ppImagesMaxima = zeros(size(ppImagesGaussMask));
% for i = 1:size(roiImgs,3)
%     maxCurrent = imregionalmax(ppImagesGaussMask(:,:,i));
%     % In the event that a frame is empty, the local maxima are the entire
%     % image (0's), this if statement removes these maxima.
%     if maxCurrent == ones(size(maxCurrent,1),size(maxCurrent,2))
%         maxCurrent = zeros(size(maxCurrent,1),size(maxCurrent,2));
%     end
%     ppImagesMaxima(:,:,i) = maxCurrent;
% end
% [maxY,maxX,maxZ] = ind2sub(size(ppImagesMaxima),find(ppImagesMaxima == 1));
% 
% 
% % Separate maxima by z (frame) and determine indices in maxR, maxC, maxS
% for i = 1:size(roiImgs,3)
%     if min(find(maxZ == i)) > 0
%         maxIndices(i,1) = min(find(maxZ == i));
%         maxIndices(i,2) = max(find(maxZ == i));
%         maxIndices(i,3) = maxIndices(i,2) - maxIndices(i,1);
%     end
% end
% 
% % Use indices to create book of subpixel maxima for use later in linking
% % maxima to pillars
% %subpixMaxima = zeros(max(maxIndices(:,3)),3,size(roiImgs,3));
% for i = 1:size(roiImgs,3)
%     if min(find(maxZ == i)) > 0
%         clear tempXY tempXY2
%         
%         %find subpixel maxima and store them to a single matrix
%         [maxSubY,maxSubX] = subpix2d(maxY(maxIndices(i,1):maxIndices(i,2)),maxX(maxIndices(i,1):maxIndices(i,2)),double(ppImagesGauss(:,:,i)));
%         tempXY(:,1) = maxSubX;
%         tempXY(:,2) = maxSubY;
%         
%         %remove data that is out of bounds (due to errors in subpix2d
%         %-greater than x image size
%         [tempInd1, ~] = find(tempXY(:,1) > size(ppImagesGaussMask,2));
%         tempXY(tempInd1,1:2) = 0;
%         %-greater than y image size
%         [tempInd1, ~] = find(tempXY(:,2) > size(ppImagesGaussMask,1));
%         tempXY(tempInd1,1:2) = 0;
%         %-smaller than 0 in x
%         [tempInd1, ~] = find(tempXY(:,1) < 0);
%         tempXY(tempInd1,1:2) = 0;
%         %-smaller than 0 in y
%         [tempInd1, ~] = find(tempXY(:,2) < 0);
%         tempXY(tempInd1,1:2) = 0;
%         
%         %remove duplicate points after rounding to the nearest half pixel
%         %Note! The rounding really helps remove duplicate points caused by
%         %subpix2D!!!
%         [tempXY2,~,~] = unique(5*round((tempXY/5),1),'rows');
%         
%         
%         %store filtered points in subpixMaxima
%         subpixMaxima(1:size(tempXY2,1),1,i) = tempXY2(:,1);
%         subpixMaxima(1:size(tempXY2,1),2,i) = tempXY2(:,2);
%         subpixMaxima(1:size(tempXY2,1),3,i) = i;
%         
%         %subpixMaxima(1:size(maxSubY,2),1,i) = maxSubX(1,:);
%         %subpixMaxima(1:size(maxSubY,2),2,i) = maxSubY(1,:);
%         %subpixMaxima(1:size(maxSubY,2),3,i) = i;
%     end
% end
%
% % %Clear out-of-bounds results from subpix2d
% % 
% % %-greater than x image size
% % [tempInd1, tempInd2] = find(subpixMaxima(:,1,:) > size(ppImagesGaussMask,2));
% % subpixMaxima(tempInd1,1:3,tempInd2) = 0;
% % %-greater than y image size
% % [tempInd1, tempInd2] = find(subpixMaxima(:,2,:) > size(ppImagesGaussMask,1));
% % subpixMaxima(tempInd1,1:3,tempInd2) = 0;
% % %-smaller than 0 in x
% % [tempInd1, tempInd2] = find(subpixMaxima(:,1,:) < 0);
% % subpixMaxima(tempInd1,1:3,tempInd2) = 0;
% % %-smaller than 0 in y
% % [tempInd1, tempInd2] = find(subpixMaxima(:,2,:) < 0);
% % subpixMaxima(tempInd1,1:3,tempInd2) = 0;

% Viewing 2D pixel/subpixel maxima
%
% close all
% %view pixel resolution maxima
% figure
% scatter3(maxR,maxC,maxS,'.')
%
% %view subpixel resolution maxima
% figure
% for i = 1:size(roiImgs,3)
%     if min(find(maxS == i)) > 0
%         scatter3(subpixMaxima(:,1,i),subpixMaxima(:,2,i),subpixMaxima(:,3,i),'.')
%         hold on
%     end
% end
    
    %% 3D Scatterplot of points color coded by pillar
% figure
% hold on
% for j = 1:size(pBook,3)
%     scatter3(pBook(:,1,j),pBook(:,2,j),pBook(:,3,j),'.')
% end
% hold off

%% Kovesi's function subpix3d
%
% % Find local maxima in 3D (pixel resolution)
% localMaxima3D = imregionalmax(ppImages8);
%
% % Obtain vectors with coordinates for x,y,z positions of local maxima with
% % pixel resolution
% [maxR,maxC,maxS] = ind2sub(size(localMaxima3D),find(localMaxima3D == 1));
%
% % Find subpixel maxima based on initial guesses from imregionalmax on the
% % original images
% [maxSubR,maxSubC,ssM] = subpix3d(maxR,maxC,maxS,cropImages2);
%
% % 3D plot subpixel local maxima
% figure
% scatter3(maxSubR,maxSubC,ssM,'.')

%% Dividing maxima by plane
% %Find the center of each z plane of dots based on histogram of local 3D
% %maxima
% [~,zCenters] = find(imregionalmax(imgaussfilt(histcounts(maxS,size(roiImgs,3)),3)));
%
% % Find the spacing (# of frames) between each plane
% zSpacing = zeros(1,size(zCenters,2)-1);
% for i = 1:(size(zCenters,2)-1)
%     zSpacing(1,i) = zCenters(1,i+1)-zCenters(1,i);
% end
%
% % Choose a 'tail' size around plane centers for associating local maxima
% % above and below the plane of interest.
% zTails = round((mean(zSpacing(1,:)))/4);
%
% % Assign local maxima to planes
% zPlaneIndices = zeros(size(zCenters,2),2);
% for i = 1:size(zCenters,2)
%     zPlaneIndices(i,1) = min(find(maxS>(zCenters(1,i)-zTails)));
%     zPlaneIndices(i,2) = max(find(maxS<(zCenters(1,i)+zTails)));
%     zPlaneIndices(i,3) = zPlaneIndices(i,2)-zPlaneIndices(i,1);
% end
%
% zSortedMaxima = zeros(max(zPlaneIndices(:,3)),3,size(zCenters,2));
% for i = 1:size(zCenters,2)
%     zSortedMaxima(1:zPlaneIndices(i,3)+1,1,i) = maxR(zPlaneIndices(i,1):zPlaneIndices(i,2),1);
%     zSortedMaxima(1:zPlaneIndices(i,3)+1,2,i) = maxC(zPlaneIndices(i,1):zPlaneIndices(i,2),1);
%     zSortedMaxima(1:zPlaneIndices(i,3)+1,3,i) = maxS(zPlaneIndices(i,1):zPlaneIndices(i,2),1);
% end
%
% zSortedMaximaFixed = zSortedMaxima;
% for i = 1:size(zCenters,2)
%     temp = zeros(zPlaneIndices(i,3),3);
%     temp(1:zPlaneIndices(i,3),:) = zSortedMaxima(1:zPlaneIndices(i,3),:,i);
%     fitobject{i} = fit([temp(:,1),temp(:,2)],temp(:,3),'poly11');
%     plot(fitobject{i},[temp(:,1),temp(:,2)],temp(:,3))
%     zSortedMaximaFixed(:,3,i) = fitobject{i}(zSortedMaximaFixed(:,1,i),zSortedMaximaFixed(:,1,i));
%     hold on
% end
% hold off
%
%% Predict New Local 3D maxima by Plane
%
% for i = 1:size(zCenters,2)
%     temp = zeros(zPlaneIndices(i,3),3);
%     temp(1:zPlaneIndices(i,3),:) = zSortedMaximaFixed(1:zPlaneIndices(i,3),:,i);
%     plot(fitobject{i},[temp(:,1),temp(:,2)],temp(:,3))
%     hold on
% end
% hold off
%
%%
% % Find subpixel maxima based on initial guesses from plane fits on the
% % original images
% zSortedMaximaFixedSubpix = zeros(size(zSortedMaximaFixed,1),3,size(zCenters,2));
% for i = 1:size(zCenters,2)
% [rsM2,csM2,ssM2] = subpix3d(zSortedMaximaFixed(:,1,i),zSortedMaximaFixed(:,2,i),round(zSortedMaximaFixed(:,3,i)),cropImages2);
% zSortedMaximaFixedSubpix(1:size(rsM2,2),1,i) = rsM2;
% zSortedMaximaFixedSubpix(1:size(rsM2,2),2,i) = csM2;
% zSortedMaximaFixedSubpix(1:size(rsM2,2),3,i) = ssM2;
% end
%
% for i = 1:size(zCenters,2)
%     plot(fitobject{i},[zSortedMaximaFixedSubpix(:,1,i),zSortedMaximaFixedSubpix(:,2,i)],zSortedMaximaFixedSubpix(:,3,i))
%     hold on
% end
% hold off
% figure
% for i = 1:size(zCenters,2)
% scatter3(zSortedMaximaFixedSubpix(:,1,i),zSortedMaximaFixedSubpix(:,2,i),zSortedMaximaFixedSubpix(:,3,i),'.')
% hold on
% end
% hold off

%%
disp('tracking.m is completed.')