% NestednessBINMATNEST - NTC (Nestedness Temperature Calculator) algorithm
% This class calculates the nestedness of a matrix using the temperature.
% The value of nestedness if found by normalizing tempereature N = (100-T)
% / 100, and have values between 0 and 1, where 1 is perfectly nested and 0\
% perfectly anti-nested. For information about how this algorithm works you
% can consult the following papers:
%
%     Atmar, Wirt and Patterson, Bruce D. The measure of order and disorder
%     in the distribution of species in fragmented habitat. Oecologia 1993
%
%     Rodriguez-Girones, Miguel A and Santamaria, Luis. A new algorithm to
%     calculate the nestedness temperature of presence--absence matrices.
%     Journal of Biogeography 2006
%
% NestednessBINMATNEST Properties:
%     P - p parameter of the isocline function that is calculated using the fill of the matrix
%     PositionMatrixX - X coordinate of each matrix cell in a unit square
%     PositionMatrixY - Y coordinate of each matrix cell in a unit square
%     dMatrix - distances with the perfect nestedness line
%     DMatrix - Size of the diagonal that cross the matrix element
%     uMatrix - Unexpectedness Matrix
%     T - T emperature
%     CalculatedFill - Calculated fill using the integral of Fxp(P,X). Ideally must have the same value than the fill of the matrix.
%     X - Vector of X coordinate
%     Fxp - Vector of isocline values in y coordinate
%     UMin - Unexpectedness matrix
%     tunsorted - 
%     DoGeometry - Flag to indicate the calculus of geometry
%     done - Flag to indicate if the algorith has ben performed
%     PMax - Maximal P value for finding the isoclane.
%     PMin - Minimal p value for finding the isoclane.
%     UsedArea - Chose a value in 1,2,3
%     DeltaX - X Increment in order to get the vector of the Isoclane values (obj.Fxp)
%     DebugMessages - 1,0 Print Debug Messages
%     K  - Constant to normalize values of T in [0,100]
%     BreakRandom - How many initial random permutations in the matrix
%
% NestednessBINMATNEST Methods:
%    NestednessBINMATNEST - Main Constructor
%    SetMatrix - Change the matrix of the algorithm
%    Detect - Main method calculating Nestedness
%    CalculateMatrixGeometry - Calculate all the geometry aspects
%    AssignMatrixPositions - Map the matrix elements to a unit
%    FindPValue - Find the parameter 'p' of the isocline function
%    GetFilledArea - Get the area above the isocline
%    CalculateDiagonalsAndDistances - Calculate diagonal and isocline distance size matrices
%    CalculateTemperature - Calculate the matrix temperature
%    CalculateUnexpectedness - Calculate the matrix unexpectedness
%    PERFECT_NESTED - Return a perfect nested matrix according to the NTC algorithm
%    FIND_UNEXPECTED_CELLS - Return a matrix that indicate what are the unexpected cells.
%    GET_ISOCLINE - Get the isocline function
%
% See also:
%    NODF
classdef NestednessBINMATNEST < handle

    properties(GetAccess = 'public')%, SetAccess = 'private')
        matrix             = []  % Bipartite Adjacency Matrix
        T                  = 0;  % T emperature
        N                  = 0;  % Nestedness NTC value
        do_geometry        = 1;  % Flag to indicate the calculus of geometry
        n_rows             = 0;  % Number of row nodes
        n_cols             = 0;  % Number of column nodes
        index_rows         = []; % Register of the swaps in Rows.
        index_cols         = []; % Register of the swaps in Cols.
        done               = 0;  % Flag to indicate if the algorith has ben performed
        connectance        = 0;  % Fill of the matrix
        trials             = 50;  
        do_sorting         = true; 
    end
    
    properties(Access = 'private')
        matrix_minimal     = [];
        P                  = 0;  % p parameter of the isocline function that is calculated using the fill of the matrix
        PositionMatrixX    = []; % X coordinate of each matrix cell in a unit square
        PositionMatrixY    = []; % Y coordinate of each matrix cell in a unit square
        dMatrix            = []; % distances with the perfect nestedness line
        DMatrix            = []; % Size of the diagonal that cross the matrix element
        uMatrix            = []; % Unexpectedness Matrix
        CalculatedFill     = 0;  % Calculated fill using the integral of Fxp(P,X). Ideally must have the same value than the fill of the matrix.
        X                  = []; % Vector of X coordinate
        Fxp                = []; % Vector of isocline values in y coordinate
        UMin               = 0;  % Unexpectedness matrix
        tunsorted          = 0;  
        sorting_method     = 2; %1 for NTC, 2 for Sum Heuristic
        n_row_sorts        = 0;
        n_col_sorts        = 0;
    end
    %DEBUG Properties - Change to parametrize and Debug the algorithm;
    properties(Access = 'private')
        PMax               = 99999;      % Maximal P value for finding the isoclane.
        PMin               = 0.0005;     % Minimal p value for finding the isoclane.
        UsedArea           = 2;          % Chose a value in 1,2,3
        DeltaX             = 0.001;      % X Increment in order to get the vector of the Isoclane values (obj.Fxp)
        DebugMessages      = 0;          % 1,0 Print Debug Messages
        K                  = 2.4125e+003 % 100 / 0.04145;  %Value found in the literature
        BreakRandom        = 10;         % How many initial random permutations in the matrix
    end
    
    %CONSTRUCTOR AND MAIN PROCEDURE ALGORITHM
    methods
        function obj = NestednessBINMATNEST(bipmatrix)
        % NestednessBINMATNEST - Main Constructor
        % 
        %   obj = NestednessBINMATNEST(MATRIX) Creates an NestednessBINMATNEST object obj
        %   using a bipartite adjacency matrix MATRIX that will be used to
        %   calculate nestedes using the Nestedness Temperature Calculator
        %   (ntc).
        %
        % See also:
        %    NestednessBINMATNEST
            
            obj.matrix = bipmatrix > 0; %Normalize the matrix
            [obj.n_rows obj.n_cols] = size(obj.matrix);
            obj.connectance = sum(sum(obj.matrix))/(obj.n_rows*obj.n_cols);   
                        
            obj.index_rows = 1:obj.n_rows;
            obj.index_cols = 1:obj.n_cols;

        end
        
        function obj = SetMatrix(obj,matrix)
        % SetMatrix - Change the adjacency matrix of the algorithm
        %
        %   obj = SetMatrix(obj,matrix) Change the matrix in which the
        %   algorithm will be performed. Useful only when the new matrix
        %   has the same size and similar connectance (fill) than a
        %   the old matrix. Usint this method, we do not have to perform
        %   the goemetrical pre-calculus another time (isocline, distances,
        %   diagonals, etc).
            obj.matrix = matrix > 0; %Normalize the matrix
            [obj.n_rows obj.n_cols] = size(matrix);
            obj.connectance = sum(sum(obj.matrix))/numel(obj.matrix);
            obj.index_rows = 1:obj.n_rows;
            obj.index_cols = 1:obj.n_cols;

        end
        
        function obj = Detect(obj)
        % CalculateNestedness - Main method for calculating NTC nestedness
        % Temperature Calculator
        %
        %   obj = CalculateNestedness(obj) Calculates the nestedness of the
        %   matrix. Use obj.N after calling this method to get the
        %   nestedness value, and obj.T for getting the temperature value.
        
            if(isempty(obj.matrix))
                obj.N = NaN;
                obj.T = NaN;
                return;
            end
        
            if(obj.n_rows==1 || obj.n_cols==1)
                obj.N = 0;
                return;
            end
            
            obj.n_row_sorts = 1;
            obj.n_col_sorts = 1;
            
            % Perfrom the calculus of geometry (isocline, distances, etc)
            if(obj.do_geometry)
                obj.CalculateMatrixGeometry();
            end

            %Calculate the temperature
            obj.CalculateTemperature();

            %Normalize the temperature to the nestedness value
            obj.N = (100-obj.T)/100;
            
            %If you want the calculus for a unsorted matrix you are
            %finished. Normally obj.do_sorting = 1, such that you want an optimal ordering. 
            if(obj.do_sorting == 0)
                return;
            end
                        
            % The next part focus in finding the ordering, such that you
            % will have the smaller possible value of temperature (and by
            % consequence the highest nestedness value)
            
            globalMinimalT = 500;
            matrixLocalMinima = [];
            indexRowLocalMinima = [];
            indexColLocalMinima = [];
            indexRowGlobalMinima = [];
            indexColGlobalMinima = [];
            
            
            failedtoincrease = 0; %Count if the next matrix randomization do an improvement
            % Do obj.trials initial random permutations of the
            % matrix to be tested
            for i = 1:obj.trials
                
                % If no increase is detected in obj.BreakRandom continuos
                % trials, no need for continue looking.
                if(failedtoincrease > obj.BreakRandom)
                    %fprintf('Break on i = %i\n',i);
                    break;
                end
                
                
                permutationMinimalT = 500; %temperature infinite
                obj.T = 500;
                
                obj.RandomizeMatrix();
