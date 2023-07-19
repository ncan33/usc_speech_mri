function Image = SVD_recon(Data,para)
disp('Performing iterative STCR reconstruction...');
disp('Showing progress...')

ifplot         = para.setting.ifplot;
ifGPU          = para.setting.ifGPU;
weight_tTV     = para.Recon.weight_tTV;
weight_sTV     = para.Recon.weight_sTV;
beta_sqrd      = para.Recon.epsilon;
para.Recon.step_size = para.Recon.step_size(1);

%{
%lambda_vbm4d   = para.vbm4d;
%lambda_new    = para.recon.low_rank;
%bloc_x = 32;
%bloc_y = 32;
%tau = (0.01/5)*bloc_x;
%lambda_new = para.Recon.low_rank;
% VBM4D params

% intensity range of the video
%profile = 'np';      % V-BM4D parameter profile
%  'lc' --> low complexity
%  'np' --> normal profile
%do_wiener = 1;       % Wiener filtering
%   1 --> enable Wiener filtering
%   0 --> disable Wiener filtering
%sharpen = 1;         % Sharpening
%   1 --> disable sharpening
%  >1 --> enable sharpening
%deflicker = 1;       % Deflickering
%   1 --> disable deflickering
%  <1 --> enable deflickering
%verbose = 0;         % Verbose mode
%p_sigma     = 1;      % Noise standard deviation. it should be in the same
%}
if isfield(para.Recon,'RF_frames')
    if sum(para.Recon.RF_frames)~=0
        RF_frames = para.Recon.RF_frames;
        PD_frames = para.Recon.PD_frames;
        Data.first_est = Data.first_est(:,:,RF_frames,:,:);
        Data.kSpace = Data.kSpace(:,:,RF_frames,:,:,:,:);
        if isfield(Data,'mask')
            Data.mask = Data.mask(:,:,RF_frames,:,:,:,:);
        end
        if isfield(Data,'phase_mod')
            Data.phase_mod = Data.phase_mod(:,:,RF_frames,:,:,:,:);
        end
        if isfield(Data,'N')
            if PD_frames(end) == 0
                PD_frames = 1:sum(PD_frames);
            end
            Data.N.S = Data.N.S(Data.N.sx_over.^2*PD_frames(end)+1:end,Data.N.siz(1)*Data.N.siz(2)*PD_frames(end)+1:end);
            Data.N.siz(3) = size(Data.first_est,3);
            %        Data.N.W = Data.N.W(:,:,RF_frames);
        end
    else
        Image = [];
        return
    end
elseif isfield(para.Recon,'PD_frames') && sum(para.Recon.PD_frames) == length(para.Recon.PD_frames)
    Image = [];
    return
end

if isfield(Data,'first_guess')
    new_img_x = Data.first_guess;   
else
    new_img_x = single(Data.first_est);
end

if isfield(Data,'phase_mod')
    Data.phase_mod_conj = conj(single(Data.phase_mod));
end

if isfield(Data,'sens_map')
    Data.sens_map_conj = conj(Data.sens_map);
end

if ifGPU
    Data.kSpace        = gpuArray(Data.kSpace);
    new_img_x          = gpuArray(new_img_x);
    Data.sens_map      = gpuArray(Data.sens_map);
    Data.sens_map_conj = gpuArray(Data.sens_map_conj);
    if isfield(Data,'mask')
        Data.mask          = gpuArray(Data.mask);
    end
    if isfield(Data,'filter')
        Data.filter        = gpuArray(Data.filter);
    end
%    Data.first_est = gpuArray(Data.first_est);
%    Data.phase_mod = gpuArray(Data.phase_mod);
%    Data.phase_mod_conj = gpuArray(Data.phase_mod_conj);
    beta_sqrd = gpuArray(beta_sqrd);
    if isfield(Data,'N')
        for i=1:length(Data.N)
            Data.N(i).S = gpuArray(Data.N(i).S);
            Data.N(i).Apodizer = gpuArray(Data.N(i).Apodizer);
            Data.N(i).W = gpuArray(Data.N(i).W);
        end
    end
    
    gpuInfo = gpuDevice;
    gpuSize = gpuInfo.AvailableMemory;
    imSize  = numel(new_img_x)*8;
