function [hdr] = ft_read_header(filename, varargin)

% FT_READ_HEADER reads header information from a variety of EEG, MEG and LFP
% files and represents the header information in a common data-independent
% format. The supported formats are listed below.
%
% Use as
%   hdr = ft_read_header(filename, ...)
%
% Additional options should be specified in key-value pairs and can be
%   'headerformat'   string
%   'fallback'       can be empty or 'biosig' (default = [])
%
% This returns a header structure with the following elements
%   hdr.Fs                  sampling frequency
%   hdr.nChans              number of channels
%   hdr.nSamples            number of samples per trial
%   hdr.nSamplesPre         number of pre-trigger samples in each trial
%   hdr.nTrials             number of trials
%   hdr.label               Nx1 cell-array with the label of each channel
%   hdr.chantype            Nx1 cell-array with the channel type, see FT_CHANTYPE
%   hdr.chanunit            Nx1 cell-array with the physical units, see FT_CHANUNIT
%
% For continuously recorded data, nSamplesPre=0 and nTrials=1.
%
% For some data formats that are recorded on animal electrophysiology
% systems (e.g. Neuralynx, Plexon), the following optional fields are
% returned, which allows for relating the timinng of spike and LFP data
%   hdr.FirstTimeStamp      number, 32 bit or 64 bit unsigned integer
%   hdr.TimeStampPerSample  double
%
% Depending on the file format, additional header information can be
% returned in the hdr.orig subfield.
%
% The following MEG dataformats are supported
%   CTF - VSM MedTech (*.ds, *.res4, *.meg4)
%   Neuromag - Elekta (*.fif)
%   BTi - 4D Neuroimaging (*.m4d, *.pdf, *.xyz)
%   Yokogawa (*.ave, *.con, *.raw)
%   NetMEG (*.nc)
%
% The following EEG dataformats are supported
%   ANT - Advanced Neuro Technology, EEProbe (*.avr, *.eeg, *.cnt)
%   Biosemi (*.bdf)
%   CED - Cambridge Electronic Design (*. smr)
%   Electrical Geodesics, Inc. (*.egis, *.ave, *.gave, *.ses, *.raw, *.sbin, MFF fileformat)
%   Megis/BESA (*.avr, *.swf)
%   NeuroScan (*.eeg, *.cnt, *.avg)
%   Nexstim (*.nxe)
%   BrainVision (*.eeg, *.seg, *.dat, *.vhdr, *.vmrk)
%   GTec (*.mat)
%
% The following spike and LFP dataformats are supported (with some limitations)
%   Plextor (*.nex, *.plx, *.ddt)
%   Neuralynx (*.ncs, *.nse, *.nts, *.nev, DMA log files)
%   CED - Cambridge Electronic Design (*.smr)
%   MPI - Max Planck Institute (*.dap)
%
% See also FT_READ_DATA, FT_READ_EVENT, FT_WRITE_DATA, FT_WRITE_EVENT,
% FT_CHANTYPE, FT_CHANUNIT

% Copyright (C) 2003-2012 Robert Oostenveld
%
% This file is part of FieldTrip, see http://www.ru.nl/neuroimaging/fieldtrip
% for the documentation and details.
%
%    FieldTrip is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    FieldTrip is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with FieldTrip. If not, see <http://www.gnu.org/licenses/>.
%
% $Id: ft_read_header.m 5585 2012-04-04 09:29:02Z roboos $

% TODO channel renaming should be made a general option (see bham_bdf)

persistent cacheheader        % for caching
persistent db_blob            % for fcdc_mysql

if isempty(db_blob)
  db_blob = false;
end

% test whether the file or directory exists
if ~exist(filename, 'file') && ~strcmp(ft_filetype(filename), 'ctf_shm') && ~strcmp(ft_filetype(filename), 'fcdc_mysql') && ~strcmp(ft_filetype(filename), 'fcdc_buffer')
  error('FILEIO:InvalidFileName', 'file or directory ''%s'' does not exist', filename);
end

% get the options
retry        = ft_getopt(varargin, 'retry', false); % the default is not to retry reading the header
headerformat = ft_getopt(varargin, 'headerformat', []);
if isempty(headerformat)
  headerformat = ft_filetype(filename); % the default is automatically detected, but only if not specified
end

% The checkUniqueLabels flag is used for the realtime buffer in case
% it contains fMRI data. It prevents 1000000 voxel names to be checked
% for uniqueness. fMRI users will probably never use channel names
% for anything.

% The skipInitialCheck flag is used to speed up the read operation from
% the realtime buffer in general.

if strcmp(headerformat, 'fcdc_buffer')
  % skip the rest of the initial checks to increase the speed for realtime operation
  
  checkUniqueLabels = false;
  % the cache and fallback option should always be false for realtime processing
  cache    = false;
  fallback = false;
  
  
else
  checkUniqueLabels = true;
  % the cache and fallback option are according to the user's specification
  cache    = ft_getopt(varargin, 'cache');
  fallback = ft_getopt(varargin, 'fallback');
  
  if isempty(cache),
    if strcmp(headerformat, 'bci2000_dat') || strcmp(headerformat, 'eyelink_asc') || strcmp(headerformat, 'gtec_mat') || strcmp(headerformat, 'biosig')
      cache = true;
    else
      cache = false;
    end
  end
  
  % ensure that the headerfile and datafile are defined, which are sometimes different than the name of the dataset
  [filename, headerfile, datafile] = dataset2files(filename, headerformat);
  if ~strcmp(filename, headerfile) && ~ft_filetype(filename, 'ctf_ds') && ~ft_filetype(filename, 'fcdc_buffer_offline') && ~ft_filetype(filename, 'fcdc_matbin')
    filename     = headerfile;                % this function should read the headerfile, not the dataset
    headerformat = ft_filetype(filename);     % update the filetype
  end
end % if skip initial check

% start with an empty header
hdr = [];

% implement the caching in a data-format independent way
if cache && exist(headerfile, 'file') && ~isempty(cacheheader)
  % try to get the header from cache
  details = dir(headerfile);
  if isequal(details, cacheheader.details)
    % the header file has not been updated, fetch it from the cache
    % fprintf('got header from cache\n');
    hdr = rmfield(cacheheader, 'details');
    
    switch ft_filetype(datafile)
      case {'ctf_ds' 'ctf_meg4' 'ctf_old' 'read_ctf_res4'}
        % for realtime analysis EOF chasing the res4 does not correctly
        % estimate the number of samples, so we compute it on the fly
        sz = 0;
        files = dir([filename '/*.*meg4']);
        for j=1:numel(files)
          sz = sz + files(j).bytes;
        end
        hdr.nTrials = floor((sz - 8) / (hdr.nChans*4) / hdr.nSamples);
    end
    
    return;
  end % if the details correspond
