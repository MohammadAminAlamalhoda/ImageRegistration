% Created and Developed by Amin Alam - 29th hun 2021
clc
clear
close all
% loading datas

SN = 18;
file_path = "./Project_Stuff/Datas/";
[V, V_label] = NiiLoader(SN,file_path);
tool = imtool3D((V));
setMask(tool,(V_label));
% saveas(gcf,"./report/images/Subject"+num2str(SN)+".png")
% showing point clouds
close all
figure
ptCloud = Pcloudmaker(V_label);
pcshow(ptCloud);
xlabel('X')
ylabel('Y')
zlabel('Z')
view(-46,60)
colormap jet
% saveas(gcf,"./report/images/MainPCSubject"+num2str(SN)+".png")
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Atlas preview
close all
file_path = "./Healthy_sample/";
VA = double(niftiread(file_path+"00"+".nii"));
VA_label = double(niftiread(file_path+"00_mask.nii"));
tool = imtool3D((VA));
setMask(tool,(VA_label));
ptCloud_A = Pcloudmaker(VA_label);
pcshow(ptCloud_A);
xlabel('X')
ylabel('Y')
zlabel('Z')
view(-46,60)
colormap jet
%% Registration just using CPD
close all
ptCloud_P = Pcloudmaker(V_label);
ptCloud_A = Pcloudmaker(VA_label);

% downsampling
GridStep = 5;
moving = pcdownsample(ptCloud_P,'gridAverage',GridStep);
fixed = pcdownsample(ptCloud_A,'gridAverage',GridStep);
tform = pcregistercpd(moving, fixed);
movingReg = pctransform(moving, tform);


% seperating vertebras
Img = V_label;
VertebraNumbers = 15:1:30;
L = 0;
for i = VertebraNumbers
    [x, y, z] = ind2sub(size(Img), find(Img == i));
    xyzPoints = [x, y, z];
    ptCloud = pointCloud(xyzPoints);
    
    if ~isempty(ptCloud.Location)
        SeperateVertebras.(sprintf("Vertebra_%i", i)).ptCloud = pcdownsample(ptCloud,'gridAverage',GridStep);
        L = L + length(SeperateVertebras.(sprintf("Vertebra_%i", i)).ptCloud.Location);
        SeperateVertebras.(sprintf("Vertebra_%i", i)).ptCloud_rotated = SeperateVertebras.(sprintf("Vertebra_%i", i)).ptCloud;
        SeperateVertebras.(sprintf("Vertebra_%i", i)).number = i;
    end
end

Img = VA_label;
VertebraNumbers = 15:1:30;
for i = VertebraNumbers
    [x, y, z] = ind2sub(size(Img), find(Img == i));
    xyzPoints = [x, y, z];
    ptCloud = pointCloud(xyzPoints);
    
    if ~isempty(ptCloud.Location)
        SeperateVertebrasA.(sprintf("Vertebra_%i", i)).ptCloud_rotated = pcdownsample(ptCloud,'gridAverage',GridStep);;
        SeperateVertebrasA.(sprintf("Vertebra_%i", i)).number = i;
    end
end
registered_pointCloud = movingReg;
Locations = movingReg.Location;
Locations = interparc(L,Locations(:,1),Locations(:,2),Locations(:,3),'spline');
movingReg = pointCloud(Locations);
SeperateVertebrasF = Segmenter(movingReg.Location, SeperateVertebras, SeperateVertebrasA);
ptCloud_A_transformed = pcdownsample(ptCloud_A,'gridAverage',GridStep);
ptCloud = pcdownsample(ptCloud_P,'gridAverage',GridStep);

figure
pcshowpair(fixed, moving, 'MarkerSize',50)
xlabel('X')
ylabel('Y')
zlabel('Z')
legend({'Atlas','Subject'},'TextColor','w')
view(-46,-10)
% saveas(gcf,"./report/images/Subject"+num2str(SN)+"Original.png")