%                i = 1;
                while(1)
                    %display(i);
                    %i = i+1;
                    obj.SortMatrix();
                    obj.CalculateTemperature();
                    
                    if(obj.DebugMessages == 1); fprintf('TLocal = %f T = %f\n', permutationMinimalT,obj.T); end;
                    
                    if(abs(permutationMinimalT - obj.T) <= 0.001 || obj.T > permutationMinimalT)
                        break;
                    end
                        
                    if(obj.T < permutationMinimalT)
                        permutationMinimalT = obj.T;
                        matrixLocalMinima = obj.matrix;
                        indexRowLocalMinima = obj.index_rows;
                        indexColLocalMinima = obj.index_cols;
                    end
                    
                end
                if(obj.DebugMessages == 1); fprintf('finalizo ciclo\n'); end;
                
                %Save if permutation is smaller than the global minimal
                if(permutationMinimalT < globalMinimalT)
                    %fprintf('TMinimalGlob = %f\n', permutationMinimalT);
                    globalMinimalT = permutationMinimalT;
                    obj.matrix_minimal = matrixLocalMinima;
                    indexRowGlobalMinima = indexRowLocalMinima;
                    indexColGlobalMinima = indexColLocalMinima;
                    failedtoincrease = 0;
                end
                
                failedtoincrease = failedtoincrease + 1;
            end
            
           %Keep the best sorting for NTC
           obj.matrix = obj.matrix_minimal;
           obj.index_rows = indexRowGlobalMinima;
           obj.index_cols = indexColGlobalMinima;
           obj.T = globalMinimalT;
           obj.N = (100-obj.T)/100;
            
           obj.done = 1;
           %obj.PrintOutput();
            
        end
        
        function str = Print(obj,filename)
        % Print - Print NTC nestedness information
        %
        %   STR = Print(obj) Print the NTC information to screen and
        %   return this information to the string STR
        %
        %   STR = Print(obj, FILE) Print the NTC information to screen and
        %   text file FILE and return this information to the string STR   
        %
        % See also: 
        %   Printer
        
            str = 'Nestedness NTC:\n';
            str = [str, '\tNTC (Nestedness value):     \t', sprintf('%16.4f',obj.N), '\n'];
            str = [str, '\tT (Temperature value):      \t', sprintf('%16.4f',obj.N), '\n'];
           
            fprintf(str);  
            
            if(nargin==2)
                Printer.PRINT_TO_FILE(str,filename);
            end
            
        end
           
    end

    % GEOMETRY DEFINITION SECTION
    methods(Access = 'protected')
       
        function obj = CalculateMatrixGeometry(obj)
        % CalculateMatrixGeometry - Calculate all the geometry aspects
        % of the algorithm
        %
        % obj = CalculateMatrixGeometry(obj)
        % This function calculate all the matrix geometry in the next
        % order:
        %   1.- Coordinate representation of of the matrix elements in a unit scuare.
        %   2.- Function of the isoclane f(x;p) based in the matrix density Fill
        %   3.- Main diagonal size for all the the matrix elements.
        %   4.- Distance along the main diagonal of all the matrix
        %   elements 
         
            %1.-Coordinate representation of of the matrix elements in a unit scuare.
            obj.AssignMatrixPositions();
            
            %2.- Function of the isoclane f(x;p) based in the matrix density Fill
            obj.X = (0.5/obj.n_cols):obj.DeltaX:((obj.n_cols-0.5)/obj.n_cols); %Define the X Vector of the function
            obj.P = obj.FindPValue();
            obj.Fxp = 0.5/obj.n_rows + ((obj.n_rows-1)/obj.n_rows) * (1-(1-(obj.n_cols*(obj.X)-0.5)/(obj.n_cols-1)).^(obj.P)).^(1/(obj.P));
            %3.-,4.-
            obj.CalculateDiagonalsAndDistances();
            
        end
        
        function obj = AssignMatrixPositions(obj)
        % AssignMatrixPositions - Map the matrix elements to a unit
        % square coordinate system.
        %
        %   obj = AssignMatrixPositiong(obj) - Map the matrix elements to a unit
        %   square coordinate system.
            for i = 1:obj.n_rows
                for j = 1:obj.n_cols
                    obj.PositionMatrixX(i,j) = (j-0.5)/obj.n_cols;
                    obj.PositionMatrixY(i,j) = (obj.n_rows-i+0.5)/obj.n_rows;
                end 
            end
        end
        
        function p = FindPValue(obj)
            % FindPValue - Find the parameter 'p' of the isocline function
            % p = FindPValue(obj) - Get the parameter p of the isocline
            % function by doing a search in the p space and doing a
            % bisection method at the end, such that the area above the
            % isocline is the same than the connectance (fill) of the matrix.
            
            p = obj.PMin; %Starting with the minimal pre-defined value of p parameter
            filledarea = 0; %Area above the curve. The objective is to equalize to obj.connectance.
            while(p < obj.PMax) %After some predefined PMax the increase in p will not affect the form of the isocline
                filledarea = obj.GetFilledArea(p);
                if(obj.connectance > filledarea) 
                    break;
                end
                if(obj.DebugMessages); fprintf('area = %5.4f p = %5.4f\n', filledarea,p); end; 
                p = p*2;          
            end
            
            %if(obj.DebugMessages); fprintf('area = %10.9f p = %5.4f lastp = %5.4f\n', filledarea,upp,lowp); end;
            
            if(p < obj.PMax && p > obj.PMin) %If the parameter p is not an extreme case
                %BISECTION METHOD
                upp = p;
                lowp = p / 2;
                mid = 0;
                while( abs( obj.connectance - filledarea) > 0.001)
                    mid = (upp + lowp)/2;
                    filledarea = obj.GetFilledArea(mid);
                    if(filledarea < obj.connectance)
                        upp = mid;
                    else
                        lowp = mid;
                    end
                    if(obj.DebugMessages); fprintf('area = %10.9f p = %f\n', filledarea,mid); end;        
                end
                if(mid ~= 0)
                    p = mid;
                end;
            end
            
            obj.CalculatedFill = filledarea;
        end
        
        function Area = GetFilledArea(obj,p)
        % GetFilledArea - Get the area above the isocline
        %
        %   Area = GetFilledArea(obj,p) - Ghet the area above the
        %   isocline with parameter p.
            
            
            %Isocline equation
            obj.Fxp = 0.5/obj.n_rows + ((obj.n_rows-1)/obj.n_rows) * (1-(1-(obj.n_cols*(obj.X)-0.5)/(obj.n_cols-1)).^p).^(1/p);
            
            %Area below the isocline
            integral = trapz(obj.X,obj.Fxp);
            
            %Three ways of calculating the area (only important when the
            %matrix is small. Case 2 gives the best results.
            switch obj.UsedArea
                case 1
                    Area = 1 - real(integral);
                case 2
                    Area = 1 - real(integral) - (obj.n_rows-0.5)*(0.5)/(obj.n_rows*obj.n_cols);
                otherwise
                    Area = (obj.n_rows-0.5)/(obj.n_rows-1) - real(integral) * obj.n_rows * obj.n_cols / ((obj.n_cols-1)*(obj.n_rows-1));
            end
        end
        
        function obj = CalculateDiagonalsAndDistances(obj)
        % CalculateDiagonalsAndDistances - Calculate diagonal and
        % isocline distance size matrices
        %
        %   obj = CalculateDiagonalsAndDistances(obj) - Calculate diagonal and
        %   isocline distance size matrices
            obj.uMatrix = zeros(size(obj.matrix));
            MaxDiag = sqrt(2);
            
            obj.DMatrix = zeros(size(obj.matrix));
            obj.dMatrix = zeros(size(obj.matrix));
            
            %For each row and column
            for i = 1:obj.n_rows
                for j = 1:obj.n_cols
                         
                    y1 = real(obj.PositionMatrixX(i,j) + obj.PositionMatrixY(i,j) - obj.X);
                    y2 = obj.Fxp;
                    
                    [~, index] = min(abs(y1-y2));
                    
                    %Intersection point between the diagonal and the
                    %iscoline
                    ycross = y1(index);
                    xcross = obj.X(index);

                    %Distance from the isocline to the matrix element
                    distance = sqrt( (obj.PositionMatrixX(i,j)-xcross)^2 + (obj.PositionMatrixY(i,j)-ycross)^2 );
                    obj.dMatrix(i,j) = distance;
                    obj.DMatrix(i,j) = (obj.PositionMatrixX(i,j) + obj.PositionMatrixY(i,j)) * sqrt(2);

                    if(obj.DMatrix(i,j) > MaxDiag)
                        obj.DMatrix(i,j) = abs(obj.PositionMatrixX(i,j) + obj.PositionMatrixY(i,j) - 2) * sqrt(2);
                    end
                    
                    % Change to negative elements below isocline, such that
                    % the sign will differentiate above vs below isocline
                    % elemnts.
                    if(obj.PositionMatrixY(i,j) < ycross)
                        obj.dMatrix(i,j) = -obj.dMatrix(i,j);
                    end
                end
            end       
        end 
        
    end
    
    
    
    % CALCULATE TEMPERATURE AND IMPORTANT VALUES
    methods(Access = 'protected')
        
        function obj = CalculateTemperature(obj)
            % CalculateTemperature - Calculate the matrix temperature
            %   obj = CalculateTemperature(obj) - Calculate the temperature
            %   using the Atmar standard equation. The temperature is in
            %   the interval [0,100], while the nestedness in the interval
            %   [0,1]. High values of temperature corresponds to low values
            %   of nestedness.
            obj.UMin = obj.CalculateUnexpectedness();
            obj.T = obj.K*obj.UMin;
            obj.N = (100-obj.T)/100;
        end
        
        function unex = CalculateUnexpectedness(obj)
            % CalculateUnexpectedness - Calculate the matrix unexpectedness
            %   obj = CalculateUnexpectedness(obj) - Sum all temperature
            %   contributions from unexpected cells (absences below the
            %   matrix and presences above the matrix)
            obj.uMatrix = zeros(size(obj.matrix));
            obj.uMatrix = ((obj.matrix==0 & obj.dMatrix > 0) | (obj.matrix ~=0 & obj.dMatrix < 0 )).*((obj.dMatrix./obj.DMatrix).^2);   
            unex = sum(sum(obj.uMatrix)) / (obj.n_rows*obj.n_cols);
        end
    end

        % SORTING AND MATRIX MANIPULATIONS
    methods
        
        function obj = SortMatrix(obj)
            %fprintf('I sort\n');
            switch obj.sorting_method
                case 1
                    obj.SortMatrixByNTCHeuristic();
                otherwise
                    obj.SortMatrixBySUMHeuristic();
            end
        end
        
        function obj = SortMatrixByNTCHeuristic(obj)
                        
            %tmsRows = size(n);
            %tmsCols = size(n);
    
            %tmsRows(i) = sum(obj.GetRScore(1));
            %tmsCols(i) = sum(obj.GetRScore(2));

            if(obj.n_cols >= obj.n_rows) 
                obj.ReorderMatrixColumns();
                obj.ReorderMatrixRows();
            else
                obj.ReorderMatrixRows();
                obj.ReorderMatrixColumns();
            end
        end
        
        function obj = SortMatrixBySUMHeuristic(obj)
            
            sumCols = sum(obj.matrix);
            sumRows = sum(obj.matrix,2);
            %sumRows = sum(obj.matrix');
            
            
            [~,tmpic]=sort(sumCols,'descend');
            [~,tmpir]=sort(sumRows,'descend');

            obj.ReorderCols(tmpic);
            obj.ReorderRows(tmpir);
            
        end
         
       
        function obj = ReorderMatrixColumns(obj)

            r = obj.GetRScore(2); %Get the vector r score in columns
            
            [~, indexr] = sort(r);
            
            obj.ReorderCols(indexr);
            
        end
        
        function obj = ReorderMatrixRows(obj)
            
            r = obj.GetRScore(1); %Get the vector r score in rows
            
            [~, indexr] = sort(r);
            
            obj.ReorderRows(indexr);
        end
        
        function r = GetRScore(obj, rowsOrCols)
            %Get the sequence or actual total r score of the rows or
            %columns.
            
            if(rowsOrCols == 1) %Case of Rows
            
                s = zeros(1,obj.n_rows);
                for i = 1:obj.n_rows
                    s(i) = 0;
                    for j = 1:obj.n_cols
                        if(obj.matrix(i,j) > 0)
                            s(i) = s(i) + (j*j);
                        end
                    end
                end

                t = zeros(1,obj.n_rows);
                for i = 1:obj.n_rows
                    t(i) = 0;
                    for j = 1:obj.n_cols
                        if(obj.matrix(i,j) == 0)
                            t(i) = t(i) + (obj.n_cols-j+1)^2;
                        end
                    end
                end
                
            else %Case of Columns
                
                s = zeros(1,obj.n_cols);
                for j = 1:obj.n_cols
                    s(j) = 0;
                    for i = 1:obj.n_rows
                        if(obj.matrix(i,j) > 0)
                            s(j) = s(j) + (i*i);
                        end
                    end
                end

                t = zeros(1,obj.n_cols);
                for j = 1:obj.n_cols
                    t(j) = 0;
                    for i = 1:obj.n_rows
                        if(obj.matrix(i,j) == 0)
                            t(j) = t(j) + (obj.n_rows-i+1)^2;
                        end
                    end
                end
            end
            r = 0.5*t - 0.5*s;
        end
        
        function obj = MirrorMatrix(obj)
            
            mirrorCols = fliplr(obj.index_cols);
            mirrorRows = filplr(obj.index_rows);
            
            obj.ReorderCols(mirrorCols);
            obj.ReorderRows(mirrorRows);
            
        end
        
        function obj = RandomizeMatrix(obj)
            %Creates a random permutation of the matrix
           
            colRandom = randperm(obj.n_cols);
            rowRandom = randperm(obj.n_rows);
            
            obj.ReorderCols(colRandom);
            obj.ReorderRows(rowRandom);
        end
      
        
        function obj = ReorderCols(obj,newIndexes)
             obj.matrix  = obj.matrix(:,newIndexes);
           %= temp;
            obj.index_cols = obj.index_cols(newIndexes);
        end
        
        function obj = ReorderRows(obj,newIndexes)
            temp = obj.matrix(newIndexes,:);
            obj.matrix = temp;
            obj.index_rows = obj.index_rows(newIndexes);
        end

    end
    
    
    
    methods(Static)
        
        function ntc = NTC(matrix)
        % ADAPTIVE_BRIM - Calculate the NTC nestedness
        %
        %   nest = NTC(matrix) Calculate the NTC nestedness,
        %   print the basic information to
        %   screen and return an NestednessBIMATNEST object that contains such
        %   information in nest.
        
            ntc = NestednessBINMATNEST(matrix);
            ntc.CalculateNestedness();
            ntc.Print();
        end
        
        function matrix = PERFECT_NESTED(nrows,ncols,fill)
        % PERFECT_NESTED - Return a perfect nested matrix according to the
        % NTC algorithm
        %
        %   matrix = PERFECT_NESTED(nrows,ncols,fill) - Return a perfect
        %   nested matrix of size nrows by ncols and a connectance = fill.
        %   The perfect nested matrix follows the definition of the NTC
        %   algorithm (the isocline divide ones from zeros in the entire
        %   matrix).
            matrix = zeros(nrows,ncols);
        
            bnest = NetworkBipartite(matrix);
            
            nest = NestednessBINMATNEST(bnest);
            nest.Fill = fill;
            nest = nest.CalculateMatrixGeometry();
            nest = nest.CalculateDiagonalsAndDistances();
            
            for i = 1:nrows
                for j = 1:ncols
                    if(nest.dMatrix(i,j) > 0)
                        matrix(i,j) = 1;
                    else
                        matrix(i,j) = 0;
                    end
                end
            end
            
            matrix(nrows,1) = 1;
            matrix(1,ncols) = 1;
           
        end
        
        function matrix_unex = FIND_UNEXPECTED_CELLS(matrix)
        % FIND_UNEXPECTED_CELLS - Return a matrix that indicate what are the
        % unexpected cells.
        %
        %   matrix = FIND_UNEXPECTED_CELLS(matrix) - For matrix 'matrix',
        %   calculate the geometry in order to return a matrix 'matrix_unex'
        %   with ones in the position of unexpected cells of the original
        %   matrix.
            nest = NestednessBINMATNEST(matrix);
            nest.CalculateMatrixGeometry();
            nest.CalculateUnexpectedness();
            
            matrix_unex = nest.uMatrix > 0;%.0005;
            
        end
        
        function [x y] = GET_ISOCLINE(n_rows,n_cols,p_value)
        % GET_ISOCLINE - Get the isocline function
        %
        %   [x y] = GET_ISOCLINE(n_rows,n_cols,p_value) - Get the isocline
        %   function in x and y vectors for a matrix of size n_rows by
        %   n_cols and a connectance of p_value. Useful when the user is
        %   only interested in the isocline (e.g. plotting) and not the
        %   temperature value.
            if(nargin==1)
                matrix = n_rows>0;
            else
                matrix = zeros(n_rows,n_cols);
                len = n_rows*n_cols;
                matrix(1:round(len*p_value))=1;
            end
            
            nest = NestednessBINMATNEST(matrix);
            
            nest.CalculateMatrixGeometry();
            x = 0.5 + nest.nCols.*nest.X;
            y = 0.5 + nest.nRows.*nest.Fxp;
        end
        
    end
end
