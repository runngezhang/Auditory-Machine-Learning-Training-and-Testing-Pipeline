    function trainAndTestSegmented()

addPathsIfNotIncluded( cleanPathFromRelativeRefs( [pwd '/..'] ) ); 
startIdentificationTraining();
addPathsIfNotIncluded( {...
    cleanPathFromRelativeRefs( [pwd '/../../segmentation-training-pipeline/src'] ), ... 
    cleanPathFromRelativeRefs( [pwd '/../../segmentation-training-pipeline/external/data-hash'] ), ...
    cleanPathFromRelativeRefs( [pwd '/../../segmentation-training-pipeline/external/yaml-matlab'] ) ...
    } );
segmModelFileName = '786468537e1df4e91d888a263917fdb1.mat';
mkdir( fullfile( xml.dbTmp, 'learned_models', 'SegmentationKS' ) );
copyfile(  segmModelFileName, ...
          fullfile( xml.dbTmp, 'learned_models', 'SegmentationKS', segmModelFileName ), ...
          'f' );

pipe = TwoEarsIdTrainPipe();
pipe.ksWrapper = DataProcs.SegmentKsWrapper( 'SegmentationTrainerParameters.yaml' );
pipe.featureCreator = FeatureCreators.FeatureSetRmAmsBlockmean();
babyLabeler = LabelCreators.MultiEventTypeLabeler( 'types', {{'baby'}}, 'negOut', 'rest' );
pipe.labelCreator = babyLabeler;
pipe.modelCreator = ModelTrainers.GlmNetLambdaSelectTrainer( ...
    'performanceMeasure', @PerformanceMeasures.BAC2, ...
    'cvFolds', 4, ...
    'alpha', 0.99 );
pipe.modelCreator.verbose( 'on' );

pipe.trainset = 'learned_models/IdentityKS/trainTestSets/NIGENS160807_mini_TrainSet_1.flist';
pipe.setupData();

sc = SceneConfig.SceneConfiguration();
sc.addSource( SceneConfig.PointSource( ...
        'data', SceneConfig.FileListValGen( 'pipeInput' ), ...
        'azimuth', SceneConfig.ValGen( 'manual', -45 ) )  );
sc.addSource( SceneConfig.PointSource( ...
        'data', SceneConfig.FileListValGen( ...
               pipe.pipeline.trainSet('fileLabel',{{'type',{'general'}}},'fileName') ),...
        'offset', SceneConfig.ValGen( 'manual', 0 ), ...
        'azimuth', SceneConfig.ValGen( 'manual', +45 )  ),...
    'snr', SceneConfig.ValGen( 'manual', 0 ),...
    'loop', 'randomSeq' );
pipe.init( sc, 'fs', 16000 );

modelPath = pipe.pipeline.run( 'modelName', 'segmModel', 'modelPath', 'test_segmented' );

fprintf( ' -- Model is saved at %s -- \n\n', modelPath );

%% test

pipe = TwoEarsIdTrainPipe();
pipe.ksWrapper = DataProcs.SegmentKsWrapper( 'SegmentationTrainerParameters.yaml', 'BlockSize', 1.0 );
pipe.ksWrapper.varAzmPrior = 20;
pipe.featureCreator = FeatureCreators.FeatureSetRmAmsBlockmean();
babyLabeler = LabelCreators.MultiEventTypeLabeler( 'types', {{'baby'}}, 'negOut', 'rest' );
pipe.labelCreator = babyLabeler;
pipe.modelCreator = ModelTrainers.LoadModelNoopTrainer( ...
    [pwd filesep 'test_segmented/segmModel.model.mat'], ...
    'performanceMeasure', @PerformanceMeasures.BAC );
pipe.modelCreator.verbose( 'on' );

pipe.testset = 'learned_models/IdentityKS/trainTestSets/NIGENS160807_mini_TestSet_1.flist';
pipe.setupData();

sc = SceneConfig.SceneConfiguration();
sc.addSource( SceneConfig.PointSource( ...
        'data', SceneConfig.FileListValGen( 'pipeInput' ), ...
        'azimuth', SceneConfig.ValGen( 'manual', -45 )   )  );
sc.addSource( SceneConfig.PointSource( ...
        'data', SceneConfig.FileListValGen( ...
               pipe.pipeline.testSet('fileLabel',{{'type',{'general'}}},'fileName') ),...
        'offset', SceneConfig.ValGen( 'manual', 0 ), ...
        'azimuth', SceneConfig.ValGen( 'manual', +45 )  ),...
    'snr', SceneConfig.ValGen( 'manual', 0 ),...
    'loop', 'randomSeq' );
pipe.init( sc, 'fs', 16000 );

modelPath = pipe.pipeline.run( 'modelName', 'segmModel', 'modelPath', 'test_segmented' );

fprintf( ' -- Model is saved at %s -- \n\n', modelPath );
