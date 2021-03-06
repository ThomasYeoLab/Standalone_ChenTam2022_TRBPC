function [ acc_corr_train, acc_corr_test, y_predict] = ...
    CBIG_TRBPC_LRR_fitrlinear_workflow_parallel_folds( params, behav_ind, start_fold, fold_num )

% [ acc_corr_train, acc_corr_test, y_predict] = ...
%    CBIG_TRBPC_LRR_fitrlinear_workflow_parallel_folds( params, behav_ind, start_fold, fold_num )
%
% This function is an adaptation to the CBIG_LRR_fitrlinear_workflow_1measure in
% CBIG_repo. There are two modifications:
% 1) The target variable can be a matrix and you need to specify which
% column in the matrix you want to predict
% 2) Instead of looping through all the cross-validation folds, ths
% function only loop through part of the cross-validation folds defined by
% `start_fold` and `fold_num`
% 
% Inputs:
%   params is a struct containing the following fields:
%   - params.sub_fold (compulsory)
%     A structure containing the information of how the data are separated
%     into training and test sets. 
%     params.sub_fold(i).fold_index is a #subjects x 1 binary vector. 1
%     refers to the corresponding subject is a test subject in the i-th
%     test fold. 0 refers to the corresponding subject is a training
%     subject in the i-th test fold.
% 
%   - params.FC_mat (compulsory)
%     A matrix of the features used as the independent variable in the
%     prediction. It can be a 2-D matrix with dimension of #features x
%     #subjects or a 3-D matrix with dimension of #ROIs1 x #ROIs2 x
%     #subjects. If params.FC_mat is 3-D, it is a connectivity matrix
%     between two sets of ROIs, and only the lower-triangular off-diagonal
%     entries will be considered as features because the connectivity
%     matrix is symmetric.
% 
%   - params.covariates (compulsory)
%     A matrix of the covariates to be regressed out from y (dimension:
%     #subjects x #regressors).
%     If the users only want to demean, an empty matrix should be passed in
%     ; if the users do not want to regress anything, set params.covariates
%     = 'NONE'.
% 
%   - params.y (compulsory)
%     A matrix of the target variables to be predicted (dimension:
%     #subjects x #target variables).
% 
%   - params.num_inner_folds (optional)
%     A string or a scalar. The number of inner-loop folds within each
%     training fold for hyperparameter selection.
%     If params does not have a field called num_inner_folds, this script
%     uses the same number of outer-loop folds as the number of inner-loop
%     folds.
% 
%   - params.outdir (compulsory)
%     A string of the full-path output directory.
% 
%   - params.outstem (compulsory)
%     A string appended to the filename to specify the output files (y
%     after regression, accuracy files, ...). For example, if outstem =
%     'AngAffect_Unadj', then the final optimal accuracy file will be names 
%     as
%     fullfile(outdir, 'results', 'optimal_acc', 'AngAffect_Unadj.mat'),
%     and the optimal model hyperparameters of k-th fold will be saved in
%     fullfile(outdir, 'params', ['dis_' k '_cv'], ...
%     'selected_parameters_AngAffect_Unadj.mat').
% 
%   - params.gpso_dir (optional)
%     A string, the full path of the directory to store the cloned git
%     repository for Gaussian process code. Current script needs the
%     Gaussian-Process Surrogate Optimisation (GPSO;
%     https://github.com/jhadida/gpso) package to optimize the objective
%     function. This git repository and its dependency "deck"
%     (https://github.com/jhadida/deck) need to be both cloned into the
%     same folder, which is passed into current script through
%     params.gpso_dir.
%     Default is
%     $CBIG_CODE_DIR/external_packages/matlab/non_default_packages/Gaussian_Process
% 
%   - params.domain (optional)
%     The searching domain of parameters used by the Gaussian process
%     optimization algorithm (dimension: #hyperparameters x 2). Default is
%     [0.001 0.1; 3 8], where 0.001-0.1 is the searching domain for the
%     feature selection threshold, and 3-8 is the searching domain for the
%     L2 regularization hyperparameter (after taking logarithm). For more
%     information, please refer to: https://github.com/jhadida/gpso
% 
%   - params.eval (optional)
%     The maximal evaluation times of the objective function (a scalar).
%     Default is 15. If it is too large, the runtime would be too long; if
%     it is too small, the objective function may not be able to reach its
%     optimal value. The users need to consider this trade-off when setting
%     this variable. For more information, please refer to: 
%     https://github.com/jhadida/gpso
% 
%   - params.tree (optional)
%     A scalar, the depth of the partition tree used to explore
%     hyperparameters. Default is 3. For more information, please refer to:
%     https://github.com/jhadida/gpso
%
%   - params.metric (optional)
%     A string, specifying how the value of lambda will be optimised with.
%     Can choose the following: corr, COD, predictive_COD, MAE,
%     MAE_norm,MSE,MSE_norm. Default: predictive_COD
%
%   - behav_ind
%     The behavior index you want to predict.param.y(:,behav_ind) will be
%     predicted
%
%   - fold_start
%     A scalar ranging from 1 to length(param.sub_fold). The function only
%     do the prediction for cross-validation folds from folder_start to
%     fold_start+fold_number-1
%
%   - fold_number
%     A scalar. See fold_start.
%
%  output (saved)
%   - acc_corr_train - training accuracy (given in correlation)
%   - acc_corr_test - test accuracies (given in correlation)
%   - y_predict - predicted target values
%   - optimal_statistics - a cell array of size equal to the number of
%   folds. Each element in the cell array is a structure storing the
%   accuracies of each possible accuracy metric (eg. corr, MAE, etc).
% 
% Written by Jianzhong Chen and CBIG under MIT license: https://github.com/ThomasYeoLab/CBIG/blob/master/LICENSE.md

%% check if submodules are correctly setup
if(~isfield(params, 'gpso_dir'))
    params.gpso_dir = fullfile(getenv('CBIG_CODE_DIR'), 'external_packages', 'matlab', ...
        'non_default_packages', 'Gaussian_Process');
end
gpso_info = dir(fullfile(params.gpso_dir, 'deck'));
if(isempty(setdiff({gpso_info.name}, {'.', '..'})))
    curr_dir = pwd;
    cd(getenv('CBIG_CODE_DIR'))
    command = sprintf('git submodule update --init --recursive');
    system(command);
    cd(curr_dir)
end

addpath(fullfile(params.gpso_dir, 'gpso'))
addpath(fullfile(params.gpso_dir, 'deck'))
dk_startup();

%% Preparation
if(~isfield(params, 'num_inner_folds'))
    params.num_inner_folds = length(params.sub_fold);
end

if(~isfield(params, 'domain'))
    params.domain = [0.001 0.1; 3 8];
end

if(~isfield(params, 'eval'))
    params.eval = 15;
end

if(~isfield(params, 'tree'))
    params.tree = 3;
end


if(~isfield(params, 'metric'))
    params.metric = 'predictive_COD';
end

params.outdir = fullfile(params.outdir,['behav_' num2str(behav_ind)]);
params.y = params.y(:,behav_ind);

%% step 1. Regress covariates from y
fprintf('# step 1: regress covariates from y for each fold.\n')
CBIG_crossvalid_regress_covariates_from_y( ...
    params.y, params.covariates, params.sub_fold, params.outdir, params.outstem);

%% step2. For each fold, use Gaussian process to optimize the linear ridge regression model
param_dir = [params.outdir '/params'];
fprintf('# step 2: optimize linear ridge regression model and predict target measure.\n')
fprintf('# Evaluations of GP: %d; depth: %d\n', params.eval, params.tree);
y_predict = cell(length(params.sub_fold), 1);
acc_corr_test = zeros(length(params.sub_fold), 1);
for currfold = start_fold:start_fold+fold_num-1
    curr_param_dir = fullfile(param_dir, ['/fold_' num2str(currfold)]);
    if(~exist(curr_param_dir, 'dir'))
        mkdir(curr_param_dir)
    end
    fprintf('=========================== Fold %d ===========================\n', currfold)
    
    load(fullfile(params.outdir, 'y', ['fold_' num2str(currfold)], ['y_regress_' params.outstem '.mat']))
    y_train = y_resid(params.sub_fold(currfold).fold_index==0);
    y_test = y_resid(params.sub_fold(currfold).fold_index==1);
    
    if(ndims(params.FC_mat) == 3)
        FC_train = params.FC_mat(:,:, params.sub_fold(currfold).fold_index==0);
        FC_test = params.FC_mat(:,:, params.sub_fold(currfold).fold_index==1);
    else
        FC_train = params.FC_mat(:, params.sub_fold(currfold).fold_index==0);
        FC_test = params.FC_mat(:, params.sub_fold(currfold).fold_index==1);
    end
    
    %% step 2.1. select hyperparameters: feature selection & inner-loop CV using GPSO
    param_file = fullfile(curr_param_dir, ['selected_parameters_' params.outstem '.mat']);
    if(~exist(param_file, 'file'))
        objfun = @(parameters) select_hyperparameter( FC_train, FC_test, y_train, ...
            parameters, params.num_inner_folds, params.metric );
        obj = GPSO();
        output =  obj.run(objfun, params.domain, params.eval, 'tree', params.tree);
        curr_threshold = output.sol.x(1);
        curr_lambda = 10^output.sol.x(2);
        save(param_file, 'curr_threshold', 'curr_lambda')
        
        curr_acc_train = output.sol.f;
        save([curr_param_dir '/acc_train_' params.outstem '.mat'], 'curr_acc_train');
    else
        load(param_file)
        if(~exist([curr_param_dir '/acc_train_' params.outstem '.mat'], 'file'))
            curr_acc_train = select_hyperparameter( FC_train, FC_test, y_train, ...
                [curr_threshold log10(curr_lambda)], params.num_inner_folds );
        else
            load([curr_param_dir '/acc_train_' params.outstem '.mat'])
        end
    end
    opt_threshold(currfold, 1) = curr_threshold;
    opt_lambda(currfold, 1) = curr_lambda;
    acc_corr_train(currfold, 1) = curr_acc_train;
    fprintf('>>> Current optimal feature selection threshold: %f, optimal lambda: %f, training accuracy: %f\n', ...
        opt_threshold(currfold), opt_lambda(currfold), acc_corr_train(currfold));
    
    %% Training & test
    fprintf('Test fold %d:\n', currfold);
    
    [feat_train, feat_test] = CBIG_FC_FeatSel( FC_train, FC_test, y_train, curr_threshold );
    [acc_corr, opt_stats,y_pred,pred_train] = ...
        CBIG_LRR_fitrlinear_train_test( feat_train', feat_test', y_train, y_test, curr_lambda, params.metric );
    save([curr_param_dir '/opt_results_' params.outstem '.mat'], 'acc_corr', 'opt_stats','y_pred','pred_train');
    acc_corr_test(currfold, 1) = acc_corr;
    clear acc_corr
end

rmpath(fullfile(params.gpso_dir, 'gpso'))
rmpath(fullfile(params.gpso_dir, 'deck'))

end


function out = select_hyperparameter( FC_train, FC_test, y_train, parameters, tot_folds, metric )

FS_threshold = parameters(1);
lambda = 10^parameters(2);

fprintf('Feature seletion threshold: %f, lambda: %f ...\n', FS_threshold, lambda);

[feat_train, ~] = CBIG_FC_FeatSel( FC_train, FC_test, y_train, FS_threshold );
[acc_corr] = CBIG_LRR_fitrlinear_innerloop_cv( feat_train', y_train, lambda, tot_folds, metric );
out = acc_corr;

end