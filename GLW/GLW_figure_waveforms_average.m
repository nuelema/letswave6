function varargout = GLW_figure_waveforms_average(varargin)
% GLW_FIGURE_WAVEFORMS_AVERAGE MATLAB code for GLW_figure_waveforms_average.fig






% Begin initialization code - DO NOT EDIT
gui_Singleton = 0;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @GLW_figure_waveforms_average_OpeningFcn, ...
                   'gui_OutputFcn',  @GLW_figure_waveforms_average_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT









% --- Executes just before GLW_figure_waveforms_average is made visible.
function GLW_figure_waveforms_average_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure1
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to GLW_figure_waveforms_average (see VARARGIN)
% Choose default command line output for GLW_figure_waveforms_average
handles.output = hObject;
% Update handles structure
guidata(hObject, handles);
%function('dummy',configuration,datasets);
%configuration
configuration=varargin{2};
set(handles.process_btn,'Userdata',configuration);
%datasets
datasets=varargin{3};
%axis
axis off;
%set_GUI_parameters
CLW_set_GUI_parameters(handles);
%!!!!!!!!!!!!!!!!!!!!!!!!
%update GUI configuration
%!!!!!!!!!!!!!!!!!!!!!!!!
%datasets_listbox
if isempty(datasets);
    return;
end;
for i=1:length(datasets);
    st{i}=datasets(i).header.name;
end;
set(handles.datasets_listbox,'String',st);
set(handles.datasets_listbox,'Value',1);
%y_edit
set(handles.y_edit,'String',num2str(datasets(1).header.ystart));
%z_edit
set(handles.z_edit,'String',num2str(datasets(1).header.zstart));
%datasets
set(handles.datasets_listbox,'Userdata',datasets);
%epoch_listbox / channel_listbox
update_listbox(handles);
%waves_listbox
set(handles.waves_listbox,'UserData',[]);
set(handles.waves_listbox,'String',{});
%linecolor_axes
set(handles.linecolor_axes,'Color',[1 1 1]);
line_handle=plot(handles.linecolor_axes,[-1 1],[0 0],'-','Color',[0 0 0],'Linewidth',1);
set(handles.linecolor_axes,'XLim',[-1.5 1.5]);
set(handles.linecolor_axes, 'XTickLabelMode', 'Manual');
set(handles.linecolor_axes, 'XTick', []);
set(handles.linecolor_axes, 'YTickLabelMode', 'Manual');
set(handles.linecolor_axes, 'YTick', []);
set(handles.linecolor_axes,'UserData',line_handle);
%font list
t=listfonts;
set(handles.font_popup,'String',t);
%find font in list
a=find(strcmpi(t,'Arial')==1);
if isempty(a);
else
    set(handles.font_popup,'Value',a(1));
end;
%
read_linestyle(handles);
%!!!
%END
%!!!
% UIWAIT makes the GUI wait for user response (see UIRESUME)





function update_listbox(handles);
datasets=get(handles.datasets_listbox,'Userdata');
selected_datasets=get(handles.datasets_listbox,'Value');
dataset=datasets(selected_datasets(1));
%epoch_listbox
for i=1:dataset.header.datasize(1);
    st{i}=num2str(i);
end;
set(handles.epoch_listbox,'String',st);
v=get(handles.epoch_listbox,'Value');
if v>length(st);
    set(handles.epoch_listbox,'Value',1);
end;
%index_popup
if dataset.header.datasize(3)==1;
    set(handles.index_text,'Enable','off');
    set(handles.index_popup,'Enable','off');
else
    set(handles.index_text,'Enable','on');
    set(handles.index_popup,'Enable','on');
    if isfield(dataset.header.index_labels);
        st=dataset.header.index_labels;
    else
        st={};
        for i=1:dataset.header.datasize(3);
            st=num2str(i);
        end;
    end;
    set(handles.index_popup,'String',st);
    v=get(handles.index_popup,'Value');
    if v>length(st);
        set(handles.index_popup,'Value',1);
    end;
