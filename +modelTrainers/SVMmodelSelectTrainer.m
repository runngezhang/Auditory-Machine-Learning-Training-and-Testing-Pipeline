classdef SVMmodelSelectTrainer < modelTrainers.HpsTrainer & Parameterized
    
    %% -----------------------------------------------------------------------------------
    properties (Access = private)
    end
    
    %% -----------------------------------------------------------------------------------
    methods

        function obj = SVMmodelSelectTrainer( varargin )
            pds{1} = struct( 'name', 'hpsEpsilons', ...
                             'default', 0.001, ...
                             'valFun', @(x)(isfloat(x) && x > 0) );
            pds{2} = struct( 'name', 'hpsKernels', ...
                             'default', 0, ...
                             'valFun', @(x)(rem(x,1) == 0 && all(x == 0 | x == 2)) );
            pds{3} = struct( 'name', 'hpsCrange', ...
                             'default', [-6 2], ...
                             'valFun', @(x)(isfloat(x) && length(x)==2 && x(1) < x(2)) );
            pds{4} = struct( 'name', 'hpsGammaRange', ...
                             'default', [-12 3], ...
                             'valFun', @(x)(isfloat(x) && length(x)==2 && x(1) < x(2)) );
            pds{5} = struct( 'name', 'makeProbModel', ...
                             'default', false, ...
                             'valFun', @islogical );
            obj = obj@Parameterized( pds );
            obj = obj@modelTrainers.HpsTrainer( varargin{:} );
            obj.setParameters( true, ...
                'buildCoreTrainer', @modelTrainers.SVMtrainer, ...
               'hpsCoreTrainerParams', {'makeProbModel', false}, ...
                varargin{:} );
            obj.setParameters( false, ...
                'finalCoreTrainerParams', ...
                    {'makeProbModel', obj.parameters.makeProbModel} );
        end
        %% -------------------------------------------------------------------------------

    end
    
    %% -----------------------------------------------------------------------------------
    methods (Access = protected)
        
        function hpsSets = getHpsGridSearchSets( obj )
            hpsCs = logspace( obj.parameters.hpsCrange(1), ...
                              obj.parameters.hpsCrange(2), ...
                              obj.parameters.hpsSearchBudget );
            hpsGs = logspace( obj.parameters.hpsGammaRange(1), ...
                              obj.parameters.hpsGammaRange(2), ...
                              obj.parameters.hpsSearchBudget );
            [kGrid, eGrid, cGrid, gGrid] = ndgrid( ...
                                                obj.parameters.hpsKernels, ...
                                                obj.parameters.hpsEpsilons, ...
                                                hpsCs, ...
                                                hpsGs );
            hpsSets = [kGrid(:), eGrid(:), cGrid(:), gGrid(:)];
            hpsSets(hpsSets(:,1)~=2,4) = 1; %set gamma equal for kernels other than rbf
            hpsSets = unique( hpsSets, 'rows' );
            hpsSets = cell2struct( num2cell(hpsSets), {'kernel','epsilon','c','gamma'},2 );
        end
        %% -------------------------------------------------------------------------------
        
        function refinedHpsTrainer = refineGridTrainer( obj, hps )
            refinedHpsTrainer = SVMmodelSelectTrainer( obj.parameters );
            best3LogMean = @(fn)(mean( log10( [hps.params(end-2:end).(fn)] ) ));
            eRefinedRange = getCenteredHalfRange( ...
                log10(obj.parameters.hpsEpsilons), best3LogMean('epsilon') );
            cRefinedRange = getCenteredHalfRange( ...
                obj.parameters.hpsCrange, best3LogMean('c') );
            gRefinedRange = getCenteredHalfRange( ...
                obj.parameters.hpsGammaRange, best3LogMean('gamma') );
            refinedHpsTrainer.setParameters( false, ...
                'hpsGammaRange', gRefinedRange, ...
                'hpsCrange', cRefinedRange, ...
                'hpsEpsilons', unique( 10.^[eRefinedRange, best3LogMean('epsilon')] ) );
        end
        %% -------------------------------------------------------------------------------
        
    end

    %% -----------------------------------------------------------------------------------
    methods (Access = private)
        
    end
    
end