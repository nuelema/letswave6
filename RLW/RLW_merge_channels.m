function [out_header,out_data,message_string]=RLW_merge_channels(datasets,merge_idx);
%RLW_merge_channels
%
%Merge channels
%
% Author : 
% Andre Mouraux
% Institute of Neurosciences (IONS)
% Universite catholique de louvain (UCL)
% Belgium
% 
% Contact : andre.mouraux@uclouvain.be
% This function is part of Letswave 6
% See http://nocions.webnode.com/letswave for additional information
%

%init message_string
message_string={};
message_string{end+1}='Merge channels';

%check merge_idx
if isempty(merge_idx);
    message_string{end+1}='No files to merge. Exit.';
    return;
end;

%merge_idx(1) > out_data & out_header
out_data=datasets(merge_idx(1)).data;
out_header=datasets(merge_idx(1)).header;

%check epochdata
if isfield(out_header,'epochdata');
    if isempty(out_header.epochdata);
    else
        if isfield(out_header.epochdata(1),'data');
            message_string{end+1}='Epoch data found in the dataset. Merged file will only contain epoch data of the first dataset.';
        end;
    end;
end;

%check events
if isfield(out_header,'events');
else
    out_header.events=[];
end;

%loop through merge_idx
if length(merge_idx)>1;
    for merge_pos=2:length(merge_idx);

        %check sizes
        if (out_header.datasize([1 3:6])==datasets(merge_idx(merge_pos)).header.datasize([1 3:6]));
        else
            message_string{end+1}='Datasets cannot be merged as their sizes do not match. Exit.';
            return;
        end;

        %merge data
        out_data=cat(2,out_data,datasets(merge_idx(merge_pos)).data);

        %number of channels
        num_channels=size(out_data,2);

        %header
        header=datasets(merge_idx(merge_pos)).header;

        %chanlocs
        out_header.chanlocs=[out_header.chanlocs header.chanlocs];

        %events
        if isfield(header,'events');
            if isempty(header.events);
            else
                message_string{end+1}='Merging events.';
                out_header.events=[out_header.events header.events];
            end;
        end;
    end;
end;

%clear out_header.history
out_header.history=[];

%change number of channels
out_header.datasize=size(out_data);

%delete duplicate events
if isfield(out_header,'events');
    if isempty(out_header.events);
    else
        message_string{end+1}='Deleting duplicate events.';
        events=out_header.events;
        if length(events)>1;
            %loop through events
            eventindex=ones(length(events));
            for eventpos=1:length(events)-1;
                for eventpos2=eventpos+1:length(events);
                    if isequal(events(eventpos),events(eventpos2));
                        eventindex(eventpos2)=0;
                    end;
                end;
            end;
            events(find(eventindex==0))=[];
            out_header.events=events;
        end;
    end;
end;
