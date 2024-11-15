% Real-time QTM for Science Rendez-Vous
% Rock paper scissors game with the robot
%Run these lines on opening (first make figure and put it in desired
%monitor

% author: Max Ferguson && Dajung Yoon
figure;
pos = get (gcf, 'position');
set(0, 'DefaultFigurePosition', pos)


clear all; close all; clc;

%direc = 'C:\Users\anveb\Desktop\ErinScienceRV';
% direc = 'C:\Users\dj969\Documents\Repositories\Science-Rendezvous\Science Rendezvous\Robot vs. QTM 2024';
addpath(genpath('C:\Program Files\Qualisys\QTM Connect for MATLAB'))
addpath(genpath('C:\Users\dj969\Documents\Repositories\Science-Rendezvous\Science Rendezvous\SR 2023'));
% Load Static File
load(fullfile("C:\Users\dj969\Documents\Repositories\Science-Rendezvous\Science Rendezvous\Robot vs. QTM 2024\Data\static_max3d.mat"));
data = static_max;
paddle_labels = {'fore_cluster1';'fore_cluster2';'fore_cluster3';'fore_cluster4';'bi_cluster1';'bi_cluster2';'bi_cluster3';'bi_cluster4'};
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
origin = mean([static.fore_cluster1;static.fore_cluster2;static.fore_cluster3;static.fore_cluster4]);
inf_pt = mean([static.fore_cluster3; static.fore_cluster4]);

z_axis = unit(origin-inf_pt);
temp = static.fore_cluster4 - static.fore_cluster3;
y_axis = unit(cross(z_axis,temp));
x_axis = unit(cross(y_axis,z_axis));
Tstat_fore = eye(4);
Tstat_fore(1:3,1:3) = [x_axis', y_axis', z_axis'];
Tstat_fore(1:3,4) = origin';

origin = mean([static.bi_cluster1;static.bi_cluster2;static.bi_cluster3;static.bi_cluster4]);
inf_pt = mean([static.bi_cluster3; static.bi_cluster4]);

z_axis = unit(origin-inf_pt);
temp = static.bi_cluster4 - static.bi_cluster3;
y_axis = unit(cross(z_axis,temp));
x_axis = unit(cross(y_axis,z_axis));
Tstat_bi = eye(4);
Tstat_bi(1:3,1:3) = [x_axis', y_axis', z_axis'];
Tstat_bi(1:3,4) = origin';

% %% Open Figure
% set(0,'units','pixels') ; Pix_SS = get(0,'screensize'); wid = Pix_SS(3); hgt = Pix_SS(4);
% 
% figure1 = figure;  hold on;
% figure1.Position = [1921         229        1280         602];
% figure1.Color = [1 1 1];
% view(-10,-10)
% axis equal
% sgtitle('Pictionary!','Fontsize',40,'fontweight','bold')
% xlim([-1,1]); ylim([-1,1]); zlim([0, 2.2])
% xlabel('X [m]'); ylabel('Y [m]'); zlabel('Z [m]')


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
for i = 1:4 % fore cluster (4 markers)
    start.(paddle_labels{i}) = marker3D(target_idx(i),:);
end

T = track_segment(paddle_labels(1:4),static,start);
Tstart_fore = T*Tstat_fore;

for i = 5:8 % bi cluster (4 markers)
    start.(paddle_labels{i}) = marker3D(target_idx(i),:);
end

T = track_segment(paddle_labels(5:8),static,start);
Tstart_bi = T*Tstat_bi;

%% Pause Here: Press space when person is ready to jump
for i = 1:4
    dynamic_fore.(paddle_labels{i}) = [];
end
for i = 5:8
    dynamic_bi.(paddle_labels{i}) = [];
end

for k =1:10000

    [frameinfo marker3D] = QCM;
    marker3D = marker3D/1000;
    for i = 1:4 %FOREARM
        dynamic_fore.(paddle_labels{i}) = [dynamic_fore.(paddle_labels{i}) ; marker3D(target_idx(i),:)];
        dynamic_inst_fore.(paddle_labels{i}) = marker3D(target_idx(i),:); %save out instantaneous variable

        fields_fore = fieldnames(dynamic_inst_fore);
        % get the field names (which is a string of the rigidbody)
        z_pos_fore = [];
        for j = 1:length(fields_fore)
            % access the third col of the field value (which is the z) and
            % put that into a list z_pos_fore
            % we then are going to look at each of those values as it comes
            % in real time, and then calculate the mean of whatever
            % clusters the camera can see
            z_pos_fore(1,end+1) = dynamic_inst_fore.(fields_fore{j})(1,3);
        end
        
        % this is to get a relative position on the cluster. so that we can
        % quanitfy its position and then later set conditions for what it
        % should do to the robot
        mean_z_pos_fore = mean(z_pos_fore);

    end

    for t = 5:8 %bicep
        dynamic_bi.(paddle_labels{t}) = [dynamic_bi.(paddle_labels{t}) ; marker3D(target_idx(t),:)];
        dynamic_inst_bi.(paddle_labels{t}) = marker3D(target_idx(t),:); %save out instantaneous variable

        fields_bi = fieldnames(dynamic_inst_bi);
        z_pos_bi = [];
        for l = 1:length(fields_bi)
            z_pos_bi(1,end+1) = dynamic_inst_bi.(fields_bi{l})(1,3);
        end

        mean_z_pos_bi = mean(z_pos_bi);

    end

    % Calculate z-position difference
    z_pos_diff = mean_z_pos_bi - mean_z_pos_fore;

    % Determine action based on z_pos_diff
    if isnan(z_pos_diff)
        disp("Action unidentified. Try again.");
    elseif z_pos_diff < -0.1
        disp("It's rock");
    elseif z_pos_diff > 0.1
        disp("It's scissors");
    else
        disp("It's paper");
    end


    %animate paddle in real-time
    %     T_inst = track_segment(paddle_labels(1:4,1),static,dynamic_inst);
    %
    %     for i = 1:4
    %         inst_pts.(paddle_labels{i}) = RT_transform(static.(paddle_labels{i}), T_inst(1:3,1:3),T_inst(1:3,4)',1);
    %     end
    % %         paddle_pts = [inst_pts.Tip; inst_pts.Back_top; ...
    % %             inst_pts.Back_bot_R;  inst_pts.Back_bot_L; inst_pts.Front_L];
    %        % patch('vertices',paddle_pts,'faces',[1 2 3 4 5 6],'facecolor',[1 1 0.5]);
    %         plot3(dynamic.fore_cluster4(1:k,1),dynamic.fore_cluster4(1:k,2),dynamic.fore_cluster4(1:k,3),'-k');
    %         drawnow()

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