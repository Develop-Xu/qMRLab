classdef ihMT < AbstractModel
    % ihMT:   inhomogenuous Magnetization Transfer
    %
    % Assumptions: 
    %
    % Inputs:
    %   R                I
    %   (Mask)             Binary mask to exclude voxels from smoothing
    %
    % Outputs:
    %	Fi          F
    %
    % Protocol:
    %	NONE
    %
    % Options:
    %   (
    %
    % Example of command line usage:
    %
    %   For more examples: <a href="matlab: qMRusage(ihMT);">qMRusage(ihMT)</a>
    %
    % Author: 
    %
    % References:
    %   Please cite the following if you use this module:
    %     Karakuzu A., Boudreau M., Duval T.,Boshkovski T., Leppert I.R., Cabana J.F., 
    %     Gagnon I., Beliveau P., Pike G.B., Cohen-Adad J., Stikov N. (2020), qMRLab: 
    %     Quantitative MRI analysis, under one umbrella doi: 10.21105/joss.02343
    properties (Hidden=true)
        onlineData_url = '';
    end
    
    properties
        MRIinputs = {'MTw_dual', 'MTw_single', 'T1w', 'PDw', 'B1map', 'Mask'};
        xnames = {};
        voxelwise = 0; % 0, if the analysis is done matricially
        % 1, if the analysis is done voxel per voxel
        % Protocol
        Prot = struct('MTw_dual',struct('Format',{{'FlipAngle' 'TR'}},...
                                   'Mat',  [9 0.028]),...
                      'MTw_single',struct('Format',{{'FlipAngle' 'TR'}},...
                                   'Mat',  [9 0.028]),...
                      'T1w',struct('Format',{{'FlipAngle' 'TR'}},...
                                   'Mat',  [20 0.030]),...
                      'PDw',struct('Format',{{'FlipAngle' 'TR'}},...
                                   'Mat',  [5 0.030]));
                               
        ProtStyle = struct('prot_namespace',{{'MTw_dual', 'MTw_single', 'T1w','PDw'}}, ...
        'style',repmat({'TableNoButton'},[1,4]));
        
        %Option panel: ModelBasedB1corrected parameters
            buttons ={'PANEL','Sequence simulation',15,...
            'B1rms',9,...
            'Number saturation pulse',2,...
            'Pulse duration',0.768,...
            'Pulse gap duration',0.6,...
            'TR',28,...
            'WExcDur',3,...
            'Number excitation',1,...
            'Frequency pattern',{'dualAlternate','single','dualContinuous'},...
            'Delta',7000,...
            'FlipAngle',9,...
            'Saturation pulse shape',{'hanning','gaussian','square'},...
            '##fitValues Directory',10,...
            '##fitValues Name',10,...
            '##MTsatValues Name',10,...
            'Run Sequence Simulation','pushbutton',...
            'PANEL','Correlate M0bapp VS R1',2,...
            'Same Imaging Protocol',false,...
            'b1rms',6.8};
        
        
        options = struct();
    end
    % Inherit these from public properties of FilterClass
    % Model options
    % buttons ={};
    % options = struct(); % structure filled by the buttons. Leave empty in the code
    
    methods
        % Constructor
        function obj = ihMT()
            obj.options = button2opts(obj.buttons);
            obj = UpdateFields(obj);
        end
        
        function [obj,fitValues] = UpdateFields(obj)
            if obj.options.Sequencesimulation_Frequencypattern == "dualAlternate"
                obj.options.Sequencesimulation_fitValuesName = "fitValues_dualAlt";
                obj.options.Sequencesimulation_MTsatValuesName = "MTsatValues_dualAlt";
            end
                
            if obj.options.Sequencesimulation_Frequencypattern == "single"
                obj.options.Sequencesimulation_fitValuesName = "fitValues_single";
                obj.options.Sequencesimulation_MTsatValuesName = "MTsatValues_single";
            end
                
            if obj.options.Sequencesimulation_Frequencypattern == "dualContinuous"
               obj.options.Sequencesimulation_fitValuesName = "fitValues_dualCont";
               obj.options.Sequencesimulation_MTsatValuesName = "MTsatValues_dualCont";
            end

            %Running simulation (takes long time)
            if obj.options.Sequencesimulation_RunSequenceSimulation
                %Setting the fitValues directory
                obj.options.Sequencesimulation_fitValuesDirectory = uigetdir(pwd,'Select directory to save fitValues');
                [fitValues,~]=simSeq_M0b_R1obs(obj);
            else
                obj.options.Sequencesimulation_fitValuesDirectory = pwd;
            end
        end
        
        function FitResult = fit(obj,data)
            %Loading fitValues results from simulation
            disp('Run a new sequence simulation or load <<fitValues.mat>> results from a previous simulation')
            [FileName_dual,PathName_dual] = uigetfile('*.mat','Load fitValues structure - DUAL');
            [FileName_single,PathName_single] = uigetfile('*.mat','Load fitValues structure - SINGLE');
            
            fitValues_dual = load([PathName_dual filesep FileName_dual]);
            fitValues_single = load([PathName_single filesep FileName_single]);
            
            %strcat(obj.options.Sequencesimulation_fitValuesDirectory, filesep, obj.options.Sequencesimulation_fitValuesName, '.mat')
            
            MTparams = obj.Prot.MTw_dual.Mat;
            PDparams = obj.Prot.PDw.Mat;
            T1params = obj.Prot.T1w.Mat;
            
            data_dual = rmfield(data,'MTw_single');
            data_dual.MTw = data_dual.MTw_dual;
            data_single = rmfield(data,'MTw_dual');
            data_single.MTw = data_single.MTw_single;

            %Correlate M0b_app VS R1
            if ~obj.options.CorrelateM0bappVSR1_SameImagingProtocol
                %Process MTsat dual
                obj.options.Sequencesimulation_fitValuesDirectory = PathName_dual;
                obj.options.Sequencesimulation_fitValuesName = FileName_dual;
                [FitResult.M0b_app_dual,FitResult.fit_qual_d,FitResult.comb_res_d,fitValues_dual]=sampleCode_calc_M0bappVsR1_1dataset(data_dual,MTparams,PDparams,T1params,fitValues_dual,obj);
                
                %Process MTsat single
                obj.options.Sequencesimulation_fitValuesDirectory = PathName_single;
                obj.options.Sequencesimulation_fitValuesName = FileName_single;
                [FitResult.M0b_app_single,FitResult.fit_qual_s,FitResult.comb_res_s,fitValues_single]=sampleCode_calc_M0bappVsR1_1dataset(data_single,MTparams,PDparams,T1params,fitValues_single,obj);
            end
            
            %Correct MTsat data
            %Process MTsat dual
            obj.options.Sequencesimulation_fitValuesDirectory = PathName_dual;
            obj.options.Sequencesimulation_fitValuesName = FileName_dual;
            [MTsat_b1corr_dual, MTsatuncor_dual,R1_dual,R1uncor_dual] = sample_code_correct_MTsat(data_dual,MTparams,PDparams,T1params,fitValues_dual,obj);
            FitResult.MTSATcor_dual = MTsat_b1corr_dual;
            FitResult.MTSAT_dual = MTsatuncor_dual;
            FitResult.T1cor_dual = 1./R1_dual;
            FitResult.T1_dual = 1./R1uncor_dual;
            
            %Process MTsat single
            obj.options.Sequencesimulation_fitValuesDirectory = PathName_single;
            obj.options.Sequencesimulation_fitValuesName = FileName_single;
            [MTsat_b1corr_single, MTsatuncor_single,R1_single,R1uncor_single] = sample_code_correct_MTsat(data_single,MTparams,PDparams,T1params,fitValues_single,obj);
            FitResult.MTSATcor_single = MTsat_b1corr_single;
            FitResult.MTSAT_single = MTsatuncor_single;
            FitResult.T1cor_single = 1./R1_single;
            FitResult.T1_single = 1./R1uncor_single;
            
            %ihMTsat map
            FitResult.ihMTsatcor = MTsat_b1corr_dual - MTsat_b1corr_single;
            FitResult.ihMTsat = MTsatuncor_dual - MTsatuncor_single;
        end
        
    end
    methods(Access = protected)
        function obj = qMRpatch(obj,loadedStruct, version)
            obj = qMRpatch@AbstractModel(obj,loadedStruct, version);
            
        end
        
    end
    
end