end;
%channel_listbox
st={};
for i=1:length(dataset.header.chanlocs);
    st{i}=dataset.header.chanlocs(i).labels;
end;
set(handles.channel_listbox,'String',st);
v=get(handles.channel_listbox,'Value');
if v>length(st);
    set(handles.channel_listbox,'Value',1);
end;
%z_edit
if dataset.header.datasize(4)==1;
    set(handles.z_text,'Enable','off');
    set(handles.z_edit,'Enable','off');
else
    set(handles.z_text,'Enable','on');
    set(handles.z_edit,'Enable','on');
end;
%y_edit
if dataset.header.datasize(5)==1;
    set(handles.y_text,'Enable','off');
    set(handles.y_edit,'Enable','off');
else
    set(handles.y_text,'Enable','on');
    set(handles.y_edit,'Enable','on');
end;




function update_waves_listbox(handles);
%wavedata
wavedata=get(handles.waves_listbox,'UserData');
%datasets
datasets=get(handles.datasets_listbox,'Userdata');
%datasetstring
datasetstring=get(handles.datasets_listbox,'String');
%build string
st={};
if isempty(wavedata);
else
    for i=1:length(wavedata);
        datasetpos=wavedata(i).datasetpos;
        header=datasets(datasetpos).header;
        if wavedata(i).average_dimension==1;
            %epoch_string
            epoch_string=[num2str(length(wavedata(i).epochpos)) ' epochs'];
            %channel_string
            channel_string=header.chanlocs(wavedata(i).channelpos).labels;
        else
            %epoch_string
            epoch_string=num2str(wavedata(i).epochpos);
            %channel_string
            channel_string=[num2str(length(wavedata(i).channelpos)) ' channels'];
        end;
        if isfield(header,'indexlabels');
            st{i}=[datasetstring{datasetpos} ' E:[' epoch_string '[ C:[' channel_string '] I:' header.indexlabels{wavedata(i).indexpos}];
        else
            st{i}=[datasetstring{datasetpos} ' E:[' epoch_string '] C:[' channel_string '] I:' num2str(wavedata(i).indexpos)];
        end;
    end;
end;
set(handles.waves_listbox,'String',st);







function read_linestyle(handles);
line_handle=get(handles.linecolor_axes,'UserData');
%color
C=get(line_handle,'Color');
set(handles.linecolor_btn,'UserData',C);
%width
W=get(line_handle,'LineWidth');
set(handles.linewidth_popup,'Value',W);
%linestyle
st={'-';':';'-.';'--'};
W=get(line_handle,'LineStyle');
set(handles.linestyle_popup,'Value',find(strcmpi(W,st)));





function write_linestyle(handles);
line_handle=get(handles.linecolor_axes,'UserData');
%color
C=get(handles.linecolor_btn,'UserData');
set(line_handle,'Color',C);
%width
W=get(handles.linewidth_popup,'Value');
set(line_handle,'LineWidth',W);
%style
st={'-';':';'-.';'--'};
W=st{get(handles.linestyle_popup,'Value')};
set(line_handle,'LineStyle',W);




% --- Outputs from this function are returned to the command line.
function varargout = GLW_figure_waveforms_average_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure1
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% Get default command line output from handles structure
varargout{1} = handles.output;
%configuration
configuration=get(handles.process_btn,'UserData');
varargout{2}=configuration;





% --- Executes during object creation, after setting all properties.
function figure1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called








% --- Executes on button press in process_btn.
function process_btn_Callback(hObject, eventdata, handles)
% hObject    handle to process_btn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
%wavedata
wavedata=get(handles.waves_listbox,'UserData');
%check wavedata is not empty
if isempty(wavedata);
    return;
