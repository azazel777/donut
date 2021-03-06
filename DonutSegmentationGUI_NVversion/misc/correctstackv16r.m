function [cortd_stack]=correctstackv16r(stack,Template,tdivn,conv_critn,numloops)

%Implementation of motion correction algorithm described in "Automated correction
%of fast motion artifacts for two-photon imaging of awake animals" by David Greenberg
%and Jason Kerr, Journal of neuroscience methods 176(2009) 1-15
%by Ko Ho

%default value for max num loops
if nargin<5
    numloops=50;
end
%defining time points: t1pxl - time spent on one pixel, tdivn - resolution
%of correction in terms of time, t - time at which pixels are taken, middle
%of period spent on that pixel
t1pxl=2e-6;
[l,w,h]=size(stack);
t=((0:l*w-1)+0.5)*t1pxl;
T=l*w*t1pxl;
numpara=2*(tdivn+1);
tdivd=T/tdivn;
tdivds=(0:tdivn-1)*tdivd;
numrep=l*w/tdivn;
rep_tdivds=reshape(repmat(tdivds,numrep,1),1,l*w);
dim=l*w;

%defining x,y coordinates as a function of time, eliminating non-necessary
%elements in x
x=zeros(1,2*l);
for i=1:2*l
    x(i)=(1+(-1)^floor(t(i)/t1pxl/l))/2+l*(1+(-1)^ceil(t(i)/t1pxl/l))/2+...
        (-1)^floor(t(i)/t1pxl/l)*floor(t(i)/t1pxl-floor(t(i)/t1pxl/l)*l);
end;
x=repmat(x,1,ceil(w/2));
y=ceil(t/t1pxl/l);
if mod(l,2)
    x(length(x)-l+1:length(x))=[];
end;

%setting inital value of pk, deltap (for entering loop)
pk=zeros(1,numpara);
deltap=ones(1,numpara);

%m is for recording the number of iterations, mp is for holding the
%number of loop that gives maximum correlation
m=zeros(1,h);

%finding gradient of Template and Dxt, Dyt
[gradTy,gradTx]=gradient(Template);
parDvt=reshape([1-(t-rep_tdivds)/tdivd (t-rep_tdivds)/tdivd],dim,2);
gradtpD=zeros(4,1,dim);
delpxl=zeros(1,1,dim);

%allocation of A and B, matrices for holding sums later (refer to loops)
A=zeros(numpara,numpara);
B=zeros(numpara,1);

%allocate matrices for holding corrected images and repeating index
cortd_stack=zeros(l,w,h);
repind=zeros(l,w);