end % if cache

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% read the data with the low-level reading function
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
switch headerformat
  case '4d'
    orig            = read_4d_hdr(datafile);
    hdr.Fs          = orig.header_data.SampleFrequency;
    hdr.nChans      = orig.header_data.TotalChannels;
    hdr.nSamples    = orig.header_data.SlicesPerEpoch;
    hdr.nSamplesPre = round(orig.header_data.FirstLatency*orig.header_data.SampleFrequency);
    hdr.nTrials     = orig.header_data.TotalEpochs;
    %hdr.label       = {orig.channel_data(:).chan_label}';
    hdr.label       = orig.Channel;
    hdr.grad        = bti2grad(orig);
    % remember original header details
    hdr.orig        = orig;
    
  case {'4d_pdf', '4d_m4d', '4d_xyz'}
    orig            = read_bti_m4d(filename);
    hdr.Fs          = orig.SampleFrequency;
    hdr.nChans      = orig.TotalChannels;
    hdr.nSamples    = orig.SlicesPerEpoch;
    hdr.nSamplesPre = round(orig.FirstLatency*orig.SampleFrequency);
    hdr.nTrials     = orig.TotalEpochs;
    hdr.label       = orig.ChannelOrder(:);
    hdr.grad        = bti2grad(orig);
    % remember original header details
    hdr.orig        = orig;
    
  case 'bci2000_dat'
    % this requires the load_bcidat mex file to be present on the path
    ft_hastoolbox('BCI2000', 1);
    % this is inefficient, since it reads the complete data
    [signal, states, parameters, total_samples] = load_bcidat(filename);
    % convert into a FieldTrip-like header
    hdr             = [];
    hdr.nChans      = size(signal,2);
    hdr.nSamples    = total_samples;
    hdr.nSamplesPre = 0;  % it is continuous
    hdr.nTrials     = 1;  % it is continuous
    hdr.Fs          = parameters.SamplingRate.NumericValue;
    % there are some differences in the fields that are present in the
    % *.dat files, probably due to different BCI2000 versions
    if isfield(parameters, 'ChannelNames') && isfield(parameters.ChannelNames, 'Value') && ~isempty(parameters.ChannelNames.Value)
      hdr.label       = parameters.ChannelNames.Value;
    elseif isfield(parameters, 'ChannelNames') && isfield(parameters.ChannelNames, 'Values') && ~isempty(parameters.ChannelNames.Values)
      hdr.label       = parameters.ChannelNames.Values;
    else
      % give this warning only once
      warning_once('creating fake channel names');
      for i=1:hdr.nChans
        hdr.label{i} = sprintf('%d', i);
      end
    end
    
    % remember the original header details
    hdr.orig.parameters       = parameters;
    % also remember the complete data upon request
    if cache
      hdr.orig.signal         = signal;
      hdr.orig.states         = states;
      hdr.orig.total_samples  = total_samples;
    end
    
  case 'besa_avr'
    orig = read_besa_avr(filename);
    hdr.Fs          = 1000/orig.di;
    hdr.nChans      = size(orig.data,1);
    hdr.nSamples    = size(orig.data,2);
    hdr.nSamplesPre = -(hdr.Fs * orig.tsb/1000);   % convert from ms to samples
    hdr.nTrials     = 1;
    if isfield(orig, 'label') && iscell(orig.label)
      hdr.label = orig.label;
    elseif isfield(orig, 'label') && ischar(orig.label)
      hdr.label = tokenize(orig.label, ' ');
    else
      % give this warning only once
      warning_once('creating fake channel names');
      for i=1:hdr.nChans
        hdr.label{i} = sprintf('%d', i);
      end
    end
    
  case 'besa_swf'
    orig = read_besa_swf(filename);
    hdr.Fs          = 1000/orig.di;
    hdr.nChans      = size(orig.data,1);
    hdr.nSamples    = size(orig.data,2);
    hdr.nSamplesPre = -(hdr.Fs * orig.tsb/1000);   % convert from ms to samples
    hdr.nTrials     = 1;
    hdr.label       = orig.label;
    
  case {'biosig'}
    % this requires the biosig toolbox
    ft_hastoolbox('BIOSIG', 1);
    hdr = read_biosig_header(filename);
    
  case {'gdf'}
    % this requires the biosig toolbox
    ft_hastoolbox('BIOSIG', 1);
    % In the case that the gdf files are written by one of the FieldTrip
    % realtime applications, such as biosig2ft, the gdf recording can be
    % split over multiple 1GB files. The sequence of files is then
    %   filename.gdf   <- this is the one that should be specified as the filename/dataset
    %   filename_1.gdf
    %   filename_2.gdf
    %   ...
    
    [p, f, x] = fileparts(filename);
    if exist(sprintf('%s_%d%s', fullfile(p, f), 1, x), 'file')
      % there are multiple files, count the number of additional files (excluding the first one)
      count = 0;
      while exist(sprintf('%s_%d%s', fullfile(p, f), count+1, x), 'file')
        count = count+1;
      end
      hdr = read_biosig_header(filename);
      for i=1:count
        hdr(i+1) = read_biosig_header(sprintf('%s_%d%s', fullfile(p, f), i, x));
        % do some sanity checks
        if hdr(i+1).nChans~=hdr(1).nChans
          error('multiple GDF files detected that should be appended, but the channel count is inconsistent');
        elseif hdr(i+1).Fs~=hdr(1).Fs
          error('multiple GDF files detected that should be appended, but the sampling frequency is inconsistent');
        elseif ~isequal(hdr(i+1).label, hdr(1).label)
          error('multiple GDF files detected that should be appended, but the channel names are inconsistent');
        end
      end % for count
      % combine all headers into one
      combinedhdr             = [];
      combinedhdr.Fs          = hdr(1).Fs;
      combinedhdr.nChans      = hdr(1).nChans;
      combinedhdr.nSamples    = sum([hdr.nSamples].*[hdr.nTrials]);
      combinedhdr.nSamplesPre = 0;
      combinedhdr.nTrials     = 1;
      combinedhdr.label       = hdr(1).label;
      combinedhdr.orig        = hdr; % include all individual file details
      hdr = combinedhdr;
      
    else
      % there is only a single file
      hdr = read_biosig_header(filename);
      % the GDF format is always continuous
      hdr.nSamples = hdr.nSamples * hdr.nTrials;
      hdr.nTrials = 1;
      hdr.nSamplesPre = 0;
    end % if single or multiple gdf files
    
    
  case {'biosemi_bdf', 'bham_bdf'}
    hdr = read_biosemi_bdf(filename);
    if any(diff(hdr.orig.SampleRate))
      error('channels with different sampling rate not supported');
    end
    if ft_filetype(filename, 'bham_bdf')
      % TODO channel renaming should be made a general option
      % this is for the Biosemi system used at the University of Birmingham
      labelold = { 'A1' 'A2' 'A3' 'A4' 'A5' 'A6' 'A7' 'A8' 'A9' 'A10' 'A11' 'A12' 'A13' 'A14' 'A15' 'A16' 'A17' 'A18' 'A19' 'A20' 'A21' 'A22' 'A23' 'A24' 'A25' 'A26' 'A27' 'A28' 'A29' 'A30' 'A31' 'A32' 'B1' 'B2' 'B3' 'B4' 'B5' 'B6' 'B7' 'B8' 'B9' 'B10' 'B11' 'B12' 'B13' 'B14' 'B15' 'B16' 'B17' 'B18' 'B19' 'B20' 'B21' 'B22' 'B23' 'B24' 'B25' 'B26' 'B27' 'B28' 'B29' 'B30' 'B31' 'B32' 'C1' 'C2' 'C3' 'C4' 'C5' 'C6' 'C7' 'C8' 'C9' 'C10' 'C11' 'C12' 'C13' 'C14' 'C15' 'C16' 'C17' 'C18' 'C19' 'C20' 'C21' 'C22' 'C23' 'C24' 'C25' 'C26' 'C27' 'C28' 'C29' 'C30' 'C31' 'C32' 'D1' 'D2' 'D3' 'D4' 'D5' 'D6' 'D7' 'D8' 'D9' 'D10' 'D11' 'D12' 'D13' 'D14' 'D15' 'D16' 'D17' 'D18' 'D19' 'D20' 'D21' 'D22' 'D23' 'D24' 'D25' 'D26' 'D27' 'D28' 'D29' 'D30' 'D31' 'D32' 'EXG1' 'EXG2' 'EXG3' 'EXG4' 'EXG5' 'EXG6' 'EXG7' 'EXG8' 'Status'};
      labelnew = { 'P9' 'PPO9h' 'PO7' 'PPO5h' 'PPO3h' 'PO5h' 'POO9h' 'PO9' 'I1' 'OI1h' 'O1' 'POO1' 'PO3h' 'PPO1h' 'PPO2h' 'POz' 'Oz' 'Iz' 'I2' 'OI2h' 'O2' 'POO2' 'PO4h' 'PPO4h' 'PO6h' 'POO10h' 'PO10' 'PO8' 'PPO6h' 'PPO10h' 'P10' 'P8' 'TPP9h' 'TP7' 'TTP7h' 'CP5' 'TPP7h' 'P7' 'P5' 'CPP5h' 'CCP5h' 'CP3' 'P3' 'CPP3h' 'CCP3h' 'CP1' 'P1' 'Pz' 'CPP1h' 'CPz' 'CPP2h' 'P2' 'CPP4h' 'CP2' 'CCP4h' 'CP4' 'P4' 'P6' 'CPP6h' 'CCP6h' 'CP6' 'TPP8h' 'TP8' 'TPP10h' 'T7' 'FTT7h' 'FT7' 'FC5' 'FCC5h' 'C5' 'C3' 'FCC3h' 'FC3' 'FC1' 'C1' 'CCP1h' 'Cz' 'FCC1h' 'FCz' 'FFC1h' 'Fz' 'FFC2h' 'FC2' 'FCC2h' 'CCP2h' 'C2' 'C4' 'FCC4h' 'FC4' 'FC6' 'FCC6h' 'C6' 'TTP8h' 'T8' 'FTT8h' 'FT8' 'FT9' 'FFT9h' 'F7' 'FFT7h' 'FFC5h' 'F5' 'AFF7h' 'AF7' 'AF5h' 'AFF5h' 'F3' 'FFC3h' 'F1' 'AF3h' 'Fp1' 'Fpz' 'Fp2' 'AFz' 'AF4h' 'F2' 'FFC4h' 'F4' 'AFF6h' 'AF6h' 'AF8' 'AFF8h' 'F6' 'FFC6h' 'FFT8h' 'F8' 'FFT10h' 'FT10'};
      % rename the channel labels
      for i=1:length(labelnew)
        chan = strcmp(labelold(i), hdr.label);
        hdr.label(chan) = labelnew(chan);
      end
    end
    
  case {'biosemi_old'}
    % this uses the openbdf and readbdf functions that were copied from EEGLAB
    orig = openbdf(filename);
    if any(orig.Head.SampleRate~=orig.Head.SampleRate(1))
      error('channels with different sampling rate not supported');
    end
    hdr.Fs          = orig.Head.SampleRate(1);
    hdr.nChans      = orig.Head.NS;
    hdr.label       = cellstr(orig.Head.Label);
    % it is continuous data, therefore append all records in one trial
    hdr.nSamples    = orig.Head.NRec * orig.Head.Dur * orig.Head.SampleRate(1);
    hdr.nSamplesPre = 0;
    hdr.nTrials     = 1;
    hdr.orig        = orig;
    % close the file between seperate read operations
    fclose(orig.Head.FILE.FID);
    
  case {'brainvision_vhdr', 'brainvision_seg', 'brainvision_eeg', 'brainvision_dat'}
    orig = read_brainvision_vhdr(filename);
    hdr.Fs          = orig.Fs;
    hdr.nChans      = orig.NumberOfChannels;
    hdr.label       = orig.label;
    hdr.nSamples    = orig.nSamples;
    hdr.nSamplesPre = orig.nSamplesPre;
    hdr.nTrials     = orig.nTrials;
    hdr.orig        = orig;
    
  case 'ced_son'
    % check that the required low-level toolbox is available
    ft_hastoolbox('neuroshare', 1);
    % use the reading function supplied by Gijs van Elswijk
    orig = read_ced_son(filename,'readevents','no','readdata','no');
    orig = orig.header;
    % In Spike2, channels can have different sampling rates, units, length
    % etc. etc. Here, channels need to have to same properties.
    if length(unique([orig.samplerate]))>1,
      error('channels with different sampling rates are not supported');
    else
      hdr.Fs   = orig(1).samplerate;
    end;
    hdr.nChans = length(orig);
    % nsamples of the channel with least samples
    hdr.nSamples    = min([orig.nsamples]);
    hdr.nSamplesPre = 0;
    % only continuous data supported
    if sum(strcmpi({orig.mode},'continuous')) < hdr.nChans,
      error('not all channels contain continuous data');
    else
      hdr.nTrials = 1;
    end;
    hdr.label = {orig.label};
    
  case  'combined_ds'
    hdr = read_combined_ds(filename);
    
  case {'ctf_ds', 'ctf_meg4', 'ctf_res4'}
    % check the presence of the required low-level toolbox
    ft_hastoolbox('ctf', 1);
    orig             = readCTFds(filename);
    hdr.Fs           = orig.res4.sample_rate;
    hdr.nChans       = orig.res4.no_channels;
    hdr.nSamples     = orig.res4.no_samples;
    hdr.nSamplesPre  = orig.res4.preTrigPts;
    hdr.nTrials      = orig.res4.no_trials;
    hdr.label        = cellstr(orig.res4.chanNames);
    for i=1:numel(hdr.label)
      % remove the site-specific numbers from each channel name, e.g. 'MZC01-1706' becomes 'MZC01'
      hdr.label{i} = strtok(hdr.label{i}, '-');
    end
    % read the balance coefficients, these are used to compute the synthetic gradients
    coeftype = cellstr(char(orig.res4.scrr(:).coefType));
    try
      [alphaMEG,MEGlist,Refindex] = getCTFBalanceCoefs(orig,'NONE', 'T');
      orig.BalanceCoefs.none.alphaMEG  = alphaMEG;
      orig.BalanceCoefs.none.MEGlist   = MEGlist;
      orig.BalanceCoefs.none.Refindex  = Refindex;
    catch
      warning('cannot read balancing coefficients for NONE');
    end
    if any(~cellfun(@isempty,strfind(coeftype, 'G1BR')))
      try
        [alphaMEG,MEGlist,Refindex] = getCTFBalanceCoefs(orig,'G1BR', 'T');
        orig.BalanceCoefs.G1BR.alphaMEG  = alphaMEG;
        orig.BalanceCoefs.G1BR.MEGlist   = MEGlist;
        orig.BalanceCoefs.G1BR.Refindex  = Refindex;
      catch
        warning('cannot read balancing coefficients for G1BR');
      end
    end
    if any(~cellfun(@isempty,strfind(coeftype, 'G2BR')))
      try
        [alphaMEG,MEGlist,Refindex] = getCTFBalanceCoefs(orig, 'G2BR', 'T');
        orig.BalanceCoefs.G2BR.alphaMEG  = alphaMEG;
        orig.BalanceCoefs.G2BR.MEGlist   = MEGlist;
        orig.BalanceCoefs.G2BR.Refindex  = Refindex;
      catch
        warning('cannot read balancing coefficients for G2BR');
      end
    end
    if any(~cellfun(@isempty,strfind(coeftype, 'G3BR')))
      try
        [alphaMEG,MEGlist,Refindex] = getCTFBalanceCoefs(orig, 'G3BR', 'T');
        orig.BalanceCoefs.G3BR.alphaMEG  = alphaMEG;
        orig.BalanceCoefs.G3BR.MEGlist   = MEGlist;
        orig.BalanceCoefs.G3BR.Refindex  = Refindex;
      catch
        warning('cannot read balancing coefficients for G3BR');
      end
    end
    if any(~cellfun(@isempty,strfind(coeftype, 'G1AR')))
      try
        [alphaMEG,MEGlist,Refindex] = getCTFBalanceCoefs(orig, 'G3AR', 'T');
        orig.BalanceCoefs.G3AR.alphaMEG  = alphaMEG;
        orig.BalanceCoefs.G3AR.MEGlist   = MEGlist;
        orig.BalanceCoefs.G3AR.Refindex  = Refindex;
      catch
        % May not want a warning here if these are not commonly used.
        % Already get a (fprintf) warning from getCTFBalanceCoefs.m
        % warning('cannot read balancing coefficients for G3AR');
      end
    end
    % add a gradiometer structure for forward and inverse modelling
    try
      hdr.grad = ctf2grad(orig);
    catch
      % this fails if the res4 file is not correctly closed, e.g. during realtime processing
      tmp = lasterror;
      disp(tmp.message);
      warning('could not construct gradiometer definition from the header');
    end
    
    % for realtime analysis EOF chasing the res4 does not correctly
    % estimate the number of samples, so we compute it on the fly from the
    % meg4 file sizes.
    sz = 0;
    files = dir([filename '/*.*meg4']);
    for j=1:numel(files)
      sz = sz + files(j).bytes;
    end
    hdr.nTrials = floor((sz - 8) / (hdr.nChans*4) / hdr.nSamples);
    
    % add the original header details
    hdr.orig = orig;
    
  case {'ctf_old', 'read_ctf_res4'}
    % read it using the open-source matlab code that originates from CTF and that was modified by the FCDC
    orig             = read_ctf_res4(headerfile);
    hdr.Fs           = orig.Fs;
    hdr.nChans       = orig.nChans;
    hdr.nSamples     = orig.nSamples;
    hdr.nSamplesPre  = orig.nSamplesPre;
    hdr.nTrials      = orig.nTrials;
    hdr.label        = orig.label;
    % add a gradiometer structure for forward and inverse modelling
    try
      hdr.grad = ctf2grad(orig);
    catch
      % this fails if the res4 file is not correctly closed, e.g. during realtime processing
      tmp = lasterror;
      disp(tmp.message);
      warning('could not construct gradiometer definition from the header');
    end
    % add the original header details
    hdr.orig = orig;
    
  case 'ctf_read_res4'
    % check that the required low-level toolbos ix available
    ft_hastoolbox('eegsf', 1);
    % read it using the CTF importer from the NIH and Daren Weber
    orig = ctf_read_res4(filename, 0);
    % convert the header into a structure that FieldTrip understands
    hdr              = [];
    hdr.Fs           = orig.setup.sample_rate;
    hdr.nChans       = length(orig.sensor.info);
    hdr.nSamples     = orig.setup.number_samples;
    hdr.nSamplesPre  = orig.setup.pretrigger_samples;
    hdr.nTrials      = orig.setup.number_trials;
    for i=1:length(orig.sensor.info)
      hdr.label{i}   = orig.sensor.info(i).label;
    end
    hdr.label        = hdr.label(:);
    % add a gradiometer structure for forward and inverse modelling
    try
      hdr.grad = ctf2grad(orig);
    catch
      % this fails if the res4 file is not correctly closed, e.g. during realtime processing
      tmp = lasterror;
      disp(tmp.message);
      warning('could not construct gradiometer definition from the header');
    end
    % add the original header details
    hdr.orig = orig;
    
  case 'ctf_shm'
    % contact Robert Oostenveld if you are interested in real-time acquisition on the CTF system
    % read the header information from shared memory
    hdr = read_shm_header(filename);
    
  case 'dataq_wdq'
    orig            = read_wdq_header(filename);
    hdr             = [];
    hdr.Fs          = orig.fsample;
    hdr.nChans      = orig.nchan;
    hdr.nSamples    = orig.nbytesdat/(2*hdr.nChans);
    hdr.nSamplesPre = 0;
    hdr.nTrials     = 1;
    for k = 1:hdr.nChans
      if isfield(orig.chanhdr(k), 'annot') && ~isempty(orig.chanhdr(k).annot)
        hdr.label{k,1} = orig.chanhdr(k).annot;
      else
        hdr.label{k,1} = orig.chanhdr(k).label;
      end
    end
    
    % add the original header details
    hdr.orig  = orig;
  case 'edf'
    % this reader is largely similar to the bdf reader
    hdr = read_edf(filename);
    
  case 'eep_avr'
    % check that the required low-level toolbox is available
    ft_hastoolbox('eeprobe', 1);
    % read the whole average and keep only header info (it is a bit silly, but the easiest to do here)
    hdr = read_eep_avr(filename);
    hdr.Fs          = hdr.rate;
    hdr.nChans      = size(hdr.data,1);
    hdr.nSamples    = size(hdr.data,2);
    hdr.nSamplesPre = hdr.xmin*hdr.rate/1000;
    hdr.nTrials     = 1;        % it can always be interpreted as continuous data
    % remove the data and variance if present
    hdr = rmfield(hdr, 'data');
    try, hdr = rmfield(hdr, 'variance'); end
    
  case 'eeglab_set'
    hdr = read_eeglabheader(filename);
    
  case 'eyelink_asc'
    asc = read_eyelink_asc(filename);
    hdr.nChans              = size(asc.dat,1);
    hdr.nSamples            = size(asc.dat,2);
    hdr.nSamplesPre         = 0;
    hdr.nTrials             = 1;
    hdr.FirstTimeStamp      = asc.dat(1,1);
    hdr.TimeStampPerSample  = mean(diff(asc.dat(1,:)));
    hdr.Fs                  = 1000/hdr.TimeStampPerSample;  % these timestamps are in miliseconds
    % give this warning only once
    warning_once('creating fake channel names');
    for i=1:hdr.nChans
      hdr.label{i} = sprintf('%d', i);
    end
    
    % remember the original header details
    hdr.orig.header = asc.header;
    % remember all header and data details upon request
    if cache
      hdr.orig = asc;
    end
    
  case  'spmeeg_mat'
    hdr = read_spmeeg_header(filename);
    
  case  'ced_spike6mat'
    hdr = read_spike6mat_header(filename);
    
  case 'eep_cnt'
    % check that the required low-level toolbox is available
    ft_hastoolbox('eeprobe', 1);
    % read the first sample from the continous data, which will also return the header
    hdr = read_eep_cnt(filename, 1, 1);
    hdr.Fs          = hdr.rate;
    hdr.nSamples    = hdr.nsample;
    hdr.nSamplesPre = 0;
    hdr.nChans      = hdr.nchan;
    hdr.nTrials     = 1;        % it can always be interpreted as continuous data
    
  case 'egi_egia'
    [fhdr,chdr,ename,cnames,fcom,ftext] = read_egis_header(filename);
    [p, f, x]       = fileparts(filename);
    
    if any(chdr(:,4)-chdr(1,4))
      error('Sample rate not the same for all cells.');
    end;
    
    hdr.Fs          = chdr(1,4); %making assumption that sample rate is same for all cells
    hdr.nChans      = fhdr(19);
    for i = 1:hdr.nChans
      % this should be consistent with ft_senslabel
      hdr.label{i,1}  = ['E' num2str(i)];
    end;
    %since NetStation does not properly set the fhdr(11) field, use the number of subjects from the chdr instead
    hdr.nTrials     = chdr(1,2)*fhdr(18); %number of trials is numSubjects * numCells
    hdr.nSamplesPre = ceil(fhdr(14)/(1000/hdr.Fs));
    
    if any(chdr(:,3)-chdr(1,3))
      error('Number of samples not the same for all cells.');
    end;
    
    hdr.nSamples    = chdr(1,3); %making assumption that number of samples is same for all cells
    
    % remember the original header details
    hdr.orig.fhdr   = fhdr;
    hdr.orig.chdr   = chdr;
    hdr.orig.ename  = ename;
    hdr.orig.cnames = cnames;
    hdr.orig.fcom   = fcom;
    hdr.orig.ftext  = ftext;
    
  case 'egi_egis'
    [fhdr,chdr,ename,cnames,fcom,ftext] = read_egis_header(filename);
    [p, f, x]       = fileparts(filename);
    
    if any(chdr(:,4)-chdr(1,4))
      error('Sample rate not the same for all cells.');
    end;
    
    hdr.Fs          = chdr(1,4); %making assumption that sample rate is same for all cells
    hdr.nChans      = fhdr(19);
    for i = 1:hdr.nChans
      % this should be consistent with ft_senslabel
      hdr.label{i,1}  = ['E' num2str(i)];
    end;
    hdr.nTrials     = sum(chdr(:,2));
    hdr.nSamplesPre = ceil(fhdr(14)/(1000/hdr.Fs));
    % assuming that a utility was used to insert the correct baseline
    % duration into the header since it is normally absent. This slot is
    % actually allocated to the age of the subject, although NetStation
    % does not use it when generating an EGIS session file.
    
    if any(chdr(:,3)-chdr(1,3))
      error('Number of samples not the same for all cells.');
    end;
    
    hdr.nSamples    = chdr(1,3); %making assumption that number of samples is same for all cells
    
    % remember the original header details
    hdr.orig.fhdr   = fhdr;
    hdr.orig.chdr   = chdr;
    hdr.orig.ename  = ename;
    hdr.orig.cnames = cnames;
    hdr.orig.fcom   = fcom;
    hdr.orig.ftext  = ftext;
    
  case 'egi_sbin'
    % segmented type only
    [header_array, CateNames, CatLengths, preBaseline] = read_sbin_header(filename);
    [p, f, x]       = fileparts(filename);
    
    hdr.Fs          = header_array(9);
    hdr.nChans      = header_array(10);
    for i = 1:hdr.nChans
      % this should be consistent with ft_senslabel
      hdr.label{i,1}  = ['E' num2str(i)];
    end;
    hdr.nTrials     = header_array(15);
    hdr.nSamplesPre = preBaseline;
    
    hdr.nSamples    = header_array(16); % making assumption that number of samples is same for all cells
    
    % remember the original header details
    hdr.orig.header_array   = header_array;
    hdr.orig.CateNames   = CateNames;
    hdr.orig.CatLengths  = CatLengths;
    
  case {'egi_mff_v1' 'egi_mff'} % this is currently the default
    % The following represents the code that was written by Ingrid, Robert
    % and Giovanni to get started with the EGI mff dataset format. It might
    % not support all details of the file formats.
    % An alternative implementation has been provided by EGI, this is
    % released as fieldtrip/external/egi_mff and referred further down in
    % this function as 'egi_mff_v2'.
    
    if ~usejava('jvm')
      error('the xml2struct requires MATLAB to be running with the Java virtual machine (JVM)');
      % an alternative implementation which does not require the JVM but runs much slower is
      % available from http://www.mathworks.com/matlabcentral/fileexchange/6268-xml4mat-v2-0
    end
    
    % get header info from .bin files
    binfiles = dir(fullfile(filename, 'signal*.bin'));
    if isempty(binfiles)
      error('could not find any signal.bin in mff directory')
    end
    
    orig = [];
    for iSig = 1:length(binfiles)
      signalname = binfiles(iSig).name;
      fullsignalname = fullfile(filename, signalname);
      orig.signal(iSig).blockhdr = read_mff_bin(fullsignalname);
    end
    
    % get hdr info from xml files
    warning('off', 'MATLAB:REGEXP:deprecated') % due to some small code xml2struct
    xmlfiles = dir( fullfile(filename, '*.xml'));
    disp('reading xml files to obtain header info...')
    for i = 1:numel(xmlfiles)
      if strcmpi(xmlfiles(i).name(1:2), '._') % Mac sometimes creates this useless files, don't use them
      elseif strcmpi(xmlfiles(i).name(1:6), 'Events') % don't read in events here, can take a lot of time, and we can do that in ft_read_event
      else
        fieldname     = xmlfiles(i).name(1:end-4);
        filename_xml  = fullfile(filename, xmlfiles(i).name);
        orig.xml.(fieldname) = xml2struct(filename_xml);
      end
    end
    warning('on', 'MATLAB:REGEXP:deprecated')
    
    %make hdr according to FieldTrip rules
    hdr = [];
    Fs = zeros(length(orig.signal),1);
    nChans = zeros(length(orig.signal),1);
    nSamples = zeros(length(orig.signal),1);
    for iSig = 1:length(orig.signal)
      Fs(iSig)      = orig.signal(iSig).blockhdr(1).fsample(1);
      nChans(iSig)  = orig.signal(iSig).blockhdr(1).nsignals;
      % the number of samples per block can be different
      nSamples_Block = zeros(length(orig.signal(iSig).blockhdr),1);
      for iBlock  = 1:length(orig.signal(iSig).blockhdr)
        nSamples_Block(iBlock) = orig.signal(iSig).blockhdr(iBlock).nsamples(1);
      end
      nSamples(iSig) = sum(nSamples_Block);
    end
    
    if length(unique(Fs)) > 1 || length(unique(nSamples)) > 1
      error('Fs and nSamples should be the same in all signals')
    end
    
    hdr.Fs          = Fs(1);
    hdr.nChans      = sum(nChans);
    hdr.nSamplesPre = 0;
    hdr.nSamples    = nSamples(1);
    hdr.nTrials     = 1;
    
    %-get channel labels, otherwise create them
    if isfield(orig.xml, 'sensorLayout') % asuming that signal1 is hdEEG sensornet, and channels are in xml file sensorLayout
      for iSens = 1:numel(orig.xml.sensorLayout.sensors)
        if strcmp(orig.xml.sensorLayout.sensors(iSens).sensor.type, '0') %EEG chans
          % this should be consistent with ft_senslabel
          hdr.label{iSens} = ['E' num2str(orig.xml.sensorLayout.sensors(iSens).sensor.number)];
        elseif strcmp(orig.xml.sensorLayout.sensors(iSens).sensor.type, '1') %REF;
          hdr.label{iSens} = ['E' num2str(iSens)]; % to be consistent with other egi formats
        else
          %non interesting channels like place holders and COM
        end
      end
      %check if the amount of lables corresponds with nChannels in signal 1
      if length(hdr.label) == orig.signal(1).blockhdr(1).nsignals
        %good
      elseif length(hdr.label) > orig.signal(1).blockhdr(1).nsignals
        warning('found more lables in xml.sensorLayout than channels in signal 1, thus can not use info in sensorLayout, creating labels on the fly')
        for iSens = 1:orig.signal(1).blockhdr(1).nsignals
          % this should be consistent with ft_senslabel
          hdr.label{iSens} = ['E' num2str(iSens)];
        end
      else warning('found less lables in xml.sensorLayout than channels in signal 1, thus can not use info in sensorLayout, creating labels on the fly')
        for iSens = 1:orig.signal(1).blockhdr(1).nsignals
          % this should be consistent with ft_senslabel
          hdr.label{iSens} = ['E' num2str(iSens)];
        end
      end
      % get lables for other signals
      if length(orig.signal) == 2
        if isfield(orig.xml, 'pnsSet') % signal2 is PIB box, and lables are in xml file pnsSet
          nbEEGchan = length(hdr.label);
          for iSens = 1:numel(orig.xml.pnsSet.sensors)
            hdr.label{nbEEGchan+iSens} = num2str(orig.xml.pnsSet.sensors(iSens).sensor.name);
          end
          if length(hdr.label) == orig.signal(2).blockhdr(1).nsignals + orig.signal(2).blockhdr(1).nsignals
            %good
          elseif length(hdr.label) < orig.signal(1).blockhdr(1).nsignals + orig.signal(2).blockhdr(1).nsignals
            warning('found less lables in xml.pnsSet than channels in signal 2, labeling with s2_unknownN instead')
            for iSens = length(hdr.label)+1 : orig.signal(1).blockhdr(1).nsignals + orig.signal(2).blockhdr(1).nsignals
              hdr.label{iSens} = ['s2_unknown', num2str(iSens)];
            end
          else warning('found more lables in xml.pnsSet than channels in signal 2, thus can not use info in pnsSet, and labeling with s2_eN instead')
            for iSens = orig.signal(1).blockhdr(1).nsignals+1 : orig.signal(1).blockhdr(1).nsignals + orig.signal(2).blockhdr(1).nsignals
              hdr.label{iSens} = ['s2_E', num2str(iSens)];
            end
          end
        else % signal2 is not PIBbox
          warning('creating channel labels for signal 2 on the fly')
          for iSens = 1:orig.signal(2).blockhdr(1).nsignals
            hdr.label{end+1} = ['s2_E', num2str(iSens)];
          end
        end
      elseif length(orig.signal) > 2
        % loop over signals and label channels accordingly
        warning('creating channel labels for signal 2 to signal N on the fly')
        for iSig = 2:length(orig.signal)
          for iSens = 1:orig.signal(iSig).blockhdr(1).nsignals
            if iSig == 1 && iSens == 1
              hdr.label{1} = ['s',num2str(iSig),'_E', num2str(iSens)];
            else
              hdr.label{end+1} = ['s',num2str(iSig),'_E', num2str(iSens)];
            end
          end
        end
      end
    else % no xml.sensorLayout present
      warning('no sensorLayout found in xml files, creating channel labels on the fly')
      for iSig = 1:length(orig.signal)
        for iSens = 1:orig.signal(iSig).blockhdr(1).nsignals
          if iSig == 1 && iSens == 1
            hdr.label{1} = ['s',num2str(iSig),'_E', num2str(iSens)];
          else
            hdr.label{end+1} = ['s',num2str(iSig),'_E', num2str(iSens)];
          end
        end
      end
    end
    
    % check if multiple epochs are present
    if isfield(orig.xml,'epoch') && length(orig.xml.epoch) > 1
      % add info to header about which sample correspond to which epochs, becasue this is quite hard for user to get...
      epochdef = zeros(length(orig.xml.epoch),3);
      for iEpoch = 1:length(orig.xml.epoch)
        if iEpoch == 1
          epochdef(iEpoch,1) = round(str2double(orig.xml.epoch(iEpoch).epoch.beginTime)./1000./hdr.Fs)+1;
          epochdef(iEpoch,2) = round(str2double(orig.xml.epoch(iEpoch).epoch.endTime)./1000./hdr.Fs);
          epochdef(iEpoch,3) = round(str2double(orig.xml.epoch(iEpoch).epoch.beginTime)./1000./hdr.Fs); %offset corresponds to timing
        else
          NbSampEpoch = round(str2double(orig.xml.epoch(iEpoch).epoch.endTime)./1000./hdr.Fs - str2double(orig.xml.epoch(iEpoch).epoch.beginTime)./1000./hdr.Fs);
          epochdef(iEpoch,1) = epochdef(iEpoch-1,2) + 1;
          epochdef(iEpoch,2) = epochdef(iEpoch-1,2) + NbSampEpoch;
          epochdef(iEpoch,3) = round(str2double(orig.xml.epoch(iEpoch).epoch.beginTime)./1000./hdr.Fs); %offset corresponds to timing
        end
      end
      warning('the data contains multiple epochs with possibly discontinuous boundaries. Added ''epochdef'' to hdr.orig defining begin and end sample of each epoch. See hdr.orig.xml.epoch for epoch details, use ft_read_header to obtain header or look in data.dhr.')
      % sanity check
      if epochdef(end,2) ~= hdr.nSamples
        error('number of samples in all epochs do not add up to total number of samples')
      end
      orig.epochdef = epochdef;
    end
    hdr.orig      = orig;
    
  case 'egi_mff_v2'
    % ensure that the EGI toolbox is on the path
    ft_hastoolbox('egi_mff', 1);
    if isunix && filename(1)~=filesep
      % add the full path to the dataset directory
      filename = fullfile(pwd, filename);
    else
      % FIXME I don't know how this is supposed to work on Windows computers
      % with the drive letter in front of the path
    end
    hdr = read_mff_header(filename);
      
  case 'fcdc_buffer'
    % read from a networked buffer for realtime analysis
    [host, port] = filetype_check_uri(filename);
    if retry
      orig = [];
      while isempty(orig)
        try
          % try reading the header, catch the error and retry
          orig = buffer('get_hdr', [], host, port);
        catch
          warning('could not read header from %s, retrying in 1 second', filename);
          pause(1);
        end
      end % while
    else
      % try reading the header only once, give error if it fails
      orig = buffer('get_hdr', [], host, port);
    end % if retry
    hdr.Fs          = orig.fsample;
    hdr.nChans      = orig.nchans;
    hdr.nSamples    = orig.nsamples;
    hdr.nSamplesPre = 0; % since continuous
    hdr.nTrials     = 1; % since continuous
    hdr.orig        = []; % add chunks if present
    
    % add the contents of attached .res4 file to the .orig field similar to offline data
    if isfield(orig, 'ctf_res4')
      if 0
        % using  READ_CTF_RES4 -- this does not produce a proper .grad structure
        % TODO: remove this code, and possibly read_ctf_res4 as well
        tmp_name = tempname;
        F = fopen(tmp_name, 'wb');
        fwrite(F, orig.ctf_res4, 'uint8');
        fclose(F);
        R4F = read_ctf_res4(tmp_name);
        delete(tmp_name);
      else
        % using FT_READ_HEADER recursively, and then readCTFds in the second call
        % this will also call ctf2grad and yield correct gradiometer information
        tmp_name = tempname;
        [dirname, fname] = fileparts(tmp_name);
        res4fn = [tmp_name '.ds/' fname '.res4'];
        meg4fn = [tmp_name '.ds/' fname '.meg4'];
        dsname = [tmp_name '.ds'];
        
        mkdir(dsname);
        
        F = fopen(res4fn, 'wb');
        fwrite(F, orig.ctf_res4, 'uint8');
        fclose(F);
        
        F = fopen(meg4fn, 'wb');
        fwrite(F, 'MEG42CP');
        fclose(F);
        
        %R4F = read_ctf_res4(tmp_name);
        R4F = ft_read_header(dsname);
        
        delete(res4fn);
        delete(meg4fn);
        rmdir(dsname);
      end
      
      % copy over the labels
      hdr.label = R4F.label;
      % copy over the 'original' header
      hdr.orig = R4F;
      if isfield(R4F,'grad')
        hdr.grad = R4F.grad;
      end
      % add the raw chunk as well
      hdr.orig.ctf_res4 = orig.ctf_res4;
    end
    
    % add the contents of attached NIFTI-1 chunk after decoding to Matlab structure
    if isfield(orig, 'nifti_1')
      hdr.nifti_1 = decode_nifti1(orig.nifti_1);
      % add the raw chunk as well
      hdr.orig.nifti_1 = orig.nifti_1;
    end
    
    % add the contents of attached SiemensAP chunk after decoding to Matlab structure
    if isfield(orig, 'siemensap') && exist('sap2matlab')==3 % only run this if MEX file is present
      hdr.siemensap = sap2matlab(orig.siemensap);
      % add the raw chunk as well
      hdr.orig.siemensap = orig.siemensap;
    end
    
    if ~isfield(hdr, 'label')
      % prevent overwriting the labels that we might have gotten from a RES4 chunk
      if isfield(orig, 'channel_names')
        hdr.label = orig.channel_names;
      else
        hdr.label = cell(hdr.nChans,1);
        if hdr.nChans < 2000 % don't do this for fMRI etc.
          warning_once('creating fake channel names');        % give this warning only once
          for i=1:hdr.nChans
            hdr.label{i} = sprintf('%d', i);
          end
        else
          warning_once('skipping fake channel names');        % give this warning only once
          checkUniqueLabels = false;
        end
      end
    end
    
    
    hdr.orig.bufsize = orig.bufsize;
    
    % As of November 2011 the header should also contain the channel type
    % (e.g. meg, eeg, trigger) and the channel units (e.g. uV, fT).
    % For the FieldTrip buffer these have not been implemented yet,
    % therefore we have to return 'unknown' for both.
    hdr.chantype = repmat('unknown', size(hdr.label));
    hdr.chanunit = repmat('unknown', size(hdr.label));
    
  case 'fcdc_buffer_offline'
    [hdr, nameFlag] = read_buffer_offline_header(headerfile);
    switch nameFlag
      case 0
        % no labels generated (fMRI etc)
        checkUniqueLabels = false; % no need to check these
      case 1
        % hase generated fake channels
        % give this warning only once
        warning_once('creating fake channel names');
        checkUniqueLabels = false; % no need to check these
      case 2
        % got labels from chunk, check those
        checkUniqueLabels = true;
    end
    
  case 'fcdc_matbin'
    % this is multiplexed data in a *.bin file, accompanied by a matlab file containing the header
    load(headerfile, 'hdr');
    
  case 'fcdc_mysql'
    % check that the required low-level toolbox is available
    ft_hastoolbox('mysql', 1);
    % read from a MySQL server listening somewhere else on the network
    db_open(filename);
    if db_blob
      hdr = db_select_blob('fieldtrip.header', 'msg', 1);
    else
      hdr = db_select('fieldtrip.header', {'nChans', 'nSamples', 'nSamplesPre', 'Fs', 'label'}, 1);
      hdr.label = mxDeserialize(hdr.label);
    end
    
  case 'gtec_mat'
    % this is a simple MATLAB format, it contains a log and a names variable
    tmp = load(headerfile);
    log   = tmp.log;
    names = tmp.names;
    
    hdr.label = cellstr(names);
    hdr.nChans = size(log,1);
    hdr.nSamples = size(log,2);
    hdr.nSamplesPre = 0;
    hdr.nTrials = 1; % assume continuous data, not epoched
    
    % compute the sampling frequency from the time channel
    sel = strcmp(hdr.label, 'Time');
    time = log(sel,:);
    
    hdr.Fs = 1./(time(2)-time(1));
    
    % also remember the complete data upon request
    if cache
      hdr.orig.log = log;
      hdr.orig.names = names;
    end
    
  case {'itab_raw' 'itab_mhd'}
    % read the full header information frtom the binary header structure
    header_info = read_itab_mhd(headerfile);
    
    % these are the channels that are visible to fieldtrip
    chansel = 1:header_info.nchan;
    
    % convert the header information into a fieldtrip compatible format
    hdr.nChans      = length(chansel);
    hdr.label       = {header_info.ch(chansel).label};
    hdr.label       = hdr.label(:);  % should be column vector
    hdr.Fs          = header_info.smpfq;
    % it will always be continuous data
    hdr.nSamples    = header_info.ntpdata;
    hdr.nSamplesPre = 0; % it is a single continuous trial
    hdr.nTrials     = 1; % it is a single continuous trial
    % keep the original details AND the list of channels as used by fieldtrip
    hdr.orig         = header_info;
    hdr.orig.chansel = chansel;
    % add the gradiometer definition
    hdr.grad         = itab2grad(header_info);
    
  case 'micromed_trc'
    orig = read_micromed_trc(filename);
    hdr             = [];
    hdr.Fs          = orig.Rate_Min; % FIXME is this correct?
    hdr.nChans      = orig.Num_Chan;
    hdr.nSamples    = orig.Num_Samples;
    hdr.nSamplesPre = 0; % continuous
    hdr.nTrials     = 1; % continuous
    %hdr.label       = cell(1,hdr.nChans);
    % give this warning only once
    %warning('creating fake channel names');
    for i=1:hdr.nChans
      %hdr.label{i} = sprintf('%3d', i);
      hdr.label{i}=orig.channelinfo(i).label1;
    end
    % this should be a column vector
    hdr.label = hdr.label(:);
    % remember the original header details
    hdr.orig = orig;
    
  case {'mpi_ds', 'mpi_dap'}
    hdr = read_mpi_ds(filename);
    
  case 'netmeg'
    ft_hastoolbox('netcdf', 1);
    
    % this will read all NetCDF data from the file and subsequently convert
    % each of the three elements into a more easy to parse MATLAB structure
    s = netcdf(filename);
    
    for i=1:numel(s.AttArray)
      fname = fixname(s.AttArray(i).Str);
      fval  = s.AttArray(i).Val;
      if ischar(fval)
        fval = fval(fval~=0); % remove the \0 characters
        fval = strtrim(fval); % remove insignificant whitespace
      end
      Att.(fname) = fval;
    end
    
    for i=1:numel(s.VarArray)
      fname = fixname(s.VarArray(i).Str);
      fval  = s.VarArray(i).Data;
      if ischar(fval)
        fval = fval(fval~=0); % remove the \0 characters
        fval = strtrim(fval); % remove insignificant whitespace
      end
      Var.(fname) = fval;
    end
    
    for i=1:numel(s.DimArray)
      fname = fixname(s.DimArray(i).Str);
      fval  = s.DimArray(i).Dim;
      if ischar(fval)
        fval = fval(fval~=0); % remove the \0 characters
        fval = strtrim(fval); % remove insignificant whitespace
      end
      Dim.(fname) = fval;
    end
    
    % convert the relevant fields into teh default header structure
    hdr.Fs          = 1000/Var.samplinginterval;
    hdr.nChans      = length(Var.channelstatus);
    hdr.nSamples    = Var.numsamples;
    hdr.nSamplesPre = 0;
    hdr.nTrials     = size(Var.waveforms, 1);
    hdr.chanunit    = cellstr(reshape(Var.channelunits, hdr.nChans, 2));
    hdr.chantype    = cellstr(reshape(lower(Var.channeltypes), hdr.nChans, 3));
    
    warning_once('creating fake channel names');
    hdr.label = cell(hdr.nChans, 1);
    for i=1:hdr.nChans
      hdr.label{i} = sprintf('%d', i);
    end
    
    % remember the original details of the file
    % note that this also includes the data
    % this is large, but can be reused elsewhere
    hdr.orig.Att = Att;
    hdr.orig.Var = Var;
    hdr.orig.Dim = Dim;
    
    % construct the gradiometer structure from the complete header information
    hdr.grad = netmeg2grad(hdr);
    
  case 'neuralynx_dma'
    hdr = read_neuralynx_dma(filename);
    
  case 'neuralynx_sdma'
    hdr = read_neuralynx_sdma(filename);
    
  case 'neuralynx_ncs'
    ncs = read_neuralynx_ncs(filename, 1, 0);
    [p, f, x]       = fileparts(filename);
    hdr.Fs          = ncs.hdr.SamplingFrequency;
    hdr.label       = {f};
    hdr.nChans      = 1;
    hdr.nTrials     = 1;
    hdr.nSamplesPre = 0;
    hdr.nSamples    = ncs.NRecords * 512;
    hdr.orig        = ncs.hdr;
    FirstTimeStamp  = ncs.hdr.FirstTimeStamp;  % this is the first timestamp of the first block
    LastTimeStamp   = ncs.hdr.LastTimeStamp;   % this is the first timestamp of the last block, i.e. not the timestamp of the last sample
    hdr.TimeStampPerSample = double(LastTimeStamp - FirstTimeStamp) ./ ((ncs.NRecords-1)*512);
    hdr.FirstTimeStamp     = FirstTimeStamp;
    
  case 'neuralynx_nse'
    nse = read_neuralynx_nse(filename, 1, 0);
    [p, f, x]       = fileparts(filename);
    hdr.Fs          = nse.hdr.SamplingFrequency;
    hdr.label       = {f};
    hdr.nChans      = 1;
    hdr.nTrials     = nse.NRecords;  % each record contains one waveform
    hdr.nSamples    = 32;            % there are 32 samples in each waveform
    hdr.nSamplesPre = 0;
    hdr.orig        = nse.hdr;
    % FIXME add hdr.FirstTimeStamp and hdr.TimeStampPerSample
    
  case {'neuralynx_ttl', 'neuralynx_tsl', 'neuralynx_tsh'}
    % these are hardcoded, they contain an 8-byte header and int32 values for a single channel
    % FIXME this should be done similar as neuralynx_bin, i.e. move the hdr into the function
    hdr             = [];
    hdr.Fs          = 32556;
    hdr.nChans      = 1;
    hdr.nSamples    = (filesize(filename)-8)/4;
    hdr.nSamplesPre = 1;
    hdr.nTrials     = 1;
    hdr.label       = {headerformat((end-3):end)};
    
  case 'neuralynx_bin'
    hdr = read_neuralynx_bin(filename);
    
  case 'neuralynx_ds'
    hdr = read_neuralynx_ds(filename);
    
  case 'neuralynx_cds'
    hdr = read_neuralynx_cds(filename);
    
  case 'nexstim_nxe'
    hdr = read_nexstim_nxe(filename);
    
  case {'neuromag_fif' 'neuromag_mne'}
    % check that the required low-level toolbox is available
    ft_hastoolbox('mne', 1);
    
    orig = fiff_read_meas_info(filename);
    % convert to fieldtrip format header
    hdr.label       = orig.ch_names(:);
    hdr.nChans      = orig.nchan;
    hdr.Fs          = orig.sfreq;
    % add a gradiometer structure for forward and inverse modelling
    try
      [hdr.grad, elec] = mne2grad(orig);
      if ~isempty(elec)
        hdr.elec     = elec;
      end
    catch
      disp(lasterr);
    end
    
    for i = 1:hdr.nChans % make a cell array of units for each channel
      switch orig.chs(i).unit
        case 201 % defined as constants by MNE, see p. 217 of MNE manual
          hdr.unit{i} = 'T/m';
        case 112
          hdr.unit{i} = 'T';
        case 107
          hdr.unit{i} = 'V';
        case 202
          hdr.unit{i} = 'Am';
        otherwise
          hdr.unit{i} = 'unknown';
      end
    end
    
    iscontinuous  = 0;
    isaverage     = 0;
    isepoched     = 0;     % FIXME don't know how to determine this, or whether epoched .fif data exists!
    
    if isempty(fiff_find_evoked(filename)) % true if file contains no evoked responses
      iscontinuous = 1;
    else
      isaverage    = 1;
    end
    
    if iscontinuous
      try
        % we only use 1 input argument here to allow backward
        % compatibility up to MNE 2.6.x:
        raw = fiff_setup_read_raw(filename);
      catch
        % the "catch me" syntax is broken on MATLAB74, this fixes it
        me = lasterror;
        % there is an error - we try to use MNE 2.7.x (if present) to
        % determine if the cause is maxshielding:
        try
          allow_maxshield = true;
          raw = fiff_setup_read_raw(filename,allow_maxshield);
        catch
          %unknown problem, or MNE version 2.6.x or less:
          rethrow(me);
        end
        % no error message from fiff_setup_read_raw? Then maxshield
        % was applied, but maxfilter wasn't, so return this error:
        error(['Maxshield data has not had maxfilter applied to it - cannot be read by fieldtrip. ' ...
          'Apply Neuromag maxfilter before converting to fieldtrip format.']);
      end
      hdr.nSamples    = raw.last_samp - raw.first_samp + 1; % number of samples per trial
      hdr.nSamplesPre = 0;
      % otherwise conflicts will occur in read_data
      hdr.nTrials     = 1;
      orig.raw        = raw; % keep all the details
      
    elseif isaverage
      evoked_data    = fiff_read_evoked_all(filename);
      vartriallength = any(diff([evoked_data.evoked.first])) || any(diff([evoked_data.evoked.last]));
      if vartriallength
        % there are trials averages with variable durations in the file
        warning('EVOKED FILE with VARIABLE TRIAL LENGTH! - check data have been processed accurately');
        hdr.nSamples = 0;
        for i=1:length(evoked_data.evoked)
          hdr.nSamples = hdr.nSamples + size(evoked_data.evoked(i).epochs, 2);
        end
        % represent it as a continuous file with a single trial
        % all trial average details will be available through read_event
        hdr.nSamplesPre = 0;
        hdr.nTrials     = 1;
        orig.evoked     = evoked_data.evoked; % this is used by read_data to get the actual data, i.e. to prevent re-reading
        orig.info       = evoked_data.info;   % keep all the details
        orig.vartriallength = 1;
      else
        % represent it as a file with multiple trials, each trial has the same length
        % all trial average details will be available through read_event
        hdr.nSamples    = evoked_data.evoked(1).last - evoked_data.evoked(1).first + 1;
        hdr.nSamplesPre = -evoked_data.evoked(1).first;   % represented as negative number in fif file
        hdr.nTrials     = length(evoked_data.evoked);
        orig.evoked     = evoked_data.evoked;             % this is used by read_data to get the actual data, i.e. to prevent re-reading
        orig.info       = evoked_data.info;               % keep all the details
        orig.vartriallength = 0;
      end
      
    elseif isepoched
      error('Support for epoched *.fif data is not yet implemented.')
    end
    
    % remember the original header details
    hdr.orig = orig;
    
    % these are useful to know in read_event
    hdr.orig.isaverage    = isaverage;
    hdr.orig.iscontinuous = iscontinuous;
    hdr.orig.isepoched    = isepoched;
    
  case 'neuromag_mex'
    % check that the required low-level toolbox is available
    ft_hastoolbox('meg-pd', 1);
    rawdata('any',filename);
    rawdata('goto', 0);
    megmodel('head',[0 0 0],filename);
    % get the available information from the fif file
    [orig.rawdata.range,orig.rawdata.calib]           = rawdata('range');
    [orig.rawdata.sf]                                 = rawdata('sf');
    [orig.rawdata.samples]                            = rawdata('samples');
    [orig.chaninfo.N,orig.chaninfo.S,orig.chaninfo.T] = chaninfo;           % Numbers, names & places
    [orig.chaninfo.TY,orig.chaninfo.NA]               = chaninfo('type');   % Coil type
    [orig.chaninfo.NO]                                = chaninfo('noise');  % Default noise level
    [orig.channames.NA,orig.channames.KI,orig.channames.NU] = channames(filename); % names, kind, logical numbers
    % read a single trial to determine the data size
    [buf, status] = rawdata('next');
    rawdata('close');
    
    % This is to solve a problem reported by Doug Davidson: The problem
    % is that rawdata('samples') is not returning the number of samples
    % correctly. It appears that the example script rawchannels in meg-pd
    % might work, however, so I want to use rawchannels to read in one
    % channel of data in order to get the number of samples in the file:
    if orig.rawdata.samples<0
      tmpchannel = 1;
      tmpvar = rawchannels(filename,tmpchannel);
      [orig.rawdata.samples] = size(tmpvar,2);
      clear tmpvar tmpchannel;
    end
    
    % convert to fieldtrip format header
    hdr.label       = orig.channames.NA;
    hdr.Fs          = orig.rawdata.sf;
    hdr.nSamplesPre = 0; % I don't know how to get this out of the file
    hdr.nChans      = size(buf,1);
    hdr.nSamples    = size(buf,2); % number of samples per trial
    hdr.nTrials     = orig.rawdata.samples ./ hdr.nSamples;
    % add a gradiometer structure for forward and inverse modelling
    hdr.grad = fif2grad(filename);
    % remember the original header details
    hdr.orig = orig;
    
  case 'neuroprax_eeg'
    orig = np_readfileinfo(filename);
    
    hdr.Fs          = orig.fa;
    hdr.nChans      = orig.K;
    hdr.nSamples    = orig.N;
    hdr.nSamplesPre = 0; % continuous
    hdr.nTrials     = 1; % continuous
    hdr.label       = orig.channels(:);
    hdr.unit        = orig.units(:);
    
    % remember the original header details
    hdr.orig = orig;
    
  case 'nimh_cortex'
    cortex = read_nimh_cortex(filename, 'epp', 'no', 'eog', 'no');
    % look at the first trial to determine whether it contains data in the EPP and EOG channels
    trial1  = read_nimh_cortex(filename, 'epp', 'yes', 'eog', 'yes', 'begtrial', 1, 'endtrial', 1);
    hasepp = ~isempty(trial1.epp);
    haseog = ~isempty(trial1.eog);
    if hasepp
      warning('EPP channels are not yet supported');
    end
    % at the moment only the EOG channels are supported here
    if haseog
      hdr.label       = {'EOGx' 'EOGy'};
      hdr.nChans      = 2;
    else
      hdr.label       = {};
      hdr.nChans      = 0;
    end
    hdr.nTrials     = length(cortex);
    hdr.nSamples    = inf;
    hdr.nSamplesPre = 0;
    hdr.orig.trial = cortex;
    hdr.orig.hasepp = hasepp;
    hdr.orig.haseog = haseog;
    
  case 'ns_avg'
    orig = read_ns_hdr(filename);
    % do some reformatting/renaming of the header items
    hdr.Fs          = orig.rate;
    hdr.nSamples    = orig.npnt;
    hdr.nSamplesPre = round(-orig.rate*orig.xmin/1000);
    hdr.nChans      = orig.nchan;
    hdr.label       = orig.label(:);
    hdr.nTrials     = 1; % the number of trials in this datafile is only one, i.e. the average
    % remember the original header details
    hdr.orig = orig;
    
  case {'ns_cnt' 'ns_cnt16', 'ns_cnt32'}
    if strcmp(headerformat, 'ns_cnt')
      orig = loadcnt(filename, 'ldnsamples', 1);
    elseif strcmp(headerformat, 'ns_cnt16')
      orig = loadcnt(filename, 'ldnsamples', 1, 'dataformat', 'int16');
    elseif strcmp(headerformat, 'ns_cnt32')
      orig = loadcnt(filename, 'ldnsamples', 1, 'dataformat', 'int32');
    end
    
    orig = rmfield(orig, {'data', 'ldnsamples'});
    
    % do some reformatting/renaming of the header items
    hdr.Fs          = orig.header.rate;
    hdr.nChans      = orig.header.nchannels;
    hdr.nSamples    = orig.header.numsamples;
    hdr.nSamplesPre = 0;
    hdr.nTrials     = 1;
    for i=1:hdr.nChans
      hdr.label{i} = deblank(orig.electloc(i).lab);
    end
    % remember the original header details
    hdr.orig = orig;
    
  case 'ns_eeg'
    orig = read_ns_hdr(filename);
    % do some reformatting/renaming of the header items
    hdr.label       = orig.label;
    hdr.Fs          = orig.rate;
    hdr.nSamples    = orig.npnt;
    hdr.nSamplesPre = round(-orig.rate*orig.xmin/1000);
    hdr.nChans      = orig.nchan;
    hdr.nTrials     = orig.nsweeps;
    % remember the original header details
    hdr.orig = orig;
    
  case 'plexon_ds'
    hdr = read_plexon_ds(filename);
    
  case 'plexon_ddt'
    orig = read_plexon_ddt(filename);
    hdr.nChans      = orig.NChannels;
    hdr.Fs          = orig.Freq;
    hdr.nSamples    = orig.NSamples;
    hdr.nSamplesPre = 0;      % continuous
    hdr.nTrials     = 1;      % continuous
    hdr.label       = cell(1,hdr.nChans);
    % give this warning only once
    warning('creating fake channel names');
    for i=1:hdr.nChans
      hdr.label{i} = sprintf('%d', i);
    end
    % also remember the original header
    hdr.orig        = orig;
    
  case {'read_nex_data'} % this is an alternative reader for nex files
    orig = read_nex_header(filename);
    % assign the obligatory items to the output FCDC header
    numsmp = cell2mat({orig.varheader.numsmp});
    adindx = find(cell2mat({orig.varheader.typ})==5);
    if isempty(adindx)
      error('file does not contain continuous channels');
    end
    hdr.nChans      = length(orig.varheader);
    hdr.Fs          = orig.varheader(adindx(1)).wfrequency;     % take the sampling frequency from the first A/D channel
    hdr.nSamples    = max(numsmp(adindx));                      % take the number of samples from the longest A/D channel
    hdr.nTrials     = 1;                                        % it can always be interpreted as continuous data
    hdr.nSamplesPre = 0;                                        % and therefore it is not trial based
    for i=1:hdr.nChans
      hdr.label{i} = deblank(char(orig.varheader(i).nam));
    end
    hdr.label = hdr.label(:);
    % also remember the original header details
    hdr.orig = orig;
    
  case {'read_plexon_nex' 'plexon_nex'} % this is the default reader for nex files
    orig = read_plexon_nex(filename);
    numsmp = cell2mat({orig.VarHeader.NPointsWave});
    adindx = find(cell2mat({orig.VarHeader.Type})==5);
    if isempty(adindx)
      error('file does not contain continuous channels');
    end
    hdr.nChans      = length(orig.VarHeader);
    hdr.Fs          = orig.VarHeader(adindx(1)).WFrequency;     % take the sampling frequency from the first A/D channel
    hdr.nSamples    = max(numsmp(adindx));                      % take the number of samples from the longest A/D channel
    hdr.nTrials     = 1;                                        % it can always be interpreted as continuous data
    hdr.nSamplesPre = 0;                                        % and therefore it is not trial based
    for i=1:hdr.nChans
      hdr.label{i} = deblank(char(orig.VarHeader(i).Name));
    end
    hdr.label = hdr.label(:);
    hdr.FirstTimeStamp     = orig.FileHeader.Beg;
    hdr.TimeStampPerSample = orig.FileHeader.Frequency ./ hdr.Fs;
    % also remember the original header details
    hdr.orig = orig;
    
  case 'plexon_plx'
    orig = read_plexon_plx(filename);
    if orig.NumSlowChannels==0
      error('file does not contain continuous channels');
    end
    fsample = [orig.SlowChannelHeader.ADFreq];
    if any(fsample~=fsample(1))
      error('different sampling rates in continuous data not supported');
    end
    for i=1:length(orig.SlowChannelHeader)
      label{i} = deblank(orig.SlowChannelHeader(i).Name);
    end
    % continuous channels don't always contain data, remove the empty ones
    sel  = [orig.DataBlockHeader.Type]==5;  % continuous
    chan = [orig.DataBlockHeader.Channel];
    for i=1:length(label)
      chansel(i) = any(chan(sel)==orig.SlowChannelHeader(i).Channel);
    end
    chansel = find(chansel); % this is required for timestamp selection
    label = label(chansel);
    % only the continuous channels are returned as visible
    hdr.nChans      = length(label);
    hdr.Fs          = fsample(1);
    hdr.label       = label;
    % also remember the original header
    hdr.orig        = orig;
    
    % select the first continuous channel that has data
    sel = ([orig.DataBlockHeader.Type]==5 & [orig.DataBlockHeader.Channel]==orig.SlowChannelHeader(chansel(1)).Channel);
    % get the timestamps that correspond with the continuous data
    tsl = [orig.DataBlockHeader(sel).TimeStamp]';
    tsh = [orig.DataBlockHeader(sel).UpperByteOf5ByteTimestamp]';
    ts  = timestamp_plexon(tsl, tsh);  % use helper function, this returns an uint64 array
    
    % determine the number of samples in the continuous channels
    num = [orig.DataBlockHeader(sel).NumberOfWordsInWaveform];
    hdr.nSamples    = sum(num);
    hdr.nSamplesPre = 0;      % continuous
    hdr.nTrials     = 1;      % continuous
    
    % the timestamps indicate the beginning of each block, hence the timestamp of the last block corresponds with the end of the previous block
    hdr.TimeStampPerSample = double(ts(end)-ts(1))/sum(num(1:(end-1)));
    hdr.FirstTimeStamp     = ts(1);                                                %  the timestamp of the first continuous sample
    
    % also make the spike channels visible
    for i=1:length(orig.ChannelHeader)
      hdr.label{end+1} = deblank(orig.ChannelHeader(i).Name);
    end
    hdr.label = hdr.label(:);
    hdr.nChans = length(hdr.label);
    
  case {'tdt_tsq', 'tdt_tev'}
    % FIXME the code below is not yet functional, it requires more input from the ESI in Frankfurt
    %     tsq = read_tdt_tsq(headerfile);
    %     k = 0;
    %     chan = unique([tsq.channel]);
    %     % loop over the physical channels
    %     for i=1:length(chan)
    %       chansel = [tsq.channel]==chan(i);
    %       code = unique({tsq(chansel).code});
    %       % loop over the logical channels
    %       for j=1:length(code)
    %         codesel = false(size(tsq));
    %         for k=1:numel(codesel)
    %           codesel(k) = identical(tsq(k).code, code{j});
    %         end
    %         % find the first instance of this logical channel
    %         this = find(chansel(:) & codesel(:), 1);
    %         % add it to the list of channels
    %         k = k + 1;
    %         frequency(k) = tsq(this).frequency;
    %         label{k}     = [char(typecast(tsq(this).code, 'uint8')) num2str(tsq(this).channel)];
    %         tsqorig(k)   = tsq(this);
    %       end
    %     end
    error('not yet implemented');
    
  case {'yokogawa_ave', 'yokogawa_con', 'yokogawa_raw', 'yokogawa_mrk'}
    % header can be read with two toolboxes: Yokogawa MEG Reader and Yokogawa MEG160 (old inofficial toolbox)
    % newest toolbox takes precedence.
    if ft_hastoolbox('yokogawa_meg_reader', 3); % stay silent if it cannot be added
      hdr = read_yokogawa_header_new(filename);
      % add a gradiometer structure for forward and inverse modelling
      hdr.grad = yokogawa2grad_new(hdr);
    else
      ft_hastoolbox('yokogawa', 1); % try it with the old version of the toolbox
      hdr = read_yokogawa_header(filename);
      % add a gradiometer structure for forward and inverse modelling
      hdr.grad = yokogawa2grad(hdr);
    end
    
  case 'nmc_archive_k'
    hdr = read_nmc_archive_k_hdr(filename);
    
  case 'neuroshare' % NOTE: still under development
    % check that the required neuroshare toolbox is available
    ft_hastoolbox('neuroshare', 1);
    
    tmp = read_neuroshare(filename);
    hdr.Fs          = tmp.hdr.analoginfo(end).SampleRate; % take the sampling freq from the last analog channel (assuming this is the same for all chans)
    hdr.nChans      = length(tmp.list.analog(tmp.analog.contcount~=0)); % get the analog channels, only the ones that are not empty
    hdr.nSamples    = max([tmp.hdr.entityinfo(tmp.list.analog).ItemCount]); % take the number of samples from the longest channel
    hdr.nSamplesPre = 0; % continuous data
    hdr.nTrials     = 1; % continuous data
    hdr.label       = {tmp.hdr.entityinfo(tmp.list.analog(tmp.analog.contcount~=0)).EntityLabel}; %%% contains non-unique chans?
    hdr.orig        = tmp; % remember the original header
    
  case 'bucn_nirs'
    orig = read_bucn_nirshdr(filename);
    hdr  = rmfield(orig, 'time');
    hdr.orig = orig;
    
  case 'neurosim'
    hdr = read_neurosim_signals(filename);
    
  otherwise
    if strcmp(fallback, 'biosig') && ft_hastoolbox('BIOSIG', 1)
      hdr = read_biosig_header(filename);
    else
      error('unsupported header format (%s)', headerformat);
    end
