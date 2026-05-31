%% 01_filter_taskwise.m
% Pipeline di Filtraggio Unità Motorie (MU) Task-Wise
% Descrizione: Il codice analizza le scariche delle MU estratte tramite decomposizione
% per i compiti motori concatenati (Pinch e Hand Closed). Applica un filtro basato
% su criteri neurofisiologici di scarica minima per trial, preservando la variabilità
% inter-trial (MU attive anche in un solo trial su due).

clear; clc;

%% ========================================================================
% 1. CONFIGURAZIONE INPUT E PARAMETRI
%% ========================================================================

infile = "C:\Users\Charlie XD\Documents\AAAUNIVERSITAAAAAAAAAAAA'\Tesi\Motoneuron_Synergies_Driven_Gesture_Prediction\data_conc_subj1_trial_1_10_13\signal_mov10_mov13_trial1_trial2_filt_for_muedit.mat_decomp";
load(infile, 'signal', 'parameters');

fs = signal.fsamp;
nGrid = numel(signal.Pulsetrain);

% --- Criteri di Selezione Neurofisiologica ---
minSpikesTrial = 15;  % Soglia minima di spike nel singolo trial (5s) per considerare la MU attiva
minFR = 0;            % Frequenza di scarica minima ammessa nella task (Hz) ridondante se messa a 0 
maxFR = 40;           % Frequenza di scarica massima ammessa nella task (Hz)
maxInstFR = 40;       % Soglia per la rimozione di spike anomali ravvicinati (fisiologicamente impossibili)
maxCoV_ISI = 0.50;    % Coefficiente di variazione dell'ISI (solo descrittivo)

%% ========================================================================
% 2. DEFINIZIONE DEI SEGMENTI TEMPORALI (TRIAL)
%% ========================================================================

mov10_trial1 = [1 9999];
mov10_trial2 = [10000 20599];
mov13_trial1 = [20600 30879];
mov13_trial2 = [30880 40719];

tasks(1).name = 'pinch';
tasks(1).segments = [mov10_trial1; mov10_trial2];

tasks(2).name = 'hand_closed';
tasks(2).segments = [mov13_trial1; mov13_trial2];

filtered = struct();
summaryRows = {};

%% ========================================================================
% 3. FILTRAGGIO TASK-WISE PER OGNI GRIGLIA
%% ========================================================================