end;
%datasets
datasets=get(handles.datasets_listbox,'Userdata');
%figure
h=figure;
%plot
hold on;
for wavepos=1:length(wavedata);
    header=datasets(wavedata(wavepos).datasetpos).header;
    epochpos=wavedata(wavepos).epochpos;
    channelpos=wavedata(wavepos).channelpos;
    %indexpos
    if header.datasize(3)==1;
        indexpos=1;
    else
        indexpos=wavedata(wavepos).indexpos;
    end;
    %dy
    if header.datasize(5)==1;
        dy=1;
    else
        y=wavedata(wavepos).y;
        dy=((y-header.ystart)/header.ystep)+1;
    end;
    %dz
    if header.datasize(4)==1;
        dz=1;
    else
        z=wavedata(wavepos).z;
        dz=((z-header.zstart)/header.zstep)+1;
    end;
    %tpx
    tpx=1:1:header.datasize(6);
    tpx=((tpx-1)*header.xstep)+header.xstart;
    %tpy
    %tpy(epochpos,channelpos,dx)
    tpy=squeeze(datasets(wavedata(wavepos).datasetpos).data(epochpos,channelpos,indexpos,dz,dy,:));
    %average_dimension
    average_dimension=wavedata(wavepos).average_dimension;
    %average
    display_option=get(handles.display_option,'Value');
    %
    switch display_option;
        case 1
            %average �sd
            tp_sd=std(tpy,[],average_dimension);
            tpy=mean(tpy,average_dimension);
            tpy_low=tpy-tp_sd;
            tpy_high=tpy+tp_sd;
        case 2
            %median �iqr
            tpy_low=prctile(tpy,0.25);
            tpy_high=prctile(tpy,0.75);
            tpy=median(tpy,average_dimension);
    end;
    %vertical spread?
    vertical_spread=str2num(get(handles.vertical_spread_edit,'String'));
    if vertical_spread==0;
    else
        offset=(vertical_spread*(wavepos-1));
        if get(handles.ydir_chk,'Value')==1;
            offset=offset*-1;
        end;
        tpy=tpy+offset;
    end;
    %crop if needed
    if get(handles.xlim_chk,'Value')==1;
        xlim1=str2num(get(handles.xlim1_edit,'String'));
        xlim2=str2num(get(handles.xlim2_edit,'String'));
        dxlim1=1;
        if xlim1>tpx(1);
            [a,b]=min(abs(tpx-xlim1));
            dxlim1=b;
        end;
        dxlim2=length(tpx);
        if xlim2<tpx(end);
            [a,b]=min(abs(tpx-xlimE));
            dxlim2=b;
        end;
        tpx=tpx(dxlim1:dxlim2);
        tpy=tpy(dxlim1:dxlim2);
    end;
    %subplot
    ax=subplot(1,1,1);
    %hold
    hold on;
    %plot
    lighter_color=wavedata(wavepos).color;
    tp=[1 1 1]-lighter_color;
    lighter_color=lighter_color+(0.5*tp);
    plot(tpx,tpy_low,'--','Color',lighter_color);
    plot(tpx,tpy_high,'--','Color',lighter_color);
    %plot
    plot(tpx,tpy,'Color',wavedata(wavepos).color,'LineWidth',wavedata(wavepos).linewidth,'LineStyle',wavedata(wavepos).linestyle);
    %hold
    hold off;
end;
%background color
set(ax,'Color',get(handles.linecolor_axes,'Color'));
set(h,'Color',get(handles.linecolor_axes,'Color'));
%XLim
if get(handles.xlim_chk,'Value')==1;
    set(ax,'XLim',[xlim1 xlim2]);
end;
xlim=get(ax,'XLim');
set(handles.xlim1_edit,'String',num2str(xlim(1)));
set(handles.xlim2_edit,'String',num2str(xlim(2)));
%YLim
if get(handles.ylim_chk,'Value')==1;
    ylim1=str2num(get(handles.ylim1_edit,'String'));
    ylim2=str2num(get(handles.ylim2_edit,'String'));
    set(ax,'YLim',[ylim1 ylim2]);