end % switch headerformat

if checkUniqueLabels
  if length(hdr.label)~=length(unique(hdr.label))
    % all channels must have unique names
    warning('all channels must have unique labels, creating unique labels');
    for i=1:hdr.nChans
      sel = find(strcmp(hdr.label{i}, hdr.label));
      if length(sel)>1
        for j=1:length(sel)
          hdr.label{sel(j)} = sprintf('%s-%d', hdr.label{sel(j)}, j);
        end
      end
    end
  end
end

% ensure taht it is a column array
hdr.label = hdr.label(:);

% as of November 2011, the header is supposed to include the channel type
% (see FT_CHANTYPE) and the units of each channel (e.g. uV, fT, ...).

if ~isfield(hdr, 'chantype')
  % use a helper function which has some built in intelligence
  hdr.chantype = ft_chantype(hdr);
end % for

if ~isfield(hdr, 'chanunit')
  % use a helper function which has some built in intelligence
  hdr.chanunit = ft_chanunit(hdr);
end % for

% ensure that the output grad/elec is according to the latest definition
if isfield(hdr, 'grad')
  hdr.grad = ft_datatype_sens(hdr.grad);
elseif isfield(hdr, 'elec')
  hdr.elec = ft_datatype_sens(hdr.elec);
end

% ensure that these are double precision and not integers, otherwise
% subsequent computations that depend on these might be messed up
hdr.Fs          = double(hdr.Fs);
hdr.nSamples    = double(hdr.nSamples);
hdr.nSamplesPre = double(hdr.nSamplesPre);
hdr.nTrials     = double(hdr.nTrials);
hdr.nChans      = double(hdr.nChans);