%before convergence, compute deltap, and update pk
for j=1:h
    fprintf('%s\n',['frame: ',num2str(j),' of ',num2str(h)]);
    %assigning the current image to be processed to Image, initialize pk
    Image=stack(:,:,j);
    
    pk=pk-pk;
    deltap=deltap-deltap+5;
    
    count=0;
    while norm(deltap)>conv_critn && m(j)<numloops
        %initialize matrices, gradtpD, A and B are used later for storing
        %products and summations of products of partial derivatives and
        %gradients

        count=count+1;
        fprintf('%s\n',['loop: ',num2str(count)]);
        A=A-A;
        B=B-B;
        delpxl=delpxl-delpxl;
        gradtpD=gradtpD-gradtpD;
        
        %generate matrices for holding displacements at times when pixels
        %were taken
        pkxlr=reshape(repmat(pk(1:tdivn),numrep,1),1,dim);
        pkxup=reshape(repmat(pk(2:tdivn+1),numrep,1),1,dim);
        Dxt=pkxlr+(pkxup-pkxlr).*(t-rep_tdivds)/tdivd;
        
        pkylr=reshape(repmat(pk(tdivn+2:numpara-1),numrep,1),1,dim);
        pkyup=reshape(repmat(pk(tdivn+3:numpara),numrep,1),1,dim);
        Dyt=pkylr+(pkyup-pkylr).*(t-rep_tdivds)/tdivd;
        
        %xpD, ypD: x,y plus rounded Dxt,Dyt
        xpD=x+round(Dxt);
        ypD=y+round(Dyt);
        for i=1:dim
            if xpD(i)>0 && xpD(i)<l+1 && ypD(i)>0 && ypD(i)<w+1
                %find gradient of Template and pixel difference
                delpxl(1,1,i)=Image(x(i),y(i))-Template(xpD(i),ypD(i));
                gradtpD(1,1,i)=gradTx(xpD(i),ypD(i))*parDvt(i,1);
                gradtpD(2,1,i)=gradTx(xpD(i),ypD(i))*parDvt(i,2);
                gradtpD(3,1,i)=gradTy(xpD(i),ypD(i))*parDvt(i,1);
                gradtpD(4,1,i)=gradTy(xpD(i),ypD(i))*parDvt(i,2);
            end
        end
        delpxlR=reshape(repmat(reshape(delpxl,l,w),1,4),l,w,4);
        gradtpDR=reshape(permute(gradtpD(:,1,:),[3 2 1]),l,w,4);
        delpxlR_Prod=delpxlR.*gradtpDR;
        
        M11=gradtpDR(:,:,1).*gradtpDR(:,:,1);
        M12=gradtpDR(:,:,1).*gradtpDR(:,:,2);
        M13=gradtpDR(:,:,1).*gradtpDR(:,:,3);
        M14=gradtpDR(:,:,1).*gradtpDR(:,:,4);
        M22=gradtpDR(:,:,2).*gradtpDR(:,:,2);
        M23=gradtpDR(:,:,2).*gradtpDR(:,:,3);
        M24=gradtpDR(:,:,2).*gradtpDR(:,:,4);
        M33=gradtpDR(:,:,3).*gradtpDR(:,:,3);
        M34=gradtpDR(:,:,3).*gradtpDR(:,:,4);
        M44=gradtpDR(:,:,4).*gradtpDR(:,:,4);
        
        gradtpDR_Prod=reshape([M11 M12 M13 M14...
            M12 M22 M23 M24...
            M13 M23 M33 M34...
            M14 M24 M34 M44],l,w,16);
        
        ATemp=reshape(permute(gradtpDR_Prod,[3 4 1 2]),4,4,dim);
        BTemp=reshape(permute(delpxlR_Prod,[3 1 2]),4,1,dim);
        for i=1:tdivn
            A(i:i+1,i:i+1)=A(i:i+1,i:i+1)...
                +sum(ATemp(1:2,1:2,(i-1)*dim/tdivn+1:(i-1)*dim/tdivn+dim/tdivn),3);
            A(i:i+1,i+tdivn+1:i+tdivn+2)=A(i:i+1,i+tdivn+1:i+tdivn+2)...
                +sum(ATemp(1:2,3:4,(i-1)*dim/tdivn+1:(i-1)*dim/tdivn+dim/tdivn),3);
            A(i+tdivn+1:i+tdivn+2,i:i+1)=A(i+tdivn+1:i+tdivn+2,i:i+1)...
                +sum(ATemp(3:4,1:2,(i-1)*dim/tdivn+1:(i-1)*dim/tdivn+dim/tdivn),3);
            A(i+tdivn+1:i+tdivn+2,i+tdivn+1:i+tdivn+2)=A(i+tdivn+1:i+tdivn+2,i+tdivn+1:i+tdivn+2)...
                +sum(ATemp(3:4,3:4,(i-1)*dim/tdivn+1:(i-1)*dim/tdivn+dim/tdivn),3);
            
            B(i:i+1,1)=B(i:i+1,1)...
                +sum(BTemp(1:2,1,(i-1)*dim/tdivn+1:(i-1)*dim/tdivn+dim/tdivn),3);
            B(i+tdivn+1:i+tdivn+2,1)=B(i+tdivn+1:i+tdivn+2,1)...
                +sum(BTemp(3:4,1,(i-1)*dim/tdivn+1:(i-1)*dim/tdivn+dim/tdivn),3);
        end
        %compute deltaf and update pk
        m(j)=m(j)+1;
        deltap=A^-1*B/m(j)^2;
        pk=pk+deltap';
    end
    
    %generate corrected image, find cross correlation
    cortd_stack(:,:,j)=cortd_stack(:,:,j)-cortd_stack(:,:,j);
    repind=repind-repind;
    
    %compute Dxt and Dyt based on current pk
    pkxlr=reshape(repmat(pk(1:tdivn),numrep,1),1,dim);
    pkxup=reshape(repmat(pk(2:tdivn+1),numrep,1),1,dim);
    Dxt=pkxlr+(pkxup-pkxlr).*(t-rep_tdivds)/tdivd;
    
    pkylr=reshape(repmat(pk(tdivn+2:numpara-1),numrep,1),1,dim);
    pkyup=reshape(repmat(pk(tdivn+3:numpara),numrep,1),1,dim);
    Dyt=pkylr+(pkyup-pkylr).*(t-rep_tdivds)/tdivd;
    
    %xmD, ymD: x,y minus rounded Dxt,Dyt
    xmD=x-round(Dxt);
    ymD=y-round(Dyt);

    %assign pixel values iff after movements still not out of boundary,
    %if pixels repeats - use average value
    for i=1:dim
        if xmD(i)>0 && xmD(i)<l+1 && ymD(i)>0 && ymD(i)<w+1
            cortd_stack(x(i),y(i),j)=cortd_stack(x(i),y(i),j)+Image(xmD(i),ymD(i));
            repind(x(i),y(i))=repind(x(i),y(i))+1;
        end
    end
    repindtemp=repind;
    repind=single(repindtemp>-1);
    for i=2:max(repindtemp(:))
        repind=repind+single(repindtemp>=i);
    end
    cortd_stack(:,:,j)=cortd_stack(:,:,j)./repind;

end