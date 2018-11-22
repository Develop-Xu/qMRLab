classdef DCE < AbstractModel % Name your Model
% DCE :  Dynamic Contrast Enhanced
%<a href="matlab: figure, imshow CustomExample.png ;">Pulse Sequence Diagram</a>
%
% Assumptions:
% (1)FILL
% (2) 
%
% Inputs:
%   PWI                 4D Dynamic Contrast Enhanced
%   (Mask)              Binary mask to accelerate the fitting
%
% Fitted Parameters:
%    Param1    
%    Param2    
%
% Non-Fitted Parameters:
%    residue                    Fitting residue.
%
% Options:
%   Q-space regularization      
%       Smooth q-space data per shell prior fitting
%
% Example of command line usage:
%   For more examples: <a href="matlab: qMRusage(CustomExample);">qMRusage(CustomExample)</a>
%
% Author: 
%
% References:
%   Please cite the following if you use this module:
%     FILL
%   In addition to citing the package:
%     Cabana J-F, Gu Y, Boudreau M, Levesque IR, Atchia Y, Sled JG, Narayanan S, Arnold DL, Pike GB, Cohen-Adad J, Duval T, Vuong M-T and Stikov N. (2016), Quantitative magnetization transfer imaging made easy with qMTLab: Software for data simulation, analysis, and visualization. Concepts Magn. Reson.. doi: 10.1002/cmr.a.21357

    properties
        MRIinputs = {'PWI','Mask'}; % used in the data panel 
        
        % fitting options
        xnames = { 'gamma_K','gamma_n','gamma_a'}; % name of the parameters to fit
        voxelwise = 1; % 1--> input data in method 'fit' is 1D (vector). 0--> input data in method 'fit' is 4D.
        st           = [ 300        35       0.5  ]; % starting point
        lb            = [ 0       0       0   ]; % lower bound
        ub           = [ inf      100       50  ]; % upper bound
        fx            = [ 0       0        0  ]; % fix parameters
        
        % Protocol
        Prot = struct('PWI',... % Creates a Panel Data4D Protocol in Model Options menu
                        struct('Format',{{'TR'; 'TE'; 'Nvolumes'}},... % columns name
                        'Mat', [1.5; 0.040; 40])); % provide a default protocol (Nx2 matrix)
        
        % Model options
        buttons = {'SMS',true,'Model',{'simple','advanced'}};
        options= struct();
        
    end
    
    methods
        function obj = DCE
            obj.options = button2opts(obj.buttons); % converts buttons values to option structure
        end
        
        function T2star = equation(obj, x)
            % Compute the Signal Model based on parameters x. 
            % x can be both a structure (FieldNames based on xnames) or a
            % vector (same order as xnames).
            x = struct2mat(x,obj.xnames);
            K = x(1);
            n = x(2);
            a = x(3);
            %% Relaxivity variation
            TR = obj.Prot.PWI.Mat(1);
            Nvol = obj.Prot.PWI.Mat(3);
            time = 0:TR:TR*(Nvol-1);
            time = time';
            T2star = K*gampdf(time,n,a);% *time.^n.*exp(-a*time);
            
        end
        
        function FitResults = fit(obj,data)
            %  Fit data using model equation.
            %  data is a structure. FieldNames are based on property
            %  MRIinputs. 
            
            if obj.options.SMS
                % buttons values can be access with obj.options
            end
            
            % set the right value for 
            obj.Prot.PWI.Mat(3) = length(data.PWI);
            % param
            TE = obj.Prot.PWI.Mat(2);
            TR = obj.Prot.PWI.Mat(1);
            Nvol = obj.Prot.PWI.Mat(3);
            time = 0:TR:TR*(Nvol-1);
            time = time';
            
            % data
            PWI = double(data.PWI);
            % normalization
            PWInorm = pwiNorm(PWI);
            T2star = pwi2T2star(PWInorm,TE);
            T2star = max(.1,T2star);
            Smax = max(T2star);
            T2star = T2star./Smax;
            % remove 0.7*T2star(tpic)
            T2star(find(diff(T2star<0.4*max(T2star)),1,'last')+4:Nvol) = 0;
            opt = optimoptions('lsqcurvefit','Display','off');
            [xopt, resnorm] = lsqcurvefit(@(x,xdata) obj.equation(addfix(obj.st,x,obj.fx)),...
                     obj.st(~obj.fx), [], T2star, obj.lb(~obj.fx), obj.ub(~obj.fx),opt);
%                  
            %  convert fitted vector xopt to a structure.
            FitResults = cell2struct(mat2cell(xopt(:),ones(length(xopt),1)),obj.xnames,1);
            FitResults.gamma_K = FitResults.gamma_K*Smax;
            FitResults.resnorm=resnorm;
            FitResults.CBV = trapz(time,equation(obj, FitResults));
        end
        
        
        function plotModel(obj, FitResults, data)
            %  Plot the Model and Data.
            if nargin<2, qMRusage(obj,'plotModel'), FitResults=obj.st; end
            
            %Get fitted Model signal
            T2star = equation(obj, FitResults);
            
            %Get the varying acquisition parameter
            TR = obj.Prot.PWI.Mat(1);
            Nvol = obj.Prot.PWI.Mat(3);
            time = 0:TR:TR*(Nvol-1);
            time = time';
            
            % Plot Fitted Model
            plot(time,T2star,'b-')
            
            % Plot Data
            if exist('data','var')
                TE = obj.Prot.PWI.Mat(2);
                % norm
                PWInorm = pwiNorm(data.PWI);
                T2star = pwi2T2star(PWInorm,TE);
                time = 0:TR:TR*(length(T2star)-1);
                hold on
                plot(time,T2star,'r+')
                hold off
            end
            legend({'Model','Data'})
        end
        
        function FitResults = Sim_Single_Voxel_Curve(obj, x, Opt, display)
            % Compute Smodel
            Smodel = equation(obj, x);
            % add rician noise
            sigma = max(Smodel)/Opt.SNR;
            data.Data4D = random('rician',Smodel,sigma);
            % fit the noisy synthetic data
            FitResults = fit(obj,data);
            % plot
            if display
                plotModel(obj, FitResults, data);
            end
        end

    end
end

function PWInorm = pwiNorm(PWI)
PWInorm = PWI/PWI(1);
end

function T2star = pwi2T2star(Snorm,TE)
T2star = -1/TE*log(Snorm);
end