if cache && exist(headerfile, 'file')
  % put the header in the cache
  cacheheader = hdr;
  % update the header details (including time stampp, size and name)
  cacheheader.details = dir(headerfile);
  % fprintf('added header to cache\n');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION to determine the file size in bytes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [siz] = filesize(filename)
l = dir(filename);
if l.isdir
  error('"%s" is not a file', filename);
end
siz = l.bytes;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION to determine the file size in bytes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [hdr] = recursive_read_header(filename)
[p, f, x] = fileparts(filename);
ls = dir(filename);
ls = ls(~strcmp({ls.name}, '.'));  % exclude this directory
ls = ls(~strcmp({ls.name}, '..')); % exclude parent directory
for i=1:length(ls)
  % make sure that the directory listing includes the complete path
  ls(i).name = fullfile(filename, ls(i).name);
end
lst = {ls.name};
hdr = cell(size(lst));
sel = zeros(size(lst));
for i=1:length(lst)
  % read the header of each individual file
  try
    thishdr = ft_read_header(lst{i});
    if isstruct(thishdr)
      thishdr.filename = lst{i};
    end
  catch
    thishdr = [];
    warning(lasterr);
    fprintf('while reading %s\n\n', lst{i});
  end
  if ~isempty(thishdr)
    hdr{i} = thishdr;
    sel(i) = true;
  else
    sel(i) = false;
  end
end
sel = logical(sel(:));
hdr = hdr(sel);
tmp = {};
for i=1:length(hdr)
  if isstruct(hdr{i})
    tmp = cat(1, tmp, hdr(i));
  elseif iscell(hdr{i})
    tmp = cat(1, tmp, hdr{i}{:});
  end
end
hdr = tmp;
