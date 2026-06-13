clear;
clc;
close all force;
close all;
app=NaN(1);  %%%%%%%%%This is to allow for Matlab Application integration.
format shortG
top_start_clock=clock;
%folder1='C:\Users\nlasorte\OneDrive - National Telecommunications and Information Administration\MATLAB2024\imt-matlab-main';
%folder1='C:\Users\nlasorte\OneDrive - National Telecommunications and Information Administration\MATLAB2024\imt-matlab-main 5-19-2026\imt-matlab-main';
%folder1='C:\Users\nlasorte\OneDrive - National Telecommunications and Information Administration\MATLAB2024\imt-matlab-main 5-26-2026\imt-matlab-main'
folder1='C:\Users\nlasorte\OneDrive - National Telecommunications and Information Administration\MATLAB2024\imt-matlab-main 6-2-2026\imt-matlab-main'
cd(folder1)
addpath(folder1)
addpath('C:\Users\nlasorte\OneDrive - National Telecommunications and Information Administration\MATLAB2024\Basic_Functions')
addpath(fullfile(folder1,'matlab'))
pause(0.1)

tf_run_test=0%1%0%1%0
if tf_run_test==1
    tic;
    test_output=run_all_tests();
    toc;  %%%%% 1min for the tests

    if test_output.allPassed~=1
        'Error on the tests'
        pause;
    end