%     if imSize*para.Recon.no_comp > gpuSize*0.3
        %para.Recon.type = [para.Recon.type,' less memory'];
%     end
end

para.Cost = struct('fidelityNorm',[],'temporalNorm',[],'spatialNorm',[],'totalCost',[]);
%new_img_x = new_img_x./Data.map;

fidelity = @(im) compute_fidelity_yt_new(im,Data,para);
spatial  = @(im) compute_sTV_yt(im,weight_sTV,beta_sqrd);
temporal = @(im) compute_tTV_yt(im,weight_tTV,beta_sqrd);
keyboard


nof = size(new_img_x,3);
im_temp = reshape(new_img_x,para.Recon.sx^2,nof,para.Recon.nSMS);
Rank = 45;
new_img_x(:,:,Rank+1:end,:,:) = [];
v_all = zeros(nof,Rank,para.Recon.nSMS,'like',new_img_x);
for i=1:para.Recon.nSMS
    [~,~,v_temp] = svd(im_temp(:,:,i),0);
    v_temp = v_temp(:,1:Rank);
    v_all(:,:,i) = v_temp;
    new_img_x(:,:,:,1,i) = reshape(im_temp(:,:,i)*v_temp,para.Recon.sx,para.Recon.sx,Rank);
end

%%% fidelity
for n = 1:100
    n
    fidelity_update_all = zeros(size(new_img_x),class(new_img_x));
    for i=1:para.Recon.no_comp
        fidelity_update = new_img_x.*Data.sens_map(:,:,:,i,:,:);
        fidelity_update = fft2(fidelity_update);
        fidelity_update = reshape(fidelity_update,[para.Recon.sx^2,Rank,para.Recon.nSMS]);
        fidelity_update_full = zeros([para.Recon.sx^2,nof,para.Recon.nSMS],'like',fidelity_update);
        for j=1:para.Recon.nSMS
            fidelity_update_full(:,:,j) = fidelity_update(:,:,j)*v_all(:,:,j)';
        end
        fidelity_update_full = reshape(fidelity_update_full,[para.Recon.sx,para.Recon.sx,nof,1,para.Recon.nSMS]);
        fidelity_update_full = sum(fidelity_update_full.*Data.SMS,5);
        fidelity_update_temp = zeros([para.Recon.sx,para.Recon.sx,nof,1,para.Recon.nSMS],class(fidelity_update_full));
        fidelity_update_full = fidelity_update_full(Data.mask);
        fidelity_update_full = Data.kSpace(:,i) - fidelity_update_full;
        fidelity_update_temp(Data.mask) = fidelity_update_full;
        fidelity_update_full = fidelity_update_temp;clear fidelity_update_temp
        fidelity_update_full = sum(fidelity_update_full.*conj(Data.SMS),7);
        if isfield(Data,'filter')
            fidelity_update_full = bsxfun(@times,fidelity_update_full,Data.filter);
        end
        fidelity_update_full = reshape(fidelity_update_full,[para.Recon.sx^2,nof,para.Recon.nSMS]);
        for j=1:para.Recon.nSMS
            fidelity_update(:,:,j) = fidelity_update_full(:,:,j)*v_all(:,:,j);
        end
        fidelity_update = reshape(fidelity_update,[para.Recon.sx,para.Recon.sx,Rank,1,para.Recon.nSMS]);
        fidelity_update = ifft2(fidelity_update);
        fidelity_update_all = fidelity_update_all + bsxfun(@times,fidelity_update,Data.sens_map_conj(:,:,:,i,:,:));
    end
    new_img_x = new_img_x + 0.1*fidelity_update_all;
    new_img_x = reshape(new_img_x,para.Recon.sx^2,Rank,para.Recon.nSMS);
    %v_all = zeros(nof,Rank,para.Recon.nSMS,'like',new_img_x);
    for j=1:para.Recon.nSMS
        im_temp(:,:,j) = new_img_x(:,:,j)*v_all(:,:,j)';
    end
    im_temp = reshape(im_temp,[para.Recon.sx,para.Recon.sx,nof,para.Recon.nSMS]);
    im_temp = im_temp + compute_sTV_yt(im_temp,weight_sTV,beta_sqrd) + compute_tTV_yt(im_temp,weight_tTV,beta_sqrd);
    im_temp = reshape(im_temp,[para.Recon.sx^2,nof,para.Recon.nSMS]);
    new_img_x = reshape(new_img_x,[para.Recon.sx,para.Recon.sx,Rank,1,para.Recon.nSMS]);
    for j=1:para.Recon.nSMS
        [~,~,v_temp] = svd(im_temp(:,:,j),0);
        v_temp = v_temp(:,1:Rank);
        v_all(:,:,j) = v_temp;
        new_img_x(:,:,:,1,j) = reshape(im_temp(:,:,j)*v_temp,para.Recon.sx,para.Recon.sx,Rank);
    end
    
    figure(1)
    imagesc(abs(new_img_x(:,:,1,1)))
    axis image
    drawnow
    figure(2)
    plot(abs(v_all(:,1,1)))
    drawnow
