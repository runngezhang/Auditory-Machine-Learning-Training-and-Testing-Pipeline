function trainAndTestSegmented( modelPath )

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

%% train

if nargin < 1 || isempty( modelPath )
    
pipe = TwoEarsIdTrainPipe();
pipe.ksWrapper = DataProcs.SegmentKsWrapper( ...
    'SegmentationTrainerParameters5.yaml', ...
    'useDnnLocKs', false, ...
    'useNsrcsKs', false, ...
    'segSrcAssignmentMethod', 'minDistance', ...
    'varAzmSigma', 15, ...
    'nsrcsBias', 0, ...
    'nsrcsRndPlusMinusBias', 2 );
pipe.featureCreator = FeatureCreators.FeatureSet5Blockmean();
babyLabeler = LabelCreators.MultiEventTypeLabeler( 'types', {{'baby'}}, 'negOut', 'rest' );
pipe.labelCreator = babyLabeler;
pipe.modelCreator = ModelTrainers.GlmNetLambdaSelectTrainer( ...
    'performanceMeasure', @PerformanceMeasures.BAC2, ...
    'cvFolds', 4, ...
    'alpha', 0.99, 'maxDataSize', 1000 );
pipe.modelCreator.verbose( 'on' );

pipe.trainset = 'learned_models/IdentityKS/trainTestSets/NIGENS160807_miniMini_TrainSet_1.flist';
pipe.setupData();

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
sc(1).addSource( SceneConfig.PointSource( ...
        'data', SceneConfig.FileListValGen( ...
               pipe.pipeline.trainSet('fileLabel',{{'type',{'general'}}},'fileName') ),...
        'offset', SceneConfig.ValGen( 'manual', 0 ), ...
        'azimuth', SceneConfig.ValGen( 'manual', +135 )  ),...
    'snr', SceneConfig.ValGen( 'manual', -10 ),...
    'loop', 'randomSeq' );
pipe.init( sc, 'fs', 16000 );

modelPath = pipe.pipeline.run( 'modelName', 'segmModel', 'modelPath', 'test_segmented' );

fprintf( ' -- Model is saved at %s -- \n\n', modelPath );

end

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

sc(1) = SceneConfig.SceneConfiguration();
sc(1).addSource( SceneConfig.PointSource( ...
        'data', SceneConfig.FileListValGen( 'pipeInput' ), ...
        'azimuth', SceneConfig.ValGen( 'manual', -45 ) )  );
sc(1).addSource( SceneConfig.PointSource( ...
        'data', SceneConfig.FileListValGen( ...
               pipe.pipeline.testSet('fileLabel',{{'type',{'general'}}},'fileName') ),...
        'offset', SceneConfig.ValGen( 'manual', 0 ), ...
        'azimuth', SceneConfig.ValGen( 'manual', +45 )  ),...
    'snr', SceneConfig.ValGen( 'manual', 10 ),...
    'loop', 'randomSeq' );
sc(1).addSource( SceneConfig.PointSource( ...
        'data', SceneConfig.FileListValGen( ...
               pipe.pipeline.testSet('fileLabel',{{'type',{'general'}}},'fileName') ),...
        'offset', SceneConfig.ValGen( 'manual', 0 ), ...
        'azimuth', SceneConfig.ValGen( 'manual', +135 )  ),...
    'snr', SceneConfig.ValGen( 'manual', -10 ),...
    'loop', 'randomSeq' );
sc(2) = SceneConfig.SceneConfiguration();
sc(2).addSource( SceneConfig.PointSource( ...
        'data', SceneConfig.FileListValGen( 'pipeInput' ), ...
        'azimuth', SceneConfig.ValGen( 'manual', -45 ) )  );
sc(2).addSource( SceneConfig.PointSource( ...
        'data', SceneConfig.FileListValGen( ...
               pipe.pipeline.testSet('fileLabel',{{'type',{'baby'}}},'fileName') ),...
        'offset', SceneConfig.ValGen( 'manual', 0 ), ...
        'azimuth', SceneConfig.ValGen( 'manual', +45 )  ),...
    'snr', SceneConfig.ValGen( 'manual', 10 ),...
    'loop', 'randomSeq' );
sc(2).addSource( SceneConfig.DiffuseSource( ...
        'offset', SceneConfig.ValGen( 'manual', 0 )  ),...
    'snr', SceneConfig.ValGen( 'manual', 0 ),...
    'loop', 'randomSeq' );
pipe.init( sc, 'fs', 16000 );

[modelPath,~,testPerfresults] = ...
             pipe.pipeline.run( 'modelName', 'segmModel', 'modelPath', 'test_segmented' );

fprintf( ' -- Model is saved at %s -- \n\n', modelPath );

%% analysis

resc = RescSparse( 'uint32', 'uint8' );
resct = RescSparse( 'uint32', 'uint8' );
    
% profile on

% filesema = setfilesemaphore( 'test.mat' );
% if exist( 'test.mat', 'file' )
%     load( 'test.mat' );
% end
% removefilesemaphore( filesema );

scp = struct('nSources',{3},'headPosIdx',{0},'ambientWhtNoise',{1},'whtNoiseSnr',{8});
scp.id = 1;
[resc,resct] = analyzeBlockbased( resc, resct, testPerfresults, scp, 2 );

% filesema = setfilesemaphore( 'test.mat' );
% if exist( 'test.mat', 'file' )
%     fileupdate = load( 'test.mat' );
%     [data,dataIdxs] = fileupdate.resc.getRowIndexed( 1:size( fileupdate.resc.dataIdxs, 1 ) );
%     dataIdxs(:,1) = dataIdxs(:,1)+1;
%     fileupdate.resc = fileupdate.resc.addData( dataIdxs, data );
%     fprintf( ':' );
%     resc = syncResults2( resc, fileupdate.resc, 2, 1 );
%     fprintf( ':' );
%     resct = syncResults2( resct, fileupdate.resct, 2, 1 );
%     fprintf( ':' );
% end
% save( 'test.mat', ...
%       'resc','resct', ...
%       '-v7.3' );
% fprintf( ';\n' );
% removefilesemaphore( filesema );

% profile viewer

tmp = resct.summarizeDown( [7,8] );
tmp = tmp.resc2mat( {@(idx)(idx+3),@(idx)(idx)} );
sens = tmp(:,1) ./ (tmp(:,1)+tmp(:,4))
spec = tmp(:,2) ./ (tmp(:,2)+tmp(:,3))

tmp = resc.summarizeDown( [7,8] );
tmp = tmp.resc2mat( {@(idx)(idx+3),@(idx)(idx)} );
sens = tmp(:,1) ./ (tmp(:,1)+tmp(:,4))
spec = tmp(:,2) ./ (tmp(:,2)+tmp(:,3))


end