figure
pcshowpair(fixed, movingReg, 'MarkerSize',50)
xlabel('X')
ylabel('Y')
zlabel('Z')
legend({'Atlas','Subject'},'TextColor','w')
view(-46,-10)
% saveas(gcf,"./report/images/Subject"+num2str(SN)+"AfterJustCPD.png")

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%% seperating each of vertebras and Pre Regeistration
close all
GridStep = 5;
ptCloud_P = Pcloudmaker(V_label);
ptCloud_A = Pcloudmaker(VA_label);
[alpha_1_P, beta_1_P, alpha_2_P] = RotationParams(ptCloud_P.Location);
[alpha_1_A, beta_1_A, alpha_2_A] = RotationParams(ptCloud_A.Location);
ptCloud_P_R = pointCloud(PreRegister(ptCloud_P.Location,alpha_1_P, beta_1_P, alpha_2_P));
ptCloud_A_R = pointCloud(PreRegister(ptCloud_A.Location,alpha_1_A, beta_1_A, alpha_2_A));

SeperateVertebras = vertebra_seperator(V_label, alpha_1_P, beta_1_P, alpha_2_P, GridStep);
SeperateVertebrasA = vertebra_seperator(VA_label, alpha_1_A, beta_1_A, alpha_2_A, GridStep);
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%% caculating transform matrixes
fn1 = fieldnames(SeperateVertebras);
fn2 = fieldnames(SeperateVertebrasA);
clc
for i = 15:1:30
    name = "Vertebra_"+num2str(i);
    if sum(ismember(fn1,name)) && sum(ismember(fn2,name))
        moving = SeperateVertebras.(sprintf("Vertebra_%i", i)).sampledPC;
        fixed = SeperateVertebrasA.(sprintf("Vertebra_%i", i)).sampledPC;
        tform = pcregistercpd(moving, fixed);
        SeperateVertebras.(sprintf("Vertebra_%i", i)).tform = tform;
        movingReg = pctransform(moving, tform);
        SeperateVertebras.(sprintf("Vertebra_%i", i)).movingReg = movingReg;

        LocsA_R = fixed.Location;
        LocsP_R = movingReg.Location;
        cp = CommonPoints(LocsA_R, LocsP_R);
        SeperateVertebras.(sprintf("Vertebra_%i", i)).CommonPointsWithAtlas = cp;
    end
end

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%% showing vertebra to vertebra registered point clouds

LocsP = [];
LocsP_R = [];
for k = 1:numel(fn1)
    pCloud = SeperateVertebras.(sprintf("Vertebra_%i", SeperateVertebras.(sprintf('%s',fn1{k})).number)).ptCloud;
    LocsP = [LocsP; pCloud.Location];
    fn = fieldnames(SeperateVertebras.(sprintf("Vertebra_%i", SeperateVertebras.(sprintf('%s',fn1{k})).number)));
    if sum(ismember(fn,"movingReg"))
        movingReg = SeperateVertebras.(sprintf("Vertebra_%i", SeperateVertebras.(sprintf('%s',fn1{k})).number)).movingReg;
        LocsP_R = [LocsP_R; movingReg.Location];
    else
        boundaryPointC = SeperateVertebras.(sprintf("Vertebra_%i", SeperateVertebras.(sprintf('%s',fn1{k})).number)).boundaryPointC;
        LocsP_R = [LocsP_R; boundaryPointC.Location];
    end
end

LocsA_R = [];
LocsA = [];
for k = 1:numel(fn2)
    pCloud = SeperateVertebrasA.(sprintf("Vertebra_%i", SeperateVertebrasA.(sprintf('%s',fn2{k})).number)).ptCloud;
    LocsA = [LocsA; pCloud.Location];
    movingReg = SeperateVertebrasA.(sprintf("Vertebra_%i", SeperateVertebrasA.(sprintf('%s',fn2{k})).number)).sampledPC;
    LocsA_R = [LocsA_R; movingReg.Location]; 
end

figure
pcshowpair(pointCloud(LocsA), pointCloud(LocsP), 'MarkerSize',50)
xlabel('X')
ylabel('Y')
zlabel('Z')
legend({'Atlas','Registered patient'},'TextColor','w')
title('Point clouds befor registration')

figure
pcshowpair(pointCloud(LocsA_R), pointCloud(LocsP_R), 'MarkerSize',50)
xlabel('X')
ylabel('Y')
zlabel('Z')
legend({'Atlas','Registered patient'},'TextColor','w')
title('Point clouds after registration')

%% registration using polynomial fitting to tranformations
clc
fn1 = fieldnames(SeperateVertebras);
fn2 = fieldnames(SeperateVertebrasA);
locs_BR = [];
locs_AR = [];

