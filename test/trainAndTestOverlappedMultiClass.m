function trainAndTestOverlappedMultiClass()

addPathsIfNotIncluded( cleanPathFromRelativeRefs( [pwd '/..'] ) ); 
startAMLTTP();

pipe = TwoEarsIdTrainPipe();
pipe.blockCreator = BlockCreators.DistractedBlockCreator( 1.0, 0.4, ...
                                                          'distractorSources', 2,...
                                                          'rejectEnergyThreshold', -30 );
pipe.featureCreator = FeatureCreators.FeatureSet1Blockmean();
% alarm will be 1, baby 2, female 3, fire 4, rest -1. Order decides in case of overlap 
%  (e.g. baby over female or fire) 
typeMulticlassLabeler = ... 
    LabelCreators.MultiEventTypeLabeler( ...
                              'types', {{'alarm'},{'baby'},{'femaleSpeech'},{'fire'}}, ...
                              'srcPrioMethod', 'order' );
pipe.labelCreator = typeMulticlassLabeler;
pipe.modelCreator = ModelTrainers.GlmNetLambdaSelectTrainer( ...
    'performanceMeasure', @PerformanceMeasures.MultinomialBAC, ...
    'family', 'multinomial', ...
    'cvFolds', 4, ...
    'alpha', 0.99 );
pipe.modelCreator.verbose( 'on' );

pipe.trainset = 'learned_models/IdentityKS/trainTestSets/NIGENS160807_mini_TrainSet_1.flist';
pipe.setupData();

sc = SceneConfig.SceneConfiguration();
sc.addSource( SceneConfig.PointSource( ...
        'data', SceneConfig.FileListValGen( 'pipeInput' ) ) );
sc.addSource( SceneConfig.PointSource( ...
        'data', SceneConfig.FileListValGen( ...
                  pipe.pipeline.trainSet('fileLabel',{{'type',{'fire'}}},'fileName') ) ),...
    'loop', 'no',...
    'snr', SceneConfig.ValGen( 'manual', 0 ),...
    'snrRef', 1 );
pipe.init( sc );

modelPath = pipe.pipeline.run( 'modelName', 'overlappedMulticlassModel', 'modelPath', 'overlappedMulticlass' );

fprintf( ' -- Model is saved at %s -- \n\n', modelPath );

%% test

pipe = TwoEarsIdTrainPipe();
pipe.blockCreator = BlockCreators.DistractedBlockCreator( 1.0, 0.4, ...
                                                          'distractorSources', 2,...
                                                          'rejectEnergyThreshold', -30 );
pipe.featureCreator = FeatureCreators.FeatureSet1Blockmean();
% alarm will be 1, baby 2, female 3, fire 4, rest -1. Order decides in case of overlap 
%  (e.g. baby over female or fire) 
typeMulticlassLabeler = ... 
    LabelCreators.MultiEventTypeLabeler( ...
                              'types', {{'alarm'},{'baby'},{'femaleSpeech'},{'fire'}}, ...
                              'srcPrioMethod', 'order' );
pipe.labelCreator = typeMulticlassLabeler;
pipe.modelCreator = ModelTrainers.LoadModelNoopTrainer( ...
    [pwd filesep 'overlappedMulticlass/overlappedMulticlassModel.model.mat'], ...
    'performanceMeasure', @PerformanceMeasures.MultinomialBAC );
pipe.modelCreator.verbose( 'on' );

pipe.testset = 'learned_models/IdentityKS/trainTestSets/NIGENS160807_mini_TestSet_1.flist';
pipe.setupData();

sc = SceneConfig.SceneConfiguration();
sc.addSource( SceneConfig.PointSource( ...
        'data', SceneConfig.FileListValGen( 'pipeInput' ) ) );
sc.addSource( SceneConfig.PointSource( ...
        'data', SceneConfig.FileListValGen( ...
                  pipe.pipeline.testSet('fileLabel',{{'type',{'fire'}}},'fileName') ) ),...
    'loop', 'no',...
    'snr', SceneConfig.ValGen( 'manual', 0 ),...
    'snrRef', 1 );
pipe.init( sc );

modelPath = pipe.pipeline.run( 'modelName', 'overlappedMulticlassModel', 'modelPath', 'overlappedMulticlass' );

fprintf( ' -- Model is saved at %s -- \n\n', modelPath );

