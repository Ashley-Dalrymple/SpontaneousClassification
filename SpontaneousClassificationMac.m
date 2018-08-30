% This function creates a user interface that will display spontaneous
% activity data. It has options to visualize the data in multiple ways,
% extract features from the data, and classify the episodes of activity
% using multilayer perceptrons. 
% Last modified: Aug. 30, 2018 by Ashley Dalrymple and Patrick Whelan

function SpontaneousClassificationMac
close all
global DetrendData
global FiltSett
global SepSett
global detect
global patches
global filename
% set before load in case over-written
DataChan = 1; 
SepSett = [];
FiltSett{DataChan} = [];    
detect = [];
patches = [];

    [FileName,~,~] = uigetfile; %User selects file and GUI gets the file name and the path to the file            
    [~,filename,extension] = fileparts(FileName);
    if extension == '.abf'
        % differentiate between single recording and episodic recording
        [Data, SampleInterval, Header] = abfload(FileName); %converts binary file to a matrix of data as well as a header file
        % if waveform fixed-length mode (serial episodic recording)
        StaticData = Data; %Copy of data that will not be altered from filtering ect.
        if ~isempty(Data(:,:,1)) % if data has a third dimension
            % concatenate all series of Data recordings (3D) into one recording (2D)
            datahold = [];
            for i = 1:size(Data,3) % for the number of serial recordings 
                datahold = [datahold;Data(:,:,i)];
                [DataLength, DataChannels] = size(datahold);
            end
            Data = datahold;
        else
            DataLength = Header.dataPtsPerChan; %Number of datapoint in each channel of data
            DataChannels = Header.nADCNumChannels; %Number of channels
        end
    elseif extension == '.mat'
        load(FileName) 
        [DataLength,DataChannels] = size(Data);
        if length(detect) > DataChannels % for split files
            detecthold = detect{DataChan}; % get new DataChan from loaded file
            detect = [];
            detect{DataChan} = detecthold; % only keep relevant channel's detected episodes
             filthold = FiltSett{DataChan};
            FiltSett = [];
            FiltSett{DataChan} = filthold;
            setthold = SepSett{DataChan};
            SepSett = [];
            SepSett{DataChan} = setthold;
        end
        if ~isempty(detect)
            ChansData = [];
                for i = 1:length(detect)
                    if ~isempty(detect{i})
                        ChansData = [ChansData,i]; % finds channels that had features extracted
                    end
                end
            DataChan = ChansData(1); % for display of plot label
        end
    end

    %Variables
    SampleFrequency = 1/(Header.nADCNumChannels*Header.fADCSampleInterval*10^-6);                                   
    MaxTime = DataLength/SampleFrequency;                               %Duration of data
    PlotDomain = (0+MaxTime/DataLength:MaxTime/DataLength:MaxTime);     %Creates a time point for each point of data
    PlotSpacing = 1;                                                    %lowers the number of points the GUI plots
    yLimits = zeros(DataChannels,2);                                    %the current min and max y value of each subplot
    xLimits = [0, MaxTime];                                             %min and max domain of the plots
    xRange = MaxTime;                                                   %Time shown of the plots
    RedCursorLocation = xRange*0.1;                                     %default location of the red cursor
    GreenCursorLocation = xRange*0.2;                                   %default location of the green cursor
    handles = struct;                                                   %make handles to objects in GUI global
    
    GUIBuilder                                                          %call the function that builds each component (window, pushbuttons, graph, ect) of the 
                                                                        %GUI along with their corresponding functions                                                   
    PlotData                                                            %Draw the data onto the GUI
            
    function GUIBuilder
        %create window
        handles.MainWindow = figure('Menubar','figure','Units','normalized','outerposition',[0 0 1 1]);