% datas to find curve fit
for i = 15:1:30
    name = "Vertebra_"+num2str(i);
    if sum(ismember(fn1,name)) && sum(ismember(fn2,name))
        beforeReg = SeperateVertebras.(sprintf("Vertebra_%i", i)).sampledPC;
        afterReg = SeperateVertebras.(sprintf("Vertebra_%i", i)).movingReg;
        locs_BR = [locs_BR; beforeReg.Location];
        locs_AR = [locs_AR; afterReg.Location];
    end
end

xP = locs_BR(:,1); yP = locs_BR(:,2); zP = locs_BR(:,3);
xR = locs_AR(:,1); yR = locs_AR(:,2); zR = locs_AR(:,3);

polyOrder = 3;
fitobject_x = polyfit(xP,xR,polyOrder);
fitobject_y = polyfit(yP,yR,polyOrder);
fitobject_z = polyfit(zP,zR,polyOrder);
%
% fit datas using curve fit
ptCloudAllPoints = [];
ptCloudAllPointsA = [];

for i = 15:1:30
    name = "Vertebra_"+num2str(i);
    if sum(ismember(fn1,name)) && sum(ismember(fn2,name))
        PtCloud = SeperateVertebras.(sprintf("Vertebra_%i", i)).ptCloud_rotated;
        ptCloudAllPoints = [ptCloudAllPoints; PtCloud.Location];
       
        PtCloudA = SeperateVertebrasA.(sprintf("Vertebra_%i", i)).sampledPC;
        ptCloudAllPointsA = [ptCloudAllPointsA; PtCloudA.Location];
    end
end
ptCloudAllPoints = ptCloud_P_R.Location;
xP_all = ptCloudAllPoints(:,1); yP_all = ptCloudAllPoints(:,2); zP_all = ptCloudAllPoints(:,3);
xP_all_R = polyval(fitobject_x,xP_all); yP_all_R = polyval(fitobject_y,yP_all); zP_all_R = polyval(fitobject_z,zP_all);

registered_pointCloud = pointCloud([xP_all_R, yP_all_R, zP_all_R]);
ptCloud_A_transformed = pointCloud(ptCloudAllPointsA);

SeperateVertebrasF = Segmenter([xP_all_R, yP_all_R, zP_all_R],SeperateVertebras,SeperateVertebrasA);

figure
pcshowpair(ptCloud_A_transformed, pointCloud(locs_BR), 'MarkerSize',50)
xlabel('X')
ylabel('Y')
zlabel('Z')
legend({'Atlas',' patient'},'TextColor','w')
title('Point clouds before registration')

figure
pcshowpair(ptCloud_A_transformed,  pointCloud(locs_AR), 'MarkerSize',50)
xlabel('X')
ylabel('Y')
zlabel('Z')
legend({'Atlas','patient'},'TextColor','w')
title('Point clouds after mohre to mohre registration')

figure
pcshowpair(ptCloud_A_transformed,  pointCloud(ptCloudAllPoints), 'MarkerSize',50)
xlabel('X')
ylabel('Y')
zlabel('Z')
legend({'Atlas','patient'},'TextColor','w')
title('Point clouds before polyval transformation')

figure
pcshowpair(ptCloud_A_transformed, registered_pointCloud, 'MarkerSize',50)
xlabel('X')
ylabel('Y')
zlabel('Z')
legend({'Atlas','patient'},'TextColor','w')
title('Point clouds after polyval transformation')
%% registration using lsqcurvefit to tranformations
clc
fn1 = fieldnames(SeperateVertebras);
fn2 = fieldnames(SeperateVertebrasA);
locs_BR = [];
locs_AR = [];

% datas to find curve fit
for i = 15:1:30
    name = "Vertebra_"+num2str(i);
    if sum(ismember(fn1,name)) && sum(ismember(fn2,name))
        beforeReg = SeperateVertebras.(sprintf("Vertebra_%i", i)).sampledPC;
        afterReg = SeperateVertebras.(sprintf("Vertebra_%i", i)).movingReg;
        locs_BR = [locs_BR; beforeReg.Location];
        locs_AR = [locs_AR; afterReg.Location];
    end
end

xP = locs_BR(:,1); yP = locs_BR(:,2); zP = locs_BR(:,3);
xR = locs_AR(:,1); yR = locs_AR(:,2); zR = locs_AR(:,3);