for g = 1:nGrid
    if isempty(signal.Pulsetrain{g}), continue; end

    muCount = size(signal.Pulsetrain{g}, 1);
    keep_any = false(muCount, 1);

    for t = 1:numel(tasks)
        taskName = tasks(t).name;
        segs = tasks(t).segments;

        keep_task = false(muCount, 1);
        active_segment_count = zeros(muCount, 1);
        clean_discharges_task = cell(1, muCount);

        for mu = 1:muCount
            spk_original = sort(signal.Dischargetimes{g, mu}(:));
            allCleanSpikes = [];

            segNSpikes = nan(size(segs,1), 1);
            segFR = nan(size(segs,1), 1);
            segCoV = nan(size(segs,1), 1);
            segRemoved = zeros(size(segs,1), 1);
            segResults = strings(size(segs,1), 1);

            % Analisi separata dei singoli trial (segmenti)
            for s = 1:size(segs, 1)
                segStart = segs(s, 1);
                segEnd = segs(s, 2);
                segDuration = (segEnd - segStart + 1) / fs;

                % Estrazione degli spike nel segmento corrente
                spkSeg = spk_original(spk_original >= segStart & spk_original <= segEnd);
                spkSeg = sort(spkSeg(:));

                % Pulizia dagli artefatti (rimozione spike troppo ravvicinati)
                [spkSegClean, nRemoved] = remove_fast_spikes(spkSeg, fs, maxInstFR);

                nSpikesSeg = numel(spkSegClean);
                frSeg = nSpikesSeg / segDuration;

                % Calcolo del CoV ISI solo se vi sono abbastanza spike nel trial
                if nSpikesSeg >= minSpikesTrial
                    % 
                    ISI = diff(spkSegClean) / fs;
                    covSeg = std(ISI) / mean(ISI);
                    segResults(s) = sprintf("active_N%d", nSpikesSeg);
                else
                    covSeg = NaN;
                    segResults(s) = "silent";
                end

                if nRemoved > 0
                    segResults(s) = segResults(s) + sprintf("_removedFast%d", nRemoved);
                end

                segNSpikes(s) = nSpikesSeg;
                segFR(s) = frSeg;
                segCoV(s) = covSeg;
                segRemoved(s) = nRemoved;

                allCleanSpikes = [allCleanSpikes; spkSegClean(:)]; %#ok<AGROW>
            end

            % Analisi globale della Task concatenata
            allCleanSpikes = sort(allCleanSpikes);
            nSpikesTask = numel(allCleanSpikes);
            
            taskDuration = 0;
            for s = 1:size(segs, 1)
                taskDuration = taskDuration + (segs(s,2) - segs(s,1) + 1) / fs;
            end
            frTask = nSpikesTask / taskDuration;

            if nSpikesTask >= 3
                ISI_task = diff(allCleanSpikes) / fs;
                covTask = std(ISI_task) / mean(ISI_task);
            else
                covTask = NaN;
            end

            % Applicazione dei Criteri di Esclusione
            reasonsTask = strings(0);
            
            % Regola Fondamentale: La MU deve essere attiva (>=15 spike) in almeno uno dei due trial
            if ~(segNSpikes(1) >= minSpikesTrial || segNSpikes(2) >= minSpikesTrial)
                reasonsTask(end+1) = "few_spikes_in_both_trials";
            end

            if frTask < minFR,  reasonsTask(end+1) = "FR_low_task";  end
            if frTask > maxFR,  reasonsTask(end+1) = "FR_high_task"; end

            keep_task(mu) = isempty(reasonsTask);
            active_segment_count(mu) = sum(segNSpikes >= minSpikesTrial);
            clean_discharges_task{mu} = allCleanSpikes;

            if isempty(reasonsTask)
                taskReason = "kept";
            else
                taskReason = strjoin(reasonsTask, "+");
            end

            % Risultati
            summaryRows(end+1, :) = { ...
                g, mu, taskName, nSpikesTask, frTask, covTask, ...
                segNSpikes(1), segNSpikes(2), min(segNSpikes), max(segNSpikes), ...
                mean(segFR, 'omitnan'), max(segFR), sum(segRemoved), ...
                active_segment_count(mu), strjoin(segResults, " | "), ...
                taskReason, keep_task(mu)}; %#ok<SAGROW>
        end

        % Task Filtrata, risultati
        filtered(g).(taskName).keep = keep_task;
        filtered(g).(taskName).active_segment_count = active_segment_count;
        filtered(g).(taskName).clean_dischargetimes = clean_discharges_task;
        filtered(g).(taskName).Pulsetrain = signal.Pulsetrain{g}(keep_task, :);
        filtered(g).(taskName).Dischargetimes_clean = clean_discharges_task(keep_task);

        keep_any = keep_any | keep_task(:);
    end
    filtered(g).keep_any = keep_any;
    filtered(g).keep_any_idx = find(keep_any);
    filtered(g).Pulsetrain_any = signal.Pulsetrain{g}(keep_any, :);
end


%% ========================================================================
% 4. SAVE
%% ========================================================================

summary = cell2table(summaryRows, 'VariableNames', { ...
    'Grid', 'MU', 'Task', 'NSpikes_clean_task', 'FR_task_Hz', 'CoV_ISI_task', ...
    'NSpikes_trial1', 'NSpikes_trial2', 'MinSpikesTrial', 'MaxSpikesTrial', ...
    'MeanFR_trials_Hz', 'MaxTrialFR_Hz', 'RemovedFastSpikes', 'ActiveSegments', ...
    'SegmentActivity', 'TaskReason', 'Keep'});

save('01_decomp_filtered_taskwise.mat', 'signal', 'parameters', 'filtered', 'summary', ...
     'tasks', 'fs', 'minFR', 'maxFR', 'minSpikesTrial', 'maxCoV_ISI', 'maxInstFR', '-v7.3');
writetable(summary, '01_decomp_filtered_taskwise_fullfile.csv');

