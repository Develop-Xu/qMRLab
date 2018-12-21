function obj = corSkipped(obj,crObj)

  % Developers: * qmrstat.getBivarCorInputs (Static)
  %               -- calls qmrstat.getBiVarCorVec (Private)
  %               ---- calls qmrstat.cleanNan (Private)
  %             * Pearson (External/robustcorrtool)

  % getBivarCorInputs includes validation step. Validation step
  % is not specific to the object arrays with 2 objects. N>2 can
  % be also validated by qmrstat.validate (private).

  if nargin<2

    crObj = obj.Object.Correlation;

  elseif nargin == 2

    obj.Object.Correlation = crObj;

  end

  [comb, lbIdx] = qmrstat.corSanityCheck(crObj);

  szcomb = size(comb);
  for kk = 1:szcomb(1) % Loop over correlation matrix combinations
    for zz = 1:lbIdx % Loope over labeled mask indexes (if available)

      % Combine pairs
      curObj = [crObj(1,comb(kk,1)),crObj(1,comb(kk,2))];

      if lbIdx >1

        % If mask is labeled, masking will be done by the corresponding
        % index, if index is passed as the third parameter.
        [VecX,VecY,XLabel,YLabel,sig] = qmrstat.getBivarCorInputs(obj,curObj,curObj(1).LabelIdx(zz));

      else
        % If mask is binary, then index won't be passed.
        [VecX,VecY,XLabel,YLabel,sig] = qmrstat.getBivarCorInputs(obj,curObj);

      end

      if strcmp(crObj(1).FigureOption,'osd')

        [r,t,~,~,hboot,CI] = skipped_correlation(VecX,VecY,XLabel,YLabel,1,sig);

      elseif strcmp(crObj(1).FigureOption,'save')

        [r,t,~,~,hboot,CI,h] = skipped_correlation(VecX,VecY,XLabel,YLabel,1,sig);
        obj.Results.Correlation(zz,kk).Skipped.figure = h;

        if lbIdx>1

          obj.Results.Correlation(zz,kk).Skipped.figLabel = [XLabel '_' YLabel '_' curObj(1).StatLabels(zz)];

        else

          obj.Results.Correlation(zz,kk).Skipped.figLabel = [XLabel '_' YLabel];

        end

      elseif strcmp(crObj(1).FigureOption,'disable')


        [r,t,~,~,hboot,CI] = skipped_correlation(VecX,VecY,XLabel,YLabel,0,sig);

      end

      % Corvis is assigned to caller (qmrstat.Pearson) workspace by
      % the Pearson function.
      % Other fields are filled by Pearson function.

      if obj.Export2Py

        PyVis.XLabel = XLabel;
        PyVis.YLabel = YLabel;
        PyVis.Stats.r = r;
        PyVis.Stats.t = t;
        PyVis.Stats.hboot = hboot;
        PyVis.Stats.CI = CI;
        obj.Results.Correlation(zz,kk).Skipped.PyVis = PyVis;

      end


      obj.Results.Correlation(zz,kk).Skipped.r = r;
      obj.Results.Correlation(zz,kk).Skipped.t = t;
      obj.Results.Correlation(zz,kk).Skipped.hboot = hboot;
      obj.Results.Correlation(zz,kk).Skipped.CI = CI;
    end
  end
end % Correlation