x0 = [-0.001 0.001 0.001 -0.001];
y0 = [-0.001 0.001 -0.001 0.001];
z0 = [-1 0.001 1 0.001 -1 0.001 0 0.001];

fitobject_x = @(x,xdata)x(1)*exp(-x(2)*xdata) + x(3)*exp(-x(4)*xdata) ;%+ x(5)*exp(-x(6)*xdata) + x(7)*exp(-x(8)*xdata);
[x,resnorm,~,exitflag,output] = lsqcurvefit(fitobject_x,x0,xP,xR);

fitobject_y = @(y,xdata)y(1)*exp(-y(2)*xdata) + y(3)*exp(-y(4)*xdata) ;%+ y(5)*exp(-y(6)*xdata) + y(7)*exp(-y(8)*xdata);
[y,resnorm,~,exitflag,output] = lsqcurvefit(fitobject_y,y0,yP,yR);

fitobject_z = @(z,xdata)z(1)*exp(-z(2)*xdata) + z(3)*exp(-z(4)*xdata) + z(5)*exp(-z(6)*xdata) + z(7)*exp(-z(8)*xdata);
[z,resnorm,~,exitflag,output] = lsqcurvefit(fitobject_z,z0,zP,zR);

%
% fit dats using curve fit
ptCloudAllPoints = [];
ptCloudAllPointsA = [];
for i = 15:1:30
    name = "Vertebra_"+num2str(i);
    if sum(ismember(fn1,name)) && sum(ismember(fn2,name))
        PtCloud = SeperateVertebras.(sprintf("Vertebra_%i", i)).ptCloud_rotated;
        ptCloudAllPoints = [ptCloudAllPoints; PtCloud.Location];
       
        PtCloudA = SeperateVertebrasA.(sprintf("Vertebra_%i", i)).sampledPC;
        ptCloudAllPointsA = [ptCloudAllPointsA; PtCloudA.Location];
    end
end

xP_all = ptCloudAllPoints(:,1); yP_all = ptCloudAllPoints(:,2); zP_all = ptCloudAllPoints(:,3);
xP_all_R = fitobject_x(x ,xP_all); yP_all_R = fitobject_y(y ,yP_all); zP_all_R = fitobject_z(z ,zP_all);

registered_pointCloud = pointCloud([xP_all_R, yP_all_R, zP_all_R]);
ptCloud_A_transformed = pointCloud(ptCloudAllPointsA);


figure
pcshowpair(ptCloud_A_transformed, pointCloud(locs_BR), 'MarkerSize',50)
xlabel('X')
ylabel('Y')
zlabel('Z')
legend({'Atlas','Registered patient'},'TextColor','w')
title('Point clouds before registration')

figure
pcshowpair(ptCloud_A_transformed,  pointCloud(locs_AR), 'MarkerSize',50)
xlabel('X')
ylabel('Y')
zlabel('Z')
legend({'Atlas','Registered patient'},'TextColor','w')
title('Point clouds after mohre to mohre registration')

figure
pcshowpair(ptCloud_A_transformed, registered_pointCloud, 'MarkerSize',50)
xlabel('X')
ylabel('Y')
zlabel('Z')
legend({'Atlas','Registered patient'},'TextColor','w')
title('Point clouds after total fiting registration')

%% registration using nonlinear model fitting to tranformations
clc
fn1 = fieldnames(SeperateVertebras);
fn2 = fieldnames(SeperateVertebrasA);
locs_BR = [];
locs_AR = [];

for i = 15:1:30
    name = "Vertebra_"+num2str(i);
    if sum(ismember(fn1,name)) && sum(ismember(fn2,name))
        beforeReg = SeperateVertebras.(sprintf("Vertebra_%i", i)).sampledPC;
        afterReg = SeperateVertebras.(sprintf("Vertebra_%i", i)).movingReg;
        locs_BR = [locs_BR; beforeReg.Location];
        locs_AR = [locs_AR; afterReg.Location];
    end
end

xP = locs_BR(:,1); yP = locs_BR(:,2); zP = locs_BR(:,3);
xR = locs_AR(:,1); yR = locs_AR(:,2); zR = locs_AR(:,3);

xP = xP + 1000;
yP = yP + 1000;
zP = zP + 1000;
xR = xR + 1000;
yR = yR + 1000;
zR = zR + 1000;

modelfun = @(b,x)b(1) + b(2)*x(:,1).^b(3);
beta0 = [0 0 0];
mdlx = fitnlm(xP,xR,modelfun,beta0)

