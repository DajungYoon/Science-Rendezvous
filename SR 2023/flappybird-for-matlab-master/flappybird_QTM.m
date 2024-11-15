function flappybird

%% TO EDIT DIFFICULTY
Tubes.Y_VAR = 50; %105 is original, 20 is very easy
Tubes.VGAP = 100; %48 is original 
close all;
%% Erin ADDING QTM THINGS - MAY 10th, 2023
w = warning ('off','all');
addpath(genpath('C:\Program Files\Qualisys\QTM Connect for MATLAB'))
direc = 'C:\Users\Erin\Documents\ScienceRV';

data = load(fullfile(direc,'paddle_static2023.mat'));
data = data.paddle_static2023;
paddle_labels = {'Tip';'Front_L';'Back_bot_L';'Back_bot_R';'Back_top'};
num_markers = length(data.Trajectories.Labeled.Labels);

% Convert data into intuitive structure for marker trajectories
for p = 1:num_markers
    stat_markers.(data.Trajectories.Labeled.Labels{p}) = (squeeze(data.Trajectories.Labeled.Data(p,1:3,:)))';
end
% Find average position from static trial, DIVIDE ALL BY 1000 for mm to m conversion
for p =1:num_markers
    static.(data.Trajectories.Labeled.Labels{p}) = nanmean(stat_markers.(data.Trajectories.Labeled.Labels{p}))/1000;
end

