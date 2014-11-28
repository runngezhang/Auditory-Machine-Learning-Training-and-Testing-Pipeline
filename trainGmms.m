function [model1, model0] = trainGmms( y, x, esetup )
% y: labels of x
% x: matrix of data points (+1 and -1!)
% esetup: training parameters
%
% model: trained gmm
% trVal: performance of trained model on training data
inds = round(random('uni',1 ,size(y,1),1,round(size(y,1)*0.1)));
x = x(inds,:);
y= y(inds);

x1 = (x(y==1,:,:))';
if sum(sum(isnan(x1)))>0
    warning('there is some missing data that create NaN which are replaced by zero')
    x1(isnan(x1))=0;
end
[~, model1, llh1] = emgm(x1, esetup.initComps);
model1.posFeature = x1;

x0 = real((x(y~=1,:,:))');
if sum(sum(isnan(x0)))>0
    warning('there is some missing data that create NaN which are replaced by zero')
    x0(isnan(x0))=0;
end

[~, model0, llh0] = emgm(x0, esetup.gmm.initComp);
model0.negFeature = x0;

% [~, trVal, ~,~,~,~] = gmmPredict( y, x, model1, model0);




