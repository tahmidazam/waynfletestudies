% Parameters
files = {
    'CLASubjectF1509283StLRHand.mat'; ...
    'CLASubjectA1601083StLRHand.mat'; ...
    'CLASubjectB1510193StLRHand.mat'; ...
    'CLASubjectB1510203StLRHand.mat'; ...
    'CLASubjectB1512153StLRHand.mat'; ...
    'CLASubjectC1511263StLRHand.mat'; ...
    'CLASubjectC1512163StLRHand.mat'; ...
    'CLASubjectC1512233StLRHand.mat'; ...
    'CLASubjectD1511253StLRHand.mat'; ...
    'CLASubjectE1512253StLRHand.mat'; ...
    'CLASubjectE1601193StLRHand.mat'; ...
    'CLASubjectE1601223StLRHand.mat'; ...
    'CLASubjectF1509163StLRHand.mat'; ...
    'CLASubjectF1509173StLRHand.mat'
};

channelLabels = {
    'Fp1'; 'Fp2'; 'F3'; 'F4'; 'C3'; 'C4'; 'P3'; ...
    'P4'; 'O1'; 'O2'; 'A1'; 'A2'; 'F7'; 'F8'; ...
    'T3'; 'T4'; 'T5'; 'T6'; 'Fz'; 'Cz'; 'Pz'
};

runICA = false;
runAC = false;
runFilter = false;
shuffle = false;

desiredChannels = [5:6];
epochStart = 0.0;
epochEnd = 1;

trainingProportion = 0.8;

% Initiliasing global arrays

sequences = {};
responses = [];    

% Initialising EEGLAB and saving channel location coordinates to file
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;
%pop_chanedit(struct('labels', channelLabels))

% Iterating through files
for fileIndex = 1: height(files)
    fileName = files{fileIndex};
    disp(strcat("Processing file #", char(fileIndex), ": ", fileName))

    % Importing variables from file into MATLAB base workspace
    file = load(strcat('Data/', fileName), 'o').o;

    % Removing timing channel (i = 22)
    EEGMatrix = file.data(:, 1:21)';

    % Clearing the datasets in EEGLAB variables
    ALLEEG = [];
    eeglab redraw;

    % Import variable from MATLAB base workspace into EEGLAB variables with
    % channel locations from file in directory.
    EEG = pop_importdata('dataformat', 'array', 'nbchan', 0, 'data', ...
        'EEGMatrix', 'srate', file.sampFreq, 'pnts', 0, 'xmin', 0);
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 0, ...
        'setname','raw', 'gui','off');  
    chanLocsRef = {'channelLocations.ced', 'filetype', 'autodetect'};
    EEG = pop_chanedit(EEG, 'load', chanLocsRef , 'nosedir', '+Y');
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 1, 'overwrite', ...
        'on', 'gui', 'off');

    % Bandpass filter from 0.5 to 90 Hz
    EEG = pop_eegfiltnew(EEG, 'locutoff',0.5,'hicutoff', 90,'plotfreqz',0);
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 1, ...
        'overwrite','on','gui','off'); 

    % Artefact correction
    if runAC
        EEG = pop_clean_rawdata(EEG, 'FlatlineCriterion','off', ...
            'ChannelCriterion','off','LineNoiseCriterion','off', ...
            'Highpass','off','BurstCriterion',20,'WindowCriterion', ...
            'off','BurstRejection','off','Distance','Euclidian');
        [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 1, ...
            'overwrite','on','gui','off'); 
    end

    % Running Independent Component Analysis (ICA)
    if runICA
        EEG = pop_runica(EEG, 'icatype', 'runica', 'extended',1, ...
            'interrupt','on');
        [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 1, ...
            'overwrite','on','gui','off'); 
        compToRemove = setdiff([1:height(channelLabels)], desiredChannels)
        EEG = pop_subcomp( EEG, compToRemove, 0);
        [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 1, ...
            'overwrite','on','gui','off'); 
    end

    % Bandpass filter from 8 to 30 Hz
    if runFilter
        EEG = pop_eegfiltnew(EEG, 'locutoff',8,'hicutoff', ...
            30,'plotfreqz',0);
        [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 1, ...
            'overwrite','on','gui','off');
    end

    % Creating a schedule of events and exporting to csv file in directory
    h = height(file.marker);
    s = [file.marker, [1:h]'];
    s = s(s(:, 1) >= 1 & s(:, 1) <= 10, :);
    q = [];
    for i = 2:height(s)
        if s(i - 1, 1) ~= s(i, 1)
            q = [q; s(i, :)];
        end
    end
    q = sortrows(q, 2);
    r = q(:, 1)<3;
    q = q(r, :);
    t = table(q(:,1), q(:,2) / 200);
    t.Properties.VariableNames = {'type','latency'};
    writetable(t, 'events.csv')
    
    % Importing events from csv file in directory
    EEG = pop_importevent(EEG, 'append','no', 'event','events.csv', ...
        'fields',{'type','latency'}, 'skipline',1, 'timeunit',1);
    [ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);

    % Epoching events
    EEG = pop_epoch(EEG, { }, [epochStart epochEnd], 'newname', ...
        'all epochs', 'epochinfo', 'yes');
    [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);

    % Exporting epochs to a csv file in directory
    exportFileName = 'allEpochsExport.csv';

    [ALLEEG, EEG, CURRENTSET] = pop_newset( ...
        ALLEEG, EEG, 4, ...
        'retrieve',1, ...
        'study',0); 
    
    pop_export(EEG,exportFileName, 'transpose','on', 'elec','off', ...
        'separator',',', 'precision',4);

    % Importing epochs from csv file in directory to MATLAB base workspace
    epochedData = readmatrix(exportFileName);
    epochedData = epochedData(:, 2:end);
    epochedData = epochedData(:, desiredChannels);

    % Splitting continous matrix (all epochs combined) into list of 
    % matrices for each epoch.
    tempSequences = {};
    for i=1:height(q)
        dur = (epochEnd-epochStart) * file.sampFreq;
        lowerBound = 1+((i-1)*dur);
        upperBound = i*dur;
        epoch = epochedData(lowerBound:upperBound,:)';
        tempSequences = [tempSequences;epoch];
    end

    % Concatenating responses and sequences
    responses = [responses; categorical(q(:, 1))];
    sequences = [sequences; tempSequences];

    eeglab redraw;
end

% Randomising the dataset

if shuffle
    l = randperm(size(sequences, 1));
    sequences = sequences(l, :);
    responses = responses(l, :);
end

% Splitting the dataset

splitIndex = round(trainingProportion * height(responses),0);

dataset = struct( ...
    'training', struct( ...
        'sequences', {sequences(1:splitIndex)}, ...
        'responses', {responses(1:splitIndex)}), ...
    'testing', struct( ...
        'sequences', {sequences(splitIndex + 1:end)}, ...
        'responses', {responses(splitIndex + 1:end)}) ...
);