end;
ylim=get(ax,'YLim');
set(handles.ylim1_edit,'String',num2str(ylim(1)));
set(handles.ylim2_edit,'String',num2str(ylim(2)));
%XInterval
if get(handles.xtick_interval_chk,'Value')==1;
    interval=str2num(get(handles.xtick_interval_edit,'String'));
    anchor=str2num(get(handles.xanchor_edit,'String'));
    xtickinterval(interval,anchor);
end;
xtick=get(ax,'XTick');
set(handles.xtick_interval_edit,'String',num2str(xtick(2)-xtick(1)));
set(handles.xanchor_edit,'String',num2str(xtick(1)));
%YInterval
if get(handles.ytick_interval_chk,'Value')==1;
    interval=str2num(get(handles.ytick_interval_edit,'String'));
    anchor=str2num(get(handles.yanchor_edit,'String'));
    ytickinterval(interval,anchor);
end;
ytick=get(ax,'YTick');
set(handles.ytick_interval_edit,'String',num2str(ytick(2)-ytick(1)));
set(handles.yanchor_edit,'String',num2str(ytick(1)));
%YDir
if get(handles.ydir_chk,'Value')==1;
    set(ax,'YDir','reverse');
else
    set(ax,'YDir','normal');
end;
hold off;
%font
st=get(handles.font_popup,'String');
font_name=st{get(handles.font_popup,'Value')};
set(ax,'FontName',font_name);
set(ax,'FontSize',str2num(get(handles.fontsize_edit,'String')));
%box
if get(handles.drawbox_chk,'Value')==1;
    set(ax,'Box','on');
else
    set(ax,'Box','off');
end;
%TickDir
st=get(handles.tickdir_popup,'String');
tickdir=st{get(handles.tickdir_popup,'Value')};
set(ax,'TickDir',tickdir);
%TickLength
ticklength=get(ax,'TickLength');
ticklength(1)=str2num(get(handles.ticklength_edit,'String'));
set(ax,'TickLength',ticklength);
%XGrid
if get(handles.xgridline_chk,'Value')==1;
    set(ax,'XGrid','on');
else
    set(ax,'XGrid','off');
end;
%YGrid
if get(handles.ygridline_chk,'Value')==1;
    set(ax,'YGrid','on');
else
    set(ax,'YGrid','off');
end;
%hide x-axis?
if get(handles.hide_xaxis_chk,'Value')==1;
    set(ax,'XTickLabelMode','Manual');
    set(ax,'XTick',[]);
    set(ax,'XColor',get(handles.linecolor_axes,'Color'))
end;
%hide y-axis?
if get(handles.hide_yaxis_chk,'Value')==1;
    set(ax,'YTickLabelMode','Manual');
    set(ax,'YTick',[]);
    set(ax,'YColor',get(handles.linecolor_axes,'Color'))
end;
%invisible axis?
if get(handles.invisible_axis_chk,'Value')==1;
    set(ax,'Visible','off');
end;
%legend?
if get(handles.drawlegend_chk,'Value')==1;
    st=get(handles.waves_listbox,'String');
    if get(handles.legendpos_popup,'Value')==1;
        legend(st,'Location','Best');
    else
        legend(st,'Location','SouthOutside');
    end;
end;
%xaxis label?
if get(handles.xaxis_label_chk,'Value')==1;
    xlabel(ax,get(handles.xaxis_label_edit,'String'));
end;    
%yaxis label?
if get(handles.yaxis_label_chk,'Value')==1;
    ylabel(ax,get(handles.yaxis_label_edit,'String'));
end;











% --- Executes on button press in overwrite_chk.
function overwrite_chk_Callback(hObject, eventdata, handles)
% hObject    handle to overwrite_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if get(handles.overwrite_chk,'Value')==1;
    set(handles.prefix_text,'Visible','off');
    set(handles.prefix_edit,'Visible','off');
