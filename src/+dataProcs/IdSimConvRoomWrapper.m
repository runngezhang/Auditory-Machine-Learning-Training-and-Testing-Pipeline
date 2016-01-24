classdef IdSimConvRoomWrapper < dataProcs.BinSimProcInterface
    
    %% -----------------------------------------------------------------------------------
    properties (Access = protected)
        convRoomSim;
        sceneConfig;
        IRDataset;
        irType;
        reverberationMaxOrder = 5;
    end
    
    %% --------------------------------------------------------------------
    methods (Static)
    end
    
    %% -----------------------------------------------------------------------------------
    methods (Access = public)
        function obj = IdSimConvRoomWrapper( hrirFile )
            obj = obj@dataProcs.BinSimProcInterface();
            obj.irType = irType;
            obj.convRoomSim = simulator.SimulatorConvexRoom();
            set(obj.convRoomSim, ...
                'BlockSize', 4096, ...
                'SampleRate', 44100, ...
                'MaximumDelay', 0.05 ... % for distances up to ~15m
                );
            if strcmpi( obj.irType, 'hrir' )
                set( obj.convRoomSim, 'Renderer', @ssr_binaural );
                obj.IRDataset.dir = simulator.DirectionalIR( xml.dbGetFile( hrirFile ) );
            elseif strcmpi( obj.irType, 'brir' )
                set( obj.convRoomSim, 'Renderer', @ssr_brs );
                if nargin < 3
                    obj.IRDataset.dir = simulator.DirectionalIR( hrirFile );
                else
                    obj.IRDataset.dir = simulator.DirectionalIR( hrirFile, multispeaker_id );
                end
            else
                error( 'Unrecognized irType' );
            end
            obj.IRDataset.fname = hrirFile;
            set(obj.convRoomSim, ...
                'Sinks', simulator.AudioSink(2) ...
                );
            set(obj.convRoomSim.Sinks, ...
                'Position' , [0; 0; 1.75], ...
                'Name', 'Head' ...
                );
            set(obj.convRoomSim, 'Verbose', false);
        end
        %% ----------------------------------------------------------------
        
        function delete( obj )
            obj.convRoomSim.set('ShutDown',true);
        end
        %% ----------------------------------------------------------------
        
        function setSceneConfig( obj, sceneConfig )
            obj.configChanged = true;
            obj.sceneConfig = sceneConfig;
        end
        %% ----------------------------------------------------------------

        function fs = getDataFs( obj )
            fs = obj.convRoomSim.SampleRate;
        end
        
        %% ----------------------------------------------------------------

        function process( obj, inputFileName )
            [obj.earSout, obj.onOffsOut] = obj.makeEarSignalsAndLabels( inputFileName );
        end
        %% ----------------------------------------------------------------
        
    end

    %% -----------------------------------------------------------------------------------
    methods (Access = protected)
        
        function outputDeps = getInternOutputDependencies( obj )
            outputDeps.sceneConfig = copy( obj.sceneConfig );
            if ~isempty( outputDeps.sceneConfig )
                outputDeps.sceneConfig.sources(1).data = []; % configs shall not include filename
            end
            outputDeps.SampleRate = obj.convRoomSim.SampleRate;
            outputDeps.ReverberationMaxOrder = obj.reverberationMaxOrder;
            rendererFunction = functions( obj.convRoomSim.Renderer );
            rendererName = rendererFunction.function;
            outputDeps.Renderer = rendererName;
            persistent hrirHash;
            persistent hrirFName;
            if isempty( hrirFName )  || ...
                    ~strcmpi( hrirFName, obj.IRDataset.dir.Filename )
                hrirFName = obj.IRDataset.dir.Filename;
                hrirHash = calcDataHash( audioread( hrirFName ) );
            end
            outputDeps.hrir = hrirHash;
        end
        %% ----------------------------------------------------------------
        
    end
    
    %% -----------------------------------------------------------------------------------
    methods (Access = private)
        
        function [earSignals, earsOnOffs] = makeEarSignalsAndLabels( obj, wavFileName )
            sceneConfigInst = obj.sceneConfig.instantiate();
            [snd, earsOnOffs] = obj.loadSound( sceneConfigInst, wavFileName );
            obj.setupSceneConfig( sceneConfigInst );
            if isa( sceneConfigInst.sources(1), 'sceneConfig.DiffuseSource' )
                earSignals = snd{1};
            else
                obj.setSourceData( snd{1} );
                obj.simulate();
                earSignals = obj.convRoomSim.Sinks.getData();
            end
            fprintf( '\n' );
            earSignals = earSignals / max( abs( earSignals(:) ) ); % normalize
        end
        %% ----------------------------------------------------------------

        function setSourceData( obj, snd )
            sigLen_s = length( snd ) / obj.convRoomSim.SampleRate;
            obj.convRoomSim.set( 'LengthOfSimulation', sigLen_s );
            obj.convRoomSim.Sinks.removeData();
            obj.convRoomSim.Sources{1}.setData( snd );
        end
        %% ----------------------------------------------------------------
        
        function simulate( obj )
            obj.convRoomSim.set( 'ReInit', true );
            while ~obj.convRoomSim.isFinished()
                obj.convRoomSim.set('Refresh',true);  % refresh all objects
                obj.convRoomSim.set('Process',true);  % processing
                fprintf( '.' );
            end
        end
        %% ----------------------------------------------------------------
        
        function setupSceneConfig( obj, sceneConfig )
            obj.convRoomSim.set( 'ShutDown', true );
            if ~isempty(obj.convRoomSim.Sources), obj.convRoomSim.Sources(2:end) = []; end;
            useSimReverb = ~isempty( sceneConfig.room );
            if useSimReverb
                if strcmpi( obj.irType, 'brir' )
                    error( 'usage of BRIR collides with simulating a room' );
                end
                obj.convRoomSim.Room = sceneConfig.room.value; 
                obj.convRoomSim.Room.set( 'ReverberationMaxOrder', ...
                                          obj.reverberationMaxOrder );
            end
            if isa( sceneConfig.sources(1), 'sceneConfig.PointSource' ) 
                if useSimReverb
                    obj.convRoomSim.Sources{1} = simulator.source.ISMGroup();
                    obj.convRoomSim.Sources{1}.set( 'Room', obj.convRoomSim.Room );
                else
                    obj.convRoomSim.Sources{1} = simulator.source.Point();
                end
                channelMapping = 1;
                if strcmpi( obj.irType, 'hrir' )
                    obj.convRoomSim.Sources{1}.Radius = ...
                        sceneConfig.sources(1).distance.value;
                    obj.convRoomSim.Sources{1}.Azimuth = ...
                        sceneConfig.sources(1).azimuth.value;
                elseif strcmpi( obj.irType, 'brir' )
                    brirSofa = SOFAload(xml.dbGetFile(obj.IRDataset.fname), 'nodata');
                    headOrientation = SOFAconvertCoordinates( ...
                        brirSofa.ListenerView(40,:),'cartesian','spherical' );
                    obj.convRoomSim.Sources{1}.IRDataset = obj.IRDataset.dir;
                    obj.convRoomSim.rotateHead( headOrientation(1), 'absolute' );
                end
            else % ~is diffuse
                obj.convRoomSim.Sources{1} = simulator.source.Binaural();
                channelMapping = [1 2];
            end
            if strcmpi( obj.irType, 'hrir' )
                set( obj.convRoomSim, 'HRIRDataset', obj.IRDataset.dir );
            end
            obj.convRoomSim.Sources{1}.AudioBuffer = simulator.buffer.FIFO( channelMapping );
            obj.convRoomSim.set('Init',true);
        end
        %% ----------------------------------------------------------------

        function [snd, onOffs] = loadSound( obj, sceneConfig, wavFile )
            startOffset = sceneConfig.sources(1).offset.value;
            src = sceneConfig.sources(1).data.value;
            onOffs = [];
            if ischar( src ) % then it is a filename
                snd{1} = getPointSourceSignalFromWav( ...
                    src, obj.convRoomSim.SampleRate, startOffset );
                if strcmpi( IdEvalFrame.readEventClass( wavFile ), 'general' )
                    onOffs = zeros(0,2);
                else
                    onOffs = IdEvalFrame.readOnOffAnnotations( wavFile ) + startOffset;
                end
            elseif isfloat( src ) && size( src, 2 ) == 1
                snd{1} = src;
                nZeros = floor( obj.convRoomSim.SampleRate * startOffset );
                zeroOffset = zeros( nZeros, 1 ) + mean( snd{1} );
                snd{1} = [zeroOffset; snd{1}; zeroOffset];
            else
                error( 'This was not foreseen.' );
            end
            if isa( sceneConfig.sources(1), 'sceneConfig.DiffuseSource' )
                snd{1} = repmat( snd{1}, 1, 2 );
            end
        end
        %% ----------------------------------------------------------------

        
    end
    
    
end
