function exp_maxData()

addpath( '../..' );
startIdentificationTraining();

featureCreators = {?featureCreators.FeatureSet1Blockmean,...
                   ?featureCreators.FeatureSet1Blockmean2Ch};
azimuths = {{0,0},...
    {0,45},{45,0},{22.5,-22.5},{67.5,112.5},{-157.5,157.5},...
    {0,90},{22.5,112.5},{45,135},{90,180},{22.5,-67.5},{45,-45},{90,0},{-157.5,112.5},...
    {0,180},{22.5,-157.5},{45,-135},{67.5,-112.5},{90,-90}}; % 19 cfgs
snrs = {0,-10,10,-20};
datasets = {'learned_models/IdentityKS/trainTestSets/NIGENS_75pTrain_TrainSet_1.flist',...
            'learned_models/IdentityKS/trainTestSets/NIGENS_75pTrain_TestSet_1.flist',...
            'learned_models/IdentityKS/trainTestSets/NIGENS_75pTrain_TrainSet_2.flist',...
            'learned_models/IdentityKS/trainTestSets/NIGENS_75pTrain_TestSet_2.flist',...
            'learned_models/IdentityKS/trainTestSets/NIGENS_75pTrain_TrainSet_3.flist',...
            'learned_models/IdentityKS/trainTestSets/NIGENS_75pTrain_TestSet_3.flist',...
            'learned_models/IdentityKS/trainTestSets/NIGENS_75pTrain_TrainSet_4.flist',...
            'learned_models/IdentityKS/trainTestSets/NIGENS_75pTrain_TestSet_4.flist'
            };
classes = {'alarm','baby','femaleSpeech','fire','crash','dog','engine','footsteps',...
           'knock','phone','piano'};

doneCfgs = {};
modelpathes = {};
% eval = {};
if exist( 'pds_expsMaxData.mat', 'file' )
    load( 'pds_expsMaxData' );
else
    warning( 'mat file not found' );
    pause;
end

for dd = 1
for cc = 1 : 2
    pdTrain(cc,dd);
end
end


    function pdTrain(cc,dd)
        for ss = 1
        for ff = 2
        for aa = [1 4 9]
        for mds = [50000 30000 15000 5000]
        for bd = [0 1]
            
            fprintf( '\n\n==============\nTraining; cc = %d, dd = %d, ff = %d, ss = %d, aa = %d, mds = %d, bd = %d.==============\n\n', ...
                cc, dd, ff, ss, aa, mds, bd );
            if any( cellfun( @(x)(all(x==[cc dd ss ff aa mds bd])), doneCfgs ) )
                continue;
            end
            
            pipe = TwoEarsIdTrainPipe();
            pipe.featureCreator = feval( featureCreators{ff}.Name );
            pipe.modelCreator = modelTrainers.GlmNetLambdaSelectTrainer( ...
                'performanceMeasure', @performanceMeasures.BAC2, ...
                'cvFolds', 7, ...
                'alpha', 0.99, ...
                'maxDataSize', mds );
            modelTrainers.Base.balMaxData( true, bd );
            pipe.modelCreator.verbose( 'on' );
            
            pipe.trainset = datasets{dd};
            pipe.setupData();
            
            sc = sceneConfig.SceneConfiguration();
            sc.addSource( sceneConfig.PointSource( ...
                'azimuth',sceneConfig.ValGen('manual',azimuths{aa}{1}) ) );
            sc.addSource( sceneConfig.PointSource( ...
                'azimuth',sceneConfig.ValGen('manual',azimuths{aa}{2}), ...
                'data',sceneConfig.FileListValGen(pipe.pipeline.data('general',:,'wavFileName')),...
                'offset', sceneConfig.ValGen('manual',0.0) ),...
                sceneConfig.ValGen( 'manual', snrs{ss} ),...
                true ); % loop
            pipe.setSceneConfig( sc );
            
            pipe.init();
            modelpathes{cc,dd,ss,ff,aa,mds,bd} = pipe.pipeline.run( classes(cc), 0 );
            doneCfgs{end+1} = [cc dd ss ff aa mds bd];
            
            save( 'pds_expsMaxData', ...
                'doneCfgs', 'modelpathes' );
        end
        end
        end
        end
        end
    end
%     function pdTest(cc,dd)
%         for ss = 1 : numel( snrs )
%         for ff = 1 : numel( featureCreators )
%         for aa = azmCfgIdxs
%             
%             fprintf( '\n\n==============\nTesting; cc = %d, dd = %d, ff = %d, ss = %d, aa = %d.==============\n\n', ...
%                 cc, dd, ff, ss, aa );
%             if any( cellfun( @(x)(all(x==[cc dd ss ff aa])), doneCfgs ) )
%                 continue;
%             end
%             
%             pipe = TwoEarsIdTrainPipe();
%             pipe.featureCreator = feval( featureCreators{ff}.Name );
%             pipe.modelCreator = modelTrainers.GlmNetLambdaSelectTrainer( ...
%                 'performanceMeasure', @performanceMeasures.BAC2, ...
%                 'cvFolds', 7, ...
%                 'alpha', 0.99 );
%             pipe.modelCreator.verbose( 'on' );
%             
%             pipe.trainset = datasets{dd};
%             pipe.setupData();
%             
%             sc = sceneConfig.SceneConfiguration();
%             sc.addSource( sceneConfig.PointSource( ...
%                 'azimuth',sceneConfig.ValGen('manual',azimuths{aa}{1}) ) );
%             sc.addSource( sceneConfig.PointSource( ...
%                 'azimuth',sceneConfig.ValGen('manual',azimuths{aa}{2}), ...
%                 'data',sceneConfig.FileListValGen(pipe.pipeline.data('general',:,'wavFileName')),...
%                 'offset', sceneConfig.ValGen('manual',0.0) ),...
%                 sceneConfig.ValGen( 'manual', snrs{ss} ),...
%                 true ); % loop
%             pipe.setSceneConfig( sc );
%             
%             pipe.init();
%             modelpathes{cc,dd,ss,ff,aa} = pipe.pipeline.run( classes(cc), 0 );
%             doneCfgs{end+1} = [cc dd ss ff aa];
%             
%             save( ['pds_' strrep(num2str(azmCfgIdxs),' ','_') '_glmnet'], ...
%                 'doneCfgs', 'modelpathes' );
%         end
%         end
%         end
%     end

end
