function trainSVMrbf_mc1( classname )

%startTwoEars( '../IdentificationTraining.xml' );
addpath( '../..' );
startIdentificationTraining();

classes = {'alarm','baby','femaleSpeech','fire'};
featureCreators = {?featureCreators.FeatureSet1Blockmean,...
                   ?featureCreators.FeatureSet1VarBlocks,...
                   ?featureCreators.FeatureSet1BlockmeanLowVsHighFreqRes};
lambdas = {'0','b','hws'};
kernels = [0, 2];

if exist( 'glmnet_mc1_test.mat', 'file' )
    load( 'glmnet_mc1_test.mat' );
else
    return;
end
if exist( ['glmnet_mc1_' classname '_svm.mat'], 'file' )
    load( ['glmnet_mc1_' classname '_svm.mat'] );
end

cc = find( strcmpi( classes, classname ) );
for ll = 3 % 1 : 3
for fc = 1 : numel( featureCreators )
for kk = 1 : numel( kernels )
    
fprintf( '.\n' );

if exist( 'modelpathes_test','var' )  && ( size(modelpathes_test,1) < fc  ...
        || size(modelpathes_test,2) < cc ||  isempty( modelpathes_test{fc,cc} ) )
    continue; 
end
if exist( 'modelpathes_svm','var' )  &&  ...
        size(modelpathes_svm,1) >= fc  &&  size(modelpathes_svm,2) >= ll  ...
        &&  size(modelpathes_svm,3) >= kk &&  ~isempty( modelpathes_svm{fc,ll,kk} )
    continue;
end
    
m = load( [modelpathes_test{fc,cc} filesep classname '.model.mat'] );
fmask = zeros( size( m.featureCreator.description ) );
switch lambdas{ll}
    case '0'
        fmask(1:end) = 1;
    case 'b'
        fmask(m.model.getBestLambdaCVresults()) = 1;
    case 'hws'
        fmask(m.model.getHighestLambdaWithinStdCVresults()) = 1;
end

pipe = TwoEarsIdTrainPipe();
pipe.featureCreator = feval( featureCreators{fc}.Name );
pipe.modelCreator = modelTrainers.SVMmodelSelectTrainer( ...
    'performanceMeasure', @performanceMeasures.BAC2, ...
    'hpsEpsilons', [0.1], ... % define hps set (not a range)
    'hpsKernels', [kernels(kk)], ...      % define hps set (not a range). 0 = linear, 2 = rbf
    'hpsCrange', [-8 2], ...    % define hps C range -- logspaced between 10^a and 10^b
    'hpsGammaRange', [-12 3], ... % define hps Gamma range -- logspaced between 10^a and 
                              ... % 10^b. Ignored for kernel other than rbf
    'hpsMaxDataSize', 5000, ...  % max data set size to use in hps (number of samples)
    'hpsRefineStages', 2, ...   % number of iterative hps refinement stages
    'hpsSearchBudget', 5, ...   % number of hps grid search parameter values per dimension
    'hpsCvFolds', 4, ...           % number of hps cv folds of training set
    'finalMaxDataSize', (80000*3)/(fc+1) );
modelTrainers.Base.featureMask( true, fmask );
pipe.modelCreator.verbose( 'on' );

setsBasePath = 'learned_models/IdentityKS/trainTestSets/';
pipe.trainset = [setsBasePath 'NIGENS_75pTrain_TrainSet_1.flist'];
pipe.setupData();

sc(1) = sceneConfig.SceneConfiguration();
sc(1).addSource( sceneConfig.PointSource() );
sc(1).addSource( sceneConfig.PointSource( ...
    'data',sceneConfig.FileListValGen(pipe.pipeline.data('general',:,'wavFileName')) ),...
    sceneConfig.ValGen( 'manual', 0 ));

sc(2) = sceneConfig.SceneConfiguration();
sc(2).addSource( sceneConfig.PointSource() );
sc(2).addSource( sceneConfig.PointSource( 'azimuth',sceneConfig.ValGen('manual',90), ...
    'data',sceneConfig.FileListValGen(pipe.pipeline.data('general',:,'wavFileName')) ),...
    sceneConfig.ValGen( 'manual', 0 ));

sc(3) = sceneConfig.SceneConfiguration();
sc(3).addSource( sceneConfig.PointSource( 'azimuth',sceneConfig.ValGen('manual',-45) ) );
sc(3).addSource( sceneConfig.PointSource( 'azimuth',sceneConfig.ValGen('manual',45), ...
    'data',sceneConfig.FileListValGen(pipe.pipeline.data('general',:,'wavFileName')) ),...
    sceneConfig.ValGen( 'manual', 0 ));

sc(4) = sceneConfig.SceneConfiguration();
sc(4).addSource( sceneConfig.PointSource( 'azimuth',sceneConfig.ValGen('manual',-90) ) );
sc(4).addSource( sceneConfig.PointSource( 'azimuth',sceneConfig.ValGen('manual',90), ...
    'data',sceneConfig.FileListValGen(pipe.pipeline.data('general',:,'wavFileName')) ),...
    sceneConfig.ValGen( 'manual', 0 ));

sc(5) = sceneConfig.SceneConfiguration();
sc(5).addSource( sceneConfig.PointSource('azimuth',sceneConfig.ValGen('manual',0)) );

sc(6) = sceneConfig.SceneConfiguration();
sc(6).addSource( sceneConfig.PointSource('azimuth',sceneConfig.ValGen('manual',135)) );

sc(7) = sceneConfig.SceneConfiguration();
sc(7).addSource( sceneConfig.PointSource() );
sc(7).addSource( sceneConfig.DiffuseSource( ...
    'data',sceneConfig.NoiseValGen(struct( 'len', sceneConfig.ValGen('manual',4410000) )) ),...
    sceneConfig.ValGen( 'manual', -10 ));

sc(8) = sceneConfig.SceneConfiguration();
sc(8).addSource( sceneConfig.PointSource() );
sc(8).addSource( sceneConfig.DiffuseSource( ...
    'data',sceneConfig.NoiseValGen(struct( 'len', sceneConfig.ValGen('manual',4410000) )) ),...
    sceneConfig.ValGen( 'manual', 0 ));

sc(9) = sceneConfig.SceneConfiguration();
sc(9).addSource( sceneConfig.PointSource() );
sc(9).addSource( sceneConfig.DiffuseSource( ...
    'data',sceneConfig.NoiseValGen(struct( 'len', sceneConfig.ValGen('manual',4410000) )) ),...
    sceneConfig.ValGen( 'manual', 10 ));

pipe.setSceneConfig( sc ); 

pipe.init();
pipe.pipeline.gatherFeaturesProc.setConfDataUseRatio( 0.15, classname );
modelpathes_svm{fc,ll,kk} = pipe.pipeline.run( {classname}, 0 );

save( ['glmnet_mc1_' classname '_svm.mat'], 'lambdas', 'featureCreators', 'kernels', ...
    'modelpathes_svm');%, 'test_performances' );

end
end
end




