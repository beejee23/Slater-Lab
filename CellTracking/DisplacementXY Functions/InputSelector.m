function [data,dataKey] = InputSelector(auto)
simple = 1;
if simple ==1
    choice = 'Custom Code';
    dataKey(1,1) = 2; %xCol
    dataKey(2,1) = 3; %yCol
    dataKey(3,1) = 4; %fCol
    dataKey(4,1) = 5; %tCol
    dataKey(5,1) = 7; %intCol
    dataKey(6,1) = 6; %totalCol
    if auto == 1
        w = 'Yes';
    else
    w = questdlg('Use a scalefactor of 1?',...
    'Scaling from tracking','Yes','No','Yes');
    waitfor(w);
    end
    if strcmp(w,'Yes') == 1
    dataKey(7,1) = 1;
    else
    prompt = 'What was the scale factor print out of tracking.m? Check the command window. Enter a decimal and press enter: ';
    dataKey(7,1) = input(prompt); %pixelScale
    end
    
    dataKey(8,1) = 0; %startVar
    dataKey(9,1) = .1625 * dataKey(7,1);
    dataKey(10,1) = 0.4;
    
    %Open trajectories.txt
    files = dir('*.txt'); %Check Directory for default filenames
    for k = 1:length(files)
        current=files(k).name;
        if length(current)>=21
            check(k)=strcmp(current(end-20:end),'trajectoriesInput.txt');
        end
    end
    loc=find(check);
    if size(loc,1)==1
        data = dlmread(files(loc(1)).name);
    else
        [name,path] = uigetfile('*.txt','Select .txt File From Particle Tracker Output');
        file = [path,name];
        data = dlmread(file);
        
    end
else
d = dialog('Position',[300 300 250 150],'Name','Select One');
txt = uicontrol('Parent',d,...
    'Style','text',...
    'Position',[20 80 210 40],...
    'String','Select an input format (.xlsx)');

popup = uicontrol('Parent',d,...
    'Style','popup',...
    'Position',[75 70 100 25],...
    'String',{'Custom Code';'TrackMate';'Mosaic'},...
    'Callback',@popup_callback);

btn = uicontrol('Parent',d,...
    'Position',[89 20 70 25],...
    'String','Close',...
    'Callback','delete(gcf)');


drawnow;
uicontrol(btn)

choice = 'Custom Code';

% Wait for d to close before running to completion
uiwait(d);
end

    function popup_callback(popup,callbackdata)
        idx = popup.Value;
        popup_items = popup.String;
        % This code uses dot notation to get properties.
        % Dot notation runs in R2014b and later.
        % For R2014a and earlier:
        % idx = get(popup,'Value');
        % popup_items = get(popup,'String');
        choice = char(popup_items(idx,:));
    end

if strcmp(choice,'Mosaic') == 1 && simple ~=1
    dataKey(1,1) = 4; %xCol = 4;
    dataKey(2,1) = 5; %yCol = 5;
    dataKey(3,1) = 3; %fCol = 3;
    dataKey(4,1) = 2; %tCol = 2;
    dataKey(6,1) = 12; %totalCol = 12;
    dataKey(7,1) = 1; %pixelScale = 1;
    
    [name,path] = uigetfile('*.xlsx','Select .xlsx File From Particle Tracker Output');
    file = [path,name];
    [data,~,~] = xlsread(file);
    
elseif strcmp(choice,'TrackMate') == 1 && simple ~=1
    dataKey(1,1) = 6; %xCol
    dataKey(2,1) = 7; %yCol
    dataKey(3,1) = 10; %fCol
    dataKey(4,1) = 4; %tCol
    dataKey(5,1) = 14; %intCol
    dataKey(6,1) = 22; %totalCol
    prompt = 'How many pixels per micron? Enter a decimal and press enter: ';
    dataKey(7,1) = input(prompt);
    dataKey(8,1) = 1;
    
    [name,path] = uigetfile('*.xlsx','Select .xlsx File From Particle Tracker Output');
    file = [path,name];
    [data,~,~] = xlsread(file);
    
elseif strcmp(choice,'Custom Code') == 1 && simple ~=1
    
    dataKey(1,1) = 2; %xCol
    dataKey(2,1) = 3; %yCol
    dataKey(3,1) = 4; %fCol
    dataKey(4,1) = 5; %tCol
    dataKey(5,1) = 7; %intCol
    dataKey(6,1) = 6; %totalCol
    prompt = 'What was the scale factor print out of tracking.m? Check the command window. Enter a decimal and press enter: ';
    dataKey(7,1) = input(prompt); %pixelScale
    dataKey(8,1) = 0; %startVar
    dataKey(9,1) = .165 * dataKey(7,1);
    
    %Open trajectories.txt
    files = dir('*.txt'); %Check Directory for default filenames
    for k = 1:length(files)
        current=files(k).name;
        if length(current)>=21
            check(k)=strcmp(current(end-20:end),'trajectoriesInput.txt');
        end
    end
    loc=find(check);
    if size(loc,1)==1
        data = dlmread(files(loc(1)).name);
    else
        [name,path] = uigetfile('*.txt','Select .txt File From Particle Tracker Output');
        file = [path,name];
        data = dlmread(file);
    end
end

end