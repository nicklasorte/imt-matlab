clear;
clc;
close all force;
close all;
app=NaN(1);  %%%%%%%%%This is to allow for Matlab Application integration.
format shortG
top_start_clock=clock;
folder1='C:\Users\nlasorte\OneDrive - National Telecommunications and Information Administration\MATLAB2024\imt-matlab-main';
cd(folder1)
addpath(folder1)
addpath('C:\Users\nlasorte\OneDrive - National Telecommunications and Information Administration\MATLAB2024\Basic_Functions')
addpath('C:\Users\nlasorte\OneDrive - National Telecommunications and Information Administration\MATLAB2024\imt-matlab-main\matlab')
pause(0.1)

%%% results = run_all_tests()



% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=1
% opts = struct();
% opts.numMc = 1000;
% opts.seed = rev_num;
% opts.azGridDeg = -60:1:60;
% opts.elGridDeg = -10:1:5;
% opts.percentiles = unique(sort(horzcat([1:1:99],0.1,0.01,99.9,99.99)));
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=2  %%%%%%%%%43 seconds
% opts = struct();
% opts.numMc = 1000;
% opts.seed = rev_num;
% opts.azGridDeg = -60:1:60;
% opts.elGridDeg = -10:1:5;
% opts.percentiles = unique(sort(horzcat([0.1:0.1:99.9],0.01,99.99)));
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=3  %%%%%%%%%2.2 mins
% opts = struct();
% opts.numMc = 5000;
% opts.seed = rev_num;
% opts.azGridDeg = -60:1:60;
% opts.elGridDeg = -10:1:5;
% opts.percentiles = unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=4  %%%%%%%%%43 seconds
% opts = struct();
% opts.numMc = 1000;
% opts.seed = rev_num;
% opts.azGridDeg = -60:1:60;
% opts.elGridDeg = -10:1:5;
% opts.binEdgesDbm = [-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles = unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
rev_num=5  %%%%%%%%%11 Mins
opts = struct();
opts.numMc = 10000;
opts.seed = rev_num;
opts.azGridDeg = -60:1:60;
opts.elGridDeg = -10:1:5;
opts.binEdgesDbm = [-100:0.1:120];  %%%%%Default is 1dB
opts.percentiles = unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%Run the Sims
tf_recalc_eirp=0%1%0%1
struct_results_filename=strcat('sim_results_',num2str(rev_num),'.mat');
[var_exist]=persistent_var_exist_with_corruption(app,struct_results_filename);
if tf_recalc_eirp==1
    var_exist=0;
end
if var_exist==2
    tic;
    load(struct_results_filename,'result')
    toc;
else
    result=runR23AasEirpCdfGrid(opts);
    tic;
    save(struct_results_filename,'result')
    toc;
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

disp(result.metadata.deployment)
result.percentileMaps
result.stats
size(result.percentileMaps.values)
size(result.stats.max_dBm)
max(max(result.stats.max_dBm))
[max1,max1_idx]=max(result.stats.max_dBm)
[max2,max2_idx]=max(max1)
%%%%%%%%%%Max: sectorEirpDbm        = 78.3   sector peak EIRP [dBm / 100 MHz]
%%%%%%%%%%%This does not take into considerations the 75/25% TDD or 20% Loading

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Create the table
az = result.percentileMaps.azGrid;
el = result.percentileMaps.elGrid;
p  = result.percentileMaps.percentiles;
V  = result.percentileMaps.values;   
[AZ, EL] = ndgrid(az, el);
T = table();
T.az_deg = AZ(:);
T.el_deg = EL(:);
for k = 1:numel(p)
    colName = sprintf('p%g_dBm', p(k));
    colName = matlab.lang.makeValidName(colName);

    slice = V(:,:,k);        % az x el
    T.(colName) = slice(:);  % 1936 x 1
end
tic;
writetable(T, strcat('eirp_percentile_grid_',num2str(rev_num),'.csv'));
toc;


az(max1_idx(max2_idx))



%%%%%%%%%%%%%%%%%%%%%%%%%Find the Zero/Zero Az/El
array_table=table2array(T);
zero_azi_idx=find(array_table(:,1)==0);
zero_ele_idx=find(array_table(:,2)==0);
row_zero_idx=intersect(zero_azi_idx,zero_ele_idx);
array_zero=array_table(row_zero_idx,[3:end]);

figure;
hold on;
plot(array_zero,opts.percentiles,'-ob')
ylabel('CDF')
xlabel('EIRP')
grid on;


end_clock=clock;
total_clock=end_clock-top_start_clock;
total_seconds=total_clock(6)+total_clock(5)*60+total_clock(4)*3600+total_clock(3)*86400;
total_mins=total_seconds/60;
total_hours=total_mins/60;
if total_hours>1
    strcat('Total Hours:',num2str(total_hours))
elseif total_mins>1
    strcat('Total Minutes:',num2str(total_mins))
else
    strcat('Total Seconds:',num2str(total_seconds))
end
cd(folder1)
'Done'