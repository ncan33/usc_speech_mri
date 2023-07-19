function Image = Recon_3D_2_injections(Data,para)

bin1 = para.Recon.bin1; % pd
if length(bin1)>size(Data.kSpace,4)
    bin1(size(Data.kSpace,4)+1:end) = [];
end
bin2 = para.Recon.bin2; % 1 injection
if length(bin2)>size(Data.kSpace,4)
    bin2(size(Data.kSpace,4)+1:end) = [];
end
if isfield(para.Recon,'bin3')
    bin3 = para.Recon.bin3; % 2 injection
    if length(bin3)>size(Data.kSpace,4)
        bin3(size(Data.kSpace,4)+1:end) = [];
    end
end

Data_temp.filter = Data.filter;
Data_temp.sens_map = Data.sens_map;

Data_temp.kSpace = Data.kSpace(:,:,:,bin1,:);
Data_temp.first_est = Data.first_est(:,:,:,bin1);
Data_temp.mask = Data.mask(:,:,:,bin1);
scale_image = mean(abs(Data_temp.first_est(:)));
para.Recon.weight_tTV = scale_image*para.weight_tTV;
para.Recon.weight_sTV = scale_image*para.weight_sTV;
para.Recon.weight_sliceTV = scale_image*para.weight_sliceTV;
Image.pd = STCR_conjugate_gradient_3D(Data_temp,para);
Image.pd = crop_half_FOV(abs(Image.pd));

Data_temp.kSpace = Data.kSpace(:,:,:,bin2,:);
Data_temp.first_est = Data.first_est(:,:,:,bin2);
Data_temp.mask = Data.mask(:,:,:,bin2);
scale_image = mean(abs(Data_temp.first_est(:)));
para.Recon.weight_tTV = scale_image*para.weight_tTV;
para.Recon.weight_sTV = scale_image*para.weight_sTV;
para.Recon.weight_sliceTV = scale_image*para.weight_sliceTV;
Image.inj1 = STCR_conjugate_gradient_3D(Data_temp,para);
Image.inj1 = crop_half_FOV(abs(Image.inj1));

if isfield(para.Recon,'bin3')
    Data_temp.kSpace = Data.kSpace(:,:,:,bin3,:);
    Data_temp.first_est = Data.first_est(:,:,:,bin3);
    Data_temp.mask = Data.mask(:,:,:,bin3);
    scale_image = mean(abs(Data_temp.first_est(:)));
    para.Recon.weight_tTV = scale_image*para.weight_tTV;
    para.Recon.weight_sTV = scale_image*para.weight_sTV;
    para.Recon.weight_sliceTV = scale_image*para.weight_sliceTV;
    Image.inj2 = STCR_conjugate_gradient_3D(Data_temp,para);
    Image.inj2 = crop_half_FOV(abs(Image.inj2));
end
