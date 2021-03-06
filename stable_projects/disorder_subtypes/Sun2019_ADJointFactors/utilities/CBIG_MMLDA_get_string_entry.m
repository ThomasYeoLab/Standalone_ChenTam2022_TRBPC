function cell_array = CBIG_MMLDA_get_string_entry(spreadsheet, phase, rid, viscode, fieldnames, phase_match, viscode_match)

% cell_array = CBIG_MMLDA_get_string_entry(spreadsheet, phase, rid, viscode, fieldnames, phase_match)
% 
% This function get string entries from ADNI spreadsheet.
%
% Input:
%   - spreadsheet   : csv file from ADNI dataset
%   - phase         : cell array of phase for subjects. Each cell contains 'ADNI1', 'ADNIGO' or ADNI2'.
%   - rid           : cell array of rid for subjects
%   - viscode       : For 'ADNI1' subjects, it is cell array of VISCODE, corrsponding to rid.
%                     For 'ADNIGO' or 'ADNI2' subjects, it is cell array of VISCODE2, corresponding to rid. 
%   - fieldnames    : cell array of column names that you want to get
%   - phase_match   : 1 (default) or 0. If phase_match == 0, this function will ignore "phase" input
%   - viscode_match : 1 (default) or 0. If viscode_match == 0, this function will ignore "viscode" input
%
% Output:
%   - cell_array        : N x M cell matrix, N is length of "rid", M is length of "fieldnames".
% 
% Example:
% spreadsheet = 'Cognitive_Tests/ADASSCORES.csv';
% phase = {'ADNI1', 'ADNI1'};
% rid = {'1412', '1411'};
% viscode = {'bl', 'm06'};
% fieldnames = {'EXAMDATE'};
% cell_array = CBIG_MMLDA_get_string_entry(spreadsheet, phase, rid, viscode, fieldnames)
%
% Written by Nanbo Sun and CBIG under MIT license: https://github.com/ThomasYeoLab/CBIG/blob/master/LICENSE.md

if nargin < 7
    viscode_match = 1;
end
if nargin < 6
    phase_match = 1;
end

% Check whether the length of rid is the same as viscode
if length(rid) ~= length(viscode) || length(rid) ~= length(phase)
    error('The length of rid is not the same as length of viscode or length of phase.')
end

% read spreadsheet into a table
t= readtable(spreadsheet);

% get the index of different fields
fields_ind = CBIG_MMLDA_find_cell_in_cell(fieldnames, t.Properties.VariableNames);

% find the corresponding fieldnames
cell_array = cell(length(rid), length(fieldnames));


for k = 1:length(rid)
    % find the table with the correct phase
    if phase_match == 1
        t_phase = t(strcmp(t.Phase, phase{k}), :);
    else
        t_phase = t;
    end
    
    % find the table with the same rid
    t_id = t_phase(strcmp(t_phase.RID, rid{k}), :);
    if isempty(t_id)
        cell_array(k, :) = repmat({'NaN'}, 1, length(fieldnames));
    else
        % find the table with the same viscode
        if viscode_match == 1
            if strcmp(phase{k}, 'ADNI1') || strcmp(phase{k}, 'ADNI3')
                t_id_viscode = t_id(strcmp(t_id.VISCODE, viscode{k}), :);
            elseif strcmp(phase{k}, 'ADNI2') || strcmp(phase{k}, 'ADNIGO')
                t_id_viscode = t_id(strcmp(t_id.VISCODE2, viscode{k}), :);
            end
        else 
            t_id_viscode = t_id;
        end
               
        if isempty(t_id_viscode)
            cell_array(k, :) = repmat({'NaN'}, 1, length(fieldnames));
        else
            % find corresponding fields in the table
            for j = 1:size(cell_array,2)
                if isempty(t_id_viscode{:,fields_ind(j)})
                    cell_array(k,j) = {'NaN'};
                else
                    cell_array(k,j) = table2cell(t_id_viscode(1,fields_ind(j)));
                end
            end
        end
    end
end


