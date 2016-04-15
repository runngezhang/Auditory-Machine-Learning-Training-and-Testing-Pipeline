function trainAndTest3PointOvrlsModel( classname )

if nargin < 1, classname = 'baby'; end;

%startTwoEars( '../IdentificationTraining.xml' );
addpath( '..' );
startIdentificationTraining();

pipe = TwoEarsIdTrainPipe();
pipe.featureCreator = featureCreators.FeatureSetRmBlockmean();
pipe.modelCreator = modelTrainers.GlmNetLambdaSelectTrainer( ...
    'performanceMeasure', @performanceMeasures.BAC2, ...
    'cvFolds', 4, ...
    'alpha', 0.99 );
pipe.modelCreator.verbose( 'on' );

pipe.trainset = 'learned_models/IdentityKS/trainTestSets/trainSet_miniMini1.flist';
pipe.setupData();

sc = sceneConfig.SceneConfiguration();
sc.addSource( sceneConfig.PointSource() );
sc.addSource( sceneConfig.PointSource( ...
    'azimuth',sceneConfig.ValGen('manual',-90),...
    'data',sceneConfig.FileListValGen(pipe.pipeline.trainSet('general',:,'wavFileName')),...
    'offset', sceneConfig.ValGen('manual',0.0) ),...
    sceneConfig.ValGen( 'manual', 10 ),...
    true );
sc.addSource( sceneConfig.PointSource( ...
    'azimuth',sceneConfig.ValGen('manual',+90),...
    'data',sceneConfig.FileListValGen(pipe.pipeline.trainSet('general',:,'wavFileName')),...
    'offset', sceneConfig.ValGen('manual',0.0) ),...
    sceneConfig.ValGen( 'manual', 10 ),...
    true );
sc.addSource( sceneConfig.PointSource( ...
    'azimuth',sceneConfig.ValGen('manual',180),...
    'data',sceneConfig.FileListValGen(pipe.pipeline.trainSet('general',:,'wavFileName')),...
    'offset', sceneConfig.ValGen('manual',0.0) ),...
    sceneConfig.ValGen( 'manual', 10 ),...
    true );

pipe.init( sc );
modelPath = pipe.pipeline.run( {classname}, 0 );

fprintf( ' -- Model is saved at %s -- \n\n', modelPath );

pipe.modelCreator = ...
    modelTrainers.LoadModelNoopTrainer( ...
        fullfile( modelPath, [classname '.model.mat'] ), ...
        'performanceMeasure', @performanceMeasures.BAC2,...
        'maxDataSize', inf ...
        );

pipe.trainset = [];
pipe.testset = 'learned_models/IdentityKS/trainTestSets/testSet_miniMini1.flist';
pipe.setupData();

sc = sceneConfig.SceneConfiguration(); % clean
sc.addSource( sceneConfig.PointSource() );
sc.addSource( sceneConfig.PointSource( ...
    'azimuth',sceneConfig.ValGen('manual',-90),...
    'data',sceneConfig.FileListValGen(pipe.pipeline.testSet('general',:,'wavFileName')),...
    'offset', sceneConfig.ValGen('manual',0.0) ),...
    sceneConfig.ValGen( 'manual', 10 ),...
    true );
sc.addSource( sceneConfig.PointSource( ...
    'azimuth',sceneConfig.ValGen('manual',+90),...
    'data',sceneConfig.FileListValGen(pipe.pipeline.testSet('general',:,'wavFileName')),...
    'offset', sceneConfig.ValGen('manual',0.0) ),...
    sceneConfig.ValGen( 'manual', 10 ),...
    true );
sc.addSource( sceneConfig.PointSource( ...
    'azimuth',sceneConfig.ValGen('manual',180),...
    'data',sceneConfig.FileListValGen(pipe.pipeline.testSet('general',:,'wavFileName')),...
    'offset', sceneConfig.ValGen('manual',0.0) ),...
    sceneConfig.ValGen( 'manual', 10 ),...
    true );

pipe.init( sc );
modelPath = pipe.pipeline.run( {classname}, 0 );