modelfun = @(b,x)b(1) + b(2)*x(:,1).^b(3);
beta0 = [0 0 0];
mdly = fitnlm(yP,yR,modelfun,beta0)

modelfun = @(b,x)b(1) + b(2)*x(:,1).^b(3);
beta0 = [0 0 0];
mdlz = fitnlm(zP,zR,modelfun,beta0)

xP_all = ptCloudAllPoints(:,1); yP_all = ptCloudAllPoints(:,2); zP_all = ptCloudAllPoints(:,3);
xP_all_R = predict(mdlx ,xP_all); yP_all_R = predict(mdly ,yP_all); zP_all_R = predict(mdlz ,zP_all);

registered_pointCloud = pointCloud(real([xP_all_R, yP_all_R, zP_all_R]));
ptCloud_A_transformed = pointCloud(ptCloudAllPointsA);


figure
pcshowpair(ptCloud_A_transformed, pointCloud(locs_BR), 'MarkerSize',50)
xlabel('X')
ylabel('Y')
zlabel('Z')
legend({'Atlas','Registered patient'},'TextColor','w')
title('Point clouds before registration')

figure
pcshowpair(ptCloud_A_transformed,  pointCloud(locs_AR), 'MarkerSize',50)
xlabel('X')
ylabel('Y')
zlabel('Z')
legend({'Atlas','Registered patient'},'TextColor','w')
title('Point clouds after mohre to mohre registration')

figure
pcshowpair(ptCloud_A_transformed, registered_pointCloud, 'MarkerSize',50)
xlabel('X')
ylabel('Y')
zlabel('Z')
legend({'Atlas','Registered patient'},'TextColor','w')
title('Point clouds after total fiting registration')

%% registration using 2 feed forward networks with 10 layer

ptCloudAllPoints = [];
ptCloudAllPointsA = [];
for i = 15:1:30
    name = "Vertebra_"+num2str(i);
    if sum(ismember(fn1,name)) && sum(ismember(fn2,name))
        PtCloud = SeperateVertebras.(sprintf("Vertebra_%i", i)).ptCloud_rotated;
        ptCloudAllPoints = [ptCloudAllPoints; PtCloud.Location];
       
        PtCloudA = SeperateVertebrasA.(sprintf("Vertebra_%i", i)).sampledPC;
        ptCloudAllPointsA = [ptCloudAllPointsA; PtCloudA.Location];
    end
end

ptCloud_A_transformed = pointCloud(ptCloudAllPointsA);

clc
DownSampled = pcdownsample(pointCloud(ptCloudAllPoints),'gridAverage',7);
ptCloud =  DownSampled;
[n,~] = size(DownSampled.Location);
% interpolating each vertebra
coeef = 0;
xP = []; yP = []; zP = [];
xR = []; yR  = []; zR = [];
for i = 15:1:30
    
    name = "Vertebra_"+num2str(i);
    if sum(ismember(fn1,name)) && sum(ismember(fn2,name))
        coeef = coeef+1;
        beforeReg = SeperateVertebras.(sprintf("Vertebra_%i", i)).sampledPC;
        afterReg = SeperateVertebras.(sprintf("Vertebra_%i", i)).movingReg;
        locs_BR = beforeReg.Location;
        locs_AR = afterReg.Location;
        SampledPC_interpolated = interparc(n,locs_BR(:,1),locs_BR(:,2),locs_BR(:,3),'spline');
        MovingReg_interpolated = interparc(n,locs_AR(:,1),locs_AR(:,2),locs_AR(:,3),'spline');
        SeperateVertebras.(sprintf("Vertebra_%i", i)).sampledPC_interpolated = pointCloud(SampledPC_interpolated);
        SeperateVertebras.(sprintf("Vertebra_%i", i)).movingReg_interpolated = pointCloud(MovingReg_interpolated);
        
        SeperateVertebrasF.(sprintf("Vertebra_%i", i)).pointCloud = pointCloud(MovingReg_interpolated); 
        xP = [xP ; SampledPC_interpolated(:,1)];
        yP = [yP ; SampledPC_interpolated(:,2)];
        zP = [zP ; SampledPC_interpolated(:,3)];
        
        xR = [xR ; MovingReg_interpolated(:,1)];
        yR = [yR ; MovingReg_interpolated(:,2)];
        zR = [zR ; MovingReg_interpolated(:,3)];
    end
    