%         these functions create each smaller divisions within window and
%         the objects contained within them
        SliderPanel

        %creates upper left button panel
        handles.TopPanel= uipanel('Parent',handles.MainWindow,...
            'Units','normalized','Position',[0 0.7 0.2 .3]);

        %Creates Cursor Zoom Button
        handles.CursorZoom = uicontrol('style','pushbutton',...
            'parent', handles.TopPanel,'units', 'normalized',...
            'position',[.05 .83 .5 .15],'String','Cursor Zoom',...
            'callback', {@CursorZoom});
        %function called when CursorZoom button is pushed
        function CursorZoom(~,~) 
            yLimits(DataChan,:) = get(handles.PlotHandles(DataChan),'ylim');
            if(RedCursorLocation<GreenCursorLocation)
                set(handles.PlotHandles(DataChan),'xlim',[RedCursorLocation,GreenCursorLocation]);
            else
                set(handles.PlotHandles(DataChan),'xlim',[GreenCursorLocation,RedCursorLocation]);
            end
            xLimits = get(handles.PlotHandles(DataChan),'xlim');
            xRange = xLimits(2) - xLimits(1);
            set(handles.HorizontalSlider, 'Visible','on','Value',xLimits(1),'max',MaxTime-xRange);
        end

        %creates the Reframe cursor button
        handles.ReframeCursors = uicontrol('style','pushbutton',...
            'parent', handles.TopPanel,'units', 'normalized',...
            'position',[.05 .63 .33 .15],'String','Reframe Cursor',...
            'callback', {@ReframeCursor, handles});
        %function called when Reframe cursors button is pushed
        function ReframeCursor(~,~,~) 
            yLimits(DataChan,:) = get(handles.PlotHandles(DataChan),'ylim');
            set(handles.GreenLines(DataChan), 'XData', [xLimits(1)+.2*xRange xLimits(1)+.2*xRange]);
            set(handles.RedLines(DataChan), 'XData', [xLimits(1)+.1*xRange xLimits(1)+.1*xRange]);
            RedCursorLocation=xLimits(1)+.1*xRange;
            GreenCursorLocation=xLimits(1)+.2*xRange;
        end
        handles.HideCursors = uicontrol('style','pushbutton',...
            'parent', handles.TopPanel,'units', 'normalized',...
            'position',[.4 .71 .15 .07],'String','Hide',...
            'callback', {@HideCursor, handles});
        function HideCursor(~,~,~) 
            yLimits(DataChan,:) = get(handles.PlotHandles(DataChan),'ylim');
            set(handles.GreenLines(DataChan),'Visible','Off');
            set(handles.RedLines(DataChan),'Visible','Off');
        end
        handles.ShowCursors = uicontrol('style','pushbutton',...
            'parent', handles.TopPanel,'units', 'normalized',...
            'position',[.4 .62 .15 .07],'String','Show',...
            'callback', {@ShowCursor, handles});
        function ShowCursor(~,~,~) 
            set(handles.GreenLines(DataChan),'Visible','On');
            set(handles.RedLines(DataChan),'Visible','On');
        end
        %Creates Reset Zoom Buttom
        handles.ResetZoom = uicontrol('style','pushbutton',...
            'parent', handles.TopPanel,'units', 'normalized',...
            'position',[.05 .43 .5 .15],'String','Reset Zoom',...
            'callback', {@ResetZoom});
        %function called when ResetZoom button is pushed
        function ResetZoom(~,~)
            delete(handles.PlotHandles)
            PlotData;
            set(handles.HorizontalSlider, 'Visible','off');
        end
        %Creates increase linewidth button
        handles.IncreaseLineWidth = uicontrol('style','pushbutton',...
            'parent', handles.TopPanel,'units', 'normalized',...
            'position',[.02 .23 .26 .15],'String','Incr Linewidth',...
            'callback', {@IncreaseLineWidth});
        %function called when increase linewidth button is pushed
        function IncreaseLineWidth(~, ~)
            Linewidth = get(handles.PlotLineHandles(DataChan),'linewidth');
            set(handles.PlotLineHandles(DataChan),'linewidth', Linewidth + 1);
        end
        %Creates decrease linewidth button
        handles.DecreaseLineWidth = uicontrol('style','pushbutton',...
            'parent', handles.TopPanel,'units', 'normalized',...
            'position',[.29 .23 .26 .15],'String','Decr Linewidth',...
            'callback', {@DecreaseLineWidth, handles});
        %functioncalled when decrease linewidth button is pushed
        function DecreaseLineWidth(~, ~,~)
            Linewidth = get(handles.PlotLineHandles(DataChan), 'linewidth');
            if Linewidth > 1 
                set(handles.PlotLineHandles(DataChan),'linewidth', Linewidth - 1);
            end
        end
        % split file for separate analysis - channel-by-channel
        handles.Splitfile = uicontrol('style','pushbutton',...
            'parent', handles.TopPanel,'units','normalized',...
            'position',[.04 .05 .5 .15],'String','Split File (chan)',...
            'callback', {@SplitFile, handles});
        function SplitFile(~, ~,~)
            [pickedx,~] = ginput;
            splitpoint = round(pickedx*SampleFrequency,0);
            splitpoint = [1;splitpoint;DataLength];
            OriginalData = Data;
            dataTrace = Data(:,DataChan);
            detect{DataChan} = []; % don't want previously detected episodes. Point of split is to redo
            for i = 1:(length(splitpoint)-1)
                Data = double(dataTrace(splitpoint(i):(splitpoint(i+1)-1))); % overwrite for saving
                NewFileName = strcat(filename,'_Chan',num2str(DataChan),'_',num2str(i));
                save(NewFileName,'Data','SampleInterval','Header','SepSett','detect','FiltSett','StaticData','DataChan')
            end
            Data = OriginalData; % restore original data if want to change other channels
        end
        % Creates panel to graph channel in
        handles.PlotPanel = zeros(DataChannels,1);
        handles.PlotHandles = zeros(DataChannels,1);
        handles.PlotPanel(DataChan) = uipanel('Parent',handles.MainWindow,...
        'Units','normalized','Position',[0.2 0.05 .82 0.99]);

        % label for y-axis zoom functions
        uicontrol(handles.TopPanel,'Style','text','String','Adjust y-axis:',...
        'Units','Normalized','Position',[.55 .33 .45 .09]);
        % creates the shift up button
        handles.yShiftUp = uicontrol('style','pushbutton',...
            'units', 'normalized','position',[.12 0.76 .026 .03],...
            'string','up','callback', {@yUpShift, handles});
        % decreases both y limits (giving the illusion of 0 moving up the plot)
        function yUpShift(~, ~, ~)
            y = get(handles.PlotHandles(DataChan),'ylim');
            ymin = y(1);
            ymax = y(2);
            set(handles.PlotHandles(DataChan),'ylim',[ymin-.1*(ymax-ymin) ymax-.1*(ymax-ymin)]);
        end
        % creates the shift down button
        handles.yShiftDown = uicontrol('style','pushbutton',...
            'units', 'normalized','position',[.12 .71 .026 .03],...
            'string','down','callback', {@yDownShift, handles});
        % increases both y limits (giving the illusion of 0 moving down the plot)
        function yDownShift(~, ~, ~)
            y = get(handles.PlotHandles(DataChan),'ylim');
            ymin = y(1);
            ymax = y(2);
            set(handles.PlotHandles(DataChan),'ylim',[ymin+.1*(ymax-ymin) ymax+.1*(ymax-ymin)]);
        end
        %creates the Y-axis zoom button
        handles.YZoomHandles = uicontrol('style','pushbutton',...
            'units','normalized','string','+','position',[.16 .76 .017 .026],...
            'callback', {@yZoom, handles});
        %function called when Y-axis zoom button is pushed
        function yZoom(~, ~, ~)
            y = get(handles.PlotHandles(DataChan),'ylim');
            ymin = y(1);
            ymax = y(2);
            set(handles.PlotHandles(DataChan),'ylim',[ymin-0.1*ymin ymax-0.1*ymax]);
        end
        %creates the Y-axis unzoom button
        handles.yUnzoomHandles = uicontrol('style','pushbutton',...
            'units','normalized','position',[.16 .711 .017 .026],...
            'string','-','callback',{@yUnzoom,handles});
        %UnZooms in the y direction (makes y limits larger)
        function yUnzoom(~,~,~)
            y = get(handles.PlotHandles(DataChan),'ylim');
            ymin = y(1);
            ymax = y(2);
            set(handles.PlotHandles(DataChan),'ylim',[ymin+.1*ymin ymax+.1*ymax]);
        end
        % load data new data file
        handles.loadfile = uicontrol('style','pushbutton','parent',...
            handles.TopPanel,'units','normalized','string','Load File',...
            'position',[.65 .8 .25 .15],'callback', {@loadFile,handles});
        function loadFile(~,~,~)
            close(handles.MainWindow)
            [FileName,~,~] = uigetfile;                  %User selects file and GUI gets the file name and the path to the file            
            [~,filename,extension] = fileparts(FileName);
            DataChan = 1;
            SepSett = [];
            FiltSett{DataChan} = [];    
            detect = [];
            patches = [];
            StaticData = []; 
            if extension == '.abf'
                [Data,SampleInterval,Header] = abfload(FileName);             %#ok<*SETNU> %converts binary file to a matrix of data as well as a header file
                DataLength = Header.dataPtsPerChan;                                 %Number of datapoint in each channel of data
                DataChannels = Header.nADCNumChannels;                              %Number of channels
            elseif extension == '.mat'
                load(FileName) 
                [DataLength,DataChannels] = size(Data);
                if length(detect) > DataChannels
                    detecthold = detect{DataChan}; % get new DataChan from loaded file
                    detect = [];
                    detect{DataChan} = detecthold; % only keep relevant channel's detected episodes
                    filthold = FiltSett{DataChan};
                    FiltSett = [];
                    FiltSett{DataChan} = filthold;
                    setthold = SepSett{DataChan};
                    SepSett = [];
                    SepSett{DataChan} = setthold;
                end
            end
            %Variables
            DataChan = 1;
            SampleFrequency = 1/(Header.nADCNumChannels*Header.fADCSampleInterval*10^-6);                  
            % StaticData = Data;                                                  %Copy of data that will not be altered from filtering ect.
            MaxTime = DataLength/SampleFrequency;                               %Duration of data
            PlotDomain = (0+MaxTime/DataLength:MaxTime/DataLength:MaxTime);     %Creates a time point for each point of data
            PlotSpacing = 1;                                                    %lowers the number of points the GUI plots
            yLimits = zeros(DataChannels,2);                                    %the current min and max y value of each subplot
            xLimits = [0, MaxTime];                                             %min and max domain of the plots
            xRange = MaxTime;                                                   %Time shown of the plots
            RedCursorLocation = xRange*0.1;                                     %default location of the red cursor
            GreenCursorLocation = xRange*0.2;                                   %default location of the green cursor
            handles = struct;                                                   %make handles to objects in GUI global                                                                                                           
            
            GUIBuilder
            PlotData 
        end

        % drop-down menu to select data channel
        uicontrol(handles.TopPanel,'Style','text','String',...
        'Data Channel:','Units','Normalized','Position',[.55 .66 .45 .08]);
        chanstr = [];
        for i = 1:DataChannels %#ok<*FXUP>
            chanNum = num2str(i);
            chanstr = [chanstr;chanNum];
        end
        handles.handles.TopPanel.selectchannel = uicontrol(handles.TopPanel,...
        'Style','popupmenu','Units','Normalized','BackgroundColor',[1 1 1],...
        'String',chanstr,'Position',[.69 .6 .15 .05],'Callback',...
        {@selectChannel,handles});
    
        function selectChannel(hObject,~,~) 
            DataChan = get(hObject,'Value'); 
            handles.PlotPanel(DataChan) = uipanel('Parent',handles.MainWindow,...
            'Units','normalized','Position',[0.2 0.05 .82 0.99]);
            try
                settings = SepSett{DataChan};
            catch
                settings = [];
            end
            if ~isempty(settings)
                set(handles.flatStartBox,'string',num2str(settings(1)));
                set(handles.flatEndBox,'string',num2str(settings(2)));
                set(handles.upTimeBox,'string',num2str(settings(3)));
                set(handles.downTimeBox,'string',num2str(settings(4)));
                set(handles.episodeDurationBox,'string',num2str(settings(5)));
                set(handles.burstSTDMultipleBox,'string',num2str(settings(6)));
                set(handles.episodeSTDMultipleBox,'string',num2str(settings(7)));
            end
            PlotData
        end
        %MiddlePanel is the middle left panel in the GUI window. 
            handles.MiddlePanel= uipanel('Parent',handles.MainWindow,...
            	'Units','normalized','Position',[0 0.44 0.2 .26]);
        % Filter options
        TypeTag = 'Low-Pass';
        % Creates the radio button group
        handles.filterType = uibuttongroup('parent',handles.MiddlePanel,...
            'units', 'normalized','position',[.05 .55 0.9 0.4],...
            'SelectionChangeFcn', @FilterType);
        %function called when filter type radio buttons are changed
        function FilterType(~, eventdata)
            TypeTag = get(eventdata.NewValue,'Tag');
            switch TypeTag
                case 'Low-Pass'
                    set(handles.HighPassEntry, 'enable', 'off');
                    set(handles.LowPassEntry, 'enable', 'on');
                    set(handles.HighPassEntry, 'string', '');
                case 'Band-Pass'
                    set(handles.HighPassEntry, 'enable', 'on');
                    set(handles.LowPassEntry, 'enable', 'on');
                case 'High-Pass'
                    set(handles.HighPassEntry, 'enable', 'on');
                    set(handles.LowPassEntry, 'enable', 'off');
                    set(handles.LowPassEntry, 'string', '');
            end
        end
        %creates the text above the top group of radio buttons   
        handles.FilterTypeText = uicontrol('Style','Text',...
            'parent',handles.filterType,'style','text',...
            'units','normalized','position',[0.02 0.78 .4 .25],...
            'string','Filter Type');
        %creates the Low-Pass radio button option
        handles.LowPassFilter = uicontrol('Style','radiobutton',...
            'String','Low-Pass','parent',handles.filterType,...
            'units', 'normalized','position', [0.05 0.46 0.5 0.28],...
            'HandleVisibility','off','Tag','Low-Pass');
        %creates the High-pass radio button option
        handles.HighPassFilter = uicontrol('Style','radiobutton',...
            'String','High-Pass','parent',handles.filterType,...
            'units', 'normalized','position', [0.5 0.46 0.5 0.28],...
            'HandleVisibility','off','Tag','High-Pass');
        %creates the Band-Pass radio button option
        handles.BandPassFilter = uicontrol('Style','radiobutton',...
            'String','Band-Pass','parent',handles.filterType,...
            'units', 'normalized','position', [0.05 0.08 0.5 0.28],...
            'HandleVisibility','off','Tag','Band-Pass');
        %creates the text for the low pass frequency box
        handles.LowPassText = uicontrol('Style','text',...
        'parent', handles.MiddlePanel,'units','normalized',...
        'position',[0.03 0.32 0.25 0.2],'String','LP (Hz)');
        %creates the low pass frequency entry box
        handles.LowPassEntry = uicontrol('Style','edit',...
            'parent', handles.MiddlePanel,'units','normalized',...
            'position', [0.05 0.27 0.2 0.13]);
        %creates the text for the high pass frequency box
        handles.HighPassText = uicontrol('Style','text',...
            'parent', handles.MiddlePanel,'units','normalized',...
            'position', [0.32 0.32 0.25 0.2],'String','HP (Hz)');
        %creates the high pass frequency entry box
        handles.HighPassEntry = uicontrol('Style','edit',...
            'parent', handles.MiddlePanel,'units','normalized',...
            'enable','off','position',[0.35 0.27 0.2 0.13]);
        %creates the text for the order box
        handles.OrderText = uicontrol('Style','text',...
            'parent', handles.MiddlePanel,'units','normalized',...
            'position', [0.67 0.32 0.25 0.2],'String','Filter Order');
        %creates the order box
        handles.OrderEntry = uicontrol('Style','edit',...
            'parent', handles.MiddlePanel,'units','normalized',...
            'position',[0.68 0.27 0.2 0.13]);
        %creates the finish button
        handles.ApplyButton = uicontrol('Style','pushbutton',...
            'parent', handles.MiddlePanel,'units','normalized',...
            'position',[0.1 0.07 .3 .15],'string','Apply',...
            'Callback',{@Apply});
        %function called when finish button is pushed
        function Apply(~,~)
            high = str2double(get(handles.HighPassEntry,'string'))/(SampleFrequency/2);
            low = str2double(get(handles.LowPassEntry,'string'))/(SampleFrequency/2);
            order = str2double(get(handles.OrderEntry,'string'));
            switch TypeTag
                case 'Low-Pass'
                    [b,a] = butter(order,low,'low');
                    Data(:,DataChan) = filtfilt(b,a,Data(:,DataChan));
                case 'Band-Pass'
                    [b,a] = butter(order,[low high],'bandpass');
                    Data(:,DataChan) = filtfilt(b,a,Data(:,DataChan));
                case 'High-Pass'
                    [b,a] = butter(order,high,'high');
                    Data(:,DataChan) = filtfilt(b,a,Data(:,DataChan));
            end
            delete(handles.PlotHandles);
            PlotData;
            filtsettings = [order,low*(SampleFrequency/2),high*(SampleFrequency/2)];
            FiltSett{DataChan} = filtsettings;
        end
        %creates the rectify button
        handles.RectifyButton = uicontrol('Style','pushbutton',...
            'parent', handles.MiddlePanel,'units','normalized',...
            'position',[0.5 0.07 .3 .15],'string','Rectify',...
            'Callback',{@Rectify});
        %function called when rectify button is pushed
        function Rectify(~,~)
            Data(:,DataChan) = abs(Data(:,DataChan));
            delete(handles.PlotHandles);
            PlotData;
        end   
        % BottomPanel is the bottom left panel in the GUI window.
        handles.BottomPanel = uipanel('Parent',handles.MainWindow,...
            'Units','normalized','Position',[0 0 .2 .44]);
        handles.EpisodeSettingsText = uicontrol('style','text',...
            'Parent',handles.BottomPanel,'Units','normalized',...
            'position',[0 0.85 0.8 0.15],'string','Episode Separation Settings');
        handles.flatStartText = uicontrol('style','text',...
            'Parent',handles.BottomPanel,'Units','normalized',...
            'position',[0.01 0.78 0.22 0.15],'string','Start Flat Part');
        handles.flatStartBox = uicontrol('style','edit',...
            'Parent',handles.BottomPanel,'Units','normalized',...
            'string','15','position',[0.25 0.86 0.12 0.08]);
        handles.flatEndText = uicontrol('style','text',...
            'Parent',handles.BottomPanel,'Units','normalized',...
            'position',[0.01 0.68 0.22 0.15],'string','End Flat Part');
        handles.flatEndBox = uicontrol('style','edit',...
            'Parent',handles.BottomPanel,'string','30',...
            'Units','normalized','position',[0.25 0.76 0.12 0.08]);
        handles.upTimeText = uicontrol('style','text',...
            'Parent',handles.BottomPanel,'Units','normalized',...
            'position',[0.01 0.58 0.22 0.15],'string','Up Time');
        handles.upTimeBox = uicontrol('style','edit',...
            'Parent',handles.BottomPanel,'Units','normalized',...
            'string','0.25','position',[0.25 0.66 0.12 0.08]);
        handles.downTimeText = uicontrol('style','text',...
            'Parent',handles.BottomPanel,'Units','normalized',...
            'position',[0.01 0.48 0.22 0.15],'string','Down Time');
        handles.downTimeBox = uicontrol('style','edit',...
            'Parent',handles.BottomPanel,'string','0.25',...
            'Units','normalized','position',[0.25 0.56 0.12 0.08]);
        handles.episodeDurationText = uicontrol('style','text',...
            'Parent',handles.BottomPanel,'Units','normalized',...
            'position',[0.01 0.36 0.22 0.18],'string','Episode Duration');
        handles.episodeDurationBox = uicontrol('style','edit',...
            'Parent',handles.BottomPanel,'string','4',...
            'Units','normalized','position',[0.25 0.46 0.12 0.08]);
        handles.burstSTDMultipleText = uicontrol('style', ' text',...
            'Parent',handles.BottomPanel,'Units','normalized',...
            'position',[0.01 0.28 0.2 0.15],'string','Burst STD');
        handles.burstSTDMultipleBox = uicontrol('style','edit',...
            'Parent',handles.BottomPanel,'string', '4',...
            'Units','normalized','position',[0.25 0.36 0.12 0.08]);
        handles.episodeSTDMultipleText = uicontrol('style','text',...
            'Parent',handles.BottomPanel,'Units','normalized',...
            'position',[0.01 0.18 0.2 0.15],'string', 'Episode STD');
        handles.episodeSTDMultipleBox = uicontrol('style','edit',...
            'Parent',handles.BottomPanel,'string', '4',...
            'Units','normalized','position',[0.25 0.26 0.12 0.08]);
        handles.detrendButton = uicontrol('style','pushbutton',...
            'Parent',handles.BottomPanel,'Units','normalized',...
            'position', [0.45 0.82 0.25 0.1],'string','Detrend',...
            'callback', {@detrendFunction});
        handles.resetplotButton = uicontrol('style','pushbutton',...
            'Parent',handles.BottomPanel,'Units','normalized',...
            'position', [0.73 0.82 0.25 0.1],'string','Reset Plot',...
            'callback', {@resetPlotFunction});
        handles.autoFeaturesButton = uicontrol('style','pushbutton',...
            'Parent',handles.BottomPanel,'Units','normalized',...
            'position', [0.45 0.7 0.53 0.1],'string','Auto Sep Episodes/Features',...
            'callback', {@autoFeaturesFunction});
        handles.manualFeaturesButton = uicontrol('style','pushbutton',...
            'Parent',handles.BottomPanel,'Units','normalized',...
            'position', [0.45 0.58 0.53 0.1],'string','Manual Sep Episodes/Features',...
            'callback', {@manualFeaturesFunction});
        handles.showBinGraphButton = uicontrol('style','pushbutton',...
            'Parent',handles.BottomPanel,'Units','normalized',...
            'position', [0.05 0.05 0.33 0.1],'string','Show Bins',...
            'callback', {@graphBins});
        handles.showEpisode = uicontrol('style','pushbutton',...
            'Parent',handles.BottomPanel,'Units','normalized',...
            'position', [0.45 0.46 0.3 0.1],'string','Show Episodes',...
            'callback', {@showEpisodes,1});
        handles.hideEpisode = uicontrol('style','pushbutton',...
            'Parent',handles.BottomPanel,'Units','normalized',...
            'position', [0.78 0.46 0.2 0.1],'string','Hide',...
            'callback', {@showEpisodes,2});
        handles.saveButton = uicontrol('style','pushbutton',...
            'Parent',handles.BottomPanel,'Units','normalized',...
            'position', [0.45 0.34 0.25 0.1],'string','Save Progress',...
            'callback', {@saveProgress});
        handles.saveplotButton = uicontrol('style','pushbutton',...
            'Parent',handles.BottomPanel,'Units','normalized',...
            'position', [0.73 0.34 0.25 0.1],'string','Save Plot',...
            'callback', {@saveplotProgress});
        function saveProgress(~,~) % saves settings currently saved in GUI along with updated Data file
            ext = '_progress';
            modFileName = strcat(filename,ext);
            save(modFileName,'Data','SampleInterval','Header','SepSett','detect','FiltSett','StaticData','DataChan')
            a = msgbox('Progress Saved!');
        end
        function saveplotProgress(~,~) % saves settings currently saved in GUI along with updated Data file
            f = figure;
            time = 1:size(Data,1);
            time = time/SampleFrequency;
            plot(time,Data(:,DataChan))
            ChanNumber = num2str(DataChan);
            ChanName = strcat('Channel',ChanNumber);
            title(ChanName)
            ylabel('Amplitude (V)')
            xlabel('time (s)')
            FigFilename = strcat(filename,ChanName,'_trace');
            savefig(f,FigFilename)
            pngFilename = strcat(FigFilename,'.png');
            saveas(f,pngFilename)            
            close(f)
        end
        handles.classifyButton = uicontrol('style','pushbutton',...
            'Parent',handles.BottomPanel,'Units','normalized',...
            'position', [0.45 0.22 0.53 0.1],'string','Classify Episodes',...
            'callback', {@ClassifyEpisodes});
        function ClassifyEpisodes(~,~)
            if ~isempty(detect) 
                ChansData = []; % find channels that have features extracted
                for i = 1:length(detect)
                    if ~isempty(detect{i})
                        ChansData = [ChansData,i];
                    end
                end
                for i = 1:length(ChansData)
                    detect{1,ChansData(i)}(:,15:18) = [];
                    [Feats,Featsnorm,a2,h,p,v] = deal([]); % initialize params
                    Feats = detect{1,ChansData(i)};
                    Feats(:,11:12) = []; % remove amp info not percent
                    Feats(:,1:4) = []; % remove start and end points/times
                    % round features to keep consistency with training
                    Feats = round(Feats,3);
                    Feats(:,1:3) = round(Feats(:,1:3),2);
                    Feats(:,7:8) = round(Feats(:,7:8),2);
                    % normalize features for classification, then replace missing with zeros
                    maxFirst2 = max(Feats(2:end,1:2));
                    maxrest = max(Feats(:,3:end));
                    minFirst2 = min(Feats(2:end,1:2));
                    minrest = min(Feats(:,3:end));
                    maxFeats = [maxFirst2,maxrest];
                    minFeats = [minFirst2,minrest];
                    basenorm = (maxFeats + minFeats)/2;
                    rangenorm = (maxFeats - minFeats)/2;
                    Featsnorm = (Feats - basenorm)./rangenorm; % normalize features - same method as Weka
                    if ((Feats(1,1) == 0) && (Feats(1,2) == 0)) % if missing time info for first episode
                        Featsnorm(1,1:2) = 0; % replace missing values
                    end
                    Featsnorm = round(Featsnorm,3); % round again
                    
                    % weights for MLP, from training - Multi-burst or not
                    Theta1_M = [-1.07967093591345,-4.14455143601136,-8.63841977046485,-1.48212139704314,...
                        -2.60294279842835,-1.02586017944657,-1.81092760926483,3.61164136975821,...
                        -1.10191926290598,-0.626675032066758;-0.865079697430849,-3.77586975841806,...
                        -2.25458530172993,-1.50335429605537,-2.86127323121429,-0.793198520845326,...
                        -1.13911343147773,-2.12486968825916,-0.912976261564134,-0.584196084999086;...
                        0.736656822430476,-0.277319225847969,3.95414063942583,1.21987062004237,...
                        2.20637160510909,0.708152031307403,-0.907948143245478,0.447712749263795,...
                        0.892833945037168,0.00985547591978766;-1.47474447239532,-4.63567747308970,...
                        -1.30037642687947,-2.72102549197537,-3.34159727666773,-1.25779852606355,...
                        -5.92999958454713,1.17927776503641,-1.53101488514416,-0.854005388244123;...
                        0.746707052130336,0.835820889958172,4.03693018430130,0.525128833798047,...
                        -1.48428208653619,0.742505954343913,1.35209753937773,-2.81292290602607,...
                        0.695676828852909,0.912584895638440;-1.22485353295615,-1.61061703133372,...
                        -0.816819471529251,-1.60826860560548,0.431276509530143,-1.14757420226453,...
                        -2.11222402431476,-0.356322603370757,-1.17768235965074,-0.936335563420752;...
                        1.51900218302497,6.30534156265590,-16.2089805831869,2.26130503174534,...
                        8.21731851259230,1.41052776663028,-0.298655874247197,3.23877045811711,...
                        1.39737302748657,0.678122654147401;-1.06212356624334,1.12660223786051,...
                        -2.68678790823574,-2.25294362951991,2.72304869722256,-0.845634493975938,...
                        -2.70730122705143,-8.01160545504334,-1.10954621043207,0.340580924991275;...
                        -1.37851740623958,-1.78276500293854,-0.367935590224081,-0.776013225464673,...
                        -6.51822472275256,-1.78077399858108,6.81782311052552,5.85699311265469,...
                        -1.83602574836560,0.0782099571571300];
                    Theta2_M = [-1.84656855968885,1.84912214953946;0.703386263023193,-0.658590979134334;...
                        3.89310420448314,-3.90116156005776;4.89867297380012,-4.89800479887042;...
                        1.25950287956612,-1.26794378355422;3.56100010956350,-3.55424969910234;...
                        0.681074155814542,-0.740152681344475;2.92685737013720,-2.92317613040812;...
                        -3.34246989568046,3.34231023885473;0.861884570506074,-0.842415379233793;...
                        -0.579113709629481,0.546239322872733];

                    % classification algorithm for multi-burst or not
                    m = size(Featsnorm, 1);
                    Featsnorm = [ones(m, 1) Featsnorm]; % adding bias node to input
                    a2 = sigmoid(Featsnorm*Theta1_M); % values of hidden nodes
                    n = size(a2,1); 
                    a2 = [ones(n, 1) a2]; % adding biase node to hidden nodes
                    h = sigmoid(a2*Theta2_M); % predictions for each output
                    [v, p] = max(h,[],2); % output prediction
                    p = p - 1; % subtract one so class 0 is 0 and class 1 is 1
                    detect{1,ChansData(i)}(:,15) = p; % add class of multi or not to detect 
                    
                    Theta1_R = [-6.25333943448409,-0.390995695495054,0.304923487946634,-3.16602117993524,...
                        3.18986827650578;-12.1420755539283,-5.89802995466231,8.04156925730145,...
                        -10.5033240617958,11.3569337467369;11.4893586175338,-12.2524696612046,...
                        8.36637797442912,-10.3548492998813,-6.33101822466593;9.03699864885469,...
                        14.3068577121271,-0.467720190766390,0.0488584193353790,-21.9850358236851;...
                        -6.20757835425955,1.11293965561423,-3.87173095137221,-0.214221945187287,...
                        -8.44313286167070;-12.3892867974519,-4.60013285632521,-1.30841614102434,...
                        -10.9817880117550,-10.9074818943511;-13.6301598933058,14.1639168856738,...
                        -5.98122067269688,-0.227236364724335,2.34015613513455;-9.53517091232371,...
                        -11.9610454197447,-11.3191096324158,-17.3468797374776,-14.6190441612141;...
                        -0.665996529739590,3.19156522375836,0.994091283375145,7.55082725833228,...
                        7.71709115025019];
                    Theta2_R = [-0.453684396061085,0.453684389702912;5.92411522030587,-5.92411434626534;...
                        3.19558446219440,-3.19558443867925;1.31926109836376,-1.31926110552648;...
                        1.27869075136877,-1.27869077153892;1.72054176717172,-1.27869077153892];
                    [a2,h,p,v] = deal([]);
                    a2 = sigmoid(Featsnorm*Theta1_R); % values of hidden nodes
                    n = size(a2,1); 
                    a2 = [ones(n, 1) a2]; % adding biase node to hidden nodes
                    h = sigmoid(a2*Theta2_R); % predictions for each output
                    [v, p] = max(h,[],2); % output prediction
                    p = p - 1; % subtract one so class 0 is 0 and class 1 is 1
                    detect{1,ChansData(i)}(:,16) = p;
                    % get amplitude-related descriptor (large = 1 or small = 0)
                    amps = detect{1,ChansData(i)}(:,13);
                    detect{1,ChansData(i)}(:,17) = 0;
                    indLarge = find(amps > 50);
                    detect{1,ChansData(i)}(indLarge,end) = 1; %#ok<FNDSB>
                    % put it all together
                    Multi = detect{1,ChansData(i)}(:,15);
                    Rhythmic = detect{1,ChansData(i)}(:,16);
                    Amp = detect{1,ChansData(i)}(:,17);
                    Class = zeros(length(Multi),1);
                    for j = 1:length(Multi) % for each episode
                        if (Multi(j) == 1) && (Rhythmic(j) == 1) % Multi, Rhythmic
                            Class(j) = 4;
                        elseif (Multi(j) == 1) && (Rhythmic(j) == 0) % Multi, not Rhythmic
                            Class(j) = 5;
                        elseif (Multi(j) == 0) && (Rhythmic(j) == 1) % Large, Rhythmic
                            Class(j) = 3;
                        elseif (Amp(j) == 1) % large amplitude, no Rhythmic
                            Class(j) = 2;
                        else
                            Class(j) = 1; % small
                        end
                    end
                    detect{1,ChansData(i)}(:,18) = Class;
                end
                ext = '_classify';
                detectFileName = strcat(filename,ext);
                save(detectFileName,'Data','SampleInterval','Header','SepSett','detect','FiltSett','StaticData','DataChan') 
                a = msgbox('Episodes Classified!');
            else
                warndlg('Need to extract features first!')
            end
        end
        handles.ExportExcelButton = uicontrol('style','pushbutton',...
            'Parent',handles.BottomPanel,'Units','normalized',...
            'position', [0.45 0.1 0.53 0.1],'string','Export to Excel',...
            'callback', {@ExportExcel});
        function ExportExcel(~,~)
            % check if have features extracted
            try
                ChanData = [];
                for i = 1:length(detect)
                    if ~isempty(detect{i})
                        ChanData = [ChanData,i]; % finds channels that had features extracted
                    end
                end
                ChanFeats = cell(1,length(ChanData));
                NumFeats = size(detect{ChanData(1)},2); % number of features extracted from number of episodes
                DetectedFeatures = cell(1,NumFeats + 2);
                Buffer = cell(1,NumFeats + 2);
                for i = 1:length(ChanData) % channel-by-channel extract data and make table
                    [numEps,NumFeats] = size(detect{ChanData(i)});
                    features = detect{ChanData(i)};
                    avgFeat = [];
                    stdFeat = [];
                    T = [];
                    T(1:numEps,1) = 1:numEps;
                    for j = 2:(NumFeats + 1) % extract each column (feature) of data for channel
                        T(:,j) = features(:,j-1);  %#ok<*SAGROW>
                        avgFeat(j-1) = mean(T(:,j));
                        stdFeat(j-1) = std(T(:,j));
                    end
                    % add column for class labels
                    finalClass = T(:,19); % get final class from table
                    classLabel = cell(numEps,1);
                    for j = 1:numEps % pair class number to class label
                        currClass = finalClass(j);
                        switch currClass
                            case 1
                                classLabel(j) = {'Small'};
                            case 2
                                classLabel(j) = {'Large, not Rhythmic'};
                            case 3
                                classLabel(j) = {'Large, Rhythmic'};              
                            case 4
                                classLabel(j) = {'Multi-burst, Rhythmic'};
                            case 5
                                classLabel(j) = {'Multi-burst, not Rhythmic'};
                        end
                    end
                    % replace average of classes with modes - most common
                    for j = 15:18
                        avgFeat(j) = mode(T(:,j+1));
                        stdFeat(j) = mode(T(:,j+1));
                    end
                    Tcell = num2cell(T); % convert values to cell
                    Tcell = [Tcell,classLabel];
                    avgLabel = {'Average'};
                    avgCell = num2cell(avgFeat);
                    avgCell = [avgLabel,avgCell];
                    % label most common class
                    commonClass = cell2mat(avgCell(19));
                    switch commonClass
                        case 1
                            commonclassLabel = {'Small'};
                        case 2
                            commonclassLabel = {'Large, not Rhythmic'};
                        case 3
                            commonclassLabel = {'Large, Rhythmic'};              
                        case 4
                            commonclassLabel = {'Multi-burst, Rhythmic'};
                        case 5
                            commonclassLabel = {'Multi-burst, not Rhythmic'};
                    end
                    avgCell = [avgCell,commonclassLabel];
                    stdLabel = {'Standard Deviation'};
                    stdCell = num2cell(stdFeat);
                    stdCell = [stdLabel,stdCell,0];
                    ChanLabel = 'Channel-';
                    ChanNumber = num2str(ChanData(i));
                    ChannelName = cell(1,NumFeats + 2);
                    ChannelName{1} = strcat(ChanLabel,ChanNumber); 
                    ColumnName = {' ','Start Data Point','End Data Point','Start Time','End Time',...
                        'Time from Previous','Start to start','Duration','Peak Frequency','Bandwidth',...
                        'Peak Power','Max Amplitude','Avg Amplitude','Max Amplitude (%)','Avg Amplitude (%)',...
                        'Multi-burst','Rhythmic','Large Amplitude','Class','Class Label'}; % 
                    DetectedFeatures = [DetectedFeatures;ChannelName;ColumnName;Tcell;Buffer;avgCell;stdCell;Buffer]; %#ok<*AGROW> % merge values and column names
                    ChanFeats(i) = {Tcell};
                    % Generate histogram plots for features of interset for each channel
                    f = figure;
                    subplot(3,2,1)
                    histogram(T(:,6),5,'Normalization','probability')
                    title('Duration')
                    subplot(3,2,2)
                    histogram(T(:,7),5,'Normalization','probability')
                    title('Pk Frequency')
                    subplot(3,2,3)
                    histogram(T(:,8),5,'Normalization','probability')
                    title('Bandwidth')
                    subplot(3,2,4)
                    histogram(T(:,9),10,'Normalization','probability')
                    title('Pk Power')
                    subplot(3,2,5)
                    histogram(T(:,12),10,'Normalization','probability')
                    title('Max Amp (%)')
                    subplot(3,2,6)
                    histogram(T(:,13),5,'Normalization','probability')
                    title('Avg Amp (%)')
                    ChanName = ChannelName{1};
                    %suptitle(ChanName)
                    FigFilename = strcat(filename,ChanName,'histograms');
                    savefig(f,FigFilename)
                    pngFilename = strcat(FigFilename,'.png');
                    saveas(f,pngFilename)
                end
                
                % add class-by-class proportions and and avg +/- std for all episodes classified in file
                AllEps = [];
                for i = 1:length(ChanFeats)
                    AllEps = [AllEps;ChanFeats{1,i}];
                end
                [totnumEps,~] = size(AllEps);
                Class = cell2mat(AllEps(:,19));
                Class1 = find(Class == 1); %#ok<*EFIND> % find indicies of each class in all episodes
                Class2 = find(Class == 2);
                Class3 = find(Class == 3);
                Class4 = find(Class == 4);
                Class5 = find(Class == 5);
                
                % for each class, calculate the proportion of total episodes, mean and standard deviation for all features in class
                if ~isempty(Class1)
                    numClass1 = length(Class1);
                    proportionClass1 = ((numClass1/totnumEps)*100);
                    FeatsClass1 = [];
                    for j = 1:numClass1
                        FeatsClass1 = [FeatsClass1;AllEps(Class1(j),6:15)];
                    end
                    FeatsClass1 = cell2mat(FeatsClass1);
                    AvgClass1 = mean(FeatsClass1,1);
                    StdClass1 = std(FeatsClass1,0,1);
                else
                    numClass1 = 0;
                    proportionClass1 = 0;
                    FeatsClass1 = zeros(1,10);
                    AvgClass1 = 0;
                    StdClass1 = 0;
                end
                if ~isempty(Class2)
                    numClass2 = length(Class2);
                    proportionClass2 = ((numClass2/totnumEps)*100);
                    FeatsClass2 = [];
                    for j = 1:numClass2
                        FeatsClass2 = [FeatsClass2;AllEps(Class2(j),6:15)];
                    end
                    FeatsClass2 = cell2mat(FeatsClass2);
                    AvgClass2 = mean(FeatsClass2,1);
                    StdClass2 = std(FeatsClass2,0,1);
                else
                    numClass2 = 0;
                    proportionClass2 = 0;
                    FeatsClass2 = zeros(1,10);
                    AvgClass2 = 0;
                    StdClass2 = 0;
                end
                if ~isempty(Class3)
                    numClass3 = length(Class3);
                    proportionClass3 = ((numClass3/totnumEps)*100);
                    FeatsClass3 = [];
                    for j = 1:numClass3
                        FeatsClass3 = [FeatsClass3;AllEps(Class3(j),6:15)];
                    end
                    FeatsClass3 = cell2mat(FeatsClass3);
                    AvgClass3 = mean(FeatsClass3,1);
                    StdClass3 = std(FeatsClass3,0,1);
                else
                    numClass3 = 0;
                    proportionClass3 = 0;
                    FeatsClass3 = zeros(1,10);
                    AvgClass3 = 0;
                    StdClass3 = 0;
                end
                if ~isempty(Class4)
                    numClass4 = length(Class4);
                    proportionClass4 = ((numClass4/totnumEps)*100);
                    FeatsClass4 = [];
                    for j = 1:numClass4
                        FeatsClass4 = [FeatsClass4;AllEps(Class4(j),6:15)];
                    end
                    FeatsClass4 = cell2mat(FeatsClass4);
                    AvgClass4 = mean(FeatsClass4,1);
                    StdClass4 = std(FeatsClass4,0,1);
                else
                    numClass4 = 0;
                    proportionClass4 = 0;
                    FeatsClass4 = zeros(1,10);
                    AvgClass4 = 0;
                    StdClass4 = 0;
                end
                if ~isempty(Class5)
                    numClass5 = length(Class5);
                    proportionClass5 = ((numClass5/totnumEps)*100);
                    FeatsClass5 = [];
                    for j = 1:numClass5
                        FeatsClass5 = [FeatsClass5;AllEps(Class5(j),6:15)];
                    end
                    FeatsClass5 = cell2mat(FeatsClass5);
                    AvgClass5 = mean(FeatsClass5,1);
                    StdClass5 = std(FeatsClass5,0,1);
                else
                    numClass5 = 0;
                    proportionClass5 = 0;
                    FeatsClass5 = zeros(1,10);
                    AvgClass5 = 0;
                    StdClass5 = 0;
                end
                
                % Class 1 Table
                Class1Name = cell(1,NumFeats + 2);
                Class1Name{1} = 'Class 1';
                Class1Name{2} = 'Small';
                Class1Table = cell(numClass1 + 3,NumFeats + 2);
                Class1Table{1,1} = numClass1;
                Class1Table{1,2} = proportionClass1;
                Class1Table{numClass1 + 2,1} = 'Average:';
                Class1Table{numClass1 + 3,1} = 'Standard Deviation:';
                % element-wise enter features into cell
                if numClass1 ~=0
                    for i = 1:numClass1
                        for j = 1:10
                            Class1Table{i,j+2} = FeatsClass1(i,j);
                        end
                    end
                    for j = 1:10
                        Class1Table{numClass1 + 2,j+2} = AvgClass1(j);
                        Class1Table{numClass1 + 3,j+2} = StdClass1(j);
                    end
                end
                
                % Class 2 Table
                Class2Name = cell(1,NumFeats + 2);
                Class2Name{1} = 'Class 2';
                Class2Name{2} = 'Large, not Rhythmic';
                Class2Table = cell(numClass2 + 3,NumFeats + 2);
                Class2Table{1,1} = numClass2;
                Class2Table{1,2} = proportionClass2;
                Class2Table{numClass2 + 2,1} = 'Average:';
                Class2Table{numClass2 + 3,1} = 'Standard Deviation:';
                % element-wise enter features into cell
                if numClass2 ~=0
                    for i = 1:numClass2
                        for j = 1:10
                            Class2Table{i,j+2} = FeatsClass2(i,j);
                        end
                    end
                    for j = 1:10
                        Class2Table{numClass2 + 2,j+2} = AvgClass2(j);
                        Class2Table{numClass2 + 3,j+2} = StdClass2(j);
                    end
                end
                
                % Class 3 Table
                Class3Name = cell(1,NumFeats + 2);
                Class3Name{1} = 'Class 3';
                Class3Name{2} = 'Large, Rhythmic';
                Class3Table = cell(numClass3 + 3,NumFeats + 2);
                Class3Table{1,1} = numClass3;
                Class3Table{1,2} = proportionClass3;
                Class3Table{numClass3 + 2,1} = 'Average:';
                Class3Table{numClass3 + 3,1} = 'Standard Deviation:';
                % element-wise enter features into cell
                if numClass3 ~=0
                    for i = 1:numClass3
                        for j = 1:10
                            Class3Table{i,j+2} = FeatsClass3(i,j);
                        end
                    end
                    for j = 1:10
                        Class3Table{numClass3 + 2,j+2} = AvgClass3(j);
                        Class3Table{numClass3 + 3,j+2} = StdClass3(j);
                    end
                end
                
                % Class 4 Table
                Class4Name = cell(1,NumFeats + 2);
                Class4Name{1} = 'Class 4';
                Class4Name{2} = 'Multi-burst, Rhythmic';
                Class4Table = cell(numClass4 + 3,NumFeats + 2);
                Class4Table{1,1} = numClass4;
                Class4Table{1,2} = proportionClass4;
                Class4Table{numClass4 + 2,1} = 'Average:';
                Class4Table{numClass4 + 3,1} = 'Standard Deviation:';
                % element-wise enter features into cell
                if numClass4 ~=0
                    for i = 1:numClass4
                        for j = 1:10
                            Class4Table{i,j+2} = FeatsClass4(i,j);
                        end
                    end
                    for j = 1:10
                        Class4Table{numClass4 + 2,j+2} = AvgClass4(j);
                        Class4Table{numClass4 + 3,j+2} = StdClass4(j);
                    end
                end
                
                % Class 5 Table
                Class5Name = cell(1,NumFeats + 2);
                Class5Name{1} = 'Class 5';
                Class5Name{2} = 'Multi-burst, not Rhythmic';
                Class5Table = cell(numClass5 + 3,NumFeats + 2);
                Class5Table{1,1} = numClass5;
                Class5Table{1,2} = proportionClass5;
                Class5Table{numClass5 + 2,1} = 'Average:';
                Class5Table{numClass5 + 3,1} = 'Standard Deviation:';
                % element-wise enter features into cell
                if numClass5 ~=0
                    for i = 1:numClass5
                        for j = 1:10
                            Class5Table{i,j+2} = FeatsClass5(i,j);
                        end
                    end
                    for j = 1:10
                        Class5Table{numClass5 + 2,j+2} = AvgClass5(j);
                        Class5Table{numClass5 + 3,j+2} = StdClass5(j);
                    end
                end
                
                 ClassColumnName = {'# Instances','Proportion of Total (%)','Time from Previous',...
                    'Start to start','Duration','Peak Frequency','Bandwidth','Peak Power',...
                    'Max Amplitude','Avg Amplitude','Max Amplitude (%)','Avg Amplitude (%)',...
                    '  ','  ','  ','  ','  ','  ','  ','  '}; 
                ClassesTable = [Class1Name;ClassColumnName;Class1Table;Buffer;Class2Name;ClassColumnName;Class2Table;Buffer;...
                    Class3Name;ClassColumnName;Class3Table;Buffer;Class4Name;ClassColumnName;Class4Table;Buffer;...
                    Class5Name;ClassColumnName;Class5Table];
                % put it all together
                DetectedFeatures = [DetectedFeatures;ClassesTable];
                
                t = cell2table(DetectedFeatures); % make a table for saving
                saveFileName = strcat(filename,'_features','.xlsx'); % save to excel file
                writetable(t,saveFileName) % save all channels in file to singles spreadsheet
                % save to mat file as well
                matfilename = strcat(filename,'_table');
                save(matfilename,'Data','DataChan','detect','FiltSett','Header','SampleInterval','SepSett','StaticData','DetectedFeatures','t')
                a = msgbox('Data Exported to Excel!');
            catch
                warndlg('Error! Have features been extracted and episodes classified?')
            end
        end
        function detrendFunction(~,~)
            dataTrace = Data(:,DataChan); 
            [pickedx,~] = ginput;
            BP = round(pickedx*SampleFrequency,0);
            BPx = [1;BP;DataLength];
            for i = 1:length(BPx) 
                BPy(i) = dataTrace(BPx(i)); %#ok<*AGROW>
            end
            for i = 1:(length(BPx)-1)
                slope(i) = (BPy(i+1)-BPy(i))/double(BPx(i+1)-BPx(i));
            end
            DetrendData = [];
            for i = 1:length(slope)
                DataRegion = double(dataTrace(BPx(i):(BPx(i+1)-1))');
                timeRegion = double(BPx(i):(BPx(i+1)-1));
                slopeRegion = slope(i);
                Trendline = double(slopeRegion.*(timeRegion-BPx(i)))+BPy(i);
                timeRegion = timeRegion*1000; %#ok<*NASGU>
                newDataRegion = DataRegion - Trendline;
                DetrendData = horzcat(DetrendData,newDataRegion);
                newDataRegion = [];
            end
            DetrendData = horzcat(0,DetrendData)';
            Data(:,DataChan) = DetrendData; % overwrite data with detrended data
            delete(handles.PlotHandles)
            PlotData
        end
        function resetPlotFunction(~,~)
            Data(:,DataChan) = StaticData(:,DataChan);
            delete(handles.PlotHandles)
            PlotData
        end
        function graphBins(~,~)
            binTime = 0.01;                                 %length of each bin in seconds (used to find threshold over trace)
            binSize = floor(binTime*SampleFrequency);       %length of each bin in data points
            binNumber = floor(DataLength/binSize);          %number of bins
            %binMax is the max point in the bin
            binMax = zeros(binNumber,DataChannels); 
            thresholds = zeros(DataChannels,1);
            sortedBinsMatrix = [];
            for d = DataChan
                currentPoint = 1;
                for i=1:binNumber-1
                    binMax(i,d) = max(Data(currentPoint:currentPoint+binSize,d));
                    currentPoint = currentPoint+binSize;
                end
                sortedBins = sort(binMax(1:end,d));
                figure
                plot(linspace(0,100,numel(sortedBins)), sortedBins)
            end
        end
        
        function autoFeaturesFunction(~,~)  
            % ClassifyFlag = false; % reset for getting new episodes
            flatStart = str2double(get(handles.flatStartBox,'string'));     %minimum amplitude of signal baseline
            flatEnd = str2double(get(handles.flatEndBox,'string')); 
            upTime = str2double(get(handles.upTimeBox,'string'));
            downTime = str2double(get(handles.downTimeBox,'string'));
            episodeDuration = str2double(get(handles.episodeDurationBox,'string'));
            burstSTDMultiple = str2double(get(handles.burstSTDMultipleBox,'string'));
            episodeMultiple = str2double(get(handles.episodeSTDMultipleBox,'string'));
        
            % detection parameters number of points the signal must be above/below
            upDuration = upTime*2500; % 0.25 time signal must be higher than thresh to trigger episode detection
            downDuration = downTime*2500; % 0.25 time signal must fall below thresh to trigger end of episode
            durationThreshold = episodeDuration*2500; % 3 length of episode to trigger burst detector, generate second threshold for mult bursts
            % flatStart = 15 lower limit to define episode detection threshold (% of data range from sorted bins)
            % flatEnd = 30 upper limit to define episode detection threshold (% of data range from sorted bins)
            % burstSTDMultiple = 4 st dev of data b/w upper and lower limits of episode to define 2ndary thresh for mult burst
            % episodeMultiple = 4 st dev of data b/w upper and lower limits of episode to define primary thresh to detect episodes

            binTime = 0.01;                                 %length of each bin in seconds (used to find threshold over trace)
            binSize = floor(binTime*SampleFrequency);       %length of each bin in data points
            binNumber = floor(DataLength/binSize);          %number of bins
            flatStart = ceil(flatStart/100*binNumber);     %converts number from 0 to 100 range to 0 to binNumber
            flatEnd = floor(flatEnd/100*binNumber);

            binMax = zeros(binNumber,DataChan);
            thresholds = zeros(DataChan,1);
            sortedBinsMatrix = [];

            for d = DataChan
                currentPoint = 1;
                for i = 1:binNumber - 1
                    binMax(i,d) = [max(Data(currentPoint:currentPoint + binSize,d))]; %#ok<NBRAK> % find max data value in each bin
                    currentPoint = currentPoint + binSize;
                end
                sortedBins = sort(binMax(1:end,d));
                sortedBinsMatrix = [sortedBinsMatrix; sortedBins];
                %makes a threshold for each channel dependent on the average of the non
                %burst regions and their standard deviation
                thresholds(d) = mean(sortedBins(flatStart:flatEnd))+burstSTDMultiple*std(sortedBins(flatStart:flatEnd));
            end
            detectedholder = cell(DataChan,1);
            for d = DataChan
                binaryData = Data(1:end,d) > thresholds(d); %creats a matrix of 1s and 0s depending on whether the signal is above/below the threshold

                %resets the variables to be used in the next trace.
                i = 1;  
                downcount = 0;  
                detected = [];
                %will go through until the program reaches the end of the trace
                while i < length(Data)
                    %i is the location in the trace that only moves when this loop
                    %'re-loops', while t is the location that moves within the bursts
                    t = i;
                    %count is the length of the burst in datapoints
                    count = 0;

                    %in order for a burst to start, it must remain above the threshold
                    %for a certain amount of time
                    while count <= upDuration && binaryData(t) == 1
                        count = count + 1;
                        t = t + 1;
                        if t > length(Data)
                            break
                        end
                    end
                    %if the start of a burst is detected, keep moving along the trace
                    %until it remains below the threshold for a certain amount of time
                    if count >= upDuration
                       while downcount < downDuration
                            if t > length(Data)
                                break
                            end
                            if binaryData(t) == 1
                                count = count + downcount;
                                downcount = 0;
                                count = count + 1;
                                t = t + 1;
                            else
                                downcount = downcount + 1;
                                t = t + 1;
                            end
                       end
                       %if count is longer than durationThreshold check for multiple
                       %bursts within the larger event using a higher threshold
                       if count >= durationThreshold
                            newThreshold = episodeMultiple*thresholds(d);
                            tempDownCount = 0;
                            tempUpCount = 0;
                            start = [];
                            stop = [];
                            f = i;
                            %keep going as long as the trace stays within the detected
                            %event
                            while f < i + count
                                %look for start of burst based on new threshold
                                while tempUpCount <= upDuration && Data(f,d)>newThreshold
                                    tempUpCount = tempUpCount + 1;
                                    f = f + 1;
                                    if f > i + count || f > length(Data)
                                        break
                                    end
                                end
                                if tempUpCount > upDuration
                                    start = [start; f - tempUpCount];
                                    while tempDownCount < downDuration
                                        if f > i + count || f > length(Data)
                                            break
                                        end 

                                        if Data(f,d) >= newThreshold
                                            tempUpCount = tempUpCount + 1;
                                            tempUpCount = tempUpCount + tempDownCount;
                                            tempDownCount = 0;
                                            f = f + 1;
                                        else
                                            tempDownCount = tempDownCount + 1;
                                            f = f + 1;
                                        end
                                    end
                                    stop = [stop; f];
                                end
                                f = f + 1;
                                tempDownCount = 0;
                                tempUpCount = 0;
                            end
                            start(1) = i;
                            if isempty(stop)
                                stop = i + count;
                            else
                                stop(end) = i + count;
                            end
                            i = start; %#ok<*NASGU>
                            count = stop - start;
                       end
                       % get frequency component of data
                       episode = Data(i(1):(i(end)+count(end)));
                       L = length(episode);
                       Fepisode = fft(episode);
                       P2 = abs(Fepisode/L);
                       P1 = P2(1:round(L/2)+1);
                       P1(2:end-1) = 2*P1(2:end-1);
                       freq = SampleFrequency*(0:(L/2))/L;
                       approx10 = dsearchn(freq',10); % 10Hz cutoff
                       P1region = P1(1:approx10);
                       fregion = freq(1:approx10);
                       
                       if length(P1region) > 3 % if too short to get freq info, not an episode
                           pks = findpeaks(P1region);
                           for j = 1:length(pks)
                               ind(j) = find(P1 == pks(j));
                               freqComponents(j) = freq(ind(j));
                           end
                           maxpk = max(pks);
                           if isempty(maxpk)
                               pkfreq = 0;
                               BW = 10;
                               pkPower = 0;
                           else
                               pkfreq = freq(P1 == maxpk);
                               pkPower = maxpk;
                               BW = freqComponents(end) - freqComponents(1);
                           end
                       detected = [detected; [i(1) i(end)+count(end) i(1)/SampleFrequency (i(end)+count(end))/SampleFrequency ((i(end)+count(end))- i(1))/SampleFrequency pkfreq BW pkPower]];    
                       end
                    end
                    downcount = 0;
                    i = t + 10;
                end
                averageAmp = zeros(size(detected,1),1);
                maxAmp = zeros(size(detected,1),1);
                [numEp, ~] = size(detected);
                for z = 1:numEp % for each episode
                    averageAmp(z,1) = mean(Data(detected(z,1):detected(z,2) - 1,d));
                    maxAmp(z,1) = max(Data(detected(z,1):detected(z,2) - 1,d));
                end
                detected = [detected(1:end,1:2) detected(1:end,3:end)];
                detected = [detected maxAmp averageAmp];
                detectedholder{d} = detected; % each cell has info for each channel of recorded data

                % add amp as % of max amp from whole trace
                maxAmpVector = detected(:,9); 
                maxAll = max(maxAmpVector);
                avgAmpVector = detected(:,10);
                maxAmpPercent = (maxAmpVector/maxAll)*100;
                avgAmpPercent = (avgAmpVector/maxAll)*100;
                detected = [detected maxAmpPercent avgAmpPercent];

                % add start-start and time from previous episode to detected features
                % Move duration and following features 2 columns over
                detectedholder = detected;
                detected(:,5:end) = [];
                % time from previous, start to start
                for a = 2:size(detected,1)
                    detected(a,5) = detected(a,3) - detected(a-1,4); % current start - prev end
                    detected(a,6) = detected(a,3) - detected(a-1,3); % current start - prev start
                end
                detected = [detected detectedholder(:,5:end)];
                detect{DataChan} = detected;
            end
            %remove episodes with too small of a duration (false detections)
            duration = detect{DataChan}(:,7);
            shortD = find(duration <= 0.95); % find short duration episodes
            for i = 1:length(shortD)
                detect{DataChan}(shortD(end-i+1),:) = []; % remove short episodes
            end
            detect{DataChan}(:,15:18) = -1;
            flatStart = str2double(get(handles.flatStartBox,'string'));     %minimum amplitude of signal baseline
            flatEnd = str2double(get(handles.flatEndBox,'string')); 
            upTime = str2double(get(handles.upTimeBox,'string'));
            downTime = str2double(get(handles.downTimeBox,'string'));
            episodeDuration = str2double(get(handles.episodeDurationBox,'string'));
            burstSTDMultiple = str2double(get(handles.burstSTDMultipleBox,'string'));
            episodeMultiple = str2double(get(handles.episodeSTDMultipleBox,'string'));
            
            settings = [flatStart,flatEnd,upTime,downTime,episodeDuration,burstSTDMultiple,episodeMultiple];
            SepSett{DataChan} = settings;
            ext = '_detect';
            detectFileName = strcat(filename,ext);
            save(detectFileName,'Data','SampleInterval','Header','SepSett','detect','FiltSett','StaticData','DataChan') 
            a = msgbox('Features Extracted!');
        end

        function manualFeaturesFunction(~,~)
%             ClassifyFlag = false; % reset for getting new episodes
            [pickedx,~] = ginput;
            episodeBoundary = round(pickedx*SampleFrequency,0);
            Estart = [];
            Eend = [];
            for i = 1:length(episodeBoundary)
                if rem(i,2)
                    Estart = [Estart,episodeBoundary(i)];
                else
                    Eend = [Eend,episodeBoundary(i)];
                end
            end
            dataTrace = Data(:,DataChan);
            detected = [];
            for i = 1:length(Estart)  % for each episode
                   episode = double(dataTrace((Estart(i)):(Eend(i))));
                   L = length(episode);
                   Fepisode = fft(episode);
                   P2 = abs(Fepisode/L);
                   P1 = P2(1:round(L/2)+1);
                   P1(2:end-1) = 2*P1(2:end-1);
                   freq = SampleFrequency*(0:(L/2))/L;
                   approx10 = dsearchn(freq',10); % 10Hz cutoff
                   P1region = P1(1:approx10);
                   fregion = freq(1:approx10);
                   pks = findpeaks(P1region);
                   for j = 1:length(pks)
                       ind(j) = find(P1 == pks(j));
                       freqComponents(j) = freq(ind(j));
                   end
                %        figure
                %        plot(fregion,P1region')
                   maxpk = max(pks);
                %             maxpk = [];
                   if isempty(maxpk)
                       pkfreq = 0;
                       BW = 10;
                   else
                       pkfreq = freq(P1 == maxpk);
                       pkPower = maxpk;
                       BW = freqComponents(end) - freqComponents(1);
                   end
                   detected = [detected; [Estart(i) Eend(i) Estart(i)/SampleFrequency Eend(i)/SampleFrequency (Eend(i) - Estart(i))/SampleFrequency pkfreq BW pkPower]];    
            end
            averageAmp = zeros(size(detected,1),1);
            maxAmp = zeros(size(detected,1),1);
            numEps = size(detected,1);
            for z = 1:numEps
                averageAmp(z,1) = mean(DetrendData(detected(z,1):detected(z,2) - 1));
                maxAmp(z,1) = max(DetrendData(detected(z,1):detected(z,2) - 1));
            end
            detected = [detected maxAmp averageAmp];
            % add amp as % of max amp from whole trace
            maxAmpVector = detected(:,9); 
            maxAll = max(maxAmpVector);
            avgAmpVector = detected(:,10);
            maxAmpPercent = (maxAmpVector/maxAll)*100;
            avgAmpPercent = (avgAmpVector/maxAll)*100;
            detected = [detected maxAmpPercent avgAmpPercent]; 
            detect{DataChan} = detected;
            ext = '_manualdetect';
            manualdetectFileName = strcat(filename,ext);
            save(manualdetectFileName,'Data','SampleInterval','Header','SepSett','detect','FiltSett','StaticData','DataChan')
        end

        function showEpisodes(~,~,vargin)
            if vargin == 1
                try 
                    feature = detect{DataChan};
                    patches = zeros(DataChannels,1);
                    X = [];
                    Y = [];
                    C = [];
                    [r,~] = size(feature);
                    for j = 1:r
                        X = [X [round(feature(j,3),0); round(feature(j,3)); round(feature(j,4)); round(feature(j,4))]];
                        height = get(handles.RedLines(DataChan), 'ydata');
                        Y = [Y [height(1); height(2); height(2); height(1)]];
                        C = [C [0;0;0;0.1]];
                    end
                    patches(DataChan) = patch(X,Y,C,'FaceAlpha',0.15,'FaceColor','Flat',...
                        'EdgeAlpha',0,'Parent', handles.PlotHandles(DataChan));
                catch
                    warndlg('No episodes have been detected!')
                end
            elseif vargin == 2
                try
                    delete(patches(DataChan)) 
                catch
                end
            end
        end
        
        %SliderPanel is the center/right bottom panel in the GUI window.
        %Contains the slider to move the data left/right in thier plots and
        %a zoom/unzoom button.
        function SliderPanel
            %creates the panel at the bottom
            handles.SliderPanel = uipanel('Parent',handles.MainWindow,...
                'Units','normalized',...
                'Position',[0.2 0 .8 0.05]);
            
            %creates the slider
            handles.HorizontalSlider = uicontrol('style','slide',...
                'unit','normalized',...
                'parent', handles.SliderPanel,...
                'position',[0.08 0.02 0.89 0.7],...
                'min',0,'max',MaxTime,'val',0,...
                'Visible', 'off',...
                'SliderStep',[0.01 0.01],...
                'callback', {@Slide, handles});
            %function that links the slider to the plots
            function Slide(~,~,~)
                    SliderLocation = get(handles.HorizontalSlider,'Value');   
                    set(handles.PlotHandles(DataChan), 'xlim',[SliderLocation SliderLocation+xRange]);
                    xLimits = get(handles.PlotHandles(DataChan), 'xlim');
                    if xLimits(2) > MaxTime
                        set(handles.PlotHandles(DataChan), 'xlim',[MaxTime-xRange MaxTime]);
                    end
                end
                
            %creates the xZoom button
            handles.xZoom = uicontrol('style','pushbutton',...
                'parent', handles.SliderPanel,...
                'units', 'normalized',...
                'position',[.04 0.4 0.02 0.5],...
                'string','>>',...
                'callback', {@xZoom});
            %function that is called when xZoom button is pushed
            function xZoom(~, ~)
            	set(handles.PlotHandles(DataChan), 'xlim', [xLimits(1)+0.1*xRange xLimits(2)-0.1*xRange]);
                xLimits = get(handles.PlotHandles(DataChan), 'xlim');
                xRange = xLimits(2)-xLimits(1);
                set(handles.HorizontalSlider, 'Value', xLimits(1), 'max', MaxTime-xRange);
                if (xLimits(2) < MaxTime || xLimits(1) > 0)
                	set(handles.HorizontalSlider, 'Visible', 'on');
                end
            end
            
            %creates the xUnZoom button
            handles.xUnZoom = uicontrol('style','pushbutton',...
                'parent', handles.SliderPanel,...
                'units', 'normalized',...
                'position',[.01 0.4 0.02 0.5],...
                'string','<<',...
                'callback', {@xUnZoom});
            %function that is called when xUnZoom button is pushed
            function xUnZoom(~, ~)
                newMaxVal = xLimits(2)+0.125*xRange;
                newMinVal = xLimits(1)-0.125*xRange;
                if (newMaxVal > MaxTime && newMinVal < 0)
                    set(handles.PlotHandles(DataChan), 'xlim', [0 MaxTime]);
                    set(handles.HorizontalSlider, 'Visible', 'off', 'Value',0);
                elseif newMaxVal > MaxTime
                    set(handles.PlotHandles(DataChan), 'xlim',[newMinVal MaxTime]);
                elseif newMinVal < 0
                    set(handles.PlotHandles(DataChan), 'xlim',[0 newMaxVal]);
                else
                    set(handles.PlotHandles(DataChan), 'xlim', [newMinVal newMaxVal]);
                end
                xLimits = get(handles.PlotHandles(DataChan), 'xlim');
                xRange = xLimits(2)-xLimits(1);
                SliderLocation = get(handles.HorizontalSlider, 'Value');
                if SliderLocation > (MaxTime-xRange)
                    set(handles.HorizontalSlider, 'Value', MaxTime-xRange);
                end
                set(handles.HorizontalSlider,'max', MaxTime-xRange);
                if (xLimits(1) <= 0 && xLimits(2) >= MaxTime)
                    set(handles.PlotHandles(DataChan), 'xlim', [0 MaxTime]);
                    set(handles.HorizontalSlider, 'Visible', 'off', 'Value',0);
                elseif xLimits(1)<0
                    set(handles.PlotHandles(DataChan), 'xlim', [0 1.1*xRange]);
                elseif xLimits(2)>MaxTime
                    set(handles.PlotHandles(DataChan), 'xlim', [MaxTime-1.1*xRange MaxTime]);
                end
            end
        end   
    end

    function PlotData
        xLimits = [0,MaxTime];                      %resets the domain of graph to original value
        xRange = MaxTime;                           %resets the domain of graph to original value
        handles.PlotHandles = zeros(DataChannels,1); %creates space for plot handles to go
        for i = DataChan 
            handles.PlotHandles(i) = axes('Parent',handles.PlotPanel(i));
            handles.PlotLineHandles(i) = line(PlotDomain(1:PlotSpacing:end),Data(1:PlotSpacing:end,i),'Parent',handles.PlotHandles(i));   %plot the data from a channel
            yLimits(i,:) = get(handles.PlotHandles(i),'ylim');
            handles.RedLines(i) = line([xRange*0.1 xRange*0.1], [yLimits(i,1) yLimits(i,2)],...             %draws the red line
            	'color', 'red','linewidth', 3,'ButtonDownFcn', @startRedDragFcn);
            RedCursorLocation=xRange*0.1; %innitial value of red line
            handles.GreenLines(i) = line([xRange*0.2 xRange*0.2], [yLimits(i,1) yLimits(i,2)],...       %draws the green line
                'color', 'green','linewidth', 3,'ButtonDownFcn', @startGreenDragFcn);
            GreenCursorLocation = xRange*0.2;                  %innitial value of green line
            title(sprintf('Channel %d',i))          %labels what channel was plotted
            xlabel('Time (s)')
            ylabel('Amplitude (V)')
            hold off
        end
        
        %Starts the Red cursor. Is activated once the red cursor has been clicked on.
        function startRedDragFcn(varargin)
        	set(handles.MainWindow,'WindowButtonMotionFcn',@redDraggingFcn)
        end
        %makes the red cursor follow the mouse.
        function redDraggingFcn(~, ~, ~)
            for i = DataChan
            	RedCursorLocation = get(handles.PlotHandles(i),'currentpoint');
                RedCursorLocation = RedCursorLocation(1);
             	set(handles.RedLines(i), 'XData', RedCursorLocation(1)*[1 1]);
            end
        end
        
        % Starts the Green cursor. Is activated once the green cursor has been clicked on
        function startGreenDragFcn(varargin)
            set(handles.MainWindow, 'WindowButtonMotionFcn', @greenDraggingFcn)
        end
        %makes the green cursor follow the mouse.
        function greenDraggingFcn(~, ~, ~)
            for i = DataChan
                GreenCursorLocation = get(handles.PlotHandles(i), 'currentpoint');  
                GreenCursorLocation = GreenCursorLocation(1);
                set(handles.GreenLines(i), 'XData', GreenCursorLocation(1)*[1 1])
            end
        end
%         linkaxes(handles.PlotHandles,'x');          %links x limits together 
        
        set(handles.MainWindow, 'WindowButtonUpFcn', @stopDragFcn);         %used when user releases the mouse from one of the cursor lines
        function stopDragFcn(varargin)
            set(handles.MainWindow, 'WindowButtonMotionFcn','');
        end        
        drawnow;                                    %refreshes the window
    end
end

function g = sigmoid(z)
%SIGMOID Compute the logarithmic sigmoid functoon
%   J = SIGMOID(z) computes the sigmoid of z.
    g = 1.0 ./ (1.0 + exp(-z));
end

%everything below this point is apart of the function that converts the
%data from abf format to matricies
%from    http://www.mathworks.com/matlabcentral/fileexchange/6190-abfload
function [d,si,h] = abfload(fn,varargin)
% ** function [d,si,h]=abfload(fn,varargin)
% loads and returns data in ABF (Axon Binary File) format.
% Data may have been acquired in the following modes:
% (1) event-driven variable-length (currently only abf versions < 2.0)
% (2) event-driven fixed-length or waveform-fixed length
% (3) gap-free
% Information about scaling, the time base and the number of channels and 
% episodes is extracted from the header of the abf file.
%
% OPERATION
% If the second input variable is the char array 'info' as in 
%         [d,si,h]=abfload('d:\data01.abf','info') 
% abfload will not load any data but return detailed information (header
% parameters) on the file in output variable h. d and si will be empty.
% In all other cases abfload will load data. Optional input parameters
% listed below (= all except the file name) must be specified as
% parameter/value pairs, e.g. as in 
%         d=abfload('d:\data01.abf','start',100,'stop','e');
%
% >>> INPUT VARIABLES >>>
% NAME        TYPE, DEFAULT      DESCRIPTION
% fn          char array         abf data file name
% start       scalar, 0          only gap-free-data: start of cutout to be 
%                                 read (unit: s)
% stop        scalar or char,    only gap-free-data: end of cutout to be  
%             'e'                 read (unit: sec). May be set to 'e' (end 
%                                 of file).
% sweeps      1d-array or char,  only episodic data: sweep numbers to be 
%             'a'                 read. By default, all sweeps will be read
%                                 ('a').
% channels    cell array         names of channels to be read, like 
%              or char, 'a'       {'IN 0','IN 8'} (make sure spelling is
%                                 100% correct, including blanks). If set 
%                                 to 'a', all channels will be read. 
%                                 *****************************************
%                                 NOTE: channel order in output variable d
%                                 ignores the order in 'channels', and
%                                 instead always matches the order inherent
%                                 to the abf file, to be retrieved in
%                                 output variable h!
%                                 *****************************************
% chunk       scalar, 0.05       only gap-free-data: the elementary chunk  
%                                 size (megabytes) to be used for the 
%                                 'discontinuous' mode of reading data 
%                                 (fewer channels to be read than exist)
% machineF    char array,        the 'machineformat' input parameter of the
%              'ieee-le'          matlab fopen function. 'ieee-le' is the 
%                                 correct option for windows; depending on 
%                                 the platform the data were recorded/shall
%                                 be read by abfload 'ieee-be' is the 
%                                 alternative.
% << OUTPUT VARIABLES <<<
% NAME  TYPE            DESCRIPTION
% d                     the data read, the format depending on the record-
%                        ing mode
%   1. GAP-FREE:
%   2d array        2d array of size 
%                    <data pts> by <number of chans>
%                    Examples of access:
%                    d(:,2)       data from channel 2 at full length
%                    d(1:100,:)   first 100 data points from all channels
%   2. EPISODIC FIXED-LENGTH/WAVEFORM FIXED-LENGTH/HIGH-SPEED OSCILLOSCOPE:
%   3d array        3d array of size 
%                    <data pts per sweep> by <number of chans> by <number 
%                    of sweeps>.
%                    Examples of access:
%                    d(:,2,:)            a matrix containing all episodes 
%                                        (at full length) of the second 
%                                        channel in its columns
%                    d(1:200,:,[1 11])   contains first 200 data points of 
%                                        episodes 1 and 11 of all channels
%   3. EPISODIC VARIABLE-LENGTH:
%   cell array      cell array whose elements correspond to single sweeps. 
%                    Each element is a (regular) array of size
%                    <data pts per sweep> by <number of chans>
%                    Examples of access:
%                    d{1}            a 2d-array which contains episode 1 
%                                    (all of it, all channels)
%                    d{2}(1:100,2)   a 1d-array containing the first 100
%                                    data points of channel 2 in episode 1
% si    scalar           the sampling interval in us
% h     struct           information on file (selected header parameters)
% 
% CONTRIBUTORS
%   Original version by Harald Hentschke (harald.hentschke@uni-tuebingen.de)
%   Extended to abf version 2.0 by Forrest Collman (fcollman@Princeton.edu)
%   pvpmod.m by Ulrich Egert (egert@bccn.uni-freiburg.de)
%   Date of this version: Aug 1, 2012

% PROBLEM CASE REPORTS
% + June 2011:
% In one specific case, a user recorded data with a recording protocol that
% may have been set up originally with pClamp 9.x. In this protocol,
% amplification of the signal via a Cyberamp (the meanwhile out-of-date
% analog programmable signal conditioner of Axon Instruments) had been set
% to 200. Internally, this registers as a value of 200 of parameter
% h.fSignalGain. However, over the years, the setup changed, the Cyberamp
% went, pClamp10 came, and the protocol was in all likelihood just adapted,
% leaving h.fSignalGain at 200 (and the data values produced by abfload too
% small by that factor) although the thing wasn't hooked up anymore.
% However, when openend in clampex, the data are properly scaled. So,
% either the axon programs ignore the values of h.fSignalGain (and
% h.fSignalOffset) or - more likely - there is a flag somewhere in the
% header structure that informs us about whether the gain shall apply
% (because the signal conditioner is connected) or not. At any rate,
% whenever you change hardware and/or software, better create the protocols
% from scratch.
%
% BUG FIXES
% + Aug 2012:
% The order of channels in input variable 'channel' is now ignored by
% abfload; instead, data is always put out according to the order inherent
% to the abf file (to be retrieved in header parameter h). In the previous
% version of abfload, specifying an order different from the inherent
% channel order could result in wrong scaling of the data (if the scaling
% differed between channels).

% -------------------------------------------------------------------------
%                       PART 1: check of input vars
% -------------------------------------------------------------------------
disp(['** ' mfilename])
% --- defaults   
% gap-free
start=0.0;
stop='e';
% episodic
sweeps='a';
% general
channels='a';
% the size of data chunks (see above) in Mb. 0.05 Mb is an empirical value
% which works well for abf with 6-16 channels and recording durations of 
% 5-30 min
chunk=0.05;
machineF='ieee-le';
verbose=1;
% if first and only optional input argument is string 'info' the user's
% request is to obtain information on the file (header parameters), so set
% flag accordingly
if nargin==2 && ischar(varargin{1}) && strcmp('info',varargin{1})
  doLoadData=false;
else
  doLoadData=true;
  % assign values of optional input parameters if any were given
  pvpmod(varargin);
end

% some constants
BLOCKSIZE=512;
% output variables
d=[]; 
si=[];
h=[];
if ischar(stop)
  if ~strcmpi(stop,'e')
    error('input parameter ''stop'' must be specified as ''e'' (=end of recording) or as a scalar');
  end
end
% check existence of file
if ~exist(fn,'file'),
  error(['could not find file ' fn]);
end

% -------------------------------------------------------------------------
%                       PART 2a: determine abf version
% -------------------------------------------------------------------------
disp(['opening ' fn '..']);
[fid,messg]=fopen(fn,'r',machineF);
if fid == -1,
  error(messg);
end
% on occasion, determine absolute file size
fseek(fid,0,'eof');
fileSz=ftell(fid);
fseek(fid,0,'bof');

% *** read value of parameter 'fFileSignature' (i.e. abf version) from header ***
sz=4;
[fFileSignature,n]=fread(fid,sz,'uchar=>char');
if n~=sz, %#ok<*NOCOL>
  fclose(fid);
  error('something went wrong reading value(s) for fFileSignature');
end
% rewind
fseek(fid,0,'bof');
% transpose
fFileSignature=fFileSignature';

% one of the first checks must be whether file signature is valid
switch fFileSignature
  case 'ABF ' % ** note the blank
    % ************************
    %     abf version < 2.0
    % ************************
  case 'ABF2'
    % ************************
    %     abf version >= 2.0
    % ************************
  otherwise
    error('unknown or incompatible file signature');
end

% -------------------------------------------------------------------------
%    PART 2b: define file information ('header' parameters) of interest
% -------------------------------------------------------------------------
% The list of header parameters created below (variable 'headPar') is
% derived from the abf version 1.8 header section. It is by no means
% exhaustive (i.e. there are many more parameters in abf files) but
% sufficient for proper upload, scaling and arrangement of data acquired
% under many conditons. Further below, these parameters will be made fields
% of struct h. h, which is also an output variable, is then used in PART 3,
% which does the actual job of uploading, scaling and rearranging the data.
% That part of the code relies on h having a certain set of fields
% irrespective of ABF version.
% Unfortunately, in the transition to ABF version 2.0 many of the header
% parameters were moved to different places within the abf file and/or
% given other names or completely restructured. In order for the code to
% work with pre- and post-2.0 data files, all parameters missing in the
% header must be gotten into h. This is accomplished in lines ~288 and
% following:
%     if h.fFileVersionNumber>=2
%       ...
% Furthermore,
% - h as an output from an ABF version < 2.0 file will not contain new
%   parameters introduced into the header like 'nCRCEnable'
% - h will in any case contain a few 'home-made' fields that have
%   proven to be useful. Some of them depend on the recording mode. Among
%   the more or less self-explanatory ones are
% -- si                   sampling interval
% -- recChNames           the names of all channels, e.g. 'IN 8',...
% -- dataPtsPerChan       sample points per channel
% -- dataPts              sample points in file
% -- recTime              recording start and stop time in seconds from
%                         midnight (millisecond resolution)
% -- sweepLengthInPts     sample points per sweep (one channel)
% -- sweepStartInPts      the start times of sweeps in sample points
%                         (from beginning of recording)


% define header proper depending on ABF version by call to local function 
headPar=define_header(fFileSignature);
% define all sections that there are
Sections=define_Sections;
% define a few of these (currently, only the TagInfo section is used for
% all versions of ABF, but that may change in the future)
ProtocolInfo=define_ProtocolInfo;
ADCInfo=define_ADCInfo;
TagInfo=define_TagInfo;

% -------------------------------------------------------------------------
%    PART 2c: read parameters of interest
% -------------------------------------------------------------------------
% convert headPar to struct
s=cell2struct(headPar,{'name','offs','numType','value'},2);
numOfParams=size(s,1);
clear tmp headPar;

% convert names in structure to variables and read value from header
for g=1:numOfParams
  if fseek(fid, s(g).offs,'bof')~=0,
    fclose(fid);
    error(['something went wrong locating ' s(g).name]);
  end
  sz=length(s(g).value);
  % use dynamic field names
  [h.(s(g).name),n]=fread(fid,sz,s(g).numType);
  if n~=sz,
    fclose(fid);
    error(['something went wrong reading value(s) for ' s(g).name]);
  end
end
% file signature needs to be transposed
h.fFileSignature=h.fFileSignature';
% several header parameters need a fix or version-specific refinement:
if strcmp(h.fFileSignature,'ABF2')
  % h.fFileVersionNumber needs to be converted from an array of integers to
  % a float
  h.fFileVersionNumber=h.fFileVersionNumber(4)+h.fFileVersionNumber(3)*.1...
    +h.fFileVersionNumber(2)*.001+h.fFileVersionNumber(1)*.0001;
  % convert ms to s
  h.lFileStartTime=h.uFileStartTimeMS*.001;
else
  % h.fFileVersionNumber is a float32 the value of which is sometimes a
  % little less than what it should be (e.g. 1.6499999 instead of 1.65)
  h.fFileVersionNumber=.001*round(h.fFileVersionNumber*1000);
  % in abf < 2.0 two parameters are needed to obtain the file start time
  % with millisecond precision - let's integrate both into parameter
  % lFileStartTime (unit: s) so that nFileStartMillisecs will not be needed
  h.lFileStartTime=h.lFileStartTime+h.nFileStartMillisecs*.001;
end

if h.fFileVersionNumber>=2
  % -----------------------------------------------------------------------
  % *** read file information that has moved from the header section to
  % other sections in ABF version >= 2.0 and assign selected values to
  % fields of 'generic' header variable h ***
  % -----------------------------------------------------------------------
  % --- read in the Sections
  Sects=cell2struct(Sections,{'name'},2);
  numOfSections=length(Sections);
  offset=76;
  % this creates all sections (ADCSection, ProtocolSection, etc.)
  for i=1:numOfSections
    eval([Sects(i).name '=ReadSectionInfo(fid,offset);']);
    offset=offset+4+4+8;
  end
  % --- read in the StringsSection and use some fields (to retrieve
  % information on the names of recorded channels and the units)
  fseek(fid,StringsSection.uBlockIndex*BLOCKSIZE,'bof');
  BigString=fread(fid,StringsSection.uBytes,'char');
  % this is a hack: determine where either of strings 'clampex',
  % 'clampfit', 'axoscope' or patchxpress' begin
  progString={'clampex','clampfit','axoscope','patchxpress'};
  goodstart=[];
  for i=1:numel(progString)
    goodstart=cat(1,goodstart,strfind(lower(char(BigString)'),progString{i}));
  end
  % if either none or more than one were found, we're likely in trouble
  if numel(goodstart)~=1
%    warning('problems in StringsSection');
  end
  BigString=BigString(goodstart(1):end)';
  stringends=find(BigString==0);
  stringends=[0 stringends];
  for i=1:length(stringends)-1
    Strings{i}=char(BigString(stringends(i)+1:stringends(i+1)-1));
  end
  h.recChNames=[];
  h.recChUnits=[];
  
  % --- read in the ADCSection & copy some values to header h
  for i=1:ADCSection.llNumEntries
    ADCsec(i)=ReadSection(fid,ADCSection.uBlockIndex*BLOCKSIZE+ADCSection.uBytes*(i-1),ADCInfo);
    ii=ADCsec(i).nADCNum+1;
    h.nADCSamplingSeq(i)=ADCsec(i).nADCNum;
    h.recChNames=strvcat(h.recChNames, Strings{ADCsec(i).lADCChannelNameIndex});
    unitsIndex=ADCsec(i).lADCUnitsIndex;
    if unitsIndex>0
        h.recChUnits=strvcat(h.recChUnits, Strings{ADCsec(i).lADCUnitsIndex});
    else
        h.recChUnits=strvcat(h.recChUnits,'');
    end
    h.nTelegraphEnable(ii)=ADCsec(i).nTelegraphEnable;
    h.fTelegraphAdditGain(ii)=ADCsec(i).fTelegraphAdditGain;
    h.fInstrumentScaleFactor(ii)=ADCsec(i).fInstrumentScaleFactor;
    h.fSignalGain(ii)=ADCsec(i).fSignalGain;
    h.fADCProgrammableGain(ii)=ADCsec(i).fADCProgrammableGain;
    h.fInstrumentOffset(ii)=ADCsec(i).fInstrumentOffset;
    h.fSignalOffset(ii)=ADCsec(i).fSignalOffset;
  end
  % --- read in the protocol section & copy some values to header h
  ProtocolSec=ReadSection(fid,ProtocolSection.uBlockIndex*BLOCKSIZE,ProtocolInfo);
  h.nOperationMode=ProtocolSec.nOperationMode;
  h.fSynchTimeUnit=ProtocolSec.fSynchTimeUnit;
  
  h.nADCNumChannels=ADCSection.llNumEntries;
  h.lActualAcqLength=DataSection.llNumEntries;
  h.lDataSectionPtr=DataSection.uBlockIndex;
  h.nNumPointsIgnored=0;
  % in ABF version < 2.0 h.fADCSampleInterval is the sampling interval
  % defined as
  %     1/(sampling freq*number_of_channels)
  % so divide ProtocolSec.fADCSequenceInterval by the number of
  % channels
  h.fADCSampleInterval=ProtocolSec.fADCSequenceInterval/h.nADCNumChannels;
  h.fADCRange=ProtocolSec.fADCRange;
  h.lADCResolution=ProtocolSec.lADCResolution;
  % --- in contrast to procedures with all other sections do not read the 
  % sync array section but rather copy the values of its fields to the
  % corresponding fields of h
  h.lSynchArrayPtr=SynchArraySection.uBlockIndex;
  h.lSynchArraySize=SynchArraySection.llNumEntries;
else
  % -------------------------------------------------------------------------
  % *** here, do the inverse: in ABF version<2 files extract information
  % from header variable h and place it in corresponding new section
  % variable(s)
  % -------------------------------------------------------------------------
  TagSection.llNumEntries=h.lNumTagEntries;
  TagSection.uBlockIndex=h.lTagSectionPtr;
  TagSection.uBytes=64;
end

% -------------------------------------------------------------------------
%    PART 2d: groom parameters & perform some plausibility checks
% -------------------------------------------------------------------------
if h.lActualAcqLength<h.nADCNumChannels,
  fclose(fid);
  error('less data points than sampled channels in file');
end
% the numerical value of all recorded channels (numbers 0..15)
recChIdx=h.nADCSamplingSeq(1:h.nADCNumChannels);
% the corresponding indices into loaded data d
recChInd=1:length(recChIdx);
if h.fFileVersionNumber<2
  % the channel names, e.g. 'IN 8' (for ABF version 2.0 these have been
  % extracted above at this point)
  h.recChNames=(reshape(char(h.sADCChannelName),10,16))';
  h.recChNames=h.recChNames(recChIdx+1,:);
  % same with signal units
  h.recChUnits=(reshape(char(h.sADCUnits),8,16))';
  h.recChUnits=h.recChUnits(recChIdx+1,:);
end
% convert to cell arrays
h.recChNames=deblank(cellstr(h.recChNames));
h.recChUnits=deblank(cellstr(h.recChUnits));

% check whether requested channels exist
chInd=[];
eflag=0;
if ischar(channels)
  if strcmp(channels,'a')
    chInd=recChInd;
  else
    fclose(fid);
    error('input parameter ''channels'' must either be a cell array holding channel names or the single character ''a'' (=all channels)');
  end
else
  [nil,chInd]=intersect(h.recChNames,channels); %#ok<*ASGLU>
  % ** index chInd must be sorted because intersect sorts h.recChNames
  % alphanumerically, which needs not necessarily correspond to the order
  % inherent in the abf file (e.g. if channels are named 'Lynx1 ... Lynx10
  % etc.)
  chInd=sort(chInd);
  if isempty(chInd)
    % set error flag to 1
    eflag=1;
  end
end
if eflag
  fclose(fid);
  disp('**** available channels:');
  disp(h.recChNames);
  disp(' ');
  disp('**** requested channels:');
  disp(channels);
  error('at least one of the requested channels does not exist in data file (see above)');
end
% display available channels if in info mode
if ~doLoadData
  disp('**** available channels:');
  disp(h.recChNames);
end

% gain of telegraphed instruments, if any
if h.fFileVersionNumber>=1.65
  addGain=h.nTelegraphEnable.*h.fTelegraphAdditGain;
  addGain(addGain==0)=1;
else
  addGain=ones(size(h.fTelegraphAdditGain));
end

% determine offset at which data start
switch h.nDataFormat
  case 0
    dataSz=2;  % bytes/point
    precision='int16';
  case 1
    dataSz=4;  % bytes/point
    precision='float32';
  otherwise
    fclose(fid);
    error('invalid number format');
end
headOffset=h.lDataSectionPtr*BLOCKSIZE+h.nNumPointsIgnored*dataSz;
% h.fADCSampleInterval is the TOTAL sampling interval
h.si=h.fADCSampleInterval*h.nADCNumChannels;
% assign same value to si, which is an output variable
si=h.si;
if ischar(sweeps) && sweeps=='a'
  nSweeps=h.lActualEpisodes;
  sweeps=1:h.lActualEpisodes;
else
  nSweeps=length(sweeps);
end

% determine time unit in synch array section
switch h.fSynchTimeUnit
  case 0  
    % time information in synch array section is in terms of ticks
    h.synchArrTimeBase=1;
  otherwise
    % time information in synch array section is in terms of usec
    h.synchArrTimeBase=h.fSynchTimeUnit;
end

% read in the TagSection, do a few computations & write to h.tags
h.tags=[];
for i=1:TagSection.llNumEntries
  tmp=ReadSection(fid,TagSection.uBlockIndex*BLOCKSIZE+TagSection.uBytes*(i-1),TagInfo);
  % time of tag entry from start of experiment in s (corresponding expisode
  % number, if applicable, will be determined later)
  h.tags(i).timeSinceRecStart=tmp.lTagTime*h.synchArrTimeBase/1e6;
  h.tags(i).comment=char(tmp.sComment)';
end

% -------------------------------------------------------------------------
%    PART 3: read data (note: from here on code is generic and abf version
%    should not matter)
% -------------------------------------------------------------------------
switch h.nOperationMode
  case 1
    disp('data were acquired in event-driven variable-length mode');
    if h.fFileVersionNumber>=2.0
      errordlg('abfload currently does not work with data acquired in event-driven variable-length mode and ABF version 2.0','ABF version issue');
    else
      if (h.lSynchArrayPtr<=0 || h.lSynchArraySize<=0),
        fclose(fid);
        error('internal variables ''lSynchArraynnn'' are zero or negative');
      end
      % the byte offset at which the SynchArraySection starts
      h.lSynchArrayPtrByte=BLOCKSIZE*h.lSynchArrayPtr;
      % before reading Synch Arr parameters check if file is big enough to hold them
      % 4 bytes/long, 2 values per episode (start and length)
      if h.lSynchArrayPtrByte+2*4*h.lSynchArraySize<fileSz,
        fclose(fid);
        error('file seems not to contain complete Synch Array Section');
      end
      if fseek(fid,h.lSynchArrayPtrByte,'bof')~=0,
        fclose(fid);
        error('something went wrong positioning file pointer to Synch Array Section');
      end
      [synchArr,n]=fread(fid,h.lSynchArraySize*2,'int32');
      if n~=h.lSynchArraySize*2,
        fclose(fid);
        error('something went wrong reading synch array section');
      end
      % make synchArr a h.lSynchArraySize x 2 matrix
      synchArr=permute(reshape(synchArr',2,h.lSynchArraySize),[2 1]);
      % the length of episodes in sample points
      segLengthInPts=synchArr(:,2)/h.synchArrTimeBase;
      % the starting ticks of episodes in sample points WITHIN THE DATA FILE
      segStartInPts=cumsum([0 (segLengthInPts(1:end-1))']*dataSz)+headOffset;
      % start time (synchArr(:,1)) has to be divided by h.nADCNumChannels to get true value
      % go to data portion
      if fseek(fid,headOffset,'bof')~=0,
        fclose(fid);
        error('something went wrong positioning file pointer (too few data points ?)');
      end
      % ** load data if requested
      if doLoadData
        for i=1:nSweeps,
          % if selected sweeps are to be read, seek correct position
          if ~isequal(nSweeps,h.lActualEpisodes),
            fseek(fid,segStartInPts(sweeps(i)),'bof');
          end
          [tmpd,n]=fread(fid,segLengthInPts(sweeps(i)),precision);
          if n~=segLengthInPts(sweeps(i)),
            warning(['something went wrong reading episode ' int2str(sweeps(i)) ': ' segLengthInPts(sweeps(i)) ' points should have been read, ' int2str(n) ' points actually read']);
          end
          h.dataPtsPerChan=n/h.nADCNumChannels;
          if rem(n,h.nADCNumChannels)>0,
            fclose(fid);
            error('number of data points in episode not OK');
          end
          % separate channels..
          tmpd=reshape(tmpd,h.nADCNumChannels,h.dataPtsPerChan);
          % retain only requested channels
          tmpd=tmpd(chInd,:);
          tmpd=tmpd';
          % if data format is integer, scale appropriately; if it's float, tmpd is fine
          if ~h.nDataFormat
            for j=1:length(chInd),
              ch=recChIdx(chInd(j))+1;
              tmpd(:,j)=tmpd(:,j)/(h.fInstrumentScaleFactor(ch)*h.fSignalGain(ch)*h.fADCProgrammableGain(ch)*addGain(ch))...
                *h.fADCRange/h.lADCResolution+h.fInstrumentOffset(ch)-h.fSignalOffset(ch);
            end
          end
          % now place in cell array, an element consisting of one sweep with channels in columns
          d{i}=tmpd;
        end
      end
    end
    
  case {2,4,5}
    if h.nOperationMode==2
      disp('data were acquired in event-driven fixed-length mode');
    elseif h.nOperationMode==4
      disp('data were acquired in high-speed oscilloscope mode');
    else
      disp('data were acquired in waveform fixed-length mode');
    end
    % extract timing information on sweeps
    if (h.lSynchArrayPtr<=0 || h.lSynchArraySize<=0),
      fclose(fid);
      error('internal variables ''lSynchArraynnn'' are zero or negative');
    end
    % the byte offset at which the SynchArraySection starts
    h.lSynchArrayPtrByte=BLOCKSIZE*h.lSynchArrayPtr;
    % before reading Synch Arr parameters check if file is big enough to hold them
    % 4 bytes/long, 2 values per episode (start and length)
    if h.lSynchArrayPtrByte+2*4*h.lSynchArraySize>fileSz,
      fclose(fid);
      error('file seems not to contain complete Synch Array Section');
    end
    if fseek(fid,h.lSynchArrayPtrByte,'bof')~=0,
      fclose(fid);
      error('something went wrong positioning file pointer to Synch Array Section');
    end
    [synchArr,n]=fread(fid,h.lSynchArraySize*2,'int32');
    if n~=h.lSynchArraySize*2,
      fclose(fid);
      error('something went wrong reading synch array section');
    end
    % make synchArr a h.lSynchArraySize x 2 matrix
    synchArr=permute(reshape(synchArr',2,h.lSynchArraySize),[2 1]);
    if numel(unique(synchArr(:,2)))>1
      fclose(fid);
      error('sweeps of unequal length in file recorded in fixed-length mode');
    end
    % the length of sweeps in sample points (**note: parameter lLength of
    % the ABF synch section is expressed in samples (ticks) whereas
    % parameter lStart is given in synchArrTimeBase units)
    h.sweepLengthInPts=synchArr(1,2)/h.nADCNumChannels;
    % the starting ticks of episodes in sample points (t0=1=beginning of
    % recording)
    h.sweepStartInPts=synchArr(:,1)*(h.synchArrTimeBase/h.fADCSampleInterval/h.nADCNumChannels);
    % recording start and stop times in seconds from midnight
    h.recTime=h.lFileStartTime;
    h.recTime=h.recTime+[0  (1e-6*(h.sweepStartInPts(end)+h.sweepLengthInPts))*h.fADCSampleInterval*h.nADCNumChannels];
    % determine first point and number of points to be read
    startPt=0;
    h.dataPts=h.lActualAcqLength;
    h.dataPtsPerChan=h.dataPts/h.nADCNumChannels;
    if rem(h.dataPts,h.nADCNumChannels)>0 || rem(h.dataPtsPerChan,h.lActualEpisodes)>0
      fclose(fid);
      error('number of data points not OK');
    end
    % temporary helper var
    dataPtsPerSweep=h.sweepLengthInPts*h.nADCNumChannels;
    if fseek(fid,startPt*dataSz+headOffset,'bof')~=0
      fclose(fid);
      error('something went wrong positioning file pointer (too few data points ?)');
    end
    d=zeros(h.sweepLengthInPts,length(chInd),nSweeps);
    % the starting ticks of episodes in sample points WITHIN THE DATA FILE
    selectedSegStartInPts=((sweeps-1)*dataPtsPerSweep)*dataSz+headOffset;
    % ** load data if requested
    if doLoadData
      for i = 1:nSweeps
        fseek(fid,selectedSegStartInPts(i),'bof');
        [tmpd,n]=fread(fid,dataPtsPerSweep,precision);
        if n~=dataPtsPerSweep,
          fclose(fid);
          error(['something went wrong reading episode ' int2str(sweeps(i)) ': ' dataPtsPerSweep ' points should have been read, ' int2str(n) ' points actually read']);
        end
        h.dataPtsPerChan=n/h.nADCNumChannels;
        if rem(n,h.nADCNumChannels)>0
          fclose(fid);
          error('number of data points in episode not OK');
        end
        % separate channels..
        tmpd=reshape(tmpd,h.nADCNumChannels,h.dataPtsPerChan);
        % retain only requested channels
        tmpd=tmpd(chInd,:);
        tmpd=tmpd';
        % if data format is integer, scale appropriately; if it's float, d is fine
        if ~h.nDataFormat
          for j=1:length(chInd),
            ch=recChIdx(chInd(j))+1;
            tmpd(:,j)=tmpd(:,j)/(h.fInstrumentScaleFactor(ch)*h.fSignalGain(ch)*h.fADCProgrammableGain(ch)*addGain(ch))...
              *h.fADCRange/h.lADCResolution+h.fInstrumentOffset(ch)-h.fSignalOffset(ch);
          end
        end
        % now fill 3d array
        d(:,:,i)=tmpd;
      end
    end
    
  case 3
    disp('data were acquired in gap-free mode');
    % from start, stop, headOffset and h.fADCSampleInterval calculate first point to be read
    %  and - unless stop is given as 'e' - number of points
    startPt=floor(1e6*start*(1/h.fADCSampleInterval));
    % this corrects undesired shifts in the reading frame due to rounding errors in the previous calculation
    startPt=floor(startPt/h.nADCNumChannels)*h.nADCNumChannels;
    % if stop is a char array, it can only be 'e' at this point (other values would have
    % been caught above)
    if ischar(stop),
      h.dataPtsPerChan=h.lActualAcqLength/h.nADCNumChannels-floor(1e6*start/h.si);
      h.dataPts=h.dataPtsPerChan*h.nADCNumChannels;
    else
      h.dataPtsPerChan=floor(1e6*(stop-start)*(1/h.si));
      h.dataPts=h.dataPtsPerChan*h.nADCNumChannels;
      if h.dataPts<=0
        fclose(fid);
        error('start is larger than or equal to stop');
      end
    end
    if rem(h.dataPts,h.nADCNumChannels)>0
      fclose(fid);
      error('number of data points not OK');
    end
    tmp=1e-6*h.lActualAcqLength*h.fADCSampleInterval;
    if verbose
      disp(['total length of recording: ' num2str(tmp,'%5.1f') ' s ~ ' num2str(tmp/60,'%3.0f') ' min']);
      disp(['sampling interval: ' num2str(h.si,'%5.0f') ' µs']);
      % 8 bytes per data point expressed in Mb
      disp(['memory requirement for complete upload in matlab: '...
        num2str(round(8*h.lActualAcqLength/2^20)) ' MB']);
    end
    % recording start and stop times in seconds from midnight
    h.recTime=h.lFileStartTime;
    h.recTime=[h.recTime h.recTime+tmp];
    if fseek(fid,startPt*dataSz+headOffset,'bof')~=0,
      fclose(fid);
      error('something went wrong positioning file pointer (too few data points ?)');
    end
    if doLoadData
      % *** decide on the most efficient way to read data:
      % (i) all (of one or several) channels requested: read, done
      % (ii) one (of several) channels requested: use the 'skip' feature of
      % fread
      % (iii) more than one but not all (of several) channels requested:
      % 'discontinuous' mode of reading data. Read a reasonable chunk of data
      % (all channels), separate channels, discard non-requested ones (if
      % any), place data in preallocated array, repeat until done. This is
      % faster than reading the data in one big lump, separating channels and
      % discarding the ones not requested
      if length(chInd)==1 && h.nADCNumChannels>1
        % --- situation (ii)
        % jump to proper reading frame position in file
        if fseek(fid,(chInd-1)*dataSz,'cof')~=0
          fclose(fid);
          error('something went wrong positioning file pointer (too few data points ?)');
        end
        % read, skipping h.nADCNumChannels-1 data points after each read
        [d,n]=fread(fid,h.dataPtsPerChan,precision,dataSz*(h.nADCNumChannels-1));
        if n~=h.dataPtsPerChan,
          fclose(fid);
          error(['something went wrong reading file (' int2str(h.dataPtsPerChan) ' points should have been read, ' int2str(n) ' points actually read']);
        end
      elseif length(chInd)/h.nADCNumChannels<1
        % --- situation (iii)
        % prepare chunkwise upload:
        % preallocate d
        d=repmat(nan,h.dataPtsPerChan,length(chInd));
        % the number of data points corresponding to the maximal chunk size,
        % rounded off such that from each channel the same number of points is
        % read (do not forget that each data point will by default be made a
        % double of 8 bytes, no matter what the original data format is)
        chunkPtsPerChan=floor(chunk*2^20/8/h.nADCNumChannels);
        chunkPts=chunkPtsPerChan*h.nADCNumChannels;
        % the number of those chunks..
        nChunk=floor(h.dataPts/chunkPts);
        % ..and the remainder
        restPts=h.dataPts-nChunk*chunkPts;
        restPtsPerChan=restPts/h.nADCNumChannels;
        % chunkwise row indices into d
        dix=(1:chunkPtsPerChan:h.dataPtsPerChan)';
        dix(:,2)=dix(:,1)+chunkPtsPerChan-1;
        dix(end,2)=h.dataPtsPerChan;
        if verbose && nChunk
          disp(['reading file in ' int2str(nChunk) ' chunks of ~' num2str(chunk) ' Mb']);
        end
        % do it: if no remainder exists loop through all rows of dix,
        % otherwise spare last row for the lines below (starting with
        % 'if restPts')
        for ci=1:size(dix,1)-(restPts>0)
          [tmpd,n]=fread(fid,chunkPts,precision);
          if n~=chunkPts
            fclose(fid);
            error(['something went wrong reading chunk #' int2str(ci) ' (' ...
              int2str(chunkPts) ' points should have been read, ' int2str(n) ' points actually read']);
          end
          % separate channels..
          tmpd=reshape(tmpd,h.nADCNumChannels,chunkPtsPerChan);
          d(dix(ci,1):dix(ci,2),:)=tmpd(chInd,:)';
        end
        % collect the rest, if any
        if restPts
          [tmpd,n]=fread(fid,restPts,precision);
          if n~=restPts
            fclose(fid);
            error(['something went wrong reading last chunk (' ...
              int2str(restPts) ' points should have been read, ' int2str(n) ' points actually read']);
          end
          % separate channels..
          tmpd=reshape(tmpd,h.nADCNumChannels,restPtsPerChan);
          d(dix(end,1):dix(end,2),:)=tmpd(chInd,:)';
        end
      else
        % --- situation (i)
        [d,n]=fread(fid,h.dataPts,precision);
        if n~=h.dataPts,
          fclose(fid);
          error(['something went wrong reading file (' int2str(h.dataPts) ' points should have been read, ' int2str(n) ' points actually read']);
        end
        % separate channels..
        d=reshape(d,h.nADCNumChannels,h.dataPtsPerChan);
        d=d';
      end
      % if data format is integer, scale appropriately; if it's float, d is fine
      if ~h.nDataFormat
        for j=1:length(chInd),
          ch=recChIdx(chInd(j))+1;
          d(:,j)=d(:,j)/(h.fInstrumentScaleFactor(ch)*h.fSignalGain(ch)*h.fADCProgrammableGain(ch)*addGain(ch))...
            *h.fADCRange/h.lADCResolution+h.fInstrumentOffset(ch)-h.fSignalOffset(ch);
        end
      end
    end
  otherwise
    disp('unknown recording mode -- returning empty matrix');
    d=[];
    h.si=[];
end
fclose(fid);

% finally, possibly add information on episode number to tags
if ~isempty(h.tags) && isfield(h,'sweepStartInPts')
  for i=1:numel(h.tags)
    tmp=find(h.tags(i).timeSinceRecStart>=h.sweepStartInPts/1e6*h.si);
    if ~isempty(tmp) % added this b/c errors with waveform fixed-length mode
        h.tags(i).episodeIndex=tmp(end);
    end
  end
end
end


% ########################################################################
%                         LOCAL FUNCTIONS
% ########################################################################

function headPar=define_header(fileSig)
switch fileSig
 case 'ABF ' % ** note the blank
   % ************************
   %     abf version < 2.0
   % ************************
   %
   % temporary initializing var
   tmp=repmat(-1,1,16);
   % define vital header parameters and initialize them with -1: set up a
   % cell array (and convert it to a struct later on, which is more
   % convenient)
   % column order is
   %    name, position in header in bytes, type, value)
   headPar={
     'fFileSignature',0,'*char',[-1 -1 -1 -1];
     'fFileVersionNumber',4,'float32',-1;
     'nOperationMode',8,'int16',-1;
     'lActualAcqLength',10,'int32',-1;
     'nNumPointsIgnored',14,'int16',-1;
     'lActualEpisodes',16,'int32',-1;
     'lFileStartTime',24,'int32',-1;
     'lDataSectionPtr',40,'int32',-1;
     'lTagSectionPtr',44,'int32',-1;
     'lNumTagEntries',48,'int32',-1;
     'lSynchArrayPtr',92,'int32',-1;
     'lSynchArraySize',96,'int32',-1;
     'nDataFormat',100,'int16',-1;
     'nADCNumChannels', 120, 'int16', -1;
     'fADCSampleInterval',122,'float', -1;
     'fSynchTimeUnit',130,'float',-1;
     'lNumSamplesPerEpisode',138,'int32',-1;
     'lPreTriggerSamples',142,'int32',-1;
     'lEpisodesPerRun',146,'int32',-1;
     'fADCRange', 244, 'float', -1;
     'lADCResolution', 252, 'int32', -1;
     'nFileStartMillisecs', 366, 'int16', -1;
     'nADCPtoLChannelMap', 378, 'int16', tmp;
     'nADCSamplingSeq', 410, 'int16',  tmp;
     'sADCChannelName',442, 'uchar', repmat(tmp,1,10);
     'sADCUnits',602, 'uchar', repmat(tmp,1,8);
     'fADCProgrammableGain', 730, 'float', tmp;
     'fInstrumentScaleFactor', 922, 'float', tmp;
     'fInstrumentOffset', 986, 'float', tmp;
     'fSignalGain', 1050, 'float', tmp;
     'fSignalOffset', 1114, 'float', tmp;
     'nTelegraphEnable',4512,'int16',tmp;
     'fTelegraphAdditGain',4576,'float',tmp
     };
 case 'ABF2'
   % ************************
   %     abf version >= 2.0
   % ************************
   headPar={
     'fFileSignature',0,'*char',[-1 -1 -1 -1];
     'fFileVersionNumber',4,'bit8=>int',[-1 -1 -1 -1];
     'uFileInfoSize',8,'uint32',-1;
     'lActualEpisodes',12,'uint32',-1;
     'uFileStartDate',16','uint32',-1;
     'uFileStartTimeMS',20,'uint32',-1;
     'uStopwatchTime',24,'uint32',-1;
     'nFileType',28,'int16',-1;
     'nDataFormat',30,'int16',-1;
     'nSimultaneousScan',32,'int16',-1;
     'nCRCEnable',34,'int16',-1;
     'uFileCRC',36,'uint32',-1;
     'FileGUID',40,'uint32',-1;
     'uCreatorVersion',56,'uint32',-1;
     'uCreatorNameIndex',60,'uint32',-1;
     'uModifierVersion',64,'uint32',-1;
     'uModifierNameIndex',68,'uint32',-1;
     'uProtocolPathIndex',72,'uint32',-1;
     };
end
end

function Sections=define_Sections
Sections={'ProtocolSection';
 'ADCSection';
 'DACSection';
 'EpochSection';
 'ADCPerDACSection';
 'EpochPerDACSection';
 'UserListSection';
 'StatsRegionSection';
 'MathSection';
 'StringsSection';
 'DataSection';
 'TagSection';
 'ScopeSection';
 'DeltaSection';
 'VoiceTagSection';
 'SynchArraySection';
 'AnnotationSection';
 'StatsSection';
 };
end

function ProtocolInfo=define_ProtocolInfo
ProtocolInfo={
 'nOperationMode','int16',1;
 'fADCSequenceInterval','float',1;
 'bEnableFileCompression','bit1',1;
 'sUnused1','char',3;
 'uFileCompressionRatio','uint32',1;
 'fSynchTimeUnit','float',1;
 'fSecondsPerRun','float',1;
 'lNumSamplesPerEpisode','int32',1;
 'lPreTriggerSamples','int32',1;
 'lEpisodesPerRun','int32',1;
 'lRunsPerTrial','int32',1;
 'lNumberOfTrials','int32',1;
 'nAveragingMode','int16',1;
 'nUndoRunCount','int16',1;
 'nFirstEpisodeInRun','int16',1;
 'fTriggerThreshold','float',1;
 'nTriggerSource','int16',1;
 'nTriggerAction','int16',1;
 'nTriggerPolarity','int16',1;
 'fScopeOutputInterval','float',1;
 'fEpisodeStartToStart','float',1;
 'fRunStartToStart','float',1;
 'lAverageCount','int32',1;
 'fTrialStartToStart','float',1;
 'nAutoTriggerStrategy','int16',1;
 'fFirstRunDelayS','float',1;
 'nChannelStatsStrategy','int16',1;
 'lSamplesPerTrace','int32',1;
 'lStartDisplayNum','int32',1;
 'lFinishDisplayNum','int32',1;
 'nShowPNRawData','int16',1;
 'fStatisticsPeriod','float',1;
 'lStatisticsMeasurements','int32',1;
 'nStatisticsSaveStrategy','int16',1;
 'fADCRange','float',1;
 'fDACRange','float',1;
 'lADCResolution','int32',1;
 'lDACResolution','int32',1;
 'nExperimentType','int16',1;
 'nManualInfoStrategy','int16',1;
 'nCommentsEnable','int16',1;
 'lFileCommentIndex','int32',1;
 'nAutoAnalyseEnable','int16',1;
 'nSignalType','int16',1;
 'nDigitalEnable','int16',1;
 'nActiveDACChannel','int16',1;
 'nDigitalHolding','int16',1;
 'nDigitalInterEpisode','int16',1;
 'nDigitalDACChannel','int16',1;
 'nDigitalTrainActiveLogic','int16',1;
 'nStatsEnable','int16',1;
 'nStatisticsClearStrategy','int16',1;
 'nLevelHysteresis','int16',1;
 'lTimeHysteresis','int32',1;
 'nAllowExternalTags','int16',1;
 'nAverageAlgorithm','int16',1;
 'fAverageWeighting','float',1;
 'nUndoPromptStrategy','int16',1;
 'nTrialTriggerSource','int16',1;
 'nStatisticsDisplayStrategy','int16',1;
 'nExternalTagType','int16',1;
 'nScopeTriggerOut','int16',1;
 'nLTPType','int16',1;
 'nAlternateDACOutputState','int16',1;
 'nAlternateDigitalOutputState','int16',1;
 'fCellID','float',3;
 'nDigitizerADCs','int16',1;
 'nDigitizerDACs','int16',1;
 'nDigitizerTotalDigitalOuts','int16',1;
 'nDigitizerSynchDigitalOuts','int16',1;
 'nDigitizerType','int16',1;
 };
end

function ADCInfo=define_ADCInfo
ADCInfo={
 'nADCNum','int16',1;
 'nTelegraphEnable','int16',1;
 'nTelegraphInstrument','int16',1;
 'fTelegraphAdditGain','float',1;
 'fTelegraphFilter','float',1;
 'fTelegraphMembraneCap','float',1;
 'nTelegraphMode','int16',1;
 'fTelegraphAccessResistance','float',1;
 'nADCPtoLChannelMap','int16',1;
 'nADCSamplingSeq','int16',1;
 'fADCProgrammableGain','float',1;
 'fADCDisplayAmplification','float',1;
 'fADCDisplayOffset','float',1;
 'fInstrumentScaleFactor','float',1;
 'fInstrumentOffset','float',1;
 'fSignalGain','float',1;
 'fSignalOffset','float',1;
 'fSignalLowpassFilter','float',1;
 'fSignalHighpassFilter','float',1;
 'nLowpassFilterType','char',1;
 'nHighpassFilterType','char',1;
 'fPostProcessLowpassFilter','float',1;
 'nPostProcessLowpassFilterType','char',1;
 'bEnabledDuringPN','bit1',1;
 'nStatsChannelPolarity','int16',1;
 'lADCChannelNameIndex','int32',1;
 'lADCUnitsIndex','int32',1;
 };
end

function TagInfo=define_TagInfo
TagInfo={
   'lTagTime','int32',1;
   'sComment','char',56;
   'nTagType','int16',1;
   'nVoiceTagNumber_or_AnnotationIndex','int16',1;
};
end

function Section = ReadSection(fid,offset,Format) %#ok<STOUT>
s=cell2struct(Format,{'name','numType','number'},2);
fseek(fid,offset,'bof');
for i=1:length(s)
 eval(['[Section.' s(i).name ',n]=fread(fid,' num2str(s(i).number) ',''' s(i).numType ''');']);
end
end

function SectionInfo = ReadSectionInfo(fid,offset) %#ok<DEFNU>
fseek(fid,offset,'bof');
SectionInfo.uBlockIndex=fread(fid,1,'uint32');
fseek(fid,offset+4,'bof');
SectionInfo.uBytes=fread(fid,1,'uint32');
fseek(fid,offset+8,'bof');
SectionInfo.llNumEntries=fread(fid,1,'int64');
end

function pvpmod(x)
% PVPMOD             - evaluate parameter/value pairs
% pvpmod(x) assigns the value x(i+1) to the parameter defined by the
% string x(i) in the calling workspace. This is useful to evaluate 
% <varargin> contents in an mfile, e.g. to change default settings 
% of any variable initialized before pvpmod(x) is called.
%
% (c) U. Egert 1998

% this loop is assigns the parameter/value pairs in x to the calling
% workspace.
    if ~isempty(x)
      for i = 1:2:size(x,2)
         assignin('caller', x{i}, x{i+1});
      end
    end
end


% 
% struct ABF_FileInfo
% {
%    UINT  uFileSignature;
%    UINT  uFileVersionNumber;
% 
%    // After this point there is no need to be the same as the ABF 1 equivalent.
%    UINT  uFileInfoSize;
% 
%    UINT  uActualEpisodes;
%    UINT  uFileStartDate;
%    UINT  uFileStartTimeMS;
%    UINT  uStopwatchTime;
%    short nFileType;
%    short nDataFormat;
%    short nSimultaneousScan;
%    short nCRCEnable;
%    UINT  uFileCRC;
%    GUID  FileGUID;
%    UINT  uCreatorVersion;
%    UINT  uCreatorNameIndex;
%    UINT  uModifierVersion;
%    UINT  uModifierNameIndex;
%    UINT  uProtocolPathIndex;   
% 
%    // New sections in ABF 2 - protocol stuff ...
%    ABF_Section ProtocolSection;           // the protocol
%    ABF_Section ADCSection;                // one for each ADC channel
%    ABF_Section DACSection;                // one for each DAC channel
%    ABF_Section EpochSection;              // one for each epoch
%    ABF_Section ADCPerDACSection;          // one for each ADC for each DAC
%    ABF_Section EpochPerDACSection;        // one for each epoch for each DAC
%    ABF_Section UserListSection;           // one for each user list
%    ABF_Section StatsRegionSection;        // one for each stats region
%    ABF_Section MathSection;
%    ABF_Section StringsSection;
% 
%    // ABF 1 sections ...
%    ABF_Section DataSection;            // Data
%    ABF_Section TagSection;             // Tags
%    ABF_Section ScopeSection;           // Scope config
%    ABF_Section DeltaSection;           // Deltas
%    ABF_Section VoiceTagSection;        // Voice Tags
%    ABF_Section SynchArraySection;      // Synch Array
%    ABF_Section AnnotationSection;      // Annotations
%    ABF_Section StatsSection;           // Stats config
%    
%    char  sUnused[148];     // size = 512 bytes
%    
%    ABF_FileInfo() 
%    { 
%       MEMSET_CTOR;
%       STATIC_ASSERT( sizeof( ABF_FileInfo ) == 512 );
% 
%       uFileSignature = ABF_FILESIGNATURE;
%       uFileInfoSize  = sizeof( ABF_FileInfo);
%    }
% 
% };
% 
% struct ABF_ProtocolInfo
% {
%    short nOperationMode;
%    float fADCSequenceInterval;
%    bool  bEnableFileCompression;
%    char  sUnused1[3];
%    UINT  uFileCompressionRatio;
% 
%    float fSynchTimeUnit;
%    float fSecondsPerRun;
%    long  lNumSamplesPerEpisode;
%    long  lPreTriggerSamples;
%    long  lEpisodesPerRun;
%    long  lRunsPerTrial;
%    long  lNumberOfTrials;
%    short nAveragingMode;
%    short nUndoRunCount;
%    short nFirstEpisodeInRun;
%    float fTriggerThreshold;
%    short nTriggerSource;
%    short nTriggerAction;
%    short nTriggerPolarity;
%    float fScopeOutputInterval;
%    float fEpisodeStartToStart;
%    float fRunStartToStart;
%    long  lAverageCount;
%    float fTrialStartToStart;
%    short nAutoTriggerStrategy;
%    float fFirstRunDelayS;
% 
%    short nChannelStatsStrategy;
%    long  lSamplesPerTrace;
%    long  lStartDisplayNum;
%    long  lFinishDisplayNum;
%    short nShowPNRawData;
%    float fStatisticsPeriod;
%    long  lStatisticsMeasurements;
%    short nStatisticsSaveStrategy;
% 
%    float fADCRange;
%    float fDACRange;
%    long  lADCResolution;
%    long  lDACResolution;
%    
%    short nExperimentType;
%    short nManualInfoStrategy;
%    short nCommentsEnable;
%    long  lFileCommentIndex;            
%    short nAutoAnalyseEnable;
%    short nSignalType;
% 
%    short nDigitalEnable;
%    short nActiveDACChannel;
%    short nDigitalHolding;
%    short nDigitalInterEpisode;
%    short nDigitalDACChannel;
%    short nDigitalTrainActiveLogic;
% 
%    short nStatsEnable;
%    short nStatisticsClearStrategy;
% 
%    short nLevelHysteresis;
%    long  lTimeHysteresis;
%    short nAllowExternalTags;
%    short nAverageAlgorithm;
%    float fAverageWeighting;
%    short nUndoPromptStrategy;
%    short nTrialTriggerSource;
%    short nStatisticsDisplayStrategy;
%    short nExternalTagType;
%    short nScopeTriggerOut;
% 
%    short nLTPType;
%    short nAlternateDACOutputState;
%    short nAlternateDigitalOutputState;
% 
%    float fCellID[3];
% 
%    short nDigitizerADCs;
%    short nDigitizerDACs;
%    short nDigitizerTotalDigitalOuts;
%    short nDigitizerSynchDigitalOuts;
%    short nDigitizerType;
% 
%    char  sUnused[304];     // size = 512 bytes
%    
%    ABF_ProtocolInfo() 
%    { 
%       MEMSET_CTOR; 
%       STATIC_ASSERT( sizeof( ABF_ProtocolInfo ) == 512 );
%    }
% };
% 
% struct ABF_MathInfo
% {
%    short nMathEnable;
%    short nMathExpression;
%    UINT  uMathOperatorIndex;     
%    UINT  uMathUnitsIndex;        
%    float fMathUpperLimit;
%    float fMathLowerLimit;
%    short nMathADCNum[2];
%    char  sUnused[16];
%    float fMathK[6];
% 
%    char  sUnused2[64];     // size = 128 bytes
%    
%    ABF_MathInfo()
%    { 
%       MEMSET_CTOR; 
%       STATIC_ASSERT( sizeof( ABF_MathInfo ) == 128 );
%    }
% };
% 
% struct ABF_ADCInfo
% {
%    // The ADC this struct is describing.
%    short nADCNum;
% 
%    short nTelegraphEnable;
%    short nTelegraphInstrument;
%    float fTelegraphAdditGain;
%    float fTelegraphFilter;
%    float fTelegraphMembraneCap;
%    short nTelegraphMode;
%    float fTelegraphAccessResistance;
% 
%    short nADCPtoLChannelMap;
%    short nADCSamplingSeq;
% 
%    float fADCProgrammableGain;
%    float fADCDisplayAmplification;
%    float fADCDisplayOffset;
%    float fInstrumentScaleFactor;
%    float fInstrumentOffset;
%    float fSignalGain;
%    float fSignalOffset;
%    float fSignalLowpassFilter;
%    float fSignalHighpassFilter;
% 
%    char  nLowpassFilterType;
%    char  nHighpassFilterType;
%    float fPostProcessLowpassFilter;
%    char  nPostProcessLowpassFilterType;
%    bool  bEnabledDuringPN;
% 
%    short nStatsChannelPolarity;
% 
%    long  lADCChannelNameIndex;
%    long  lADCUnitsIndex;
% 
%    char  sUnused[46];         // size = 128 bytes
%    
%    ABF_ADCInfo()
%    { 
%       MEMSET_CTOR; 
%       STATIC_ASSERT( sizeof( ABF_ADCInfo ) == 128 );
%    }
% };
% 
% struct ABF_DACInfo
% {
%    // The DAC this struct is describing.
%    short nDACNum;
% 
%    short nTelegraphDACScaleFactorEnable;
%    float fInstrumentHoldingLevel;
% 
%    float fDACScaleFactor;
%    float fDACHoldingLevel;
%    float fDACCalibrationFactor;
%    float fDACCalibrationOffset;
% 
%    long  lDACChannelNameIndex;
%    long  lDACChannelUnitsIndex;
% 
%    long  lDACFilePtr;
%    long  lDACFileNumEpisodes;
% 
%    short nWaveformEnable;
%    short nWaveformSource;
%    short nInterEpisodeLevel;
% 
%    float fDACFileScale;
%    float fDACFileOffset;
%    long  lDACFileEpisodeNum;
%    short nDACFileADCNum;
% 
%    short nConditEnable;
%    long  lConditNumPulses;
%    float fBaselineDuration;
%    float fBaselineLevel;
%    float fStepDuration;
%    float fStepLevel;
%    float fPostTrainPeriod;
%    float fPostTrainLevel;
%    short nMembTestEnable;
% 
%    short nLeakSubtractType;
%    short nPNPolarity;
%    float fPNHoldingLevel;
%    short nPNNumADCChannels;
%    short nPNPosition;
%    short nPNNumPulses;
%    float fPNSettlingTime;
%    float fPNInterpulse;
% 
%    short nLTPUsageOfDAC;
%    short nLTPPresynapticPulses;
% 
%    long  lDACFilePathIndex;
% 
%    float fMembTestPreSettlingTimeMS;
%    float fMembTestPostSettlingTimeMS;
% 
%    short nLeakSubtractADCIndex;
% 
%    char  sUnused[124];     // size = 256 bytes
%    
%    ABF_DACInfo()
%    { 
%       MEMSET_CTOR; 
%       STATIC_ASSERT( sizeof( ABF_DACInfo ) == 256 );
%    }
% };
% 
% struct ABF_EpochInfoPerDAC
% {
%    // The Epoch / DAC this struct is describing.
%    short nEpochNum;
%    short nDACNum;
% 
%    // One full set of epochs (ABF_EPOCHCOUNT) for each DAC channel ...
%    short nEpochType;
%    float fEpochInitLevel;
%    float fEpochLevelInc;
%    long  lEpochInitDuration;  
%    long  lEpochDurationInc;
%    long  lEpochPulsePeriod;
%    long  lEpochPulseWidth;
% 
%    char  sUnused[18];      // size = 48 bytes
%    
%    ABF_EpochInfoPerDAC()
%    { 
%       MEMSET_CTOR; 
%       STATIC_ASSERT( sizeof( ABF_EpochInfoPerDAC ) == 48 );
%    }
% };
% 
% struct ABF_EpochInfo
% {
%    // The Epoch this struct is describing.
%    short nEpochNum;
% 
%    // Describes one epoch
%    short nDigitalValue;
%    short nDigitalTrainValue;
%    short nAlternateDigitalValue;
%    short nAlternateDigitalTrainValue;
%    bool  bEpochCompression;   // Compress the data from this epoch using uFileCompressionRatio
% 
%    char  sUnused[21];      // size = 32 bytes
%    
%    ABF_EpochInfo()
%    { 
%       MEMSET_CTOR; 
%       STATIC_ASSERT( sizeof( ABF_EpochInfo ) == 32 );
%    }
% };
% 
% struct ABF_StatsRegionInfo
% { 
%    // The stats region this struct is describing.
%    short nRegionNum;
%    short nADCNum;
% 
%    short nStatsActiveChannels;
%    short nStatsSearchRegionFlags;
%    short nStatsSelectedRegion;
%    short nStatsSmoothing;
%    short nStatsSmoothingEnable;
%    short nStatsBaseline;
%    long  lStatsBaselineStart;
%    long  lStatsBaselineEnd;
% 
%    // Describes one stats region
%    long  lStatsMeasurements;
%    long  lStatsStart;
%    long  lStatsEnd;
%    short nRiseBottomPercentile;
%    short nRiseTopPercentile;
%    short nDecayBottomPercentile;
%    short nDecayTopPercentile;
%    short nStatsSearchMode;
%    short nStatsSearchDAC;
%    short nStatsBaselineDAC;
% 
%    char  sUnused[78];   // size = 128 bytes
%    
%    ABF_StatsRegionInfo()
%    { 
%       MEMSET_CTOR; 
%       STATIC_ASSERT( sizeof( ABF_StatsRegionInfo ) == 128 );
%    }
% };
% 
% struct ABF_UserListInfo
% {
%    // The user list this struct is describing.
%    short nListNum;
% 
%    // Describes one user list
%    short nULEnable;
%    short nULParamToVary;
%    short nULRepeat;
%    long  lULParamValueListIndex;
% 
%    char  sUnused[52];   // size = 64 bytes
%    
%    ABF_UserListInfo()
%    { 
%       MEMSET_CTOR; 
%       STATIC_ASSERT( sizeof( ABF_UserListInfo ) == 64 );
%    }
% };*/=