else
    set(handles.prefix_text,'Visible','on');
    set(handles.prefix_edit,'Visible','on');
end;
    




% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
delete(hObject);






% --- Executes on selection change in datasets_listbox.
function datasets_listbox_Callback(hObject, eventdata, handles)
% hObject    handle to datasets_listbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
update_listbox(handles);






% --- Executes during object creation, after setting all properties.
function datasets_listbox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to datasets_listbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end





% --- Executes on selection change in epoch_listbox.
function epoch_listbox_Callback(hObject, eventdata, handles)
% hObject    handle to epoch_listbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)






% --- Executes during object creation, after setting all properties.
function epoch_listbox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to epoch_listbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function z_edit_Callback(hObject, eventdata, handles)
% hObject    handle to z_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)




% --- Executes during object creation, after setting all properties.
function z_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to z_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function y_edit_Callback(hObject, eventdata, handles)
% hObject    handle to y_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)




% --- Executes during object creation, after setting all properties.
function y_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to y_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in index_popup.
function index_popup_Callback(hObject, eventdata, handles)
% hObject    handle to index_popup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)




% --- Executes during object creation, after setting all properties.
function index_popup_CreateFcn(hObject, eventdata, handles)
% hObject    handle to index_popup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end





% --- Executes on button press in add_btn.
function add_btn_Callback(hObject, eventdata, handles)
% hObject    handle to add_btn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%datasets
datasets=get(handles.datasets_listbox,'Userdata');
%wavedata
wavedata=get(handles.waves_listbox,'UserData');
%datasetpos,epochpos,channelpos
datasetpos_idx=get(handles.datasets_listbox,'Value');
epochpos_list=get(handles.epoch_listbox,'Value');
channelpos_list=get(handles.channel_listbox,'Value');
%wavepos
wavepos=length(wavedata)+1;
%dataset
dataset=datasets(datasetpos_idx);
%datasetpos
wavedata(wavepos).datasetpos=datasetpos_idx;
wavedata(wavepos).epochpos=epochpos_list;
wavedata(wavepos).channelpos=channelpos_list;
if dataset.header.datasize(3)==1;
    wavedata(wavepos).indexpos=1;
else
    wavedata(wavepos).indexpos=get(handles.index_popup,'Value');
end;
if dataset.header.datasize(4)==1;
    wavedata(wavepos).z=1;
else
    wavedata(wavepos).z=str2num(get(handles.z_edit,'String'));
end;
if dataset.header.datasize(5)==1;
    wavedata(wavepos).y=1;
else
    wavedata(wavepos).y=str2num(get(handles.y_edit,'String'));
end;
%style
line_handle=get(handles.linecolor_axes,'UserData');
wavedata(wavepos).color=get(line_handle,'Color');
wavedata(wavepos).linewidth=get(line_handle,'LineWidth');
wavedata(wavepos).linestyle=get(line_handle,'LineStyle');
%average_dimension
wavedata(wavepos).average_dimension=get(handles.dimension_popup,'Value');
%
set(handles.waves_listbox,'UserData',wavedata);
%
set(handles.waves_listbox,'Value',length(wavedata));
%
update_waves_listbox(handles);











% --- Executes on button press in clear_btn.
function clear_btn_Callback(hObject, eventdata, handles)
% hObject    handle to clear_btn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(handles.waves_listbox,'UserData',[]);
set(handles.waves_listbox,'Value',[]);
update_waves_listbox(handles);







% --- Executes on selection change in channel_listbox.
function channel_listbox_Callback(hObject, eventdata, handles)
% hObject    handle to channel_listbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- Executes during object creation, after setting all properties.
function channel_listbox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to channel_listbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in delete_btn.
function delete_btn_Callback(hObject, eventdata, handles)
% hObject    handle to delete_btn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%wavedata
wavedata=get(handles.waves_listbox,'UserData');
wavepos=get(handles.waves_listbox,'Value');
if isempty(wavedata)
else
    wavedata(wavepos)=[];
    set(handles.waves_listbox,'UserData',wavedata);
    wavepos2=wavepos-1;
    if wavepos2==0
        wavepos2=1;
    end;
    set(handles.waves_listbox,'Value',wavepos2);
