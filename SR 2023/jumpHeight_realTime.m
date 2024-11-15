% Real-time QTM for Science Rendez-Vous
% Jump height

%Run these lines on opening (first make figure and put it in desired
%monitor
%figure;
%pos = get (gcf, 'position');
%set(0, 'DefaultFigurePosition', pos)

clear all; close all; clc;

%% HEIGHT OF L-FRAME
h0 = 0.416; %m

direc = 'C:\Users\Erin\Documents\ScienceRV';
addpath(genpath('C:\Program Files\Qualisys\QTM Connect for MATLAB'))
%direc = 'C:\Users\erinc\Documents\Outreach\Science RendezVous';
%% Load Static File
load(fullfile(direc,'paddle_static2023.mat'));
data = paddle_static2023;
paddle_labels = {'Tip';'Front_L';'Back_bot_L';'Back_bot_R';'Back_top'};
num_markers = length(data.Trajectories.Labeled.Labels);

% Convert data into intuitive structure for marker trajectories
for i = 1:num_markers
    stat_markers.(data.Trajectories.Labeled.Labels{i}) = (squeeze(data.Trajectories.Labeled.Data(i,1:3,:)))';
end
% Find average position from static trial, DIVIDE ALL BY 1000 for mm to m conversion
for i =1:num_markers
    static.(data.Trajectories.Labeled.Labels{i}) = nanmean(stat_markers.(data.Trajectories.Labeled.Labels{i}))/1000;
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

%% Open Figure
set(0,'units','pixels') ; Pix_SS = get(0,'screensize'); wid = Pix_SS(3); hgt = Pix_SS(4);

figure1 = figure;  hold on;
%figure1.Position = [ 1  1  wid hgt];
figure1.Position = [1921         229        1280         602];
figure1.Color = [1 1 1];
s1 = subplot(1,3,1); s2 = subplot(1,3,2); s3 = subplot(1,3,3);
sgtitle('Jump Height Contest!','Fontsize',40,'fontweight','bold')

subplot(1,3,1)
hold on;
ax = gca;
ax.InnerPosition = [0.03 0.1100 0.15 0.8150];
set(gca,'visible','off'); 
text(0,0.7,{'\color[rgb]{0.6 0.3 0.9}Step 1\color[rgb]{0 0 0}: Secure the yellow' ;'paddle on your hand'},...
    'fontweight','bold','fontsize',23);
text(0,0.5,{'\color[rgb]{0.6 0.3 0.9}Step 2\color[rgb]{0 0 0}: Hold the paddle'; 'as high as you can!'},...
    'fontweight','bold','fontsize',23);
text(0,0.3,'\color[rgb]{0.6 0.3 0.9}Step 3\color[rgb]{0 0 0}: Jump as high as you can!',...
    'fontweight','bold','fontsize',23);
subplot(s3)
set(gca,'visible','off'); 

%% Stream Real-time data

QCM('connect','127.0.0.1','frameinfo','3d')
labels = QCM('3dlabels');
target_idx = [];

for m = 1:length(paddle_labels)
    idx = find(ismember(labels,paddle_labels{m}));
    target_idx = [target_idx; idx];
end

%% Pause Here: Press space when person is in starting position
disp('Press space button in standing position.')
pause()

[frameinfo marker3D] = QCM;
marker3D = marker3D/1000; 
for i = 1:size(target_idx,1)
    start.(paddle_labels{i}) = marker3D(target_idx(i),:);
end

T = track_segment(paddle_labels,static,start);
Tstart = T*Tstat;
starting_height = Tstart(3,4);
fprintf('Starting height is %.2f cm.\n',starting_height*100);
subplot(s3)
hold on;
ax1 = gca;
%ax1.InnerPosition = [0.70 0.1100 0.98 0.8150];

%set(gca,'visible','off'); 
%text(0.5,0.8,{['\color[rgb]{0 0 1}Starting Height\color[rgb]{0 0 0}: ' sprintf('%.1f',starting_height*100) ' cm']},...
%     'fontweight','bold','fontsize',23,'HorizontalAlignment', 'center');

%% Pause Here: Press space when person is ready to jump
 for i = 1:size(target_idx,1)
    dynamic.(paddle_labels{i}) = [];
end

disp('Press space button when person is ready to jump.')
pause() 

subplot(s2)
ax2 = gca;
%ax2.OuterPosition = [0.15 0.1100 0.66 0.8150];
ax2.OuterPosition = [0.2 0.1 0.66 0.8150];
hold on;
xlabel('X [m]'); ylabel('Y [m]'); zlabel('Z [m]')
view(65,15)
axis equal
xlim([-1,1]); ylim([-1,1]); zlim([0, 3])


for k = 1:150  %change this as needed
 
    [frameinfo marker3D] = QCM;
    marker3D = marker3D/1000;
    for i = 1:size(target_idx,1)
        dynamic.(paddle_labels{i}) = [dynamic.(paddle_labels{i}) ; marker3D(target_idx(i),:)];
        dynamic_inst.(paddle_labels{i}) = marker3D(target_idx(i),:); %save out instantaneous variable
    end
    %animate paddle in real-time
    T_inst = track_segment(paddle_labels,static,dynamic_inst);
    
    for i = 1:size(target_idx,1)
        inst_pts.(paddle_labels{i}) = RT_transform(static.(paddle_labels{i}), T_inst(1:3,1:3),T_inst(1:3,4)',1);
    end
        paddle_pts = [inst_pts.Tip; inst_pts.Back_top;...
            inst_pts.Back_bot_R;  inst_pts.Back_bot_L; inst_pts.Front_L];
        patch('vertices',paddle_pts,'faces',[1 2 3 4 5],'facecolor',[1 1 0.5]);
        plot3(dynamic.Tip(1:k,1),dynamic.Tip(1:k,2),dynamic.Tip(1:k,3),'g');
        plot3(dynamic.Front_L(1:k,1),dynamic.Front_L(1:k,2),dynamic.Front_L(1:k,3),'m');
        plot3(dynamic.Back_top(1:k,1),dynamic.Back_top(1:k,2),dynamic.Back_top(1:k,3),'c');
        plot3(dynamic.Back_bot_L(1:k,1),dynamic.Back_bot_L(1:k,2),dynamic.Back_bot_L(1:k,3),'c');
        plot3(dynamic.Back_bot_R(1:k,1),dynamic.Back_bot_R(1:k,2),dynamic.Back_bot_R(1:k,3),'c');
        drawnow()
    
end
 
T = track_segment(paddle_labels,static,dynamic);
for k = 1:size(T,3)
    Tdyn(:,:,k) = T(:,:,k)*Tstat;
    height(k,1) = Tdyn(3,4,k);
end

[max_height,max_frame] = max(height);

hold on;

plot3(dynamic.Tip(max_frame,1),dynamic.Tip(max_frame,2),dynamic.Tip(max_frame,3),'.k','markersize',25);
pts = [dynamic.Tip(max_frame,:); dynamic.Back_top(max_frame,:); ...
            dynamic.Back_bot_R(max_frame,:);  dynamic.Back_bot_L(max_frame,:); dynamic.Front_L(max_frame,:)];
patch('vertices',pts,'faces',[1 2 3 4 5 6],'facecolor',[0.5 1 0.5]);
%patch('vertices',pts,'faces',[1 2 3],'facecolor',[0.5 1 0.5]);

fprintf('Jump Height: %.2f cm.\n',(max_height+ h0)*100);
subplot(s3)
hold on;
%text(0.5,0.65,{['\color[rgb]{0 0 1}Maximum Height Reached\color[rgb]{0 0 0}: ' sprintf('%.1f',max_height*100) ' cm']},...
%     'fontweight','bold','fontsize',23,'HorizontalAlignment', 'center');
jump_height = max_height-starting_height;

text(0.6,0.7,{'\color[rgb]{0 0.7 0}Maximum Vertical\color[rgb]{0 0 0}: ';[ sprintf('%.1f',jump_height*100) ' cm']},...
     'fontweight','bold','fontsize',33,'HorizontalAlignment', 'center');

text(0.6,0.4,{'\color[rgb]{0 0.7 0}Percent Height Jumped\color[rgb]{0 0 0}: '; [ sprintf('%.1f',100*jump_height/(starting_height+h0)) ' %']},...
     'fontweight','bold','fontsize',33,'HorizontalAlignment', 'center');

fprintf('Maximum vertical: %.2f cm.\n',(max_height-starting_height)*100);



%% Functions
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
