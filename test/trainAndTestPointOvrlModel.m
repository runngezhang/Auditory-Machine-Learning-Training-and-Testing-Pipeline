function trainAndTestPointOvrlModel( classname )

if nargin < 1, classname = 'piano'; end;

addPathsIfNotIncluded( cleanPathFromRelativeRefs( [pwd '/..'] ) ); 
startAMLTTP();

pipe = TwoEarsIdTrainPipe();
pipe.featureCreator = FeatureCreators.FeatureSetRmAmsBlockmean();
% <classname> will be 1, rest -1
oneVsRestLabeler = ... 
    LabelCreators.MultiEventTypeLabeler( 'types', {{classname}}, 'negOut', 'rest' );
pipe.labelCreator = oneVsRestLabeler;
pipe.modelCreator = ModelTrainers.GlmNetLambdaSelectTrainer( ...
    'performanceMeasure', @PerformanceMeasures.BAC2, ...
    'cvFolds', 4, ...
    'alpha', 0.99 );
pipe.modelCreator.verbose( 'on' );

pipe.trainset = 'learned_models/IdentityKS/trainTestSets/NIGENS160807_mini_TrainSet_1.flist';
pipe.setupData();

sc = SceneConfig.SceneConfiguration();
sc.addSource( SceneConfig.PointSource( ...
        'data', SceneConfig.FileListValGen( 'pipeInput' )  )  );
sc.addSource( SceneConfig.PointSource( ...
        'data', SceneConfig.FileListValGen( ...
               pipe.pipeline.trainSet('fileLabel',{{'type',{'general'}}},'fileName') ),...
        'offset', SceneConfig.ValGen( 'manual', 0 ) ),...
    'snr', SceneConfig.ValGen( 'manual', 0 ),...
    'loop', 'randomSeq' );
sc.setLengthRef( 'source', 1, 'min', 30 );
pipe.init( sc );

modelPath = pipe.pipeline.run( 'modelName', classname, 'modelPath', 'test_pointOvrl_training' );

fprintf( ' -- Model is saved at %s -- \n', modelPath );


pipe = TwoEarsIdTrainPipe();
pipe.featureCreator = FeatureCreators.FeatureSetRmAmsBlockmean();
% <classname> will be 1, rest -1
oneVsRestLabeler = ... 
    LabelCreators.MultiEventTypeLabeler( 'types', {{classname}}, 'negOut', 'rest' );
pipe.labelCreator = oneVsRestLabeler;
pipe.modelCreator = ...
    ModelTrainers.LoadModelNoopTrainer( ...
        fullfile( modelPath, [classname '.model.mat'] ), ...
        'performanceMeasure', @PerformanceMeasures.BAC,...
        'maxDataSize', inf ...
        );

pipe.trainset = [];
pipe.testset = 'learned_models/IdentityKS/trainTestSets/NIGENS160807_mini_TestSet_1.flist';
pipe.setupData();

sc = SceneConfig.SceneConfiguration();
sc.addSource( SceneConfig.PointSource( ...
        'data', SceneConfig.FileListValGen( 'pipeInput' )  )  );
sc.addSource( SceneConfig.PointSource( ...
        'data', SceneConfig.FileListValGen( ...
               pipe.pipeline.testSet('fileLabel',{{'type',{'general'}}},'fileName') ),...
        'offset', SceneConfig.ValGen( 'manual', 0 ) ),...
    'snr', SceneConfig.ValGen( 'manual', 0 ),...
    'loop', 'randomSeq' );
sc.setLengthRef( 'source', 1, 'min', 30 );
pipe.init( sc );

modelPath = pipe.pipeline.run( 'modelName', classname, 'modelPath', 'test_pointOvrl_testing' );

fprintf( ' -- Model is saved at %s -- \n', modelPath );