end;
update_waves_listbox(handles);








% --- Executes on button press in update_btn.
function update_btn_Callback(hObject, eventdata, handles)
% hObject    handle to update_btn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%check that it is a single selection
datasetpos=get(handles.datasets_listbox,'Value');
epochpos=get(handles.epoch_listbox,'Value');
channelpos=get(handles.channel_listbox,'Value');
if length(datasetpos)>1;
    errordlg('Update requires a single selection');
end;
%wavepos
wavepos=get(handles.waves_listbox,'Value');
if isempty(wavepos);
else
    %wavedata
    wavedata=get(handles.waves_listbox,'UserData');
    if isempty(wavedata);
    else
        wavedata(wavepos).datasetpos=datasetpos;
        wavedata(wavepos).epochpos=epochpos;
        wavedata(wavepos).channelpos=channelpos;
        wavedata(wavepos).indexpos=get(handles.index_popup,'Value');
        wavedata(wavepos).y=str2num(get(handles.y_edit,'String'));
        wavedata(wavepos).z=str2num(get(handles.z_edit,'String'));
        %style
        line_handle=get(handles.linecolor_axes,'UserData');
        wavedata(wavepos).color=get(line_handle,'Color');
        wavedata(wavepos).linewidth=get(line_handle,'LineWidth');
        wavedata(wavepos).linestyle=get(line_handle,'LineStyle');
        set(handles.waves_listbox,'UserData',wavedata);
        %
        wavedata(wavepos).average_dimension=get(handles.dimension_popup,'Value');
        %
        update_waves_listbox(handles);
    end;
end;






% --- Executes on selection change in linestyle_popup.
function linestyle_popup_Callback(hObject, eventdata, handles)
% hObject    handle to linestyle_popup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
write_linestyle(handles);







% --- Executes during object creation, after setting all properties.
function linestyle_popup_CreateFcn(hObject, eventdata, handles)
% hObject    handle to linestyle_popup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end





% --- Executes on selection change in linewidth_popup.
function linewidth_popup_Callback(hObject, eventdata, handles)
% hObject    handle to linewidth_popup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
write_linestyle(handles);






% --- Executes during object creation, after setting all properties.
function linewidth_popup_CreateFcn(hObject, eventdata, handles)
% hObject    handle to linewidth_popup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in linecolor_btn.
function linecolor_btn_Callback(hObject, eventdata, handles)
% hObject    handle to linecolor_btn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
C=get(handles.linecolor_btn,'UserData');
C=uisetcolor(C);
set(handles.linecolor_btn,'UserData',C);
write_linestyle(handles);








% --- Executes on button press in xtick_interval_chk.
function xtick_interval_chk_Callback(hObject, eventdata, handles)
% hObject    handle to xtick_interval_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of xtick_interval_chk





function xanchor_edit_Callback(hObject, eventdata, handles)
% hObject    handle to xanchor_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- Executes during object creation, after setting all properties.
function xanchor_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to xanchor_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end





