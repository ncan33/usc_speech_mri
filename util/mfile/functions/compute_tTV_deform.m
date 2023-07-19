function tTV_update = compute_tTV_deform(Image,weight,beta_square,Motion)

%temp_f = Image(Motion.idx_b) - Image(:,:,1:end-1,:,:);
%temp_b = Image(:,:,2:end,:,:) - Image(Motion.idx_f);
%temp_f = temp_f./sqrt(abs(temp_f).^2+beta_square);
%temp_b = temp_b./sqrt(abs(temp_b).^2+beta_square);

%tTV_update = weight*cat(3,temp_f(:,:,1,:,:),temp_f(:,:,2:end,:,:)-temp_b(:,:,1:end-1,:,:),-temp_b(:,:,end,:,:));
%tTV_update = weight*(temp_f(:,:,2:end)-temp_b(:,:,1:end-1));
%tTV_update(:,:,end+1:end+2) = 0;
%tTV_update = circshift(tTV_update,1,3);
%return

nof = size(Image,3);
nos = size(Image,5);
for ns = 1:nos
    for i=2:nof-1
        
        I0 = Image(:,:,i,:,ns);
        If = Image(:,:,i+1,:,ns);
        Ib = Image(:,:,i-1,:,ns);

        If = interp2(If,Motion.xb(:,:,i,:,ns),Motion.yb(:,:,i,:,ns));
        Ib = interp2(Ib,Motion.xf(:,:,i,:,ns),Motion.yf(:,:,i,:,ns));
        
        temp_f = If - I0;
        temp_b = I0 - Ib;
        
        temp_f = temp_f./sqrt(abs(temp_f).^2+beta_square);
        temp_b = temp_b./sqrt(abs(temp_b).^2+beta_square);
        
        tTV_update(:,:,i,:,ns) = temp_f-temp_b;
    
    end
end
tTV_update(:,:,end+1,:,:) = 0;
tTV_update = weight*tTV_update;