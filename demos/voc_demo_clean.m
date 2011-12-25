%This is an Exemplar-SVM training demo
%We train one bus exemplar against 10 negative images, calibrate it
%with 5 in-class images, and test it on 5 in-class images
%Tomasz Malisiewicz (tomasz@cmu.edu)

%% Initialize dataset parameters
data_directory = '/Users/tmalisie/projects/Pascal_VOC/'
%data_directory = '/Users/tomasz/projects/Pascal_VOC/';
results_directory = '/nfs/baikal/tmalisie/esvm-data2/';
%data_directory = '/Users/tomasz/projects/pascal/VOCdevkit/';
%results_directory = '/nfs/baikal/tmalisie/esvm-toy/';
cls = 'bus';
dataset_params = get_voc_dataset('VOC2007',...
                                 data_directory,...
                                 results_directory);

CACHE_STREAM = 0;
CACHE_MODELS = 1;
CACHE_BETAS = 1;


%% Issue warning if lock files are present
lockfiles = check_for_lock_files(results_directory);
if length(lockfiles) > 0
  fprintf(1,'WARNING: %d lockfiles present in current directory\n', ...
          length(lockfiles));
end

%% Set exemplar-initialization parameters

%Initialize framing function
init_params.sbin = 8;
init_params.goal_ncells = 100;
init_params.MAXDIM = 12;
init_params.init_function = @esvm_initialize_goalsize_exemplar;
init_params.init_type = 'g'; 
dataset_params.init_params = init_params;

%Initialize exemplar stream
dataset_params.stream_set_name = 'trainval';
dataset_params.stream_max_ex = 1;
dataset_params.must_have_seg = 0;
dataset_params.must_have_seg_string = '';
dataset_params.model_type = 'exemplar';

%Choose a short string to indicate the name of the current experiment
dataset_params.models_name = ...
    [cls '-' init_params.init_type ...
     '.' dataset_params.model_type];


%Create an exemplar stream (list of exemplars)
e_stream_set = esvm_get_pascal_stream(dataset_params, cls, CACHE_STREAM);

%% Define parameters and training
%Create mining/validation/testing params as defaults
dataset_params.params = get_default_mining_params;
dataset_params.mining_params = dataset_params.params;
dataset_params.mining_params.training_function = @esvm_update_svm;
dataset_params.mining_params.NMS_OS = 1.0; %disable NMS
dataset_params.mining_params.MAXSCALE = 0.5;
dataset_params.mining_params.TOPK = 100;
dataset_params.mining_params.set_name = ['train-' cls];
neg_set = get_pascal_set(dataset_params, ...
                           dataset_params.mining_params.set_name);
neg_set = neg_set(1:5);

%% Exemplar initialization 
initial_models = esvm_initialize_exemplars(dataset_params, e_stream_set, ...
                                           dataset_params.init_params, ...
                                           dataset_params.models_name,...
                                           CACHE_MODELS);

%Append the nn-type string if we are in nn mode
if length(dataset_params.params.nnmode) > 0
  models_name = [models_name '-' dataset_params.params.nnmode];
end

%% Perform Exemplar-SVM training
models = esvm_train_exemplars(dataset_params, ...
                                initial_models, neg_set, ...
                              CACHE_MODELS);

%% Define validation set
dataset_params.val_params = dataset_params.params;
dataset_params.val_params.NMS_OS = 0.5;
dataset_params.val_params.set_name = ['trainval+' cls];;
val_set = get_pascal_set(dataset_params, ...
                         dataset_params.val_params.set_name);
val_set = val_set(1:5);
 
%% Apply trained exemplars on validation set
dataset_params.params = dataset_params.val_params;
dataset_params.params.gt_function = @get_pascal_anno_function;
val_grid = esvm_detect_imageset(dataset_params, models, val_set,...
                            dataset_params.val_params.set_name);


%% Perform both platt calibration and M-matrix estimation
M = esvm_perform_calibration(dataset_params, models, ...
                             val_grid, val_set, CACHE_BETAS);


%% Define test-set
dataset_params.test_params = dataset_params.params;
dataset_params.test_params.NMS_OS = 0.5;
dataset_params.test_params.set_name = ['test+' cls];
test_set = get_pascal_set(dataset_params, ...
                          dataset_params.test_params.set_name);
test_set = test_set(1:5);

%% Apply on test set
dataset_params.params = dataset_params.test_params;
test_grid = esvm_detect_imageset(dataset_params, models, test_set,...
                                 dataset_params.test_params.set_name);

%apply calibration matrix to test-set results
test_struct = esvm_apply_calibration(dataset_params, models, ...
                                     test_grid, M);

% %Show top hits from model 1
% bbs = cat(1,test_struct.unclipped_boxes{:});
% [aa,bb] = sort(bbs(:,end),'descend');
% bbs = bbs(bb,:);
% m = models{1};
% m.model.svbbs = bbs;
% m.model = rmfield(m.model,'svxs');
% m.train_set = test_set;
% figure(1)
% clf
% imagesc(get_sv_stack(m,4,4))
% axis image
% axis off
% title('Exemplar, w,  and top 16 detections');
% snapnow

% Perform evaluation which will print result files
% [results] = evaluate_pascal_voc_grid(dataset_params, ...
%                                      models, test_grid, ...
%                                      dataset_params.test_params.set_name, ...
%                                      test_struct);
%rc = results.corr;
% clear options
% options.format ='html';
% options.outputDir = [results_directory  '/www/'];
% publish('display_helper',options)

maxk = 2;
allbbs = show_top_dets(dataset_params, models, test_grid, ...
                       test_set, dataset_params.test_params.set_name, ...
                       test_struct, maxk);