% --- Executes on button press in drawbox_chk.
function drawbox_chk_Callback(hObject, eventdata, handles)
% hObject    handle to drawbox_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- Executes on selection change in font_popup.
function font_popup_Callback(hObject, eventdata, handles)
% hObject    handle to font_popup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- Executes during object creation, after setting all properties.
function font_popup_CreateFcn(hObject, eventdata, handles)
% hObject    handle to font_popup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function fontsize_edit_Callback(hObject, eventdata, handles)
% hObject    handle to fontsize_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- Executes during object creation, after setting all properties.
function fontsize_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to fontsize_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function ticklength_edit_Callback(hObject, eventdata, handles)
% hObject    handle to ticklength_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- Executes during object creation, after setting all properties.
function ticklength_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ticklength_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in tickdir_popup.
function tickdir_popup_Callback(hObject, eventdata, handles)
% hObject    handle to tickdir_popup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- Executes during object creation, after setting all properties.
function tickdir_popup_CreateFcn(hObject, eventdata, handles)
% hObject    handle to tickdir_popup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function vertical_spread_edit_Callback(hObject, eventdata, handles)
% hObject    handle to vertical_spread_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- Executes during object creation, after setting all properties.
function vertical_spread_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to vertical_spread_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in xlim_chk.
function xlim_chk_Callback(hObject, eventdata, handles)
% hObject    handle to xlim_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)




function xlim1_edit_Callback(hObject, eventdata, handles)
% hObject    handle to xlim1_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- Executes during object creation, after setting all properties.
function xlim1_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to xlim1_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function xlim2_edit_Callback(hObject, eventdata, handles)
% hObject    handle to xlim2_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- Executes during object creation, after setting all properties.
function xlim2_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to xlim2_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function xtick_interval_edit_Callback(hObject, eventdata, handles)
% hObject    handle to xtick_interval_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- Executes during object creation, after setting all properties.
function xtick_interval_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to xtick_interval_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in ylim_chk.
function ylim_chk_Callback(hObject, eventdata, handles)
% hObject    handle to ylim_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)




function ylim1_edit_Callback(hObject, eventdata, handles)
% hObject    handle to ylim1_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- Executes during object creation, after setting all properties.
function ylim1_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ylim1_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function ylim2_edit_Callback(hObject, eventdata, handles)
% hObject    handle to ylim2_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- Executes during object creation, after setting all properties.
function ylim2_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ylim2_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in ytick_interval_chk.
function ytick_interval_chk_Callback(hObject, eventdata, handles)
% hObject    handle to ytick_interval_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)




function ytick_interval_edit_Callback(hObject, eventdata, handles)
% hObject    handle to ytick_interval_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- Executes during object creation, after setting all properties.
function ytick_interval_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ytick_interval_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function yanchor_edit_Callback(hObject, eventdata, handles)
% hObject    handle to yanchor_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- Executes during object creation, after setting all properties.
function yanchor_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to yanchor_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in ydir_chk.
function ydir_chk_Callback(hObject, eventdata, handles)
% hObject    handle to ydir_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- Executes on button press in ygridline_chk.
function ygridline_chk_Callback(hObject, eventdata, handles)
% hObject    handle to ygridline_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- Executes on button press in hide_yaxis_chk.
function hide_yaxis_chk_Callback(hObject, eventdata, handles)
% hObject    handle to hide_yaxis_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- Executes on button press in xgridline_chk.
function xgridline_chk_Callback(hObject, eventdata, handles)
% hObject    handle to xgridline_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- Executes on button press in hide_xaxis_chk.
function hide_xaxis_chk_Callback(hObject, eventdata, handles)
% hObject    handle to hide_xaxis_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)






% --- Executes on selection change in waves_listbox.
function waves_listbox_Callback(hObject, eventdata, handles)
% hObject    handle to waves_listbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%wavedata
wavedata=get(handles.waves_listbox,'UserData');
%update using current selection
selected=get(handles.waves_listbox,'Value');
if isempty(selected);
else
    set(handles.datasets_listbox,'Value',wavedata(selected).datasetpos);
    update_waves_listbox(handles);
    set(handles.epoch_listbox,'Value',wavedata(selected).epochpos);
    set(handles.channel_listbox,'Value',wavedata(selected).channelpos);
    set(handles.index_popup,'Value',wavedata(selected).indexpos);
    set(handles.y_edit,'String',num2str(wavedata(selected).y));
    set(handles.z_edit,'String',num2str(wavedata(selected).z));
    %styles
    line_handle=get(handles.linecolor_axes,'UserData');
    set(line_handle,'Color',wavedata(selected).color);
    set(line_handle,'LineWidth',wavedata(selected).linewidth);
    set(line_handle,'LineStyle',wavedata(selected).linestyle);
    read_linestyle(handles);
    set(handles.dimension_popup,'Value',wavedata(selected).average_dimension);
