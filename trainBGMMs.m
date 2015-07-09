function [model1, model0] = trainBGMMs( y, x, esetup )
% y: labels of x
% x: matrix of data points (+1 and -1!)
% esetup: training parameters
%
% model: trained gmm

x1 = (x(y==1,:,:))';
if sum(sum(isnan(x1)))>0
    warning('there is some missing data that create NaN which are replaced by zero')
    x1(isnan(x1))=0;
end


x0 = (x(y~=1,:,:))';
if sum(sum(isnan(x0)))>0
    warning('there is some missing data that create NaN which are replaced by zero')
    x0(isnan(x0))=0;
end

[~, model1] = vbgm(x1, esetup.nComp); %

[~, model0] = vbgm(x0, esetup.nComp); %

