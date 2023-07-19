function [im_recon,Ux] = LRT_recon_SMS(Data,Phi)
% Phi = gpuArray(Phi);
% Data.sens_map = gpuArray(Data.sens_map);
% Data.first_est = gpuArray(Data.first_est);
% Data.kSpace = gpuArray(Data.kSpace);
% Data.mask = gpuArray(Data.mask);

nof = size(Phi,2);
nl0 = size(Phi,1);
sx = size(Data.first_est,1);
no_comp = size(Data.kSpace,4);
nSMS = size(Phi,3);

mask = sum(Data.mask,7);
mask(mask==0) = 1;
mask = 1./mask;

for i=1:nSMS
    Phi_pinv(:,:,i) = pinv(Phi(:,:,i));
    Ux(:,:,i) = reshape(Data.first_est(:,:,:,1,i),sx^2,nof)*Phi_pinv(:,:,i);
end
Ux = reshape(Ux,[sx,sx,nl0,1,nSMS]);
weight = 0.001*max(max(abs(Ux)));

for i=1:15
    i
    fidelity = fft2(Ux.*Data.sens_map);
    fidelity = permute(fidelity,[1,2,4,3,5]);
    fidelity = reshape(fidelity,[sx*sx*no_comp,nl0,nSMS]);
    for j=1:nSMS
        fidelity(:,1:nof,j) = fidelity(:,1:nl0,j)*Phi(:,:,j);
    end
    fidelity = reshape(fidelity,sx,sx,no_comp,nof,nSMS);
    fidelity = permute(fidelity,[1,2,4,3,5]);
    fidelity = sum(fidelity.*Data.SMS,5);
    fidelity = Data.kSpace - fidelity;
    fidelity = fidelity.*Data.mask;
    fnorm(i) = sum(abs(fidelity(:)));
    fidelity = sum(fidelity.*conj(Data.SMS),7);
    fidelity = fidelity.*mask;
    fidelity = permute(fidelity,[1,2,4,3,5]);
    fidelity = reshape(fidelity,[sx*sx*no_comp,nof,nSMS]);
    for j=1:nSMS
        fidelity(:,1:nl0,j) = fidelity(:,:,j)*Phi_pinv(:,:,j);
    end
    fidelity(:,nl0+1:end,:) = [];
    fidelity = reshape(fidelity,[sx,sx,no_comp,nl0,nSMS]);
    fidelity = permute(fidelity,[1,2,4,3,5]);
    fidelity = ifft2(fidelity);
    fidelity = fidelity.*conj(Data.sens_map);
    fidelity = sum(fidelity,4);
    
    %stv = weight.*compute_sTV_yt(Ux,1,1e-14);
    Ux = Ux + fidelity;
    
    figure(1)
    im = abs(Ux(:,:,1,:));
    imagesc(im(:,:))
    axis image
    drawnow
    figure(2)
    plot(fnorm)
    drawnow
end

for i=1:nSMS
    im_recon(:,:,:,i) = reshape(Ux(:,:,:,1,i),sx*sx,nl0)*Phi(:,:,i);
end
im_recon = reshape(im_recon,[sx,sx,nof,nSMS]);


