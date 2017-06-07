function trainAndTestSegmented()

addPathsIfNotIncluded( cleanPathFromRelativeRefs( [pwd '/..'] ) ); 
startAMLTTP();
addPathsIfNotIncluded( {...
    cleanPathFromRelativeRefs( [pwd '/../../segmentation-training-pipeline/src'] ), ... 
    cleanPathFromRelativeRefs( [pwd '/../../segmentation-training-pipeline/external/data-hash'] ), ...
    cleanPathFromRelativeRefs( [pwd '/../../segmentation-training-pipeline/external/yaml-matlab'] ) ...
    } );
segmModelFileName = '70c4feac861e382413b4c4bfbf895695.mat';
mkdir( fullfile( db.tmp, 'learned_models', 'SegmentationKS' ) );
copyfile( ['./' segmModelFileName], ...
          fullfile( db.tmp, 'learned_models', 'SegmentationKS', segmModelFileName ), ...
          'f' );

pipe = TwoEarsIdTrainPipe();
pipe.ksWrapper = DataProcs.SegmentKsWrapper( ...
    'SegmentationTrainerParameters5.yaml', ...
    'useDnnLocKs', false, ...
    'useNsrcsKs', false, ...
    'segSrcAssignmentMethod', 'minPermutedDistance', ...
    'varAzmSigma', 15, ...
    'nsrcsBias', 0, ...
    'nsrcsRndPlusMinusBias', 2 );
pipe.featureCreator = FeatureCreators.FeatureSet5Blockmean();
babyLabeler = LabelCreators.MultiEventTypeLabeler( 'types', {{'baby'}}, 'negOut', 'rest' );
pipe.labelCreator = babyLabeler;
pipe.modelCreator = ModelTrainers.GlmNetLambdaSelectTrainer( ...
    'performanceMeasure', @PerformanceMeasures.BAC2, ...
    'cvFolds', 4, ...
    'alpha', 0.99 );
pipe.modelCreator.verbose( 'on' );

pipe.trainset = 'learned_models/IdentityKS/trainTestSets/NIGENS160807_miniMini_TrainSet_1.flist';
pipe.setupData();

sc(2) = SceneConfig.SceneConfiguration();
sc(2).addSource( SceneConfig.PointSource( ...
        'data', SceneConfig.FileListValGen( 'pipeInput' ), ...
        'azimuth', SceneConfig.ValGen( 'manual', -45 ) )  );
sc(2).addSource( SceneConfig.PointSource( ...
        'data', SceneConfig.FileListValGen( ...
               pipe.pipeline.trainSet('fileLabel',{{'type',{'general'}}},'fileName') ),...
        'offset', SceneConfig.ValGen( 'manual', 0 ), ...
        'azimuth', SceneConfig.ValGen( 'manual', +45 )  ),...
    'snr', SceneConfig.ValGen( 'manual', 10 ),...
    'loop', 'randomSeq' );
sc(2).addSource( SceneConfig.PointSource( ...
        'data', SceneConfig.FileListValGen( ...
               pipe.pipeline.trainSet('fileLabel',{{'type',{'general'}}},'fileName') ),...
        'offset', SceneConfig.ValGen( 'manual', 0 ), ...
        'azimuth', SceneConfig.ValGen( 'manual', +135 )  ),...
    'snr', SceneConfig.ValGen( 'manual', -10 ),...
    'loop', 'randomSeq' );
sc(1) = SceneConfig.SceneConfiguration();
sc(1).addSource( SceneConfig.PointSource( ...
        'data', SceneConfig.FileListValGen( 'pipeInput' ), ...
        'azimuth', SceneConfig.ValGen( 'manual', -45 ) )  );
sc(1).addSource( SceneConfig.PointSource( ...
        'data', SceneConfig.FileListValGen( ...
               pipe.pipeline.trainSet('fileLabel',{{'type',{'general'}}},'fileName') ),...
        'offset', SceneConfig.ValGen( 'manual', 0 ), ...
        'azimuth', SceneConfig.ValGen( 'manual', +45 )  ),...
    'snr', SceneConfig.ValGen( 'manual', 10 ),...
    'loop', 'randomSeq' );
sc(1).addSource( SceneConfig.DiffuseSource( ...
        'offset', SceneConfig.ValGen( 'manual', 0 )  ),...
    'snr', SceneConfig.ValGen( 'manual', 0 ) );
pipe.init( sc, 'fs', 16000 );

modelPath = pipe.pipeline.run( 'modelName', 'segmModel', 'modelPath', 'test_segmented' );

fprintf( ' -- Model is saved at %s -- \n\n', modelPath );

%% test

pipe = TwoEarsIdTrainPipe();
pipe.ksWrapper = DataProcs.SegmentKsWrapper( ...
    'SegmentationTrainerParameters5.yaml', ...
    'useDnnLocKs', false, ...
    'useNsrcsKs', false, ...
    'segSrcAssignmentMethod', 'minPermutedDistance', ...
    'varAzmSigma', 15, ...
    'nsrcsBias', 0, ...
    'nsrcsRndPlusMinusBias', 2 );
pipe.featureCreator = FeatureCreators.FeatureSet5Blockmean();
babyLabeler = LabelCreators.MultiEventTypeLabeler( 'types', {{'baby'}}, 'negOut', 'rest' );
pipe.labelCreator = babyLabeler;
pipe.modelCreator = ModelTrainers.LoadModelNoopTrainer( ...
    [pwd filesep 'test_segmented/segmModel.model.mat'], ...
    'performanceMeasure', @PerformanceMeasures.BAC );
pipe.modelCreator.verbose( 'on' );

pipe.testset = 'learned_models/IdentityKS/trainTestSets/NIGENS160807_miniMini_TestSet_1.flist';
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
