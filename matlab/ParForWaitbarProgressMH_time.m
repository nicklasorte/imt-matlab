function ParForWaitbarProgressMH_time(h,NbrePts,Msg,start_time)
% h: Handle of the Waitbar
% NbrePts: Number of Steps  
% Msg: Waitbar's Message Field


% Get the Fractional Length of the Waitbar (increment first so the first
% callback reflects 1 completed step, avoiding division-by-zero when x==0)
x = get(h,'UserData') + 1;

%%%%%%Update the Message with Estmated Time
sec_elap=etime(clock,start_time);  % the total elapsed time
mins_elap=sec_elap/60;
hours_elap=mins_elap/60;
days_elap=hours_elap/24;

%%%%%%%%Calculate the estimated time remaining
percentage=x/NbrePts;
sec_left=sec_elap*((1/percentage)-1);
mins_left=sec_left/60;
hours_left=mins_left/60;
days_left=hours_left/24;

if sec_elap<60
    label_elap=strcat(' Elapsed:',num2str(round(sec_elap,0)),' Secs ');
elseif mins_elap<60
    label_elap=strcat(' Elapsed:',num2str(round(mins_elap,0)),' Mins ');
elseif hours_elap<24
    label_elap=strcat(' Elapsed:',num2str(round(hours_elap,0)),' Hours ');
else
    label_elap=strcat(' Elapsed:',num2str(round(days_elap,0)),' Days ');
end

if sec_left<60
    label_remain=strcat(' - Remaining:',num2str(round(sec_left,0)),' Secs ');
elseif mins_left<60
    label_remain=strcat(' - Remaining:',num2str(round(mins_left,0)),' Mins ');
elseif hours_left<24
    label_remain=strcat(' - Remaining:',num2str(round(hours_left,0)),' Hours ');
else
    label_remain=strcat(' - Remaining:',num2str(round(days_left,0)),' Days ');
end


temp_Msg=strcat(Msg,label_elap,label_remain);

%waitbar(percentage,h,Msg);
waitbar(percentage,h,temp_Msg);

% Progress Indicator as a Percentage
set(h,'Name',sprintf('%.0f%%',percentage*100))

% Update the Fractional Length of the Waitbar 
set(h,'UserData',x)

end


