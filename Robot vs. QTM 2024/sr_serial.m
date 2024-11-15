% D:\Onedrive\QueensU\2024\Science_rendezvous\MATLAB
% MATLAB <-> arduino serial port
% 1 <-> HAND #1 rock
% 2 <-> HAND #1 scissor
% 3 <-> HAND #1 paper
% 4 <-> HAND #2 rock
% 5 <-> HAND #2 scissor
% 6 <-> HAND #2 paper
% 7 <-> HAND #1&2 standby

clc;
clear all;

device=serialportlist("available")';
Obj = serialport(device(1),9600);
pause(3); % For stable connection
%% Only run this part
%Random number
z_pos_diff = rand*(0.3-(-0.3))-0.3;
if isnan(z_pos_diff)
    disp("Action unidentified. Try again.");
elseif z_pos_diff < -0.1
    write(Obj,"1","char");
    disp("It's rock");
elseif z_pos_diff > 0.1
    write(Obj,"2","char"); 
    disp("It's scissors");
else
    write(Obj,"3","char");
    disp("It's paper");
end

%% Two hand test
pause_time = 2;
pause_time_2 = 1;

while 1
    write(Obj,"1","char");
    pause(pause_time_2);
    write(Obj,"5","char");
    pause(pause_time);
    write(Obj,"3","char");
    pause(pause_time_2);
    write(Obj,"4","char");
    pause(pause_time);
    write(Obj,"2","char");
    pause(pause_time_2);
    write(Obj,"6","char");
    pause(pause_time);
    write(Obj,"7","char");
    pause(pause_time);
end

