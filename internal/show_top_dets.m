function allbbs = show_top_dets(dataset_params, models, grid, fg, set_name, ...
                                finalstruct, maxk, CACHE_FILES)
% Show the top detections for [models] where [grid] is the set of
% detections from the set [fg] with name [set_name] ('test' or 'trainval')
% finalstruct (which contains final boxes) is obtained from
% the function pool_exemplar_detections
%
% Tomasz Malisiewicz (tomasz@cmu.edu)

%Default exemplar-inpainting show mode
%SHOW_MODE = 1;

%Default segmentation show mode
%SHOW_MODE = 2;

%Mode to show 
%SHOW_MODE = 3;

suffix = '';

%maxk is the maximum number of top detections we display
if ~exist('maxk','var')
  maxk = 20;
  if strcmp(models{1}.cls,'bus')
    maxk = 100;
  end
end

final_boxes = finalstruct.unclipped_boxes;
final_maxos = finalstruct.final_maxos;

bbs = cat(1,final_boxes{:});
try
  imids = bbs(:,11);
catch
  imids = [];
end
moses = cat(1,final_maxos{:});

%% sort detections by score
try
  [aa,bb] = sort(bbs(:,end), 'descend');
catch
  aa = [];
  bb = [];
end

%% only good ones now!
%bb = bb(moses(bb)>.5);

if 0
  fprintf(1,'Only segmentation ones here\n');
  %% get ones with segmentation only
  ids = cellfun2(@(x)x.curid,models(bbs(bb,6)));
  %VOCinit
  has_seg = cellfun(@(x)fileexists(sprintf('%s/%s/SegmentationObject/%s.png',...
                                           dataset_params.datadir, ...
                                           dataset_params.dataset,x)),ids);
  bb = bb(find(has_seg));
  finalstruct.rc = finalstruct.rc(find(has_seg));
  suffix = '.seg';
end

if 0
  %% get ones with 3d model only
  ids = cellfun2(@(x)sprintf('%s.%d.png',x.curid,x.objectid),models(bbs(bb,6)));
  VOCinit
  
  extradir = '/nfs/hn22/tmalisie/ddip/renderings/';
  has_3d = cellfun(@(x)fileexists(sprintf('%s/%s.%d.chair-3d.png', ...
                                          extradir,...
                                          x.curid, ...
                                          x.objectid)),models(bbs(bb,6)));
  bb = bb(find(has_3d));
end

counter = 1;

for k = 1:maxk

  try
    corr = finalstruct.rc(k);
  catch
    corr = 0;
  end
  if 1 
    if counter > length(bb)
      break;
    end
    
    wwwdir = sprintf('%s/www/%s.%s%s/',dataset_params.localdir,...
                     set_name, ...
                     models{1}.models_name,finalstruct.calib_string);
    if ~exist(wwwdir,'dir') && exist('CACHE_FILES','var') && (CACHE_FILES == 1)
      mkdir(wwwdir);
    end
    
    filer = sprintf('%s/%05d%s.eps',wwwdir,k,suffix);
    filerlock = [filer '.lock'];
    if 0 %fileexists(filer) || (mymkdir_dist(filerlock) == 0)
      counter = counter + 1;
      continue
    end

    fprintf(1,'Top det %d\n', k);
    allbbs(k,:) = bbs(bb(counter),:);
    
    curb = bb(counter);
    curid = grid{imids(curb)}.curid;
    I = (convert_to_I(fg{bbs(bb(counter),11)}));
    
    TARGET_BUS = -1;

    if TARGET_BUS > 0
      gtrecs = PASreadrecord(sprintf(dataset_params.annopath,curid));
      businds = find(ismember({gtrecs.objects.class},{'bus'}) & ~[gtrecs.objects.difficult]);
      gtbbs = cat(1,gtrecs.objects.bbox);
      gtbbs = gtbbs(businds,:);
    else
      businds = [];
    end

    bbox = bbs(curb,:);

    if length(businds) > 0
      [alpha,beta] = max(getosmatrix_bb(gtbbs,bbox));
      TARGET_BUS = businds(beta);
    end
        
    if length(moses) > 0
      stuff.os = moses(curb);
    else
      stuff.os = 0;
    end
    stuff.score = bbs(curb,end);
    stuff.curid = curid;
    stuff.rank = counter;
   
    extra = '';
    
    if ismember(models{1}.models_name,{'dalal'})
      extra='-dalal';
    end

    estring = '';
    if exist('betas','var')
      estring = 'withbetas';
    end
    
    %ccc = bbox(6);
    
    %target_image_id = imids(bb(counter));
    %target_cluster_id = bbs(bb(counter),5);
            
    %USE THE RAW DETECTION
    fprintf(1,' -- Taking Final det score\n');
    allbb = bbs(bb(counter),:);
    
    %CVPR VERSION: use the top local score within a cluster
    %fprintf(1,' -- Finding within-cluster local max\n');
    % allbb = finalstruct.raw_boxes{target_image_id};
    % osmat = getosmatrix_bb(allbb,bbs(bb(counter),:));
    % goods = find(osmat>.5);
    % allbb = allbb(goods,:);
    % [alpha,beta] = sort(allbb(:,end),'descend');
    % allbb = allbb(beta,:);
    
    sumI = I*0;
    countI = zeros(size(I,1),size(I,2),1);
    %ooo = cell(0,1);
    
    %mean0 = mean(allbb,1);
    %curoses = getosmatrix_bb(mean0(1,:),allbb);
    
    stuff.I = I;
    stuff.dataset_params = dataset_params;
    
    clear overlays
    
    for zzz = 1:min(1,size(allbb,1))
      overlays{zzz} = exemplar_inpaint(allbb(zzz,:), ...
                                       models{allbb(zzz,6)}, ...
                                       stuff);
    end


    %sumI = sumI ./ repmat(countI,[1 1 3]);
    
    if TARGET_BUS > -1
      %% load GT for test 
      %gtfiles = dir(sprintf(['/nfs/baikal/tmalisie/buslabeling/' ...
      %                '%s*mat'],curid));
      gtmat = load(sprintf(['/nfs/baikal/tmalisie/finalbuslabeling/' ...
                    '%s.%d.mat'],curid,TARGET_BUS));
      seg = gtmat.res.seg;
      gtim = faces2colors(seg);
      
      shower = I;
      fg = repmat(double(seg~=0),[1 1 3]);
      
      shower(find(fg)) = shower(find(fg))*.0 + 1.0*gtim(find(fg));
      gtim = shower;
      gtim(repmat(seg==0,[1 1 3]))=0;
      
    else
      gtim = zeros(size(I,1),size(I,2));
    end
    
    figure(1)
    clf

    current_rank = k;
    NR = show_hits_figure_iccv(I,models,allbb, ...
                               overlays,current_rank, corr);
    axis image
    drawnow
    snapnow
    
    if exist('CACHE_FILES','var') && CACHE_FILES == 1
      print(gcf,'-depsc2',filer);
      finalfile = strrep(filer,'.eps','.pdf');
      unix(sprintf('ps2pdf -dEPSCrop -dPDFSETTINGS=/prepress %s %s',...
                   filer,finalfile));
      
      if fileexists(finalfile)
        unix(sprintf('rm %s',filer));
      end
      
      if exist(filerlock,'dir')
        rmdir(filerlock);
      end
    end
    
    %filer2 = filer;
    %filer2(end-2:end) = 'png';
    %print(gcf,'-dpng',filer2);
       
    counter = counter+1;    
  end
end