fprintf('\n=== KEPT MU PER GRID AND TASK ===\n');
for g = 1:max(summary.Grid)
    for t = unique(string(summary.Task))'
        idx = summary.Grid == g & string(summary.Task) == t;
        fprintf('Grid %d - %s: %d / %d MU kept\n', g, t, sum(summary.Keep(idx)), sum(idx));
    end
end

fprintf('\n=== ACTIVE IN ONE OR TWO TRIALS ===\n');
disp(groupsummary(summary(summary.Keep == true,:), ["Grid", "Task", "ActiveSegments"]));
disp('Salvati: 01_decomp_filtered_taskwise.mat / .csv');

% ========================================================================
% DIAGNOSTICA: REPORT RIMOZIONE SPIKE 
% ========================================================================
fprintf('\n=========================================================\n');
fprintf('        REPORT DIAGNOSTICO: RIMOZIONE SPIKE FAST\n');
fprintf('=========================================================\n');

idx_removed = summary.RemovedFastSpikes > 0;

if any(idx_removed)
    % Estraiamo solo le righe in cui il filtro ha effettivamente lavorato
    tbl_diagnostica = summary(idx_removed, {'Grid', 'MU', 'Task', 'NSpikes_clean_task', 'RemovedFastSpikes'});
    disp(tbl_diagnostica);
    
    total_removed = sum(summary.RemovedFastSpikes);
    total_spikes = sum(summary.NSpikes_clean_task) + total_removed;
    perc_removed = (total_removed / total_spikes) * 100;
    
    fprintf('-> Totale anomalie rimosse nel dataset: %d spike\n', total_removed);
    fprintf('-> Impatto sul dataset: %.3f%% degli spike totali eliminati.\n', perc_removed);
    fprintf('-> NOTA: Se l''impatto è basso (<1%%), il filtro agisce come "salvavita" isolato.\n');
else
    fprintf('Il filtro NON ha eliminato alcuno spike nell''intero dataset.\n');
    fprintf('Tutte le distanze tra spike consecutivi sono fisiologiche (> %d ms, cioè < %d Hz).\n', ...
        round(1000/maxInstFR), maxInstFR);
end
fprintf('=========================================================\n');

%% ========================================================================
% 5. ELENCO ID DELLE MU PER ISPEZIONE IN MUedit
%% ========================================================================

fprintf('\n=========================================================\n');
fprintf('        ELENCO ID DELLE MU SALVATE (RIFERIMENTO MUedit)\n');
fprintf('=========================================================\n');

grids = unique(summary.Grid);
tasks_list = unique(string(summary.Task))'; 

for g = grids'
    fprintf('\n GRIGLIA %d \n', g);
    for t = tasks_list
        idx_stable = (summary.Grid == g & string(summary.Task) == t & summary.Keep == true & summary.ActiveSegments == 2);
        mu_stable = summary.MU(idx_stable);
        
        idx_single = (summary.Grid == g & string(summary.Task) == t & summary.Keep == true & summary.ActiveSegments == 1);
        mu_single = summary.MU(idx_single);
        
        fprintf('  Movimento: %s\n', upper(t));
        fprintf('    ID MU Stabili (attive 2/2 trial) [%d unità]:\n      %s\n', numel(mu_stable), mat2str(mu_stable'));
        
        if ~isempty(mu_single)
            fprintf('    ID MU in un solo trial (attive 1/2) [%d unità]:\n      %s\n', numel(mu_single), mat2str(mu_single'));
        else
            fprintf('    ID MU in un solo trial (attive 1/2): Nessuna\n');
        end
        fprintf('  -------------------------------------------------------\n');
    end
end
fprintf('=========================================================\n');

%% ========================================================================
% FUNZIONI - rimozione spike
%% ========================================================================
function [spikesClean, nRemoved] = remove_fast_spikes(spikes, fs, maxInstFR)
    spikesClean = sort(spikes(:));
    nRemoved = 0;
    if numel(spikesClean) < 2, return; end

    minISI_samples = round(fs / maxInstFR);
    changed = true;
    
    while changed
        changed = false;
        isi_samples = diff(spikesClean);
        badIdx = find(isi_samples < minISI_samples, 1, 'first');

        if ~isempty(badIdx)
            spikesClean(badIdx + 1) = [];
            nRemoved = nRemoved + 1;
            changed = true;
        end
    end
end