end

%
xyzP = [xP, yP, zP];
xyzR = [xR, yR, zR];

% pcshowpair(pointCloud([xP,yP,zP]), pointCloud(xyz))
pcshowpair(pointCloud(ptCloudAllPoints), pointCloud(xyzP))
xlabel('X')
ylabel('Y')
zlabel('Z')
legend({'main point cloud',' interpolated point cloud'},'TextColor','w')

clc

index = 1;
x = [];
t = [];

for i=1:coeef
x = [x, xyzP(i:coeef:end,index)];
t = [t, xyzR(i:coeef:end,index)];
end
trainFcn = 'trainscg'; 
hiddenLayerSize = 10;
net = fitnet(hiddenLayerSize,trainFcn);

net.divideParam.trainRatio = 100/100;
net.divideParam.valRatio = 0/100;
net.divideParam.testRatio = 0/100;

[net,tr] = train(net,x,t);

F_xR = net(DownSampled.Location(:,index));
%
index = 2;
x = [];
t = [];
for i=1:coeef
x = [x, xyzP(i:coeef:end,index)];
t = [t, xyzR(i:coeef:end,index)];
end

trainFcn = 'trainscg'; 
hiddenLayerSize = 10;
net = fitnet(hiddenLayerSize,trainFcn);

net.divideParam.trainRatio = 100/100;
net.divideParam.valRatio = 0/100;
net.divideParam.testRatio = 0/100;

[net,tr] = train(net,x,t);

F_yR = net(DownSampled.Location(:,index));
%
index = 3;
x = [];
t = [];
for i=1:coeef
x = [x, xyzP(i:coeef:end,index)];
t = [t, xyzR(i:coeef:end,index)];
end

trainFcn = 'trainscg'; 
hiddenLayerSize = 10;
net = fitnet(hiddenLayerSize,trainFcn);

net.divideParam.trainRatio = 100/100;
net.divideParam.valRatio = 0/100;
net.divideParam.testRatio = 0/100;

[net,tr] = train(net,x,t);

F_zR = net(DownSampled.Location(:,index));

SeperateVertebrasF.PCloud = pointCloud([F_xR,F_yR,F_zR]);
registered_pointCloud = SeperateVertebrasF.PCloud;

figure
pcshowpair(ptCloud_A_transformed, pointCloud([xP,yP,zP]))
legend({'before registration','before registration'},'TextColor','w')
figure
pcshowpair(ptCloud_A_transformed, pointCloud([xR,yR,zR]))
legend({'before registration','after mohre to mohre registration'},'TextColor','w')
figure
pcshowpair(ptCloud_A_transformed, pointCloud([F_xR,F_yR,F_zR]), 'MarkerSize',50)
legend({'Atlas','after network registration'},'TextColor','w')

%% cacluating common points of each vertebra with atals
clc
fn1 = fieldnames(SeperateVertebras);
fn2 = fieldnames(SeperateVertebrasA);
for i = 15:1:30
        name = "Vertebra_"+num2str(i);
        if sum(ismember(fn1,name)) && sum(ismember(fn2,name))
            moving = SeperateVertebrasF.(sprintf("Vertebra_%i", i)).pointCloud;
            fixed = SeperateVertebrasA.(sprintf("Vertebra_%i", i)).ptCloud_rotated;
            LocsA_R = fixed.Location;
            LocsP_R = moving.Location;
            cp = CommonPoints(LocsA_R, LocsP_R);
            SeperateVertebrasF.(sprintf("Vertebra_%i", i)).CommonPointsWithAtlas = cp;
        end
end
%% Dice score
clc
DiceScore = DS(SeperateVertebrasF,SeperateVertebrasA)
%% Hausdorff Distance

HausdorffScore = HD(SeperateVertebrasF,SeperateVertebrasA)
%% Average Surface Distance

ASD_Score = ASD(SeperateVertebrasF.PCloud, ptCloud_A_transformed)
%% intersection of vertebras

VertebraIntersectsVolume = VertebraIntersect_calc(SeperateVertebrasF,SeperateVertebrasA)
%% jacobian of displacemnet field

DisplacemnetField = registered_pointCloud.Location - ptCloud.Location;
JacobianMatofDisplacemnetField = JacobianMatCalc(DisplacemnetField)