end



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
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=5  %%%%%%%%%11 Mins
% opts = struct();
% opts.numMc = 10000;
% opts.seed = rev_num;
% opts.azGridDeg = -60:1:60;
% opts.elGridDeg = -10:1:5;
% opts.binEdgesDbm = [-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles = unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=6  %%%%%%%%%
% opts = struct();
% opts.numMc = 100;
% opts.seed = rev_num;
% opts.azGridDeg = -60:1:60;
% opts.elGridDeg = -10:1:5;
% opts.binEdgesDbm = [-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles = unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=7  %%%%%%%%%7 Mins
% opts = struct();
% opts.numMc = 10000;
% opts.seed = rev_num;
% opts.azGridDeg = -60:1:60;
% opts.elGridDeg = -10:1:5;
% opts.binEdgesDbm = [-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles = unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=8  %%%%%%%%%? Mins
% opts = struct();
% opts.numMc = 20000;
% opts.seed = rev_num;
% opts.azGridDeg = -60:1:60;
% opts.elGridDeg = -10:1:5;
% opts.binEdgesDbm = [-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles = unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=9  %%%%%%%%% Mins
% opts = struct();
% opts.numMc = 10;
% opts.seed = rev_num;
% opts.azGridDeg = -180:1:180;
% opts.elGridDeg = -90:1:90;
% opts.binEdgesDbm = [-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles = unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=10  %%%%%%%%% Mins
% opts = struct();
% opts.numMc = 100;
% opts.seed = rev_num;
% opts.azGridDeg = -120:2:120;
% opts.elGridDeg = -30:2:30;
% opts.binEdgesDbm = [-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles = unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=11  %%%%%%%%% 2 Mins
% opts = struct();
% opts.numMc = 1000;
% opts.seed = rev_num;
% opts.azGridDeg = -120:2:120;
% opts.elGridDeg = -30:2:30;
% opts.binEdgesDbm = [-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles = unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=12  %%%%%%%%% 13 Mins
% opts = struct();
% opts.numMc = 10000;
% opts.seed = rev_num;
% opts.azGridDeg = -120:2:120;
% opts.elGridDeg = -30:2:30;
% opts.binEdgesDbm = [-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles = unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=13  %%%%%%%%% 1 Mins, Test CTIA inputs
% opts = struct();
% opts.aasGeometryPreset='ctia_7ghz_1x6'
% opts.numMc = 10;
% opts.seed = rev_num;
% opts.azGridDeg = -120:2:120;
% opts.elGridDeg = -30:2:30;
% opts.binEdgesDbm = [-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles = unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=14  %%%%%%%%% 1 Mins, Test CTIA inputs
% opts = struct();
% opts.aasGeometryPreset='ctia_7ghz_1x6'  %%%%90.8dBm
% opts.numMc = 1000;
% opts.seed = rev_num;
% opts.azGridDeg = -120:2:120;
% opts.elGridDeg = -30:2:30;
% opts.binEdgesDbm = [-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles = unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=15  %%%%%%%%% 1 Mins, IMT:  78.3
% opts = struct();
% opts.numMc = 1000;
% opts.seed = rev_num;
% opts.azGridDeg = -120:2:120;
% opts.elGridDeg = -30:2:30;
% opts.binEdgesDbm = [-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles = unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=16  %%%%%%%%% 1 Mins, IMT:  78.3
% opts = struct();
% opts.aasGeometryPreset='r23_1x3_default'
% opts.numMc = 100;
% opts.seed = rev_num;
% opts.azGridDeg = -120:2:120;
% opts.elGridDeg = -30:2:30;
% opts.binEdgesDbm = [-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles = unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=17  %%%%%%%%% 1 Mins, IMT:  78.3
% opts = struct();
% opts.aasGeometryPreset='r23_1x3_default'
% opts.numMc = 1000;
% opts.seed = rev_num;
% opts.azGridDeg = -120:2:120;
% opts.elGridDeg = -30:2:30;
% opts.binEdgesDbm = [-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles = unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % rev_num=18  %%%%%%%%% 10 Mins, IMT:  78.3/100MHz: Baseline 10k against the CTIA heatmap
% % opts = struct();
% % opts.aasGeometryPreset='r23_1x3_default'
% % opts.numMc = 10000;
% % opts.seed = rev_num;
% % opts.azGridDeg = -120:2:120;
% % opts.elGridDeg = -30:2:30;
% % opts.binEdgesDbm = [-100:0.1:120];  %%%%%Default is 1dB
% % opts.percentiles = unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=19  %%%%%%%%% 10 Mins, CTIA:  78.3/100MHz: Baseline 10k against the CTIA heatmap
% opts = struct();
% opts.aasGeometryPreset='ctia_7ghz_1x6'  %%%%90.8dBm
% opts.numMc = 10000;
% opts.seed = rev_num;
% opts.azGridDeg = -120:2:120;
% opts.elGridDeg = -30:2:30;
% opts.binEdgesDbm = [-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles = unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=20  %%%%%%%%% 
% opts=struct();
% opts.aasGeometryPreset='ctia_7ghz_1x6'  %%%%90.8dBm
% opts.outputFrame='panel' %%%%%%%%%The CTIA heatmap coordinate system
% opts.numMc=100;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180;
% opts.elGridDeg=-90:2:90;
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=21  %%%%%%%%
% opts=struct();
% opts.aasGeometryPreset='r23_1x3_default' 
% opts.outputFrame='panel' %%%%%%%%%The CTIA heatmap coordinate system
% opts.numMc=100;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180;
% opts.elGridDeg=-90:2:90;
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=22  %%%%%%%%
% opts=struct();
% opts.aasGeometryPreset='r23_1x3_default' 
% opts.outputFrame='global'
% opts.numMc=100;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180;
% opts.elGridDeg=-90:2:90;
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % rev_num=23  %%%%%%%%% For comparison: 22 mins
% % opts=struct();
% % opts.aasGeometryPreset='ctia_7ghz_1x6'  %%%%90.8dBm
% % opts.outputFrame='panel' %%%%%%%%%The CTIA heatmap coordinate system
% % opts.numMc=1000;
% % opts.seed=rev_num;
% % opts.azGridDeg=-180:2:180; %%%%CTIA grid 
% % opts.elGridDeg=-90:1:90; %%%%CTIA grid
% % opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% % opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=24  %%%%%%%%% For comparison: 18 mins
% opts=struct();
% opts.aasGeometryPreset='r23_1x3_default'  %%%%90.8dBm
% opts.outputFrame='panel' %%%%%%%%%The CTIA heatmap coordinate system
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid 
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=25  %%%%%%%%% For comparison: 22 mins
% opts=struct();
% opts.aasGeometryPreset='ctia_7ghz_1x6'  %%%%90.8dBm
% opts.outputFrame='panel' %%%%%%%%%The CTIA heatmap coordinate system
% opts.numMc=2000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid 
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
rev_num=26  %%%%%%%%% For comparison:3 Hours (Need to break it down into chunks)
opts=struct();
opts.aasGeometryPreset='ctia_7ghz_1x6'  %%%%90.8dBm
opts.outputFrame='panel' %%%%%%%%%The CTIA heatmap coordinate system
opts.numMc=10000;
opts.seed=rev_num;
opts.azGridDeg=-180:2:180; %%%%CTIA grid 
opts.elGridDeg=-90:1:90; %%%%CTIA grid
opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=27  %%%%%%%%% For comparison: 18 mins
% opts=struct();
% opts.aasGeometryPreset='r23_1x3_default'  %%%%90.8dBm
% opts.outputFrame='panel' %%%%%%%%%The CTIA heatmap coordinate system
% opts.environment='suburban'; 
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid 
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


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
max_dBm=result.stats.max_dBm;
min_dBm=result.stats.min_dBm;
mean_dBm=result.stats.mean_dBm;
size(max_dBm)
size(V)

[AZ, EL] = ndgrid(az, el);
T = table();
T.az_deg = AZ(:);
size(AZ(:)) %%%1936 x 1
T.el_deg = EL(:);

%'Add the min/max/mean to the table at the end'
T.min_dBm = min_dBm(:);
T.mean_dBm = mean_dBm(:);
T.max_dBm = max_dBm(:);

for k = 1:numel(p)
    colName = sprintf('p%g_dBm', p(k));
    colName = matlab.lang.makeValidName(colName);
    slice = V(:,:,k);        % az x el
    T.(colName) = slice(:);  % 1936 x 1
end

'Writing the table'
tic;
writetable(T, strcat('eirp_percentile_grid_',num2str(rev_num),'.csv'));
toc;


%%%%%%%%%%%%%%%%%%%%%%%%%Find the Zero/Zero Az/El
array_table=table2array(T);
zero_azi_idx=find(array_table(:,1)==0);
zero_ele_idx=find(array_table(:,2)==0);
row_zero_idx=intersect(zero_azi_idx,zero_ele_idx);
array_zero=array_table(row_zero_idx,[6:end]);
table_header=T.Properties.VariableNames
t_max_idx=find(contains(table_header,'max_dBm'));
t_min_idx=find(contains(table_header,'min_dBm'));

%%%% Keep only numeric characters, decimal points, and minus signs
per_number=str2double(regexprep(table_header, '[^\d.-]', ''));
nnan_idx=find(~isnan(per_number));
per_number=per_number(~isnan(per_number));
array_cdfs=array_table(:,[6:end]);
max_row_cdf=max(array_cdfs,[],2);
max(max_dBm(:))
array_full_cdf=table2array(T(:,horzcat(t_min_idx,nnan_idx,t_max_idx)));
[max_val, linear_idx] = max(array_full_cdf(:,end))
array_max_cdf=array_full_cdf(linear_idx,:);
full_per=horzcat(0,opts.percentiles,100);
horzcat(array_max_cdf',full_per')

%'find the max eirp az/el and plot that cdf'
figure;
hold on;
plot(array_max_cdf,full_per,'-ob')
ylabel('CDF')
xlabel('EIRP')
grid on;
pause(0.1)
saveas(gcf,char(strcat('cdf_max_single_',num2str(rev_num),'.png')))
pause(0.1);


figure;
hold on;
plot(array_zero,opts.percentiles,'-ob')
ylabel('CDF')
xlabel('EIRP')
grid on;
pause(0.1)
saveas(gcf,char(strcat('cdf_single_zero_',num2str(rev_num),'.png')))
pause(0.1);


% figure;
% hold on;
% plot(array_cdfs,opts.percentiles,'-')
% ylabel('CDF')
% xlabel('EIRP')
% grid on;
% pause(0.1)
% saveas(gcf,char(strcat('cdf_all_',num2str(rev_num),'.png')))
% pause(0.1);




array_azi=AZ(:);
array_ele=EL(:);
array_eirp=max_dBm;
uni_azi=unique(array_azi);
uni_el=unique(array_ele);
mat_size=[numel(uni_azi),numel(uni_el)]; % or swap, depending on what order you want.
z_eirp=reshape(array_eirp,mat_size);
 max(max(array_eirp))
 min(min(array_eirp))
dbm2_range=max(max(array_eirp))-min(min(array_eirp));
color_set=plasma(dbm2_range); %%%%%%%%%%%%Colormap
tic;
f1=figure;
AxesH = axes;
hold on;
[X,Y] = meshgrid(uni_azi,uni_el);
Z=z_eirp;
size(X)
size(Y)
size(Z)
surf(X,Y,Z','EdgeColor','none')
(max(uni_azi)-min(uni_azi))/10
xticks(min(uni_azi):(max(uni_azi)-min(uni_azi))/10:max(uni_azi))
yticks(min(uni_el):(max(uni_el)-min(uni_el))/10:max(uni_el))
xlabel('Azimuth [Degrees]')
ylabel('Elevation [Degrees]')
h = colorbar;
ylabel(h, 'EIRP [dBm/100MHz]')
grid on;
colormap(f1,color_set)
toc;
filename1=strcat('ITU_heatmap',num2str(rev_num),'.png');
saveas(gcf,char(filename1))
toc;
pause(0.1)


max(max(max_dBm))


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