end;
update_dimensions(handles);







% --- Executes during object creation, after setting all properties.
function waves_listbox_CreateFcn(hObject, eventdata, handles)
% hObject    handle to waves_listbox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end







% --- Executes on button press in invisible_axis_chk.
function invisible_axis_chk_Callback(hObject, eventdata, handles)
% hObject    handle to invisible_axis_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)







% --- Executes on button press in cycle_colors_btn.
function cycle_colors_btn_Callback(hObject, eventdata, handles)
% hObject    handle to cycle_colors_btn (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%wavedata
wavedata=get(handles.waves_listbox,'UserData');
%distinguishable_colors
bg=get(handles.linecolor_axes,'Color');
colors=distinguishable_colors(length(wavedata),bg);
%loop
for wavepos=1:length(wavedata);
    wavedata(wavepos).color=colors(wavepos,:);
end;
set(handles.waves_listbox,'UserData',wavedata);





% --- Executes on button press in drawlegend_chk.
function drawlegend_chk_Callback(hObject, eventdata, handles)
% hObject    handle to drawlegend_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)






% --- Executes on selection change in legendpos_popup.
function legendpos_popup_Callback(hObject, eventdata, handles)
% hObject    handle to legendpos_popup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)







% --- Executes during object creation, after setting all properties.
function legendpos_popup_CreateFcn(hObject, eventdata, handles)
% hObject    handle to legendpos_popup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function yaxis_label_edit_Callback(hObject, eventdata, handles)
% hObject    handle to yaxis_label_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- Executes during object creation, after setting all properties.
function yaxis_label_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to yaxis_label_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in yaxis_label_chk.
function yaxis_label_chk_Callback(hObject, eventdata, handles)
% hObject    handle to yaxis_label_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)




function xaxis_label_edit_Callback(hObject, eventdata, handles)
% hObject    handle to xaxis_label_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)




% --- Executes during object creation, after setting all properties.
function xaxis_label_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to xaxis_label_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end






% --- Executes on button press in xaxis_label_chk.
function xaxis_label_chk_Callback(hObject, eventdata, handles)
% hObject    handle to xaxis_label_chk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)






% --- Executes on selection change in plot_popup.
function plot_popup_Callback(hObject, eventdata, handles)
% hObject    handle to plot_popup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)





% --- Executes during object creation, after setting all properties.
function plot_popup_CreateFcn(hObject, eventdata, handles)
% hObject    handle to plot_popup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in dimension_popup.
function dimension_popup_Callback(hObject, eventdata, handles)
% hObject    handle to dimension_popup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
update_dimensions(handles);






function update_dimensions(handles);
v=get(handles.dimension_popup,'Value');
switch v;
    case 1
        v=get(handles.channel_listbox,'Value');
        if isempty(v);
            v=1;
        else
            v=v(1);
        end;
        set(handles.channel_listbox,'Value',v);
        set(handles.channel_listbox,'Max',1);
        set(handles.epoch_listbox,'Max',2);
    case 2
        v=get(handles.epoch_listbox,'Value');
        if isempty(v);
            v=1;
        else
            v=v(1);
        end;
        set(handles.epoch_listbox,'Value',v);
        set(handles.epoch_listbox,'Max',1);
        set(handles.channel_listbox,'Max',2);
end;



% --- Executes during object creation, after setting all properties.
function dimension_popup_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dimension_popup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in display_option.
function display_option_Callback(hObject, eventdata, handles)
% hObject    handle to display_option (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)





% --- Executes during object creation, after setting all properties.
function display_option_CreateFcn(hObject, eventdata, handles)
% hObject    handle to display_option (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