end
clear im
for i=1:para.Recon.nSMS
    im(:,:,i) = reshape(new_img_x(:,:,:,:,i),[para.Recon.sx^2,Rank])*v_all(:,:,j)';
end
im = reshape(im,[para.Recon.sx,para.Recon.sx,nof,para.Recon.nSMS]);






for iter_no = 1:para.Recon.noi

    if mod(iter_no,10) == 1
        t1 = tic;
    end

%%%%% fidelity term/temporal/spatial TV

    tic; 
    [update_term,fidelity_norm] = fidelity(new_img_x);
    para.CPUtime.fidelity(iter_no) = toc;
    
    tic;
    update_term = update_term + temporal(new_img_x)*.75;
    para.CPUtime.tTV(iter_no) = toc;
    
    tic;
    update_term = update_term + spatial(new_img_x);
    para.CPUtime.sTV(iter_no) = toc;
    %update_term = update_term + (LowRank_yt(new_img_x) - new_img_x)*0.1;
    if isfield(para.Recon,'bins')
        update_term = update_term + compute_tTV_bins(new_img_x,weight_tTV,beta_sqrd,para.Recon.bins)*.75;
    end

%%%%% conjugate gradient
    tic;
    if iter_no > 1
        beta = update_term(:)'*update_term(:)/(update_term_old(:)'*update_term_old(:)+eps('single'));
        update_term = update_term + beta*update_term_old;
    end
    update_term_old = update_term; clear update_term
    
%%%%% line search    
    
    %fidelity_update = compute_fidelity_for_line_search_yt(new_img_x,Data,para);
    
    para.Cost = Cost_STCR(fidelity_norm, new_img_x, weight_sTV, weight_tTV, para.Cost); clear fidelity_update
    step_size = line_search(new_img_x,update_term_old,Data,para);
    para.Recon.step_size(iter_no) = step_size;

    new_img_x = new_img_x + step_size * update_term_old;
    para.CPUtime.update(iter_no) = toc;
%{
%%%%% VBM4D

    tic;
    if(lambda_vbm4d~=0)
        vbm4d_term_update = VBM4D_ye(new_img_x);
        new_img_x = new_img_x + lambda_vbm4d*(vbm4d_term_update-new_img_x);
    end
    para.CPUtime.VBM4D(iter_no) = toc;
 
%%%%% Low Rank

    if lambda_new~=0
        for i=1:size(new_img_x,5)
            lr_update(:,:,:,:,i) = low_rank_yt(new_img_x(:,:,:,:,i),bloc_x,bloc_y,tau);
        end

        new_img_x = new_img_x + lambda_new * (lr_update - new_img_x);
        clear lr_update
    end
%}
%%%%% plot&save part 

    if ifplot == 1
        showImage(new_img_x,para.Cost)
    end

%%%%% break when step size too small or cost not changing too much

    if para.Recon.break && iter_no > 1
        if step_size<1e-4 %|| abs(para.Cost.totalCost(end) - para.Cost.totalCost(end-1))/para.Cost.totalCost(end-1) < 1e-4
            break
        end
    end
    
    if mod(iter_no,10) == 0
        fprintf(['Iteration = ' num2str(iter_no) '...']);
        toc(t1);
    end
end

Image = squeeze(gather(new_img_x));
para = get_CPU_time(para);
fprintf(['Iterative STCR running time is ' num2str(para.CPUtime.interative_recon) 's' '\n'])