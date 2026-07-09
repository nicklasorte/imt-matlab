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
%folder1='C:\Users\nlasorte\OneDrive - National Telecommunications and Information Administration\MATLAB2024\imt-matlab-main 6-2-2026\imt-matlab-main'
folder1='C:\Users\nlasorte\OneDrive - National Telecommunications and Information Administration\MATLAB2024\imt-matlab-main 7-7-2026\imt-matlab-main'
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
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=26  %%%%%%%%% For comparison:3 Hours (Need to break it down into chunks)
% opts=struct();
% opts.aasGeometryPreset='ctia_7ghz_1x6'  %%%%90.8dBm
% opts.outputFrame='panel' %%%%%%%%%The CTIA heatmap coordinate system
% opts.numMc=10000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%7-7-2026
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=28 % %%: ITU r23 1x3, EIRP
% opts=struct();
% opts.numMc=1000;  %%%%11 mins
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='r23_1x3_default'
% opts.outputFrame='panel' %%%%%%%%%The CTIA heatmap coordinate system
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
rev_num=29 % %%: ITU r23 1x3, EIRP + realized-GAIN heatmap
opts=struct();
opts.numMc=1000;
opts.seed=rev_num;
opts.azGridDeg=-180:2:180; %%%%CTIA grid
opts.elGridDeg=-90:1:90; %%%%CTIA grid
opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
opts.aasGeometryPreset='r23_1x3_default'
opts.outputFrame='panel'
opts.outputDomain='both' %%%%'eirp' | 'gain' | 'both'
opts.gainBinEdgesDbi=[-60:0.1:40]; %%%%default is -100:0.5:40
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=30 % %% CTIA 1x6, EIRP + gain heatmap
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='ctia_7ghz_1x6'
% opts.outputFrame='panel'
% opts.outputDomain='both'  %%%%'eirp' | 'gain' | 'both'
% opts.gainBinEdgesDbi=[-60:0.1:40];
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=31 % %% rev 49: activity-weighted '% of time' CDF, LEGACY model (p = tdd*load)
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='r23_1x3_default';
% opts.outputFrame='panel';
% opts.activityWeightedCdf=true;
% opts.activityModel='legacy';
% opts.tddActivityFactor=0.75;
% opts.networkLoadingFactor=0.25; %%ITU example -> p = 0.1875
% opts.activityOffFloorDbm=-Inf;
% %%%%%%%%%%%%%%see result.activityWeightedPercentileMaps
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%It reshapes the CDF — it is not a flat −10·log10(p) power cut.
% The model treats p as probability-of-transmission: the sector is at full peak a fraction p of the time and off the rest,so requested percentile
% Pout maps to the always-on percentile Pon = 100 − (100−Pout)/p.
% With p=0.1875 the sector is off ~81% of the time, so every percentile at or below 100·(1−p) ≈ 81.25% falls in the off region and takes activityOffFloorDbm (−Inf by default → those cells read −Inf, i.e. off).
% Only the top ~19% of time-percentiles carry real EIRP. That's the correct "% of time" exceedance behavior, but it will look nothing like a uniformly-dimmed heatmap, so don't expect the whole map to drop ~7 dB.
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=32 %%%%%%Antenna Pointing Histogram for the Example in Rev3 Working Paper
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180;
% opts.elGridDeg=-90:1:90;
% opts.binEdgesDbm=[-100:0.1:120];
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='r23_1x3_default';
% opts.outputFrame='panel';
% opts.computePointingHistogram=true;
% opts.outputDomain='both';               % EIRP + antenna gain heatmap
% opts.gainBinEdgesDbi=[-60:0.1:40];     % finer than default -100:0.5:40
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Gain output lands in two fields:
%result.gainPercentileMaps — .values in dBi, same Naz × Nel × P shape as percentileMaps. 
% This is the gain heatmap per percentile.
%result.gainStats — the dBi accumulator (counts / bin edges), same structure as .stats but in gain units, 
% if you want to re-slice at other percentiles yourself.
%One interpretation note: the gain aggregation rule is max_over_beams_envelope (confirmed in metadata.gainAggregation) — 
% the peak gain envelope across beams per cell, not a power sum. So far-off-axis cells sit at the floor with near-degenerate distributions; 
% that's expected.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%%%%%%%%%%%%%%%%%%%THESE HAVE NOT RUN YET

% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=31 % %% rev 36: r23 1x3, CODEBOOK beams (quantized PMI vs ideal steering)
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='r23_1x3_default'
% opts.outputFrame='panel'
% opts.beamSelection='codebook' %%%%default is 'ideal'
% opts.codebookOversample=[4 4]; %%%%TS 38.214 Table 5.2.2.2.1-2 default
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



% %% rev 30: CTIA 1x6, panel frame
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=30
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='ctia_7ghz_1x6'
% opts.outputFrame='panel'
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');




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


plot_eirp_heatmap_steps(struct('result', result));    % bare call also works; it runs the baseline itself

'check'
pause;

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



%%%%%%%%%The antenna pointing histogram
if ~isempty(result.pointingHistogram.counts)

    result.gainStats

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    h = result.pointingHistogram;         % needs the run to have computePointingHistogram=true
    % Step 1: how many times the antenna pointed at each (az,el)
    counts = double(h.counts);            % nAzBin x nElBin, az = rows (integer tallies)

    % Step 2: normalize over the entire area (fraction of all pointing events per cell)
    Pn = h.pmf;                           % == counts ./ h.numInRange ; sums to 1 in-range

    azc = h.azCenters;                    % 1 x nAzBin bin centers [deg]
    elc = h.elCenters;                    % 1 x nElBin

    % Step 3: surf, color = normalized counts (your house style)
    [X1,Y1] = meshgrid(azc, elc);         % Nel x Naz
    int_az  = min(azc):1:max(azc);
    int_el  = min(elc):1:max(elc);
    [Xq,Yq] = meshgrid(int_az, int_el);
    Zq = interp2(X1, Y1, Pn', Xq, Yq);    % Pn' : Naz x Nel -> Nel x Naz

    color_set1 = plasma(256);             % NOT plasma(range): PMF range is <1
    f1 = figure;
    axes;
    hold on;
    surf(Xq, Yq, Zq, 'EdgeColor','none')
    xticks(min(Xq(:)):(max(Xq(:))-min(Xq(:)))/20:max(Xq(:)))
    yticks(min(Yq(:)):(max(Yq(:))-min(Yq(:)))/10:max(Yq(:)))
    xlabel('Azimuth [Degrees]')
    ylabel('Elevation [Degrees]')
    hcb = colorbar; ylabel(hcb, 'Normalized pointing count')
    grid on;
    colormap(f1, color_set1);
    filename1=strcat('antenna_point_hist_',num2str(rev_num),'.png');
    saveas(gcf,char(filename1))
    toc;
    pause(0.1)

    axis([-60 60 -20, 5])
    xticks(min(xlim):(max(xlim)-min(xlim))/10:max(xlim))
    yticks(min(ylim):(max(ylim)-min(ylim))/25:max(ylim))
    pause(0.1)
    filename1=strcat('antenna_point_hist_zoom_',num2str(rev_num),'.png');
    saveas(gcf,char(filename1))
    toc;
    pause(0.1)



    % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Create a heatmap
    % g = result.gainStats;
    % 
    % % ---- pick the gain statistic (Naz x Nel, dBi) ----
    % z_gain1 = g.max_dBm;                              % 100th-pct peak envelope
    % % z_gain1 = 10*log10(g.sum_lin_mW ./ g.numMc);   % or: power-domain mean gain
    % 
    % % ---- native grid + interpolation mesh (finer, for a smooth surface) ----
    % [X1,Y1] = meshgrid(g.azGrid, g.elGrid);          % Nel x Naz  (el rows, az cols)
    % int_mesh_azi = min(g.azGrid):0.5:max(g.azGrid);
    % int_mesh_ele = min(g.elGrid):0.5:max(g.elGrid);
    % 
    % [Xq,Yq] = meshgrid(int_mesh_azi,int_mesh_ele);
    % Z1_Vq = interp2(X1,Y1,z_gain1',Xq,Yq);           % z_gain1' : Naz x Nel -> Nel x Naz
    % dbm1_range=max(max(Z1_Vq))-min(min(Z1_Vq));
    % color_set1=plasma(dbm1_range); %%%%%%%%%%%%Colormap
    % tic;
    % f1=figure;
    % AxesH = axes;
    % hold on;
    % surf(Xq,Yq,Z1_Vq,'EdgeColor','none')
    % xticks(min(min(Xq)):(max(max(Xq))-min(min(Xq)))/10:max(max(Xq)))
    % yticks(min(min(Yq)):(max(max(Yq))-min(min(Yq)))/10:max(max(Yq)))
    % xlabel('Azimuth [Degrees]')
    % ylabel('Elevation [Degrees]')
    % h = colorbar;
    % ylabel(h, 'Antenna Gain [dBi]')
    % grid on;
    % colormap(f1,color_set1)

    % az = result.gainStats.azGrid;      % 1 x 181
    % el = result.gainStats.elGrid;      % 1 x 181
    % p  = result.gainStats.binEdges;    % 1 x 1001  (gain bin edges, dBi)
    % V  = result.gainStats.counts;      % 181 x 181 x 1000  (az x el x gainbin)
    % 
    % % ---- collapse the counts cube -> one gain per (az,el) cell ----
    % bc  = (p(1:end-1) + p(2:end)) / 2;   % 1 x 1000 gain bin centers [dBi]
    % c   = double(V);
    % cum = cumsum(c, 3);
    % tot = cum(:,:,end);                  % samples per cell (= numMc where in-range)
    % 
    % P = 100;                             % 100 = peak, 50 = median, 95 = 95th, ...
    % [~, idx] = max(cum >= (P/100).*tot, [], 3);
    % Zg = reshape(bc(idx), size(idx));    % 181 x 181 gain surface [dBi]
    % Zg(tot == 0) = NaN;                  % guard empty cells (no counts in range)
    % 
    % % ---- your plot block, sourced from az/el/Zg ----
    % [X1,Y1] = meshgrid(az, el);          % Nel x Naz
    % int_mesh_azi = min(az):0.5:max(az);
    % int_mesh_ele = min(el):0.5:max(el);
    % 
    % [Xq,Yq] = meshgrid(int_mesh_azi,int_mesh_ele);
    % Z1_Vq = interp2(X1,Y1,Zg',Xq,Yq);    % Zg' : 181x181 az x el -> el x az
    % dbm1_range=max(max(Z1_Vq))-min(min(Z1_Vq));
    % color_set1=plasma(round(dbm1_range)); %%%%%%%%%%%%Colormap
    % tic;
    % f1=figure;
    % AxesH = axes;
    % hold on;
    % surf(Xq,Yq,Z1_Vq,'EdgeColor','none')
    % xticks(min(min(Xq)):(max(max(Xq))-min(min(Xq)))/10:max(max(Xq)))
    % yticks(min(min(Yq)):(max(max(Yq))-min(min(Yq)))/10:max(max(Yq)))
    % xlabel('Azimuth [Degrees]')
    % ylabel('Elevation [Degrees]')
    % h = colorbar;
    % ylabel(h, 'Antenna Gain [dBi]')
    % grid on;
    % colormap(f1,color_set1)

    % tic;
    % [ia, ie, ib] = ind2sub(size(V), find(V > 0));   % occupied voxels only
    % cnt = double(V(V > 0));
    % figure; scatter3(az(ia), el(ie), bc(ib), 6, cnt, 'filled');
    % xlabel('Azimuth [Deg]'); ylabel('Elevation [Deg]'); zlabel('Antenna Gain [dBi]');
    % h = colorbar; ylabel(h, 'Count'); colormap(plasma(256)); view(45,30);
    % toc;


    % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Create the table for Ant
    % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Pointing Distribution
    % az = result.gainStats.azGrid;
    % el = result.gainStats.elGrid;
    % p  = result.gainStats.binEdges;
    % V  = result.gainStats.counts;
    % 
    % 
    % 'try to make a 3D histogram?'
    % pause;
    % [AZ, EL] = ndgrid(az, el);
    % T_ant_dist = table();
    % T_ant_dist.az_deg = AZ(:);
    % size(AZ(:)) %%%1936 x 1
    % T_ant_dist.el_deg = EL(:);
    % for k = 1:numel(p)
    %     colName = sprintf('p%g_dBi', p(k));
    %     colName = matlab.lang.makeValidName(colName);
    %     slice = V(:,:,k);        % az x el
    %     T_ant_dist.(colName) = slice(:);  % 1936 x 1
    % end
    % 
    % 'Writing the table . . .'
    % tic;
    % writetable(T_ant_dist, strcat('antenna_gainStats_grid_',num2str(rev_num),'.csv'));
    % toc;
    % T_ant_dist

end




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Antenna Gain Heatmap, need to
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%toggle it in the inputs 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% opts.outputDomain='both'  %%%%'eirp' | 'gain' | 'both'
if ~isempty(result.gainPercentileMaps.values)
    result.gainPercentileMaps
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Create the table for Ant Gain
    az = result.gainPercentileMaps.azGrid;
    el = result.gainPercentileMaps.elGrid;
    p  = result.gainPercentileMaps.percentiles;
    V  = result.gainPercentileMaps.values;

    [AZ, EL] = ndgrid(az, el);
    T_ant_gain = table();
    T_ant_gain.az_deg = AZ(:);
    size(AZ(:)) %%%1936 x 1
    T_ant_gain.el_deg = EL(:);
    for k = 1:numel(p)
        colName = sprintf('p%g_dBi', p(k));
        colName = matlab.lang.makeValidName(colName);
        slice = V(:,:,k);        % az x el
        T_ant_gain.(colName) = slice(:);  % 1936 x 1
    end

    'Writing the table . . .'
    tic;
    writetable(T_ant_gain, strcat('gainPercentileMaps_grid_',num2str(rev_num),'.csv'));
    toc;

    array_T_ant_gain=table2array(T_ant_gain);
    [max_ant_gain,max3_idx]=max(array_T_ant_gain(:,end))
    array_zero_gain=array_T_ant_gain(max3_idx,[3:end]);
    max(array_zero_gain)

    figure;
    hold on;
    plot(array_zero_gain,p,'-ob')
    ylabel('CDF')
    xlabel('Antenna Gain [dBi]')
    grid on;
    pause(0.1)
    saveas(gcf,char(strcat('cdf_ant_gain_single_zero_',num2str(rev_num),'.png')))
    pause(0.1);



     %%%%%%%%%%%%%%%%%%%%%%%Heatmap
    table_header=T_ant_gain.Properties.VariableNames
    t_az_idx=find(contains(table_header,'az_deg'));
    t_el_idx=find(contains(table_header,'el_deg'));
    t50idx=find(contains(table_header,'p50_dB'));
    data1=table2array(T_ant_gain(:,[t_az_idx,t_el_idx,t50idx]));

    %%%%%%%%%%%%%%%%%%%%%%%%%%
    array_eirp1=data1(:,3);
    max(array_eirp1)
    array_azi1=data1(:,1);
    array_ele1=data1(:,2);
    uni_azi1=unique(array_azi1);
    uni_el1=unique(array_ele1);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    mat_size1=[numel(uni_azi1),numel(uni_el1)];
    z_eirp1=reshape(array_eirp1,mat_size1);
    [X1,Y1]=meshgrid(uni_azi1,uni_el1);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


    %%%%%%%%%%%%%%Need to define a meshgrid to interp2 both data sets.
    min_azi_step=min(diff(uni_azi1));
    min_ele_step=min(diff(uni_el1));

    %%%%%%%%%Cover the minimum range of both;
    azi_intersect=uni_azi1;
    ele_intersect=uni_el1;

    int_mesh_azi=min(azi_intersect):min_azi_step:max(azi_intersect);
    int_mesh_ele=min(ele_intersect):min_ele_step:max(ele_intersect);

    [Xq,Yq] = meshgrid(int_mesh_azi,int_mesh_ele);
    Z1_Vq = interp2(X1,Y1,z_eirp1',Xq,Yq);
    dbm1_range=max(max(Z1_Vq))-min(min(Z1_Vq));
    color_set1=plasma(dbm1_range); %%%%%%%%%%%%Colormap
    tic;
    f1=figure;
    AxesH = axes;
    hold on;
    surf(Xq,Yq,Z1_Vq,'EdgeColor','none')
    xticks(min(min(Xq)):(max(max(Xq))-min(min(Xq)))/10:max(max(Xq)))
    yticks(min(min(Yq)):(max(max(Yq))-min(min(Yq)))/10:max(max(Yq)))
    xlabel('Azimuth [Degrees]')
    ylabel('Elevation [Degrees]')
    h = colorbar;
    ylabel(h, 'Antenna Gain [dBi]')
    grid on;
    colormap(f1,color_set1)
    toc;
    filename1=strcat('antenna_gain_',num2str(rev_num),'.png');
    saveas(gcf,char(filename1))
    toc;
    pause(0.1)


    'need to check this plot'
    pause;



end



if ~isempty(result.activityWeightedPercentileMaps.values)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    result.activityWeightedPercentileMaps
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    az = result.activityWeightedPercentileMaps.azGrid;
    el = result.activityWeightedPercentileMaps.elGrid;
    p  = result.activityWeightedPercentileMaps.percentiles;
    V  = result.activityWeightedPercentileMaps.values;

    [AZ, EL] = ndgrid(az, el);
    T_activity = table();
    T_activity.az_deg = AZ(:);
    size(AZ(:)) %%%32761 x 1
    T_activity.el_deg = EL(:);

    %'Add the min/max/mean to the table at the end'
    for k = 1:numel(p)
        colName = sprintf('p%g_dBm', p(k));
        colName = matlab.lang.makeValidName(colName);
        slice = V(:,:,k);        % az x el
        T_activity.(colName) = slice(:);  % 1936 x 1
    end

    'Writing the table'
    tic;
    writetable(T_activity, strcat('activityWeightedPercentileMaps_grid_',num2str(rev_num),'.csv'));
    toc;

    T_activity


       array_T_activity=table2array(T_activity);
    [max_pwr,max4_idx]=max(array_T_activity(:,end))
    array_max_activity=array_T_activity(max4_idx,[3:end]);
    max(array_max_activity)

    figure;
    hold on;
    plot(array_max_activity,p,'-ob')
    ylabel('CDF')
    xlabel('EIRP [dBm/100MHz]')
    grid on;
    axis([0 80 0 100])
    pause(0.1)
    saveas(gcf,char(strcat('activityWeightedPercentileMaps_single_zero_',num2str(rev_num),'.png')))
    pause(0.1);

end





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
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Permutations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% =======================================================================
%  r23_permutation_runs.m
%  Major-permutation sweep for result = runR23AasEirpCdfGrid(opts)
%  Verified against nicklasorte/imt-matlab HEAD 443050a (2026-07-07).
%
%  28 runs, rev_num 28..55. Every block is fully self-contained
%  (copy/paste any one alone). Common base = CTIA grid, panel frame
%  unless noted, numMc=1000, seed=rev_num, 0.1 dB bins, dense
%  percentiles (~18 min each -> ~8.5 h full sweep).
%
%  Groups:
%    A  28-33  geometry x outputFrame        (3 presets x panel/global)
%    B  34-35  environment variants          (suburban, microSuburban)
%    C  36-38  beamSelection='codebook'      (per geometry)
%    D  39-41  outputDomain='both' (gain)    (per geometry)
%    E  42-43  clampElevation=false          (RKF/DoD no-clip)
%    F  44-53  feature layers, one at a time (1x3 panel baseline)
%    G  54-55  kitchen sink (all layers on)  (1x3, 1x6)
%
%  Notes:
%   - epre / subband are SEPARATE outputs: stats/percentileMaps unchanged.
%   - layering / prbWeighting / ueCountModel RESHAPE the CDF (sensitivity).
%   - prbWeighting departs from the ITU equal-bandwidth baseline.
%  =======================================================================

% %% ---- GROUP A: geometry x outputFrame ---------------------------------

% %% rev 28: r23 1x3 baseline, panel frame (reference run)
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=28
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='r23_1x3_default'
% opts.outputFrame='panel' %%%%%%%%%The CTIA heatmap coordinate system
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');

% %% rev 29: r23 1x3 baseline, GLOBAL frame (curved 'tilt smile' maps)
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=29
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='r23_1x3_default'
% opts.outputFrame='global'
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');

% %% rev 30: CTIA 1x6, panel frame
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=30
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='ctia_7ghz_1x6'
% opts.outputFrame='panel'
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');

% %% rev 31: CTIA 1x6, GLOBAL frame
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=31
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='ctia_7ghz_1x6'
% opts.outputFrame='global'
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');

% %% rev 32: micro 8x8 (ITU Table 19), microUrban, panel frame
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=32
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='r23_micro_8x8'
% opts.environment='microUrban' %%%%pair per docstring; 6 m BS height
% opts.outputFrame='panel'
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');

% %% rev 33: micro 8x8, microUrban, GLOBAL frame
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=33
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='r23_micro_8x8'
% opts.environment='microUrban'
% opts.outputFrame='global'
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');

% %% ---- GROUP B: environment variants -----------------------------------

% %% rev 34: r23 1x3, macro SUBURBAN, panel frame
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=34
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='r23_1x3_default'
% opts.environment='suburban'
% opts.outputFrame='panel'
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');

% %% rev 35: micro 8x8, microSUBURBAN, panel frame
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=35
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='r23_micro_8x8'
% opts.environment='microSuburban'
% opts.outputFrame='panel'
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');
%
% %% ---- GROUP C: 3GPP Type I DFT/PMI codebook beam selection ------------

% %% rev 36: r23 1x3, CODEBOOK beams (quantized PMI vs ideal steering)
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=36
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='r23_1x3_default'
% opts.outputFrame='panel'
% opts.beamSelection='codebook' %%%%default is 'ideal'
% opts.codebookOversample=[4 4]; %%%%TS 38.214 Table 5.2.2.2.1-2 default
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');

% %% rev 37: CTIA 1x6, CODEBOOK beams (aliasing / grating-lobe caveat case)
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=37
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='ctia_7ghz_1x6'
% opts.outputFrame='panel'
% opts.beamSelection='codebook'
% opts.codebookOversample=[4 4];
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');

% %% rev 38: micro 8x8, CODEBOOK beams
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=38
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='r23_micro_8x8'
% opts.environment='microUrban'
% opts.outputFrame='panel'
% opts.beamSelection='codebook'
% opts.codebookOversample=[4 4];
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');

% %% ---- GROUP D: antenna GAIN heatmap (outputDomain='both') -------------
%
% %% rev 39: r23 1x3, EIRP + realized-GAIN heatmap
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=39
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='r23_1x3_default'
% opts.outputFrame='panel'
% opts.outputDomain='both' %%%%'eirp' | 'gain' | 'both'
% opts.gainBinEdgesDbi=[-60:0.1:40]; %%%%default is -100:0.5:40
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');

% %% rev 40: CTIA 1x6, EIRP + gain heatmap
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=40
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='ctia_7ghz_1x6'
% opts.outputFrame='panel'
% opts.outputDomain='both'
% opts.gainBinEdgesDbi=[-60:0.1:40];
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');

% %% rev 41: micro 8x8, EIRP + gain heatmap
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=41
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='r23_micro_8x8'
% opts.environment='microUrban'
% opts.outputFrame='panel'
% opts.outputDomain='both'
% opts.gainBinEdgesDbi=[-60:0.1:40];
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');

% %% ---- GROUP E: elevation no-clip  --------------

% %% rev 42: r23 1x3, elevation NO-CLIP
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=42
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='r23_1x3_default'
% opts.outputFrame='panel'
% opts.clampElevation=false %%%%default true clamps steering to [-10,0]
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');
%
% %% rev 43: CTIA 1x6, elevation NO-CLIP
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=43
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='ctia_7ghz_1x6'
% opts.outputFrame='panel'
% opts.clampElevation=false
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');

% %% ---- GROUP F: feature layers one-at-a-time (1x3, panel) --------------

% %% rev 44: per-RE EPRE offsets (TS 38.214 Cl 4.1) -> out.epre envelope; CDF unchanged
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=44
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='r23_1x3_default'
% opts.outputFrame='panel'
% opts.epre=struct( ...
%     'dmrsConfigType',       1, ...  %%Table 4.1-1
%     'dmrsCdmGroupsNoData',  2, ...  %%-> +3 dB DM-RS boost
%     'includePtrs',          true, ...
%     'pdschLayers',          4, ...  %%Table 4.1-2 -> +6 dB PT-RS boost
%     'epreRatioState',       0, ...
%     'csirsPowerOffsetSsDb', 3);     %%powerControlOffsetSS
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');

% %% rev 45: rank / MU-MIMO LAYERING (RESHAPES the CDF; alt scenario)
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=45
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='r23_1x3_default'
% opts.outputFrame='panel'
% opts.layering=struct( ...
%     'rank',           [0.5 0.3 0.15 0.05], ...  %%rank PMF over 1..4
%     'maxTotalLayers', 8, ...
%     'layerSpreadDeg', 2, ...
%     'clipRule',       'greedy');
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');

% %% rev 46: PRB / bandwidth WEIGHTING (SENSITIVITY ONLY -- departs from ITU)
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=46
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='r23_1x3_default'
% opts.outputFrame='panel'
% opts.prbWeighting=struct('mode','random','spread',0.5); %%log-normal shares
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');

% %% rev 47: per-SUBBAND narrowband worst-case density -> out.subband; CDF unchanged
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=47
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='r23_1x3_default'
% opts.outputFrame='panel'
% opts.subband=struct('subbandMHz',1); %%dBm/MHz victim view
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');

% %% rev 48: SSB broadcast sweep + time-weighted grid -> out.ssb / out.timeWeighted
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=48
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='r23_1x3_default'
% opts.outputFrame='panel'
% opts.ssb=struct(); %%default 8-beam sweep, coarseConf [3 3 2], tiers [6 0 -3]
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');

% %% rev 49: activity-weighted '% of time' CDF, LEGACY model (p = tdd*load)
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=49
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='r23_1x3_default'
% opts.outputFrame='panel'
% opts.activityWeightedCdf=true
% opts.activityModel='legacy'
% opts.tddActivityFactor=0.75;
% opts.networkLoadingFactor=0.25; %%ITU example -> p = 0.1875
% opts.activityOffFloorDbm=-Inf;
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');

% %% rev 50: activity-weighted CDF, FRAME model (p = alphaUe) + SSB sweep off-floor
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=50
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='r23_1x3_default'
% opts.outputFrame='panel'
% opts.ssb=struct(); %%supplies the per-cell off-region floor
% opts.activityWeightedCdf=true
% opts.activityModel='frame' %%symbol-counted TS 38.214 frame budget
% opts.activityOffFloorUses='timeAvg' %%'timeAvg' | 'envelope'
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');

% %% rev 51: variable UE count, UNIFORM (RESHAPES the CDF)
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=51
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='r23_1x3_default'
% opts.outputFrame='panel'
% opts.ueCountModel='uniform'
% opts.minUesPerSector=1;
% opts.maxUesPerSector=6;
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');

% %% rev 52: variable UE count, POISSON (RESHAPES the CDF)
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=52
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='r23_1x3_default'
% opts.outputFrame='panel'
% opts.ueCountModel='poisson'
% opts.meanUesPerSector=3; %%lambda = nominal 3 UEs
% opts.minUesPerSector=1;
% opts.maxUesPerSector=10;
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');

% %% rev 53: pointing diagnostics (histogram PMF + weighted map + mean heatmap)
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=53
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='r23_1x3_default'
% opts.outputFrame='panel'
% opts.computePointingHistogram=true
% opts.pointingWeightedMap=true %%FSS-zone (0,0) worst-case-but-likely map
% opts.computePointingHeatmap=true
% %%defaults cover clamp + no-clamp cases: az -60:2:60, el -50:1:5
% %%opts.pointingAzBinEdgesDeg=[-60:2:60]; opts.pointingElBinEdgesDeg=[-50:1:5];
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');

% %% ---- GROUP G: kitchen sink -------------------------------------------

% %% rev 54: KITCHEN SINK, r23 1x3: all layers on
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=54
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='r23_1x3_default'
% opts.outputFrame='panel'
% opts.beamSelection='codebook'
% opts.codebookOversample=[4 4];
% opts.outputDomain='both'
% opts.gainBinEdgesDbi=[-60:0.1:40];
% opts.epre=struct('dmrsConfigType',1,'dmrsCdmGroupsNoData',2, ...
%     'includePtrs',true,'pdschLayers',4,'epreRatioState',0, ...
%     'csirsPowerOffsetSsDb',3);
% opts.layering=struct('rank',[0.5 0.3 0.15 0.05],'maxTotalLayers',8, ...
%     'layerSpreadDeg',2,'clipRule','greedy');
% opts.prbWeighting=struct('mode','random','spread',0.5);
% opts.subband=struct('subbandMHz',1);
% opts.ssb=struct();
% opts.activityWeightedCdf=true
% opts.activityModel='frame'
% opts.activityOffFloorUses='timeAvg'
% opts.ueCountModel='poisson'
% opts.meanUesPerSector=3;
% opts.minUesPerSector=1;
% opts.maxUesPerSector=10;
% opts.computePointingHistogram=true
% opts.pointingWeightedMap=true
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');

% %% rev 55: KITCHEN SINK, CTIA 1x6: all layers on
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rev_num=55
% opts=struct();
% opts.numMc=1000;
% opts.seed=rev_num;
% opts.azGridDeg=-180:2:180; %%%%CTIA grid
% opts.elGridDeg=-90:1:90; %%%%CTIA grid
% opts.binEdgesDbm=[-100:0.1:120];  %%%%%Default is 1dB
% opts.percentiles=unique(sort(horzcat([1:1:99],[0.1:0.1:1],[99:0.1:99.9],0.01, 99.99)));
% opts.aasGeometryPreset='ctia_7ghz_1x6'
% opts.outputFrame='panel'
% opts.beamSelection='codebook'
% opts.codebookOversample=[4 4];
% opts.outputDomain='both'
% opts.gainBinEdgesDbi=[-60:0.1:40];
% opts.epre=struct('dmrsConfigType',1,'dmrsCdmGroupsNoData',2, ...
%     'includePtrs',true,'pdschLayers',4,'epreRatioState',0, ...
%     'csirsPowerOffsetSsDb',3);
% opts.layering=struct('rank',[0.5 0.3 0.15 0.05],'maxTotalLayers',8, ...
%     'layerSpreadDeg',2,'clipRule','greedy');
% opts.prbWeighting=struct('mode','random','spread',0.5);
% opts.subband=struct('subbandMHz',1);
% opts.ssb=struct();
% opts.activityWeightedCdf=true
% opts.activityModel='frame'
% opts.activityOffFloorUses='timeAvg'
% opts.ueCountModel='poisson'
% opts.meanUesPerSector=3;
% opts.minUesPerSector=1;
% opts.maxUesPerSector=10;
% opts.computePointingHistogram=true
% opts.pointingWeightedMap=true
% % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% result=runR23AasEirpCdfGrid(opts);
% % save(sprintf('result_rev%02d.mat',rev_num),'result','-v7.3');