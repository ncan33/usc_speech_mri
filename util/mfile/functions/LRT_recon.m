function im_recon = LRT_recon(Data,Phi)
Phi = gpuArray(Phi);
Data.sens_map = gpuArray(Data.sens_map);
Data.first_est = gpuArray(Data.first_est);
Data.kSpace = gpuArray(Data.kSpace);
Data.mask = gpuArray(Data.mask);

nof = size(Phi,2);
nl0 = size(Phi,1);
sx = size(Data.first_est,1);
no_comp = size(Data.kSpace,4);

Phi_pinv = pinv(Phi);
Ux = reshape(Data.first_est,sx^2,nof)*Phi_pinv;
Ux = reshape(Ux,sx,sx,nl0);
weight = 0.001*max(max(abs(Ux)));
for i=1:60
    
    fidelity = fft2(Ux.*Data.sens_map);
    fidelity = permute(fidelity,[1,2,4,3]);
    fidelity = reshape(fidelity,sx*sx*no_comp,nl0)*Phi;
    fidelity = reshape(fidelity,sx,sx,no_comp,nof);
    fidelity = permute(fidelity,[1,2,4,3]);
    fidelity = Data.kSpace - fidelity;
    fidelity = fidelity.*Data.mask;
    fnorm(i) = sum(abs(fidelity(:)));
    fidelity = permute(fidelity,[1,2,4,3]);
    fidelity = reshape(fidelity,[sx*sx*no_comp,nof])*Phi_pinv;
    fidelity = reshape(fidelity,[sx,sx,no_comp,nl0]);
    fidelity = permute(fidelity,[1,2,4,3]);
    fidelity = ifft2(fidelity);
    fidelity = fidelity.*conj(Data.sens_map);
    fidelity = sum(fidelity,4);
    
    %stv = weight.*compute_sTV_yt(Ux,1,1e-14);
    Ux = Ux + fidelity;
    
    figure(1)
    imagesc(abs(Ux(:,:,1)))
    axis image
    drawnow
    figure(2)
    plot(fnorm)
    drawnow
end

im_recon = reshape(Ux,sx*sx,nl0)*Phi;
im_recon = reshape(im_recon,[sx,sx,nof]);


