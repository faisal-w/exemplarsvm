function [models,results] = learnDT(cls, data_set, test_set, params, ...
                            results_directory)
% Learn a DalalTriggs template detector
% Copyright (C) 2011-12 by Tomasz Malisiewicz
% All rights reserved. 
%
% This file is part of the Exemplar-SVM library and is made
% available under the terms of the MIT license (see COPYING file).
% Project homepage: https://github.com/quantombone/exemplarsvm

addpath(genpath(pwd));

if ~exist('cls','var')
  error('Needs class as input');
end

data_directory = '/Users/tomasz/projects/pascal/';
dataset_directory = 'VOC2007';
%data_directory = '/csail/vision-videolabelme/databases/';
%data_directory = '/csail/vision-videolabelme/people/tomasz/VOCdevkit/';

if ~exist('data_set','var')
  load(sprintf('%s/%s/trainval.mat',...
               data_directory, dataset_directory),'data_set');
end

if ~exist('params','var')
  %% Get default parameters
  params = esvm_get_default_params;
  params.display = 1;  
  params.dump_images = 1;
  params.detect_max_scale = 0.5;
  params.detect_exemplar_nms_os_threshold = 1.0; 
  params.detect_max_windows_per_exemplar = 100;
  params.train_max_negatives_in_cache = 5000;
  params.train_max_mined_images = 500;
  params.latent_iterations = 2;
  % for dalaltriggs, it seams having same constant on positives as
  % negatives is better than using 50
  params.train_positives_constant = 1;
  params.detect_pyramid_padding = 0;
end

if ~exist('results_directory','var')
  results_directory = '/nfs/baikal/tmalisie/esvm-dt/';
end

params.localdir = ''; %results_directory;

%% Issue warning if lock files are present
% lockfiles = check_for_lock_files(results_directory);
% if length(lockfiles) > 0
%   fprintf(1,'WARNING: %d lockfiles present in current directory\n', ...
%           length(lockfiles));
% end

% KILL_LOCKS = 1;
% for i = 1:length(lockfiles)
%   unix(sprintf('rmdir %s',lockfiles{i}));
% end

models = esvm_initialize_dt(data_set, cls, params);
models = esvm_train(models);

for niter = 1:params.latent_iterations
  models = esvm_latent_update_dt(models);
  models = esvm_train(models);
end

%% Perform Platt calibration and M-matrix estimation
%M = esvm_perform_calibration(val_grid, val_set, models,val_params);

%% Apply trained exemplars on validation set
%val_grid = esvm_detect_imageset(val_set, models, val_params, val_set_name);
                       
%% Define test-set
test_params = params;
test_params.detect_exemplar_nms_os_threshold = 1.0;
test_params.detect_max_windows_per_exemplar = 500;
test_params.detect_keep_threshold = -2.0;

test_set = load(sprintf('%s/%s/trainval.mat',...
             data_directory, dataset_directory),'data_set');
test_set = test_set.data_set;

test_set = get_objects_set(test_set, cls);
test_set_name = ['trainval+' cls];

%% Apply on test set
test_grid = esvm_detect_imageset(test_set, models, test_params, test_set_name);

%% Apply calibration matrix to test-set results
test_struct = esvm_pool_exemplar_dets(test_grid, models, [], ...
                                      test_params);

%% Perform the exemplar evaluation
results = esvm_evaluate_pascal_voc(test_struct, test_set, models, params, ...
                                     test_set_name);

if params.display
  for mind = 1:length(models)
    I = esvm_show_top_exemplar_dets(test_struct, test_set, ...
                                    models, mind,10,10);
    figure(45)
    imagesc(I)
    title('Top detections');
    drawnow
    snapnow
    
    if params.dump_images == 1 && length(params.localdir)>0
      filer = sprintf('%s/results/topdet.%s-%04d-%s.png',...
                      results_directory, models{mind}.models_name, mind, test_set_name);
      
      imwrite(I,filer);
    end 
  end
end

% return;

% %NOTE: the show_top_dets functions doesn't even work for dalaltriggs (but we can apply NN
% %hack! if we want to)


% %% Show top 20 detections as exemplar-inpainting results
% maxk = 20;
% allbbs = esvm_show_top_dets(test_struct, test_grid, test_set, models, ...
%                             params,  maxk, test_set_name);

