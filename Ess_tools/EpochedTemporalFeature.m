classdef EpochedTemporalFeature < EpochedFeature
    properties
    end;
    
    methods
        function obj = EpochedTemporalFeature
            obj = obj@EpochedFeature;
            obj.type = 'ess:EpochedFeature/EpochedTemporalFeature'; % use / to append childen types here.
            obj = obj.setId;
        end
        
        function obj = epochChannels(obj, EEG, varargin)
            inputOptions = arg_define(varargin, ...
                arg('channelIndices',[],[],'EEG channel indices to use. If empty and no "channellabels" is provided then all channels will be selected. If both "channelIndices" and "channellabels" are provided, their intersection will be used.'), ...
                arg('channellabels',[],[],'EEG channel labels to use. If both "channelIndices" and "channellabels" are provided, their intersection will be used.'), ...
                arg('timeRange',[-2 2],[],'Time range [before after] to include in the epoch. This is in seconds.'), ...
                arg('lowpass', 0.5,[0 Inf],'Low-pass EEG at this frequency. Use empty to skip'), ...
                arg('highpass', 20,[0 Inf],'High-pass EEG at this frequency. Leave empty to skip.'), ...
                arg('maxChannels', Inf,[1 Inf],'Maximum number of channels to use. A uniform subset of channels will be used if this value is less than the number of channels in EEG.'), ...
                arg_sub('select',{},@EpochedFeature.getTrialTimesFromEEGstructure, 'A struct argument. Arguments are as in myotherfunction(), can be assigned as a cell array of name-value pairs or structs.'));
            
            assert(inputOptions.timeRange(2) > inputOptions.timeRange(1), 'The "timeRange" is invalid');                    
            
            inputOptions.select.EEG = EEG;
            [trialFrames, trialTimes, trialHEDStrings, trialEventTypes] =  EpochedFeature.getTrialTimesFromEEGstructure(inputOptions.select);
            
            if isempty(inputOptions.channelIndices)
                chanlocIds = 1:length(EEG.chanlocs);
            else
                chanlocIds = inputOptions.channelIndices;
            end;
            
            for i=1:length(chanlocIds)
                if strcmpi(EEG.chanlocs(chanlocIds(i)).type, 'EEG') && (isempty(inputOptions.channellabels) || ismember(EEG.chanlocs(chanlocIds(i)).labels, inputOptions.channellabels))
                    inputOptions.channelIndices = [inputOptions.channelIndices chanlocIds(i)];
                end;
            end;
            
            EEG = pop_select(EEG, 'channel', inputOptions.channelIndices);
                            
            if size(EEG.data, 1) > inputOptions.maxChannels
                subset = loc_subsets(EEG.chanlocs, inputOptions.maxChannels);
                EEG = pop_select(EEG, 'channel', subset{1});
            end;                      
            
            if inputOptions.timeRange(1) < 0
                numberOfIndicesBefore = -inputOptions.timeRange(1) * EEG.srate;
                numberOfIndicesAfter =  inputOptions.timeRange(2) * EEG.srate;
                epochTimes = trialFrames;
            else % the start of the range is afer the event, need to swicth epoch time to suite the way epochTensor() works.
                epochTimes = epochTimes + (inputOptions.timeRange(1) * EEG.srate);
                numberOfIndicesBefore = 0;
                numberOfIndicesAfter = (inputOptions.timeRange(2) - inputOptions.timeRange(1)) * EEG.srate;
            end;
                        
            % filter EEG channels
            if ~isempty(inputOptions.lowpass)
                EEG = pop_eegfiltnew(EEG, inputOptions.lowpass, []);
            end;            
            if ~isempty(inputOptions.highpass)
                EEG = pop_eegfiltnew(EEG, [], inputOptions.highpass);
            end;
            
            obj.tensor = EpochedFeature.epochTensor(EEG.data', epochTimes, numberOfIndicesBefore, numberOfIndicesAfter);

            obj.axes{1} = TrialAxis('times', trialTimes, 'hedStrings', trialHEDStrings, 'codes', trialEventTypes);
            obj.axes{2} = TimeAxis('initTime', inputOptions.timeRange(1), 'nominalRate', EEG.srate, 'numberOfTimes', size(obj.tensor, 2));
            obj.axes{3} = ChannelAxis('chanlocs', EEG.chanlocs);
            
            assert(obj.isValid, 'Result is not valid');
        end
    end
end