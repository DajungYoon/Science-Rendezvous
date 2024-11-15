% Real-time QTM for Science Rendez-Vous
% Drawing real time

%Run these lines on opening (first make figure and put it in desired
%monitor
figure;
pos = get (gcf, 'position');
set(0, 'DefaultFigurePosition', pos)

clear all; close all; clc;

%direc = 'C:\Users\anveb\Desktop\ErinScienceRV';
direc = 'C:\Users\Erin\Documents\ScienceRV';
%direc = 'P:\ErinLee\Outreach\Science RV';
addpath(genpath('C:\Program Files\Qualisys\QTM Connect for MATLAB'))
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
figure1.Position = [1921         229        1280         602];
figure1.Color = [1 1 1];
view(-10,-10)
axis equal
sgtitle('Pictionary!','Fontsize',40,'fontweight','bold')
xlim([-1,1]); ylim([-1,1]); zlim([0, 2.2])
xlabel('X [m]'); ylabel('Y [m]'); zlabel('Z [m]')


%% Stream Real-time data

QCM('connect','127.0.0.1','frameinfo','3d')
labels = QCM('3dlabels');
target_idx = [];

for m = 1:length(paddle_labels)
    idx = find(ismember(labels,paddle_labels{m}));
    target_idx = [target_idx; idx];
end

%% Pause Here: Press space when person is in starting position
disp('Press space button when person is ready to draw.')
pause() 

[frameinfo marker3D] = QCM;
marker3D = marker3D/1000; 
for i = 1:size(target_idx,1)
    start.(paddle_labels{i}) = marker3D(target_idx(i),:);
end

T = track_segment(paddle_labels,static,start);
Tstart = T*Tstat;


%% Pause Here: Press space when person is ready to jump
for i = 1:size(target_idx,1)
    dynamic.(paddle_labels{i}) = [];
end


for k =1:10000
 
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
        paddle_pts = [inst_pts.Tip; inst_pts.Back_top; ...
            inst_pts.Back_bot_R;  inst_pts.Back_bot_L; inst_pts.Front_L];
       % patch('vertices',paddle_pts,'faces',[1 2 3 4 5 6],'facecolor',[1 1 0.5]);
        plot3(dynamic.Tip(1:k,1),dynamic.Tip(1:k,2),dynamic.Tip(1:k,3),'-k');
        drawnow()
    
end



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