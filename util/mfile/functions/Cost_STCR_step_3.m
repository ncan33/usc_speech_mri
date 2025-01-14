function [Cost_new,Cost,fNorm,tNorm,sNorm] = Cost_STCR_step_3(fUpdate, Image, sWeight, tWeight, l2ref, l2Weight, Cost_old)

N = numel(Image);

fNorm = sum(abs(fUpdate(:)).^2);
% Image = crop_half_FOV(Image);
if tWeight ~= 0
    tNorm = tWeight .* abs(diff(Image,1,3));
    tNorm = sum(tNorm(:));
%     Image_temp = permute(Image,[1,2,4,3]);
%     patch_all = Image_temp(llr.idx);  
%     tNorm2 = tWeight .* diff(patch_all, 1, 2);
%     tNorm = tNorm + sum(abs(tNorm2(:)));
else
    tNorm = 0;
end

if l2Weight
    l2Norm = Image - l2ref;
    l2Norm = l2Weight * sum(abs(l2Norm(:)).^2);
else
    l2Norm = 0;
end

if sWeight ~= 0
    sx_norm = abs(diff(Image,1,2));
    sx_norm(:,end+1,:,:,:)=0;
    sy_norm = abs(diff(Image,1,1));
    sy_norm(end+1,:,:,:,:)=0;
    sNorm = sWeight .* sqrt(abs(sx_norm).^2+abs(sy_norm).^2);
    sNorm = sum(sNorm(:));
else
    sNorm = 0;
end

fNorm = fNorm/N;
tNorm = tNorm/N;
sNorm = sNorm/N;
l2Norm = l2Norm/N;

Cost = sNorm + tNorm + fNorm + l2Norm;

if nargin == 6
    Cost_new = Cost;
    return
end

Cost_new = Cost_old;

if isempty(Cost_old.fidelityNorm)==1
    Cost_new.fidelityNorm = gather(fNorm);
    Cost_new.temporalNorm = gather(tNorm);
    Cost_new.spatialNorm = gather(sNorm);
    Cost_new.l2Norm = gather(l2Norm);
    Cost_new.totalCost = gather(Cost);
else    
    Cost_new.fidelityNorm(end+1) = gather(fNorm);
    Cost_new.temporalNorm(end+1) = gather(tNorm);
    Cost_new.spatialNorm(end+1) = gather(sNorm);
    Cost_new.l2Norm(end+1) = gather(l2Norm);
    Cost_new.totalCost(end+1) = gather(Cost);
end

end