%build coordinate system from from paddle
origin = static.Tip;
inf_pt = mean([static.Back_top; static.Front_L]);
z_axis = unit(origin-inf_pt);
temp = static.Back_top - static.Front_L;
y_axis = unit(cross(z_axis,temp));
x_axis = unit(cross(y_axis,z_axis));
Tstat = eye(4);
Tstat(1:3,1:3) = [x_axis', y_axis', z_axis'];
Tstat(1:3,4) = origin';

%Start a variable for height so we can take moving speed and identify
%"flap"
tip_height_moving = [];
%stream real-time data
QCM('connect','127.0.0.1','frameinfo','3d')

%% System Variables:
GameVer = '1.0';          % The first full playable game

%% Constant Definitions:
GAME.MAX_FRAME_SKIP = [];

GAME.RESOLUTION = [];       % Game Resolution, default at [256 144]
GAME.WINDOW_SCALE = 2;     % The actual size of the window divided by resolution
GAME.FLOOR_TOP_Y = [];      % The y position of upper crust of the floor.
GAME.N_UPDATES_PER_SEC = [];
GAME.FRAME_DURATION = [];
GAME.GRAVITY = 0.05; %0.1356; %0.15; %0.2; %1356;  % empirical gravity constant

TUBE.MIN_HEIGHT = [];       % The minimum height of a tube
TUBE.RANGE_HEIGHT = [];     % The range of the height of a tube
TUBE.SUM_HEIGHT = [];       % The summed height of the upper and low tube
TUBE.H_SPACE = [];           % Horizontal spacing between two tubs
TUBE.V_SPACE = [];           % Vertical spacing between two tubs
TUBE.WIDTH   = [];            % The 'actual' width of the detection box

GAMEPLAY.RIGHT_X_FIRST_TUBE = [];  % Xcoord of the right edge of the 1st tube

ShowFPS = true;
SHOWFPS_FRAMES = 5;
%% Handles
MainFigureHdl = [];
MainAxesHdl = [];
MainCanvasHdl = [];
BirdSpriteHdl = [];
TubeSpriteHdl = [];
BeginInfoHdl = [];
FloorSpriteHdl = [];
ScoreInfoHdl = [];
ScoreInfoBackHdl = []; %Erin added
ScoreInfoForeHdl = []; %Erin addded
GameOverHdl = [];
FloorAxesHdl = [];
%% Game Parameters
MainFigureInitPos = [];
MainFigureSize = [];
MainAxesInitPos = []; % The initial position of the axes IN the figure
MainAxesSize = [];

InGameParams.CurrentBkg = 1;
InGameParams.CurrentBird = 1;

Flags.IsGameStarted = true;     %
Flags.IsFirstTubeAdded = false; % Has the first tube been added to TubeLayer
Flags.ResetFloorTexture = true; % Result the pointer for the floor texture
Flags.PreGame = true;
Flags.NextTubeReady = true;
CloseReq = false;

FlyKeyNames = {'space', 'return', 'uparrow', 'w'};
FlyKeyStatus = false; %(size(FlyKeyNames));
FlyKeyValid = true(size(FlyKeyNames));      %
%% Canvases:
MainCanvas = [];

% The scroll layer for the tubes
TubeLayer.Alpha = [];
TubeLayer.CData = [];


%% RESOURCES:
Sprites = [];

%% Positions:
Bird.COLLIDE_MASK = [];
Bird.INIT_SCREEN_POS = [45 100];                    % In [x y] order;
Bird.WorldX = [];
Bird.ScreenPos = [45 100]; %[45 100];   % Center = The 9th element horizontally (1based)
% And the 6th element vertically
Bird.SpeedXY = [ 0];
Bird.Angle = 0;
Bird.XGRID = [];
Bird.YGRID = [];
Bird.CurFrame = 1;
Bird.SpeedY = 0;
Bird.LastHeight = 0;

SinYRange = 44;
SinYPos = [];
SinY = [];

Score = 0;

Tubes.FrontP = 1;              % 1-3
%Tubes.ScreenX = [300 380 460]-2; % The middle of each tube

%Tubes.VOffset = ceil(rand(1,3)*105);  %105

Best = 0;
%% -- Game Logic --
initVariables();
initWindow();

if ShowFPS
    fps_text_handle = text(10,10, 'FPS:60.0', 'Visible', 'off');
    var_text_handle = text(10,20, '', 'Visible', 'off'); % Display a variable
    total_frame_update = 0;
end

% Show flash screen
CurrentFrameNo = double(0);

fade_time = cumsum([0.5 0.5 0.5]);

pause(0.25);
logo_stl = text(72, 100, 'Stellari Studio', 'FontSize', 20, 'Color',[1 1 1], 'HorizontalAlignment', 'center');
logo_and = text(72, 130, 'and', 'FontSize', 10, 'Color',[1 1 1], 'HorizontalAlignment', 'center');
logo_ilovematlabcn = image([22 122], [150 180], Sprites.MatlabLogo, 'AlphaData',0);
stageStartTime = tic;
while 1
    loops = 0;
    curTime = toc(stageStartTime);
    while (curTime >= ((CurrentFrameNo) * GAME.FRAME_DURATION) && loops < GAME.MAX_FRAME_SKIP)
        if curTime < fade_time(1)
            set(logo_stl, 'Color',1 - [1 1 1].*max(min(curTime/fade_time(1), 1),0));
            set(logo_ilovematlabcn, 'AlphaData', max(min(curTime/fade_time(1), 1),0));
            set(logo_and, 'Color',1 - [1 1 1].*max(min(curTime/fade_time(1), 1),0));
        elseif curTime < fade_time(2)
            set(logo_stl, 'Color',[0 0 0]);
            set(logo_ilovematlabcn, 'AlphaData', 1);
            set(logo_and, 'Color', [0 0 0]);
        else
            set(logo_stl, 'Color',[1 1 1].*max(min((curTime-fade_time(2))/(fade_time(3) - fade_time(2)), 1),0));
            set(logo_ilovematlabcn, 'AlphaData',1-max(min((curTime-fade_time(2))/(fade_time(3) - fade_time(2)), 1),0));
            set(logo_and, 'Color', [1 1 1].*max(min((curTime-fade_time(2))/(fade_time(3) - fade_time(2)), 1),0));
        end
        CurrentFrameNo = CurrentFrameNo + 1;
        loops = loops + 1;
        frame_updated = true;
    end
    if frame_updated
        drawnow;
    end
    if curTime > fade_time
        break;
    end
end
delete(logo_stl);
delete(logo_ilovematlabcn);
delete(logo_and);
pause(0.5);


% Main Game
while 1
    initGame();
    CurrentFrameNo = double(0);
    collide = false;
    fall_to_bottom = false;
    gameover = false;
    stageStartTime = tic;
    c = stageStartTime;
    FPS_lastTime = toc(stageStartTime);
    ready2flap = 1; %indicates that flap can be detected
    flap=0;
    %plot_height = figure;
    frame_times = toc(stageStartTime);%initialize this with starting time
    while 1
        loops = 0;
        curTime = toc(stageStartTime);
        while (curTime >= ((CurrentFrameNo) * GAME.FRAME_DURATION) && loops < GAME.MAX_FRAME_SKIP)

            %% READ QTM Data
            get_QCM_data
            %  disp(tip_height_moving(end))
            if length(tip_height_moving)>1
                frame_times = [frame_times; curTime];
                tip_z_spd = diff(tip_height_moving)./diff(frame_times); %m/s
                %diff(frame_times)
                flap = 0; %Flap is reset to false at each frame

                %% IDENTIFIY FLAPS
                %for a flap to be identified, paddle tip must be moving downwards
                %at at least 1 m/s for 1/10th of a second

                %PADDLE MUST ALSO BE 'READY TO FLAP'
                if ready2flap == 1
                    time_thresh = 0.05;
                    flap_thresh = -0.4;
                    %find number of frames in last 1/10th second
                    [~,frame_grab] = max(find((frame_times(end) - frame_times)>time_thresh));

                    if isempty(frame_grab) == 0
                        num_frames_forThresh = length(frame_times) - frame_grab;
                        recent_speeds= tip_z_spd((length(tip_z_spd)-num_frames_forThresh+1):end);
                        if length(find(recent_speeds>flap_thresh)) >= num_frames_forThresh
                            flap = 1;
                            ready2flap=0;
                            disp('Flap')
                        end
                    end
                end
                %% IDENTIFY RESET (READY2FLAP)
                %for a ready2flap to be identified, paddle tip must be moving
                %upwards at at least 0.5 m/s for 1/10th of a second

                %only do this if a reset is required
                if ready2flap == 0

                    reset_time_thresh = 0.05;
                    reset_thresh = 0.4;
                    %find number of frames in last 1/10th second
                    [~,frame_grab] = max(find((frame_times(end) - frame_times)>reset_time_thresh));
                    if isempty(frame_grab) == 0
                        num_frames_forThresh = length(frame_times) - frame_grab;
                        recent_speeds= tip_z_spd((length(tip_z_spd)-num_frames_forThresh+1):end);
                        %if the paddle has been raised consistently over 1/10th second
                        if length(find(recent_speeds>reset_thresh)) >= num_frames_forThresh
                            ready2flap=1;
                            disp('Flap Reset')
                        end
                    end
                end


            end

            %% Input
            %Responds if key is pressed OR if flap is detected
            %%   if flap == 1 || FlyKeyStatus  % If left key is pressed
            %pause()

            if FlyKeyStatus
                if Flags.PreGame
                        Flags.PreGame = false;
                        set(BeginInfoHdl, 'Visible','off');
                        set(ScoreInfoBackHdl, 'Visible','on');
                        set(ScoreInfoForeHdl, 'Visible','on');
                        Bird.ScrollX = 0;
                end
            end

            if FlyKeyStatus || flap ==1
                if ~gameover
                    Bird.SpeedY = -1.25; % -2.5;
                    FlyKeyStatus = false;
                    Bird.LastHeight = Bird.ScreenPos(2);
%                     if Flags.PreGame
%                         Flags.PreGame = false;
%                         set(BeginInfoHdl, 'Visible','off');
%                         set(ScoreInfoBackHdl, 'Visible','on');
%                         set(ScoreInfoForeHdl, 'Visible','on');
%                         Bird.ScrollX = 0;
%                     end
                else
                    if Bird.SpeedY < 0
                        Bird.SpeedY = 0;
                    end
                end
            end
            if Flags.PreGame
                processCPUBird;
            else
                processBird;
                Bird.ScrollX = Bird.ScrollX + 1;
                if ~gameover
                    scrollTubes(1);
                end
            end
            addScore;
            Bird.CurFrame = 3 - floor(double(mod(CurrentFrameNo, 9))/3);

            %% Cycling the Palette
            % Update the cycle variables
            collide = isCollide();
            if collide
                gameover = true;
            end
            CurrentFrameNo = CurrentFrameNo + 1;
            loops = loops + 1;
            frame_updated = true;

            % If the bird has fallen to the ground
            if Bird.ScreenPos(2) >= 200-5;
                Bird.ScreenPos(2) = 200-5;
                gameover = true;
                if abs(Bird.Angle - pi/2) < 1e-3
                    fall_to_bottom = true;
                    FlyKeyStatus = false;
                end
            end

        end

        %% Redraw the frame if the world has been processed
        if frame_updated
            %         drawToMainCanvas();
            set(MainCanvasHdl, 'CData', MainCanvas(1:200,:,:));
            %         Bird.Angle = double(mod(CurrentFrameNo,360))*pi/180;
            if fall_to_bottom
                Bird.CurFrame = 2;
            end
            refreshBird();
            refreshTubes();
            if (~gameover)
                refreshFloor(CurrentFrameNo);
            end
            curScoreString = sprintf('%d',(Score));
            set(ScoreInfoForeHdl, 'String', curScoreString);
            set(ScoreInfoBackHdl, 'String', curScoreString);
            drawnow;
            frame_updated = false;
            c = toc(stageStartTime);
            if ShowFPS
                total_frame_update = total_frame_update + 1;
                varname = 'collide';%'Mario.curFrame';
                if mod(total_frame_update,SHOWFPS_FRAMES) == 0 % If time to update fps
                    set(fps_text_handle, 'String',sprintf('FPS: %.2f',SHOWFPS_FRAMES./(c-FPS_lastTime)));
                    FPS_lastTime = toc(stageStartTime);
                end
                set(var_text_handle, 'String', sprintf('%s = %.2f', varname, eval(varname)));
            end
        end
        if fall_to_bottom
            if Score > Best
                Best = Score;

                for i_save = 1:4     % Try saving four times if error occurs
                    try
                        save sprites3.mat Best -append
                        break;
                    catch
                        continue;
                    end
                end     % If the error still persist even after four saves, then
                if i_save == 4
                    disp('FLAPPY_BIRD: Can''t save high score');
                end
            end
            score_report = {sprintf('Score: %d', Score), sprintf('Best: %d', Best)};
            set(ScoreInfoHdl, 'Visible','on', 'String', score_report);
            set(GameOverHdl, 'Visible','on');
            save sprites2.mat Best -append
            if FlyKeyStatus
                FlyKeyStatus = false;
                break;
            end
        end

        if CloseReq
            delete(MainFigureHdl);
            clear all;
            return;
        end
    end
end
    function initVariables()
        Sprites = load('sprites3.mat');

        %HERE, EDIT GAP IN TUBES - ERIN
        TUBE_VGAP = Tubes.VGAP; %original is 48

        temp_TubGap = zeros(size(Sprites.TubGap.Alpha,1),size(Sprites.TubGap.Alpha,2));
        top_gap = 0.5*size(Sprites.TubGap.Alpha,1) - ceil(0.5*TUBE_VGAP); %d
        bottom_gap= 0.5*size(Sprites.TubGap.Alpha,1) + ceil(0.5*TUBE_VGAP);
        
        temp_TubGap(:,2:end-1) = 1;
        temp_TubGap(top_gap:bottom_gap,:) = 0;
        temp_TubGap(top_gap-11:top_gap-1,[1,size(Sprites.TubGap.Alpha,2)]) = 1;
        temp_TubGap(bottom_gap+1:bottom_gap+11,[1,size(Sprites.TubGap.Alpha,2)]) = 1;

        %Save info to be used later
        Sprites.TubGap.Alpha = temp_TubGap;
        Tubes.top_gap = top_gap;
        Tubes.bottom_gap = bottom_gap;        

        %Also adjust Colours
        OG_Colours = Sprites.TubGap.CData;
        CData_Out = [];
        for k = 1:3
            CData = Sprites.TubGap.CData(:,:,k);
            top_rim = CData(117:128,:);
            bottom_rim = CData(177:188,:);
            temp_colours = repmat(CData(1,:),size(CData,1),1);
            temp_colours(top_gap:bottom_gap,:) = 0;
            temp_colours(top_gap-12:top_gap-1,:) = top_rim;
            temp_colours(bottom_gap+1:bottom_gap+12,:) = bottom_rim;            
            CData_Out(:,:,k) = temp_colours;
        end
        Sprites.TubGap.CData = uint8(CData_Out);

        GAME.MAX_FRAME_SKIP = 5;
        GAME.RESOLUTION = [256 144]; %256 144
        GAME.WINDOW_RES = [256 144]; %256 144
        GAME.FLOOR_HEIGHT = 56;
        GAME.FLOOR_TOP_Y = GAME.RESOLUTION(1) - GAME.FLOOR_HEIGHT + 1;
        GAME.N_UPDATE_PERSEC = 60;
        GAME.FRAME_DURATION = 1/GAME.N_UPDATE_PERSEC;

        %NONE OF THIS ACTUALLY GETS USED
%        TUBE.H_SPACE = 100;  %100         % Horizontal spacing between two tubs
%        TUBE.V_SPACE = 48;  %48         % Vertical spacing between two tubs - edit to make easier
%        TUBE.WIDTH   = 24;            % The 'actual' width of the detection box, DEFAULT = 24
%        TUBE.MIN_HEIGHT = 36; %36
% NONE OF 
%         TUBE.SUM_HEIGHT = GAME.RESOLUTION(1)-TUBE.V_SPACE-...
%             GAME.FLOOR_HEIGHT;
%         TUBE.RANGE_HEIGHT = TUBE.SUM_HEIGHT -TUBE.MIN_HEIGHT*2;

 %       TUBE.PASS_POINT = [1 44];

        %TUBE.RANGE_HEIGHT_DOWN;      % Sorry you just don't have a choice
 %       GAMEPLAY.RIGHT_X_FIRST_TUBE = 100;  % Xcoord of the right edge of the 1st tube

        %% Handles
        MainFigureHdl = [];
        MainAxesHdl = [];

        %% Game Parameters
        MainFigureInitPos = [500 100];
        MainFigureSize = GAME.WINDOW_RES([2 1]).*2;
        MainAxesInitPos = [0 0]; %[0.1 0.1]; % The initial position of the axes IN the figure
        MainAxesSize = [144 200]; % GAME.WINDOW_RES([2 1]);
        FloorAxesSize = [144 56];
        %% Canvases:
        MainCanvas = uint8(zeros([GAME.RESOLUTION 3]));

        bird_size = Sprites.Bird.Size;
        [Bird.XGRID, Bird.YGRID] = meshgrid([-ceil(bird_size(2)/2):floor(bird_size(2)/2)], ...
            [ceil(bird_size(1)/2):-1:-floor(bird_size(1)/2)]);
        Bird.COLLIDE_MASK = false(12,12);
        [tempx tempy] = meshgrid(linspace(-1,1,12));
        Bird.COLLIDE_MASK = (tempx.^2 + tempy.^2) <= 1;


        Bird.OSCIL_RANGE = [128 4]; % [YPos, Amplitude]

        SinY = Bird.OSCIL_RANGE(1) + sin(linspace(0, 2*pi, SinYRange))* Bird.OSCIL_RANGE(2);
        SinYPos = 1;
        Best = Sprites.Best;    % Best Score
    end

%% --- Graphics Section ---
    function initWindow()
        % initWindow - initialize the main window, axes and image objects
        MainFigureHdl = figure('Name', ['Flappy Bird ' GameVer], ...
            'NumberTitle' ,'off', ...
            'Units', 'pixels', ...
            'Position', 1e3*[2.5540    0.2310    0.5175    0.5805],... %'Position', [MainFigureInitPos, MainFigureSize],... %'Position', 1e3*[340.5000   -42.0000  726.0000  780.5000],... %'Position', [MainFigureInitPos, MainFigureSize], ... %'Position', 1e3*[ 2.7700   0.4440    0.80    1.2545],...
            'MenuBar', 'figure', ...
            'Renderer', 'OpenGL',...
            'Color',[0 0 0], ...
            'KeyPressFcn', @stl_KeyPressFcn, ...
            'WindowKeyPressFcn', @stl_KeyDown,...
            'WindowKeyReleaseFcn', @stl_KeyUp,...
            'CloseRequestFcn', @stl_CloseReqFcn);
        FloorAxesHdl = axes('Parent', MainFigureHdl, ...
            'Units', 'normalized',...
            'Position', [MainAxesInitPos, (1-MainAxesInitPos.*2) .* [1 56/256]], ...
            'color', [1 1 1], ...
            'XLim', [0 MainAxesSize(1)]-0.5, ...
            'YLim', [0 56]-0.5, ...
            'YDir', 'reverse', ...
            'NextPlot', 'add', ...
            'Visible', 'on',...
            'XTick',[], 'YTick', []);
        MainAxesHdl = axes('Parent', MainFigureHdl, ...
            'Units', 'normalized',...
            'Position', [MainAxesInitPos + [0 (1-MainAxesInitPos(2).*2)*56/256], (1-MainAxesInitPos.*2).*[1 200/256]], ...
            'color', [1 1 1], ...
            'XLim', [0 MainAxesSize(1)]-0.5, ...
            'YLim', [0 MainAxesSize(2)]-0.5, ...
            'YDir', 'reverse', ...
            'NextPlot', 'add', ...
            'Visible', 'on', ...
            'XTick',[], ...
            'YTick',[]);


        MainCanvasHdl = image([0 MainAxesSize(1)-1], [0 MainAxesSize(2)-1], [],...
            'Parent', MainAxesHdl,...
            'Visible', 'on');
        TubeSpriteHdl = zeros(1,3);
        for i = 1:3
             TubeSpriteHdl(i) = image([0 26-1], [0 304-1], [],...
                 'Parent', MainAxesHdl,...
                 'Visible', 'on');
%              TubeSpriteHdl(i) = image([0 30-1], [0 330-1], [],...
%                  'Parent', MainAxesHdl,...
%                  'Visible', 'on');
        end

        BirdSpriteHdl = surface(Bird.XGRID-100,Bird.YGRID-100, ...
            zeros(size(Bird.XGRID)), Sprites.Bird.CDataNan(:,:,:,1), ...
            'CDataMapping', 'direct',...
            'EdgeColor','none', ...
            'Visible','on', ...
            'Parent', MainAxesHdl);
        FloorSpriteHdl = image([0], [0],[],...
            'Parent', FloorAxesHdl, ...
            'Visible', 'on ');
        BeginInfoHdl = text(72, 100, 'Tap SPACE to begin', ... %originally at 72,100
            'FontName', 'Helvetica', 'FontSize', 20, 'HorizontalAlignment', 'center','Color',[.25 .25 .25], 'Visible','off');
        ScoreInfoBackHdl = text(72, 50, '0', ...
            'FontName', 'Helvetica', 'FontSize', 30, 'HorizontalAlignment', 'center','Color',[0,0,0], 'Visible','off');
        ScoreInfoForeHdl = text(70.5, 48.5, '0', ...
            'FontName', 'Helvetica', 'FontSize', 30, 'HorizontalAlignment', 'center', 'Color',[1 1 1], 'Visible','off');
        GameOverHdl = text(72, 70, 'GAME OVER', ...
            'FontName', 'Arial', 'FontSize', 20, 'HorizontalAlignment', 'center','Color',[1 0 0], 'Visible','off');

        ScoreInfoHdl = text(72, 110, 'Best', ...
            'FontName', 'Helvetica', 'FontSize', 20, 'FontWeight', 'Bold', 'HorizontalAlignment', 'center','Color',[1 1 1], 'Visible', 'off');
    end

    function initGame()
        % The scroll layer for the tubes
        TubeLayer.Alpha = false([GAME.RESOLUTION.*[1 2] 3]);
        TubeLayer.CData = uint8(zeros([GAME.RESOLUTION.*[1 2] 3]));

        Bird.Angle = 0;
        Score = 0;
        %TubeLayer.Alpha(GAME.FLOOR_TOP_Y:GAME.RESOLUTION(1), :, :) = true;
        Flags.ResetFloorTexture = true;
        SinYPos = 1;
        Flags.PreGame = true;
        %         scrollTubeLayer(GAME.RESOLUTION(2));   % Do it twice to fill the
        %         disp('mhaha');
        %         scrollTubeLayer(GAME.RESOLUTION(2));   % Entire tube layer
        drawToMainCanvas();
        set(MainCanvasHdl, 'CData', MainCanvas);
        set(BeginInfoHdl, 'Visible','on');
        set(ScoreInfoHdl, 'Visible','off');
        set(ScoreInfoBackHdl, 'Visible','off');
        set(ScoreInfoForeHdl, 'Visible','off');
        set(GameOverHdl, 'Visible','off');
        set(FloorSpriteHdl, 'CData',Sprites.Floor.CData);
        Tubes.FrontP = 1;              % 1-3
        % Tubes.ScreenX = [300 380 460]-2; % The middle of each tube
        Tubes.ScreenX = [300 380 460]-2; % The middle of each tube
        Tubes.VOffset = ceil(rand(1,3)*Tubes.Y_VAR); %originally 105
        refreshTubes;
        for i = 1:3
            set(TubeSpriteHdl(i),'CData',Sprites.TubGap.CData,...
                'AlphaData',Sprites.TubGap.Alpha);
            redrawTube(i);
        end
        if ShowFPS
            set(fps_text_handle, 'Visible', 'on');
            set(var_text_handle, 'Visible', 'on'); % Display a variable
        end
    end
%% Game Logic
    function processBird()
        Bird.ScreenPos(2) = Bird.ScreenPos(2) + Bird.SpeedY;
        Bird.SpeedY = Bird.SpeedY + GAME.GRAVITY;
        if Bird.SpeedY < 0
            Bird.Angle = max(Bird.Angle - pi/10, -pi/10);
        else
            if Bird.ScreenPos(2) < Bird.LastHeight
                Bird.Angle = -pi/10; %min(Bird.Angle + pi/100, pi/2);
            else
                Bird.Angle = min(Bird.Angle + pi/30, pi/2);
            end
        end
    end
    function processCPUBird() % Process the bird when the game is not started
        Bird.ScreenPos(2) = SinY(SinYPos);
        SinYPos = mod(SinYPos, SinYRange)+1;
    end
    function drawToMainCanvas()
        % Draw the scrolls and sprites to the main canvas

        % Redraw the background
        MainCanvas = Sprites.Bkg.CData(:,:,:,InGameParams.CurrentBkg);

        TubeFirstCData = TubeLayer.CData(:, 1:GAME.RESOLUTION(2), :);
        TubeFirstAlpha = TubeLayer.Alpha(:, 1:GAME.RESOLUTION(2), :);
        % Plot the first half of TubeLayer
        MainCanvas(TubeFirstAlpha) = ...
            TubeFirstCData (TubeFirstAlpha);
    end
    function scrollTubes(offset)
        Tubes.ScreenX = Tubes.ScreenX - offset;
        if Tubes.ScreenX(Tubes.FrontP) <=-26
            Tubes.ScreenX(Tubes.FrontP) = Tubes.ScreenX(Tubes.FrontP) + 240; %+240
            Tubes.VOffset(Tubes.FrontP) = ceil(rand*Tubes.Y_VAR);  %ceil(rand*105)
            redrawTube(Tubes.FrontP);
            Tubes.FrontP = mod((Tubes.FrontP),3)+1;
            Flags.NextTubeReady = true;
        end
    end

    function refreshTubes()
        % Refreshing Scheme 1: draw the entire tubes but only shows a part
        % of each
        for i = 1:3
            set(TubeSpriteHdl(i), 'XData', Tubes.ScreenX(i) + [0 26-1]);
        end
    end

    function refreshFloor(frameNo)
        %    offset = mod(frameNo, 24);
        offset = mod(frameNo, TUBE.WIDTH);
        set(FloorSpriteHdl, 'XData', -offset);
    end

    function redrawTube(i)
    %    set(TubeSpriteHdl(i), 'YData', -(Tubes.VOffset(i)-1));
         set(TubeSpriteHdl(i), 'YData', -(Tubes.VOffset(i)-1));
    end

%% --- Math Functions for handling Collision / Rotation etc. ---
    function collide_flag = isCollide()
        collide_flag = 0;
        if Bird.ScreenPos(1) >= Tubes.ScreenX(Tubes.FrontP)-5 && ...
                Bird.ScreenPos(1) <= Tubes.ScreenX(Tubes.FrontP)+6+25

        else
            return;
        end

        GapY = [Tubes.top_gap Tubes.bottom_gap] - (Tubes.VOffset(Tubes.FrontP)-1);    % The upper and lower bound of the GAP, 0-based, OG was [128 177]
       
        if Bird.ScreenPos(2) < GapY(1)+4 || Bird.ScreenPos(2) > GapY(2)-4
            collide_flag = 1;
        end
        return;
    end

    function addScore()
        if Tubes.ScreenX(Tubes.FrontP) < 40 && Flags.NextTubeReady
        %   if Tubes.ScreenX(Tubes.FrontP) < 40 && Flags.NextTubeReady
            Flags.NextTubeReady = false;
            Score = Score + 1;
        end
    end

    function refreshBird()
        % move bird to pos [X Y],
        % and rotate the bird surface by X degrees, anticlockwise = +
        cosa = cos(Bird.Angle);
        sina = sin(Bird.Angle);
        xrotgrid = cosa .* Bird.XGRID + sina .* Bird.YGRID;
        yrotgrid = sina .* Bird.XGRID - cosa .* Bird.YGRID;
        xtransgrid = xrotgrid + Bird.ScreenPos(1)-0.5;
        ytransgrid = yrotgrid + Bird.ScreenPos(2)-0.5;
        set(BirdSpriteHdl, 'XData', xtransgrid, ...
            'YData', ytransgrid, ...
            'CData', Sprites.Bird.CDataNan(:,:,:, Bird.CurFrame));
    end
%% -- Display Infos --


%% -- Callbacks --
    function stl_KeyUp(hObject, eventdata, handles)
        key = get(hObject,'CurrentKey');
        % Remark the released keys as valid
        FlyKeyValid = FlyKeyValid | strcmp(key, FlyKeyNames);
    end
    function stl_KeyDown(hObject, eventdata, handles)
        key = get(hObject,'CurrentKey');

        % Has to be both 'pressed' and 'valid';
        % Two key presses at the same time will be counted as 1 key press
        down_keys = strcmp(key, FlyKeyNames);
        FlyKeyStatus = any(FlyKeyValid & down_keys);
        FlyKeyValid = FlyKeyValid & (~down_keys);
    end
    function stl_KeyPressFcn(hObject, eventdata, handles)
        curKey = get(hObject, 'CurrentKey');
        switch true
            case strcmp(curKey, 'escape')
                CloseReq = true;
        end
    end
    function stl_CloseReqFcn(hObject, eventdata, handles)
        CloseReq = true;
    end

%% GET QTM INPUT
%Read QCM data

    function get_QCM_data()
        labels = QCM('3dlabels');
        target_idx = [];

        for m = 1:length(paddle_labels)
            idx = find(ismember(labels,paddle_labels{m}));
            target_idx = [target_idx; idx];
        end


        [frameinfo marker3D] = QCM;
        marker3D = marker3D/1000;
        for i = 1:size(target_idx,1)
            start.(paddle_labels{i}) = marker3D(target_idx(i),:);
        end

        T = track_segment(paddle_labels,static,start);
        Tnow = T*Tstat;
        tip_height = Tnow(3,4);
        tip_height_moving = [tip_height_moving; tip_height];
    end

%track segment function
    function T = track_segment(tracking_markers,static,dynamic);
        %track_segment.m  takes names of tracking labels, static structure,
        %and dynamic struc ture to return transform from static to dynamic frame
        num_frames = size(dynamic.(tracking_markers{1}),1);

        markers_static = [];
        for i = 1:length(tracking_markers)
            markers_static = [markers_static; static.(tracking_markers{i})];
        end

        for k = 1:num_frames
            T(:,:,k) = eye(4);
            markers_dyn = [];
            for i = 1:length(tracking_markers)
                markers_dyn = [markers_dyn; dynamic.(tracking_markers{i})(k,:)];
            end
            %    [one,two] = soderNaN(markers_static,markers_dyn);

            %CHECK FOR NANS (if there are not 3 markers without nans, set whole
            %transform to nans)
            if length(tracking_markers) - length(find(isnan(markers_dyn(:,1)))) < 3
                T(:,:,k) = nan;
            else
                [T(1:3,1:3,k),T(1:3,4,k)] = soderNaN(markers_static,markers_dyn);
            end
        end
    end

end